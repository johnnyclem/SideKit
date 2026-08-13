#include "Engine.hpp"
#include "Decode.hpp"
#include "Peaks.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <new>

namespace sidekit {

namespace {
float dbToLin(float db) { return std::pow(10.f, db / 20.f); }

float equalPower(float x) {
    x = std::clamp(x, 0.f, 1.f);
    return std::cos((1.f - x) * 0.5f * 3.14159265f);
}
} // namespace

ParamCmd makeCmd(ParamId id, uint8_t ch, float a = 0, float b = 0, float c = 0, float d = 0, uint32_t u = 0) {
    return ParamCmd{id, ch, a, b, c, d, u};
}

Engine::Engine(double sample_rate, uint32_t channels)
    : sample_rate_(sample_rate > 0 ? sample_rate : 48000.0)
    , channels_(channels == 0 ? 2 : channels) {
    ch1_.updateEQ(static_cast<float>(sample_rate_));
    ch2_.updateEQ(static_cast<float>(sample_rate_));
    ch1_.setBpm(static_cast<float>(sample_rate_), 120.f);
    ch2_.setBpm(static_cast<float>(sample_rate_), 128.f);
}

ChannelVoice &Engine::voice(uint8_t ch) { return ch == 2 ? ch2_ : ch1_; }
const ChannelVoice &Engine::voice(uint8_t ch) const { return ch == 2 ? ch2_ : ch1_; }
ClipBank &Engine::bank(uint8_t ch) { return ch == 2 ? clip2_ : clip1_; }

void Engine::post(ParamCmd cmd) { commands_.push(cmd); }

int Engine::loadClip(uint8_t ch, const float *interleaved, uint32_t frames, uint32_t channels) {
    if (!interleaved || frames == 0 || frames > kMaxClipFrames || (channels != 1 && channels != 2)) {
        return 0;
    }
    auto &b = bank(ch);
    const uint32_t dest = 1 - b.live;
    float *buf = new (std::nothrow) float[static_cast<size_t>(frames) * 2];
    if (!buf) {
        return 0;
    }
    upmixToStereo(interleaved, frames, channels, buf);
    delete[] b.pcm[dest];
    b.pcm[dest] = buf;
    b.frames[dest] = frames;
    post(makeCmd(ParamId::LoadClip, ch, static_cast<float>(dest), static_cast<float>(frames)));
    return 1;
}

void Engine::requestClearClip(uint8_t ch) { post(makeCmd(ParamId::ClearClip, ch)); }

SKClipInfo Engine::clipInfo(uint8_t ch) const {
    const auto &v = voice(ch);
    SKClipInfo info{};
    info.frames = v.clip_frames;
    info.playhead = v.playheadFrame();
    info.channels = 2;
    info.loaded = v.has_clip ? 1 : 0;
    info.playing = v.want_playing ? 1 : 0;
    info.fading = v.fade_dir != 0 ? 1 : 0;
    return info;
}

void Engine::consumeCommands() {
    ParamCmd cmd{};
    const float sr = static_cast<float>(sample_rate_);
    while (commands_.pop(cmd)) {
        ++commands_applied_;
        switch (cmd.id) {
        case ParamId::Master:
            master_ = std::clamp(cmd.a, 0.f, 1.5f);
            break;
        case ParamId::Crossfader:
            xf_ = std::clamp(cmd.a, 0.f, 1.f);
            break;
        case ParamId::ChannelMix: {
            auto &v = voice(cmd.ch);
            v.gain_db = std::clamp(cmd.a, -24.f, 24.f);
            v.fader = std::clamp(cmd.b, 0.f, 1.f);
            v.mute = cmd.c > 0.5f;
            break;
        }
        case ParamId::ChannelEQ: {
            auto &v = voice(cmd.ch);
            v.eq_lo = std::clamp(cmd.a, -1.f, 1.f);
            v.eq_mid = std::clamp(cmd.b, -1.f, 1.f);
            v.eq_hi = std::clamp(cmd.c, -1.f, 1.f);
            v.style_mul = std::clamp(cmd.d, 6.f, 24.f);
            v.updateEQ(sr);
            break;
        }
        case ParamId::Transport: {
            auto &v = voice(cmd.ch);
            const bool play = cmd.a > 0.5f;
            const auto pat = static_cast<uint8_t>(std::clamp(cmd.b, 0.f, 4.f));
            if (play) {
                v.start(sr, pat, cmd.c);
            } else {
                v.stop();
            }
            break;
        }
        case ParamId::TestToneEnable:
            tone_on_ = cmd.a > 0.5f;
            break;
        case ParamId::TestToneHz:
            tone_hz_ = std::clamp(cmd.a, 20.f, 12000.f);
            break;
        case ParamId::OutputGain:
            tone_gain_ = std::clamp(cmd.a, 0.f, 1.f);
            break;
        case ParamId::LoadClip: {
            auto &b = bank(cmd.ch);
            const auto slot = static_cast<uint32_t>(cmd.a) & 1u;
            b.live = slot;
            voice(cmd.ch).attachClip(b.pcm[slot], b.frames[slot]);
            break;
        }
        case ParamId::ClearClip:
            voice(cmd.ch).clearClip();
            break;
        case ParamId::ClipSeek:
            voice(cmd.ch).seekNorm(cmd.a);
            break;
        case ParamId::SeekFrames:
            voice(cmd.ch).seekFrames(cmd.u);
            break;
        case ParamId::Restart:
            voice(cmd.ch).restart();
            break;
        case ParamId::Pitch:
            voice(cmd.ch).setPitch(cmd.a);
            break;
        }
    }
}

uint32_t Engine::render(float *interleaved, uint32_t frames) {
    if (!interleaved || frames == 0) {
        return 0;
    }

    consumeCommands();

    const float sr = static_cast<float>(sample_rate_);
    const float xf1 = equalPower(1.f - xf_);
    const float xf2 = equalPower(xf_);
    const float t1 = ch1_.mute ? 0.f : ch1_.fader * dbToLin(ch1_.gain_db) * xf1 * 0.55f * master_;
    const float t2 = ch2_.mute ? 0.f : ch2_.fader * dbToLin(ch2_.gain_db) * xf2 * 0.55f * master_;

    const double two_pi = 6.283185307179586;
    const double tone_inc = two_pi * static_cast<double>(tone_hz_) / sample_rate_;

    float peak = 0.f;
    float p1 = 0.f;
    float p2 = 0.f;

    for (uint32_t i = 0; i < frames; ++i) {
        ch1_.level += (t1 - ch1_.level) * 0.0025f;
        ch2_.level += (t2 - ch2_.level) * 0.0025f;

        const float s1 = ch1_.tick(sr);
        const float s2 = ch2_.tick(sr);
        float mix = s1 + s2;

        if (tone_on_ && tone_gain_ > 0.f) {
            mix += static_cast<float>(std::sin(phase_)) * tone_gain_;
            phase_ += tone_inc;
            if (phase_ >= two_pi) {
                phase_ -= two_pi;
            }
        }

        mix = std::clamp(mix, -1.f, 1.f);
        const float a = std::fabs(mix);
        if (a > peak) {
            peak = a;
        }
        const float a1 = std::fabs(s1);
        const float a2 = std::fabs(s2);
        if (a1 > p1) {
            p1 = a1;
        }
        if (a2 > p2) {
            p2 = a2;
        }

        for (uint32_t c = 0; c < channels_; ++c) {
            interleaved[i * channels_ + c] = mix;
        }
    }

    sample_time_ += frames;
    info_.frames_rendered = frames;
    info_.sample_time = sample_time_;
    info_.peak = peak;
    info_.peak_ch1 = p1;
    info_.peak_ch2 = p2;
    info_.commands_applied = commands_applied_;
    return frames;
}

} // namespace sidekit

extern "C" {

const char *sk_engine_version(void) { return "0.6.0-sk013"; }

SKEngine *sk_engine_create(double sample_rate, uint32_t channels) {
    auto *engine = new (std::nothrow) sidekit::Engine(sample_rate, channels);
    return reinterpret_cast<SKEngine *>(engine);
}

void sk_engine_destroy(SKEngine *engine) {
    delete reinterpret_cast<sidekit::Engine *>(engine);
}

uint32_t sk_engine_render(SKEngine *engine, float *interleaved, uint32_t frames) {
    if (!engine) {
        return 0;
    }
    return reinterpret_cast<sidekit::Engine *>(engine)->render(interleaved, frames);
}

SKRenderInfo sk_engine_last_info(const SKEngine *engine) {
    if (!engine) {
        return SKRenderInfo{0, 0, 0.f, 0.f, 0.f, 0};
    }
    return reinterpret_cast<const sidekit::Engine *>(engine)->info();
}

void sk_engine_set_master(SKEngine *engine, float linear) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::Master, 0, linear));
    }
}

void sk_engine_set_crossfader(SKEngine *engine, float xf) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::Crossfader, 0, xf));
    }
}

void sk_engine_set_channel_mix(SKEngine *engine, uint32_t ch, float gain_db, float fader, int mute) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::ChannelMix, static_cast<uint8_t>(ch), gain_db, fader, mute ? 1.f : 0.f));
    }
}

void sk_engine_set_channel_eq(SKEngine *engine, uint32_t ch, float lo, float mid, float hi, float style_mul) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::ChannelEQ, static_cast<uint8_t>(ch), lo, mid, hi, style_mul));
    }
}

void sk_engine_set_transport(SKEngine *engine, uint32_t ch, int playing, uint32_t pattern, float bpm) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::Transport, static_cast<uint8_t>(ch), playing ? 1.f : 0.f, static_cast<float>(pattern), bpm));
    }
}

void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz) {
    if (!engine) {
        return;
    }
    auto *e = reinterpret_cast<sidekit::Engine *>(engine);
    e->post(sidekit::makeCmd(sidekit::ParamId::TestToneEnable, 0, enabled ? 1.f : 0.f));
    e->post(sidekit::makeCmd(sidekit::ParamId::TestToneHz, 0, hz));
}

void sk_engine_set_output_gain(SKEngine *engine, float linear) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::OutputGain, 0, linear));
    }
}

int sk_engine_load_clip(SKEngine *engine, uint32_t ch, const float *interleaved, uint32_t frames, uint32_t channels) {
    if (!engine) {
        return 0;
    }
    return reinterpret_cast<sidekit::Engine *>(engine)->loadClip(static_cast<uint8_t>(ch), interleaved, frames, channels);
}

void sk_engine_clear_clip(SKEngine *engine, uint32_t ch) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->requestClearClip(static_cast<uint8_t>(ch));
    }
}

SKClipInfo sk_engine_clip_info(const SKEngine *engine, uint32_t ch) {
    if (!engine) {
        return SKClipInfo{0, 0, 2, 0, 0, 0};
    }
    return reinterpret_cast<const sidekit::Engine *>(engine)->clipInfo(static_cast<uint8_t>(ch));
}

void sk_engine_set_clip_position(SKEngine *engine, uint32_t ch, float normalized) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::ClipSeek, static_cast<uint8_t>(ch), normalized));
    }
}

void sk_engine_seek_frames(SKEngine *engine, uint32_t ch, uint32_t frame) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::SeekFrames, static_cast<uint8_t>(ch), 0, 0, 0, 0, frame));
    }
}

void sk_engine_restart(SKEngine *engine, uint32_t ch) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(sidekit::makeCmd(sidekit::ParamId::Restart, static_cast<uint8_t>(ch)));
    }
}

void sk_engine_set_pitch(SKEngine *engine, uint32_t ch, float percent) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(
            sidekit::makeCmd(sidekit::ParamId::Pitch, static_cast<uint8_t>(ch), percent));
    }
}

uint32_t sk_resample_stereo(const float *in, uint32_t in_frames, uint32_t in_ch, double in_sr, float *out,
                            uint32_t out_capacity, double out_sr) {
    return sidekit::resampleStereo(in, in_frames, in_ch, in_sr, out, out_capacity, out_sr);
}

int sk_wav_decode_file(const char *path, float **out_interleaved, uint32_t *frames, uint32_t *channels, double *sr) {
    if (!path || !out_interleaved || !frames || !channels || !sr) {
        return 0;
    }
    sidekit::WavData wav;
    if (!sidekit::decodeWav(path, wav)) {
        return 0;
    }
    auto *buf = new (std::nothrow) float[wav.pcm.size()];
    if (!buf) {
        return 0;
    }
    std::memcpy(buf, wav.pcm.data(), wav.pcm.size() * sizeof(float));
    *out_interleaved = buf;
    *frames = wav.frames;
    *channels = wav.channels;
    *sr = wav.sample_rate;
    return 1;
}

void sk_pcm_free(float *p) { delete[] p; }

uint32_t sk_peaks_build(const float *interleaved, uint32_t frames, uint32_t channels, float *out_min, float *out_max,
                        uint32_t bins) {
    return sidekit::buildPeaks(interleaved, frames, channels, out_min, out_max, bins);
}

int sk_peaks_write(const char *path, uint32_t frames, const float *mn, const float *mx, uint32_t bins) {
    return sidekit::writePeaks(path, frames, mn, mx, bins);
}

int sk_peaks_read(const char *path, uint32_t *frames, float *mn, float *mx, uint32_t bins_cap, uint32_t *bins_out) {
    return sidekit::readPeaks(path, frames, mn, mx, bins_cap, bins_out);
}

} // extern "C"
