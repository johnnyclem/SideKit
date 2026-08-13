#include "sidekit_audio.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

int main() {
    const char *ver = sk_engine_version();
    if (!ver || ver[0] == '\0') {
        std::fprintf(stderr, "FAIL: empty version\n");
        return 1;
    }

    SKEngine *eng = sk_engine_create(48000.0, 2);
    if (!eng) {
        std::fprintf(stderr, "FAIL: create\n");
        return 1;
    }

    // Silence path: peak must stay 0.
    std::vector<float> buf(256 * 2, 1.f);
    uint32_t n = sk_engine_render(eng, buf.data(), 128);
    if (n != 128) {
        std::fprintf(stderr, "FAIL: silence frames %u\n", n);
        return 1;
    }
    SKRenderInfo info = sk_engine_last_info(eng);
    if (info.peak > 1e-6f) {
        std::fprintf(stderr, "FAIL: silence leaked peak=%f\n", info.peak);
        return 1;
    }

    // Hello tone path: 440 Hz at ~-12 dB should produce a non-zero peak.
    sk_engine_set_test_tone(eng, 1, 440.f);
    sk_engine_set_output_gain(eng, 0.25f);
    n = sk_engine_render(eng, buf.data(), 256);
    info = sk_engine_last_info(eng);
    if (n != 256 || info.peak < 0.1f || info.peak > 0.3f) {
        std::fprintf(stderr, "FAIL: tone peak=%f frames=%u\n", info.peak, n);
        return 1;
    }
    if (info.sample_time != 128 + 256) {
        std::fprintf(stderr, "FAIL: sample_time %llu\n",
                     static_cast<unsigned long long>(info.sample_time));
        return 1;
    }

    if (std::fabs(buf[0] - buf[1]) > 1e-6f) {
        std::fprintf(stderr, "FAIL: L/R mismatch\n");
        return 1;
    }

    sk_engine_destroy(eng);
    std::printf("OK  SideKitAudio %s  hello render callback ran  peak=%.3f  t=%llu\n",
                ver, info.peak, static_cast<unsigned long long>(info.sample_time));
    return 0;
}
