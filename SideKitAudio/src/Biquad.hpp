#pragma once

#include <cmath>

namespace sidekit {

/// RBJ biquad. Coeffs updated on the audio thread only when a command lands.
struct Biquad {
    float b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
    float z1 = 0, z2 = 0;

    float process(float x) {
        const float y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        return y;
    }

    void reset() { z1 = z2 = 0; }

    void lowshelf(float sr, float hz, float gain_db) {
        const float a = std::pow(10.f, gain_db / 40.f);
        const float w = 2.f * 3.14159265f * hz / sr;
        const float cs = std::cos(w);
        const float sn = std::sin(w);
        const float s = 1.f;
        const float beta = std::sqrt(a) / s;
        const float b0n = a * ((a + 1) - (a - 1) * cs + beta * sn);
        const float b1n = 2 * a * ((a - 1) - (a + 1) * cs);
        const float b2n = a * ((a + 1) - (a - 1) * cs - beta * sn);
        const float a0n = (a + 1) + (a - 1) * cs + beta * sn;
        const float a1n = -2 * ((a - 1) + (a + 1) * cs);
        const float a2n = (a + 1) + (a - 1) * cs - beta * sn;
        set(b0n, b1n, b2n, a0n, a1n, a2n);
    }

    void peaking(float sr, float hz, float gain_db, float q) {
        const float a = std::pow(10.f, gain_db / 40.f);
        const float w = 2.f * 3.14159265f * hz / sr;
        const float cs = std::cos(w);
        const float sn = std::sin(w);
        const float alpha = sn / (2.f * q);
        const float b0n = 1 + alpha * a;
        const float b1n = -2 * cs;
        const float b2n = 1 - alpha * a;
        const float a0n = 1 + alpha / a;
        const float a1n = -2 * cs;
        const float a2n = 1 - alpha / a;
        set(b0n, b1n, b2n, a0n, a1n, a2n);
    }

    void highshelf(float sr, float hz, float gain_db) {
        const float a = std::pow(10.f, gain_db / 40.f);
        const float w = 2.f * 3.14159265f * hz / sr;
        const float cs = std::cos(w);
        const float sn = std::sin(w);
        const float s = 1.f;
        const float beta = std::sqrt(a) / s;
        const float b0n = a * ((a + 1) + (a - 1) * cs + beta * sn);
        const float b1n = -2 * a * ((a - 1) + (a + 1) * cs);
        const float b2n = a * ((a + 1) + (a - 1) * cs - beta * sn);
        const float a0n = (a + 1) - (a - 1) * cs + beta * sn;
        const float a1n = 2 * ((a - 1) - (a + 1) * cs);
        const float a2n = (a + 1) - (a - 1) * cs - beta * sn;
        set(b0n, b1n, b2n, a0n, a1n, a2n);
    }

private:
    void set(float b0n, float b1n, float b2n, float a0n, float a1n, float a2n) {
        const float inv = 1.f / a0n;
        b0 = b0n * inv;
        b1 = b1n * inv;
        b2 = b2n * inv;
        a1 = a1n * inv;
        a2 = a2n * inv;
    }
};

} // namespace sidekit
