#include "sidekit_audio.h"

#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <new>
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

int main() {
    const char *ver = sk_engine_version();
    if (!ver || ver[0] == '\0') {
        return fail("empty version");
    }

    SKEngine *eng = sk_engine_create(48000.0, 2);
    if (!eng) {
        return fail("create");
    }

    std::vector<float> buf(4096 * 2, 1.f);

    // 1. Graph start → silence (no transport, no tone).
    uint32_t n = sk_engine_render(eng, buf.data(), 256);
    SKRenderInfo info = sk_engine_last_info(eng);
    if (n != 256 || info.peak > 1e-6f) {
        std::fprintf(stderr, "FAIL: start silence peak=%f n=%u\n", info.peak, n);
        return 1;
    }

    // 2. Diagnostic tone still works via SPSC.
    sk_engine_set_test_tone(eng, 1, 440.f);
    sk_engine_set_output_gain(eng, 0.25f);
    n = sk_engine_render(eng, buf.data(), 256);
    info = sk_engine_last_info(eng);
    if (n != 256 || info.peak < 0.1f || info.peak > 0.3f) {
        std::fprintf(stderr, "FAIL: tone peak=%f\n", info.peak);
        return 1;
    }
    if (info.commands_applied < 2) {
        return fail("tone commands not consumed");
    }
    sk_engine_set_test_tone(eng, 0, 440.f);
    sk_engine_set_output_gain(eng, 0.f);
    sk_engine_render(eng, buf.data(), 2048); // flush tone + smoother
    info = sk_engine_last_info(eng);
    if (info.peak > 1e-4f) {
        std::fprintf(stderr, "FAIL: tone stop leak peak=%f\n", info.peak);
        return 1;
    }

    // 3. Transport on deck A → energy. Stop → silence.
    sk_engine_set_master(eng, 0.9f);
    sk_engine_set_crossfader(eng, 0.0f); // full A
    sk_engine_set_channel_mix(eng, 1, 0.f, 0.85f, 0);
    sk_engine_set_channel_eq(eng, 1, 0.f, 0.f, 0.f, 18.f);
    sk_engine_set_transport(eng, 1, 1, SK_PATTERN_KICK, 120.f);

    float energy = 0.f;
    for (int block = 0; block < 20; ++block) {
        sk_engine_render(eng, buf.data(), 1024);
        info = sk_engine_last_info(eng);
        energy = std::max(energy, info.peak_ch1);
    }
    if (energy < 0.02f) {
        std::fprintf(stderr, "FAIL: kick energy=%f\n", energy);
        return 1;
    }

    sk_engine_set_transport(eng, 1, 0, SK_PATTERN_KICK, 120.f);
    for (int block = 0; block < 8; ++block) {
        sk_engine_render(eng, buf.data(), 2048);
    }
    info = sk_engine_last_info(eng);
    if (info.peak > 0.01f || info.peak_ch1 > 0.01f) {
        std::fprintf(stderr, "FAIL: stop leak peak=%f ch1=%f\n", info.peak, info.peak_ch1);
        return 1;
    }

    // 4. Mute kills output while transport stays on.
    sk_engine_set_transport(eng, 1, 1, SK_PATTERN_BASS, 110.f);
    for (int i = 0; i < 8; ++i) {
        sk_engine_render(eng, buf.data(), 1024);
    }
    sk_engine_set_channel_mix(eng, 1, 0.f, 0.85f, 1);
    for (int i = 0; i < 6; ++i) {
        sk_engine_render(eng, buf.data(), 1024);
    }
    info = sk_engine_last_info(eng);
    if (info.peak > 0.01f) {
        std::fprintf(stderr, "FAIL: mute leak peak=%f\n", info.peak);
        return 1;
    }
    sk_engine_set_transport(eng, 1, 0, 0, 120.f);
    sk_engine_set_channel_mix(eng, 1, 0.f, 0.85f, 0);
    sk_engine_render(eng, buf.data(), 1024);

    // 5. No allocations on the audio thread.
    g_allocs.store(0);
    g_count_allocs = true;
    for (int i = 0; i < 16; ++i) {
        sk_engine_set_channel_mix(eng, 1, -3.f, 0.7f, 0);
        sk_engine_set_crossfader(eng, 0.4f);
        sk_engine_render(eng, buf.data(), 512);
    }
    g_count_allocs = false;
    const long allocs = g_allocs.load();
    if (allocs != 0) {
        std::fprintf(stderr, "FAIL: %ld allocations during render\n", allocs);
        return 1;
    }

    sk_engine_destroy(eng);
    std::printf("OK  SideKitAudio %s  sk004 render/SPSC/silence/no-alloc  kick=%.3f\n", ver, energy);
    return 0;
}
