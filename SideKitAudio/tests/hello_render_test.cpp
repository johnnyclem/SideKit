#include "Decode.hpp"
#include "sidekit_audio.h"

#include <atomic>
#include <cmath>
#include <cstdio>
#include <ctime>
#include <cstring>
#include <new>
#include <string>
#include <vector>

static std::atomic<long> g_allocs{0};
static bool g_count_allocs = false;

void *operator new(std::size_t n) {
    if (g_count_allocs) {
        g_allocs.fetch_add(1, std::memory_order_relaxed);
    }
    void *p = std::malloc(n);
    if (!p) {
        throw std::bad_alloc();
    }
    return p;
}

void operator delete(void *p) noexcept { std::free(p); }
void operator delete(void *p, std::size_t) noexcept { std::free(p); }
void *operator new[](std::size_t n) { return operator new(n); }
void operator delete[](void *p) noexcept { operator delete(p); }
void operator delete[](void *p, std::size_t) noexcept { operator delete(p); }

static int fail(const char *msg) {
    std::fprintf(stderr, "FAIL: %s\n", msg);
    return 1;
}

static void fillSine(std::vector<float> &buf, uint32_t frames, uint32_t ch, double sr, float hz, float amp) {
    buf.assign(static_cast<size_t>(frames) * ch, 0.f);
    for (uint32_t i = 0; i < frames; ++i) {
        const float s = amp * static_cast<float>(std::sin(2.0 * 3.141592653589793 * hz * i / sr));
        for (uint32_t c = 0; c < ch; ++c) {
            buf[i * ch + c] = s;
        }
    }
}

static float goertzel(const float *x, int n, int stride, float freq, float sr) {
    const float k = 0.5f + static_cast<float>(n) * freq / sr;
    const float w = 2.f * 3.14159265f * k / static_cast<float>(n);
    const float c = 2.f * std::cos(w);
    float s0 = 0, s1 = 0, s2 = 0;
    for (int i = 0; i < n; ++i) {
        s0 = x[i * stride] + c * s1 - s2;
        s2 = s1;
        s1 = s0;
    }
    return s1 * s1 + s2 * s2 - c * s1 * s2;
}

int main() {
    const char *ver = sk_engine_version();
    if (!ver || std::strstr(ver, "sk012") == nullptr) {
        return fail("version should be sk012");
    }

    SKEngine *eng = sk_engine_create(48000.0, 2);
    if (!eng) {
        return fail("create");
    }

    std::vector<float> buf(4096 * 2, 1.f);

    // 1. Silence on start.
    uint32_t n = sk_engine_render(eng, buf.data(), 256);
    SKRenderInfo info = sk_engine_last_info(eng);
    if (n != 256 || info.peak > 1e-6f) {
        std::fprintf(stderr, "FAIL: start silence peak=%f n=%u\n", info.peak, n);
        return 1;
    }

    // 2. Pattern still works (no clip).
    sk_engine_set_master(eng, 0.9f);
    sk_engine_set_crossfader(eng, 0.0f);
    sk_engine_set_channel_mix(eng, 1, 0.f, 0.85f, 0);
    sk_engine_set_transport(eng, 1, 1, SK_PATTERN_KICK, 120.f);
    float kick = 0.f;
    for (int i = 0; i < 20; ++i) {
        sk_engine_render(eng, buf.data(), 1024);
        kick = std::max(kick, sk_engine_last_info(eng).peak_ch1);
    }
    if (kick < 0.02f) {
        std::fprintf(stderr, "FAIL: kick energy=%f\n", kick);
        return 1;
    }
    sk_engine_set_transport(eng, 1, 0, SK_PATTERN_KICK, 120.f);
    for (int i = 0; i < 8; ++i) {
        sk_engine_render(eng, buf.data(), 2048);
    }

    // 3. WAV write/decode + 44.1 → 48 k resample.
    const char *wav48 = "/tmp/sk010_48k.wav";
    const char *wav44 = "/tmp/sk010_441.wav";
    const char *garbage = "/tmp/sk010_garbage.bin";

    std::vector<float> tone48;
    fillSine(tone48, 48000 / 4, 2, 48000.0, 440.f, 0.5f);
    if (!sidekit::writeWavS16(wav48, tone48.data(), 48000 / 4, 2, 48000)) {
        return fail("write 48k wav");
    }

    std::vector<float> tone44;
    fillSine(tone44, 44100 / 4, 1, 44100.0, 440.f, 0.5f); // mono 44.1
    if (!sidekit::writeWavS16(wav44, tone44.data(), 44100 / 4, 1, 44100)) {
        return fail("write 44.1 wav");
    }

    FILE *gf = std::fopen(garbage, "wb");
    std::fwrite("not a codec", 1, 11, gf);
    std::fclose(gf);

    float *decoded = nullptr;
    uint32_t dframes = 0, dch = 0;
    double dsr = 0;
    if (!sk_wav_decode_file(wav48, &decoded, &dframes, &dch, &dsr) || dframes != 12000 || dch != 2 || dsr != 48000.0) {
        std::fprintf(stderr, "FAIL: decode 48k frames=%u ch=%u sr=%f\n", dframes, dch, dsr);
        return 1;
    }
    if (std::fabs(decoded[0]) < 0.01f && std::fabs(decoded[20]) < 0.01f) {
        return fail("decoded 48k is silent");
    }
    sk_pcm_free(decoded);

    decoded = nullptr;
    if (!sk_wav_decode_file(wav44, &decoded, &dframes, &dch, &dsr) || dch != 1 || std::fabs(dsr - 44100.0) > 0.1) {
        return fail("decode 44.1");
    }
    const uint32_t expect48 = static_cast<uint32_t>(std::llround(dframes * (48000.0 / 44100.0)));
    std::vector<float> rs(static_cast<size_t>(expect48 + 8) * 2);
    uint32_t out_n = sk_resample_stereo(decoded, dframes, dch, dsr, rs.data(), expect48 + 8, 48000.0);
    sk_pcm_free(decoded);
    if (out_n != expect48 || expect48 < 11900 || expect48 > 12100) {
        std::fprintf(stderr, "FAIL: resample frames=%u expect≈12000\n", out_n);
        return 1;
    }

    if (sk_wav_decode_file(garbage, &decoded, &dframes, &dch, &dsr)) {
        return fail("garbage file should fail");
    }

    // 4. Load resampled clip, play, energy, then stop → silence.
    if (!sk_engine_load_clip(eng, 1, rs.data(), out_n, 2)) {
        return fail("load clip");
    }
    sk_engine_set_channel_mix(eng, 1, 0.f, 0.9f, 0);
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    float clip_peak = 0.f;
    for (int i = 0; i < 12; ++i) {
        sk_engine_render(eng, buf.data(), 1024);
        info = sk_engine_last_info(eng);
        clip_peak = std::max(clip_peak, info.peak_ch1);
    }
    SKClipInfo clip = sk_engine_clip_info(eng, 1);
    if (!clip.loaded || clip.frames != out_n) {
        return fail("clip info after load");
    }
    if (clip_peak < 0.05f) {
        std::fprintf(stderr, "FAIL: clip peak=%f\n", clip_peak);
        return 1;
    }

    sk_engine_set_transport(eng, 1, 0, 0, 120.f);
    for (int i = 0; i < 6; ++i) {
        sk_engine_render(eng, buf.data(), 1024);
    }
    if (sk_engine_last_info(eng).peak > 0.01f) {
        return fail("clip pause leak");
    }

    // 5. Clear clip, no pattern play → silence.
    sk_engine_clear_clip(eng, 1);
    sk_engine_render(eng, buf.data(), 512);
    clip = sk_engine_clip_info(eng, 1);
    if (clip.loaded) {
        return fail("clip still loaded after clear");
    }

    // 6. No allocations on the audio thread while playing a clip.
    if (!sk_engine_load_clip(eng, 1, tone48.data(), 48000 / 4, 2)) {
        return fail("reload 48k clip");
    }
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    sk_engine_render(eng, buf.data(), 256); // apply load/transport
    g_allocs.store(0);
    g_count_allocs = true;
    for (int i = 0; i < 16; ++i) {
        sk_engine_set_channel_mix(eng, 1, -2.f, 0.8f, 0);
        sk_engine_set_clip_position(eng, 1, 0.1f);
        sk_engine_render(eng, buf.data(), 512);
    }
    g_count_allocs = false;
    const long allocs = g_allocs.load();
    if (allocs != 0) {
        std::fprintf(stderr, "FAIL: %ld allocations during clip render\n", allocs);
        return 1;
    }

    // 7. SK-011: frame-accurate seek while stopped.
    sk_engine_set_transport(eng, 1, 0, 0, 120.f);
    for (int i = 0; i < 4; ++i) {
        sk_engine_render(eng, buf.data(), 512);
    }
    sk_engine_seek_frames(eng, 1, 1234);
    sk_engine_render(eng, buf.data(), 64);
    clip = sk_engine_clip_info(eng, 1);
    if (clip.playhead != 1234) {
        std::fprintf(stderr, "FAIL: stopped seek playhead=%u want 1234\n", clip.playhead);
        return 1;
    }
    if (clip.playing) {
        return fail("stopped seek should not start playback");
    }

    // 8. Seek while playing: after one quantum, playhead is target + frames (±1).
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    sk_engine_seek_frames(eng, 1, 5000);
    sk_engine_render(eng, buf.data(), 256);
    clip = sk_engine_clip_info(eng, 1);
    const int drift = static_cast<int>(clip.playhead) - static_cast<int>(5000 + 256);
    if (std::abs(drift) > 1 || !clip.playing) {
        std::fprintf(stderr, "FAIL: playing seek playhead=%u playing=%d drift=%d\n", clip.playhead, clip.playing,
                     drift);
        return 1;
    }

    // 9. Restart → playhead 0 after one quantum (then advances if playing).
    sk_engine_restart(eng, 1);
    sk_engine_render(eng, buf.data(), 128);
    clip = sk_engine_clip_info(eng, 1);
    if (clip.playhead > 128 + 1) {
        std::fprintf(stderr, "FAIL: restart playhead=%u\n", clip.playhead);
        return 1;
    }

    // 10. Equal-power fade-in ≤ 5 ms, first sample near 0.
    sk_engine_set_transport(eng, 1, 0, 0, 120.f);
    for (int i = 0; i < 4; ++i) {
        sk_engine_render(eng, buf.data(), 512);
    }
    sk_engine_seek_frames(eng, 1, 0);
    sk_engine_set_channel_mix(eng, 1, 0.f, 1.f, 0);
    sk_engine_set_master(eng, 1.f);
    sk_engine_set_crossfader(eng, 0.f);
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    std::vector<float> fade(480 * 2, 0.f);
    sk_engine_render(eng, fade.data(), 240);
    const float s0 = std::fabs(fade[0]);
    const float sMid = std::fabs(fade[120 * 2]);
    const float sEnd = std::fabs(fade[239 * 2]);
    if (s0 > 0.02f) {
        std::fprintf(stderr, "FAIL: fade-in click s0=%f\n", s0);
        return 1;
    }
    if (!(s0 < sMid && sMid < sEnd + 0.05f) || sEnd < 0.05f) {
        std::fprintf(stderr, "FAIL: fade-in shape s0=%f mid=%f end=%f\n", s0, sMid, sEnd);
        return 1;
    }

    // 11. Fade-out ≤ 5 ms → silence, playing=0 after one extra quantum.
    sk_engine_set_transport(eng, 1, 0, 0, 120.f);
    std::vector<float> fadeOut(480 * 2, 0.f);
    sk_engine_render(eng, fadeOut.data(), 240);
    const float o0 = std::fabs(fadeOut[0]);
    const float oEnd = std::fabs(fadeOut[239 * 2]);
    if (oEnd > 0.02f) {
        std::fprintf(stderr, "FAIL: fade-out tail oEnd=%f\n", oEnd);
        return 1;
    }
    if (o0 + 0.01f < oEnd) {
        std::fprintf(stderr, "FAIL: fade-out rose o0=%f oEnd=%f\n", o0, oEnd);
        return 1;
    }
    sk_engine_render(eng, buf.data(), 64);
    clip = sk_engine_clip_info(eng, 1);
    if (clip.playing) {
        return fail("playing still set after fade-out");
    }

    // 12. SK-012: +8% time-stretch keeps 440 Hz (key lock) and advances ~1.08×.
    std::vector<float> sine2;
    fillSine(sine2, 48000 * 2, 2, 48000.0, 440.f, 0.55f);
    if (!sk_engine_load_clip(eng, 1, sine2.data(), 48000 * 2, 2)) {
        return fail("load sine2");
    }
    sk_engine_set_channel_mix(eng, 1, 0.f, 1.f, 0);
    sk_engine_set_master(eng, 1.f);
    sk_engine_set_crossfader(eng, 0.f);
    sk_engine_set_pitch(eng, 1, 8.f);
    sk_engine_seek_frames(eng, 1, 4000);
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    std::vector<float> stretch(8192 * 2, 0.f);
    sk_engine_render(eng, stretch.data(), 2048); // warmup fade + WSOLA
    const uint32_t ph0 = sk_engine_clip_info(eng, 1).playhead;
    sk_engine_render(eng, stretch.data(), 4800);
    const uint32_t ph1 = sk_engine_clip_info(eng, 1).playhead;
    const float ratio = static_cast<float>(ph1 - ph0) / 4800.f;
    if (ratio < 1.03f || ratio > 1.14f) {
        std::fprintf(stderr, "FAIL: +8%% playhead ratio=%f (ph %u→%u)\n", ratio, ph0, ph1);
        return 1;
    }
    const float g440 = goertzel(stretch.data(), 4800, 2, 440.f, 48000.f);
    const float g475 = goertzel(stretch.data(), 4800, 2, 475.2f, 48000.f);
    if (g440 < g475 * 1.2f) {
        std::fprintf(stderr, "FAIL: key lock 440=%g 475=%g\n", g440, g475);
        return 1;
    }

    // 13. -8% slower playhead.
    sk_engine_set_pitch(eng, 1, -8.f);
    sk_engine_seek_frames(eng, 1, 8000);
    sk_engine_render(eng, stretch.data(), 1024);
    const uint32_t ph2 = sk_engine_clip_info(eng, 1).playhead;
    sk_engine_render(eng, stretch.data(), 4800);
    const uint32_t ph3 = sk_engine_clip_info(eng, 1).playhead;
    const float ratioLo = static_cast<float>(ph3 - ph2) / 4800.f;
    if (ratioLo < 0.86f || ratioLo > 0.97f) {
        std::fprintf(stderr, "FAIL: -8%% playhead ratio=%f\n", ratioLo);
        return 1;
    }

    // 14. Continuous pitch drag: no zipper vs steady tone.
    sk_engine_set_pitch(eng, 1, 0.f);
    sk_engine_seek_frames(eng, 1, 2000);
    sk_engine_set_transport(eng, 1, 1, 0, 120.f);
    sk_engine_render(eng, stretch.data(), 2048);
    float steady_d = 0.f;
    sk_engine_set_pitch(eng, 1, 8.f);
    sk_engine_render(eng, stretch.data(), 4096);
    for (int i = 1; i < 4096; ++i) {
        steady_d = std::max(steady_d, std::fabs(stretch[i * 2] - stretch[(i - 1) * 2]));
    }
    float sweep_d = 0.f;
    for (int step = 16; step >= 0; --step) { // +8 → -8, continuous
        sk_engine_set_pitch(eng, 1, -8.f + step * 1.f);
        sk_engine_render(eng, stretch.data(), 128);
        for (int i = 1; i < 128; ++i) {
            sweep_d = std::max(sweep_d, std::fabs(stretch[i * 2] - stretch[(i - 1) * 2]));
        }
    }
    if (sweep_d > steady_d * 3.2f + 0.08f) {
        std::fprintf(stderr, "FAIL: zipper sweep=%f steady=%f\n", sweep_d, steady_d);
        return 1;
    }

    // 15. Reset to 0% restores 1.0× playhead.
    sk_engine_set_pitch(eng, 1, 0.f);
    sk_engine_seek_frames(eng, 1, 3000);
    sk_engine_render(eng, stretch.data(), 512);
    const uint32_t ph4 = sk_engine_clip_info(eng, 1).playhead;
    sk_engine_render(eng, stretch.data(), 1024);
    const uint32_t ph5 = sk_engine_clip_info(eng, 1).playhead;
    const int zeroDrift = static_cast<int>(ph5) - static_cast<int>(ph4) - 1024;
    if (std::abs(zeroDrift) > 4) {
        std::fprintf(stderr, "FAIL: pitch 0 playhead drift=%d\n", zeroDrift);
        return 1;
    }

    // 16. CPU proxy: 1 s of +8% stretch should be well under 15% of realtime.
    {
        const auto t0 = std::clock();
        for (int i = 0; i < 48; ++i) {
            sk_engine_render(eng, stretch.data(), 1000);
        }
        const double sec = static_cast<double>(std::clock() - t0) / CLOCKS_PER_SEC;
        if (sec > 0.45) {
            std::fprintf(stderr, "FAIL: stretch CPU %.3fs for 1s audio\n", sec);
            return 1;
        }
        std::printf("     stretch cpu %.3fs / 1s audio (%.0f%% core)\n", sec, sec * 100.0);
    }

    sk_engine_destroy(eng);
    std::printf("OK  SideKitAudio %s  stretch +8%% ratio=%.3f keylock 440/475=%.2f\n", ver, ratio, g440 / std::max(g475, 1e-9f));
    return 0;
}
