#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>

namespace sidekit {

/// Realtime WSOLA time-stretch for DJ pitch ±8% (tempo in, key locked).
/// All storage is inline — no allocations after construction.
struct Wsola {
    static constexpr int kN = 1024;
    static constexpr int kHa = 256;
    static constexpr int kSearch = 72;

    float ola[kN]{};
    float prev[kN]{};
    float win[kN]{};
    int read_i = 0;
    bool have_prev = false;
    bool primed = false;
    double desired = 0; // tempo timeline — search must not accumulate into this
    float rate = 1.f;
    int ended = 0;

    Wsola() {
        for (int i = 0; i < kN; ++i) {
            win[i] = 0.5f - 0.5f * std::cos(6.283185307179586f * static_cast<float>(i) / static_cast<float>(kN - 1));
        }
    }

    void reset(double pos) {
        std::memset(ola, 0, sizeof(ola));
        std::memset(prev, 0, sizeof(prev));
        read_i = kHa;
        have_prev = false;
        primed = false;
        desired = pos;
        ended = 0;
    }

    double playhead() const {
        const double hs = static_cast<double>(kHa) * static_cast<double>(rate);
        if (!primed) {
            return desired;
        }
        return (desired - hs) + static_cast<double>(std::min(read_i, kHa)) * static_cast<double>(rate);
    }

    static float monoAt(const float *stereo, uint32_t frames, int idx) {
        if (frames == 0) {
            return 0.f;
        }
        if (idx < 0) {
            idx = 0;
        }
        if (idx >= static_cast<int>(frames)) {
            idx = static_cast<int>(frames) - 1;
        }
        const float l = stereo[static_cast<uint32_t>(idx) * 2];
        const float r = stereo[static_cast<uint32_t>(idx) * 2 + 1];
        return (l + r) * 0.5f;
    }

    int search(const float *stereo, uint32_t frames, int expected) const {
        const int ov = kN - kHa;
        float best = -1e30f;
        int best_d = 0;
        const int lo = -kSearch;
        const int hi = kSearch;
        for (int d = lo; d <= hi; d += 2) {
            const int pos = expected + d;
            if (pos < 0 || pos + ov >= static_cast<int>(frames)) {
                continue;
            }
            float corr = 0.f;
            for (int i = 0; i < ov; i += 2) {
                corr += prev[kHa + i] * monoAt(stereo, frames, pos + i);
            }
            if (corr > best) {
                best = corr;
                best_d = d;
            }
        }
        return best_d;
    }

    void shift() {
        for (int i = 0; i < kN - kHa; ++i) {
            ola[i] = ola[i + kHa];
        }
        for (int i = kN - kHa; i < kN; ++i) {
            ola[i] = 0.f;
        }
        read_i = 0;
    }

    void synthesize(const float *stereo, uint32_t frames) {
        if (frames == 0) {
            ended = 1;
            return;
        }
        if (primed) {
            shift();
        } else {
            std::memset(ola, 0, sizeof(ola));
            read_i = 0;
            primed = true;
        }

        const int expected = static_cast<int>(std::lround(desired));
        int start = expected;
        if (have_prev) {
            start = expected + search(stereo, frames, expected);
        }
        if (start < 0) {
            start = 0;
        }
        if (start + kN >= static_cast<int>(frames)) {
            if (expected + 8 >= static_cast<int>(frames)) {
                ended = 1;
                return;
            }
            start = std::max(0, static_cast<int>(frames) - kN);
        }

        for (int i = 0; i < kN; ++i) {
            const float s = monoAt(stereo, frames, start + i) * win[i];
            ola[i] += s;
            prev[i] = s;
        }
        have_prev = true;
        desired += static_cast<double>(kHa) * static_cast<double>(rate);
    }

    float pull(const float *stereo, uint32_t frames, float rate_target) {
        rate += (rate_target - rate) * 0.15f;
        if (ended) {
            return 0.f;
        }
        if (!primed || read_i >= kHa) {
            synthesize(stereo, frames);
            if (ended) {
                return 0.f;
            }
        }
        if (read_i >= kHa) {
            return 0.f;
        }
        return ola[read_i++];
    }
};

} // namespace sidekit
