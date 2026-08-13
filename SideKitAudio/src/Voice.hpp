#pragma once

#include "Biquad.hpp"
#include "sidekit_audio.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace sidekit {

enum class Wave : uint8_t { Sine, Saw, Tri, Noise };

struct Partial {
    bool active = false;
    Wave wave = Wave::Sine;
    double phase = 0;
    double inc = 0;
    double inc_end = 0;
    float env = 0;
    float decay = 0;
    float amp = 0;
    uint32_t noise = 0xACE1u;
};

struct ChannelVoice {
    static constexpr int kPartials = 6;

    bool playing = false;
    uint8_t pattern = 0;
    float bpm = 120.f;
    double step_accum = 0;
    double samples_per_step = 48000.0 * 60.0 / 120.0 / 4.0;
    int step = 0;

    float gain_db = 0;
    float fader = 0.78f;
    bool mute = false;
    float eq_lo = 0, eq_mid = 0, eq_hi = 0;
    float style_mul = 18.f;
    float level = 0;
    float peak = 0;

    Biquad lo, mid, hi;
    Partial parts[kPartials]{};

    void setBpm(float sr, float new_bpm) {
        bpm = std::clamp(new_bpm, 40.f, 220.f);
        samples_per_step = static_cast<double>(sr) * 60.0 / static_cast<double>(bpm) / 4.0;
    }

    void start(float sr, uint8_t pat, float new_bpm) {
        playing = true;
        pattern = pat;
        setBpm(sr, new_bpm);
        step = 0;
        step_accum = 0;
        for (auto &p : parts) {
            p.active = false;
        }
    }

    void stop() {
        playing = false;
        for (auto &p : parts) {
            p.active = false;
        }
    }

    void updateEQ(float sr) {
        lo.lowshelf(sr, 250.f, eq_lo * style_mul);
        mid.peaking(sr, 1000.f, eq_mid * style_mul * 0.7f, 0.9f);
        hi.highshelf(sr, 4000.f, eq_hi * style_mul);
    }

    void hit(Wave wave, float sr, float hz, float dur, float amp, bool drop = false) {
        int slot = 0;
        float lowest = 2.f;
        for (int i = 0; i < kPartials; ++i) {
            if (!parts[i].active) {
                slot = i;
                break;
            }
            if (parts[i].env < lowest) {
                lowest = parts[i].env;
                slot = i;
            }
        }
        auto &p = parts[slot];
        p.active = true;
        p.wave = wave;
        p.phase = 0;
        p.inc = 2.0 * 3.141592653589793 * static_cast<double>(hz) / static_cast<double>(sr);
        p.inc_end = drop ? p.inc * 0.4 : p.inc;
        p.env = 1.f;
        const float frames = std::max(32.f, dur * sr);
        p.decay = std::exp(-1.f / (frames * 0.45f));
        p.amp = amp;
        p.noise = 0xACE1u + static_cast<uint32_t>(slot * 97 + step * 13);
    }

    void fireStep(float sr) {
        const int s = step & 15;
        switch (pattern) {
        case SK_PATTERN_KICK:
            if (s % 4 == 0) {
                hit(Wave::Sine, sr, 55.f, 0.22f, 0.55f, true);
            }
            if (s == 4 || s == 12) {
                hit(Wave::Noise, sr, 180.f, 0.08f, 0.16f);
            }
            if (s % 2 == 1) {
                hit(Wave::Noise, sr, 8000.f, 0.03f, 0.04f);
            }
            break;
        case SK_PATTERN_BASS: {
            const float notes[8] = {55.f, 55.f, 65.4f, 73.4f, 82.4f, 55.f, 73.4f, 65.4f};
            if (s % 4 == 0 || s == 6 || s == 10) {
                hit(Wave::Saw, sr, notes[s % 8], 0.18f, 0.22f);
            }
            if (s % 8 == 4) {
                hit(Wave::Sine, sr, 90.f, 0.12f, 0.15f);
            }
            break;
        }
        case SK_PATTERN_HAT:
            if (s % 2 == 0) {
                hit(Wave::Noise, sr, 9000.f, 0.04f, 0.08f);
            }
            if (s % 4 == 2) {
                hit(Wave::Noise, sr, 12000.f, 0.03f, 0.05f);
            }
            if (s == 0 || s == 8) {
                hit(Wave::Sine, sr, 60.f, 0.18f, 0.35f, true);
            }
            break;
        case SK_PATTERN_BREAK:
            if (s == 0 || s == 3 || s == 6 || s == 8 || s == 11 || s == 14) {
                hit(Wave::Sine, sr, 50.f, 0.16f, 0.45f, true);
            }
            if (s == 4 || s == 12) {
                hit(Wave::Noise, sr, 200.f, 0.10f, 0.22f);
            }
            if (s % 2 == 1) {
                hit(Wave::Noise, sr, 7000.f, 0.025f, 0.06f);
            }
            break;
        default: {
            const float chord[4] = {220.f, 277.f, 330.f, 392.f};
            if (s == 0 || s == 3 || s == 7 || s == 10 || s == 12) {
                hit(Wave::Tri, sr, chord[s % 4], 0.25f, 0.14f);
            }
            if (s % 8 == 0) {
                hit(Wave::Sine, sr, 55.f, 0.2f, 0.3f, true);
            }
            break;
        }
        }
        step = (step + 1) & 15;
    }

    float tick(float sr) {
        if (playing) {
            step_accum += 1.0;
            if (step_accum >= samples_per_step) {
                step_accum -= samples_per_step;
                fireStep(sr);
            }
        }

        float s = 0.f;
        for (auto &p : parts) {
            if (!p.active) {
                continue;
            }
            float o = 0.f;
            switch (p.wave) {
            case Wave::Sine:
                o = static_cast<float>(std::sin(p.phase));
                break;
            case Wave::Saw:
                o = static_cast<float>(2.0 * (p.phase / (2.0 * 3.141592653589793) - std::floor(p.phase / (2.0 * 3.141592653589793) + 0.5)));
                break;
            case Wave::Tri: {
                const double t = p.phase / (2.0 * 3.141592653589793);
                const double f = t - std::floor(t);
                o = static_cast<float>(std::fabs(2.0 * f - 1.0) * 2.0 - 1.0);
                break;
            }
            case Wave::Noise:
                p.noise = p.noise * 1664525u + 1013904223u;
                o = static_cast<float>(static_cast<int32_t>(p.noise) / 2147483648.0);
                break;
            }
            s += o * p.env * p.amp;
            p.phase += p.inc;
            if (p.inc_end < p.inc) {
                p.inc += (p.inc_end - p.inc) * 0.0025;
            }
            if (p.phase > 2.0 * 3.141592653589793) {
                p.phase -= 2.0 * 3.141592653589793;
            }
            p.env *= p.decay;
            if (p.env < 0.0008f) {
                p.active = false;
            }
        }

        s = hi.process(mid.process(lo.process(s)));
        s *= level;
        const float a = std::fabs(s);
        peak = peak * 0.995f + a * 0.005f;
        if (a > peak) {
            peak = a;
        }
        return s;
    }
};

} // namespace sidekit
