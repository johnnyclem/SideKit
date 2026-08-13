#pragma once

#include "Biquad.hpp"
#include "Wsola.hpp"
#include "sidekit_audio.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace sidekit {

enum class Wave : uint8_t { Sine, Saw, Tri, Noise };

inline uint32_t fadeFramesFor(float sr) {
    const auto n = static_cast<uint32_t>(std::lround(static_cast<double>(sr) * (SK_FADE_MS / 1000.0)));
    return n < 1 ? 1 : n;
}

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
    bool want_playing = false;
    uint8_t pattern = 0;
    float bpm = 120.f;
    float sr_ = 48000.f;
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

    const float *clip_pcm = nullptr;
    uint32_t clip_frames = 0;
    double clip_pos = 0;
    bool has_clip = false;

    float pitch_pct = 0.f;
    float rate_z = 1.f;
    bool wsola_on = false;
    Wsola wsola{};

    int fade_dir = 0; // +1 in, -1 out, 0 idle
    uint32_t fade_i = 0;
    uint32_t fade_len = 240;

    Biquad lo, mid, hi;
    Partial parts[kPartials]{};

    void setBpm(float sr, float new_bpm) {
        sr_ = sr;
        bpm = std::clamp(new_bpm, 40.f, 220.f);
        samples_per_step = static_cast<double>(sr) * 60.0 / static_cast<double>(bpm) / 4.0;
        fade_len = fadeFramesFor(sr);
    }

    void beginFadeIn() {
        fade_len = fadeFramesFor(sr_);
        fade_i = 0;
        fade_dir = 1;
    }

    void beginFadeOut() {
        fade_len = fadeFramesFor(sr_);
        fade_i = 0;
        fade_dir = -1;
    }

    float fadeGain() const {
        if (fade_dir == 0) {
            return playing ? 1.f : 0.f;
        }
        const float t = static_cast<float>(fade_i) / static_cast<float>(fade_len < 1 ? 1 : fade_len);
        const float clamped = std::clamp(t, 0.f, 1.f);
        const float half_pi = 1.5707963267948966f;
        if (fade_dir > 0) {
            return std::sin(half_pi * clamped);
        }
        return std::cos(half_pi * clamped);
    }

    void finishFade() {
        if (fade_dir < 0) {
            playing = false;
            want_playing = false;
            for (auto &p : parts) {
                p.active = false;
            }
        }
        fade_dir = 0;
        fade_i = 0;
    }

    void stepFade() {
        if (fade_dir == 0) {
            return;
        }
        ++fade_i;
        if (fade_i >= fade_len) {
            finishFade();
        }
    }

    void setPitch(float percent) {
        pitch_pct = std::clamp(percent, -8.f, 8.f);
        if (std::fabs(pitch_pct) < 0.02f) {
            pitch_pct = 0.f;
            rate_z = 1.f;
        }
    }

    float targetRate() const { return 1.f + pitch_pct * 0.01f; }

    void attachClip(const float *pcm, uint32_t frames) {
        clip_pcm = pcm;
        clip_frames = frames;
        clip_pos = 0;
        has_clip = pcm != nullptr && frames > 0;
        fade_dir = 0;
        fade_i = 0;
        wsola_on = false;
        wsola.reset(0);
        rate_z = targetRate();
        for (auto &p : parts) {
            p.active = false;
        }
    }

    void clearClip() {
        clip_pcm = nullptr;
        clip_frames = 0;
        clip_pos = 0;
        has_clip = false;
    }

    uint32_t playheadFrame() const {
        if (clip_frames == 0) {
            return 0;
        }
        if (clip_pos <= 0) {
            return 0;
        }
        if (clip_pos >= clip_frames) {
            return clip_frames;
        }
        return static_cast<uint32_t>(clip_pos);
    }

    void seekFrames(uint32_t frame) {
        if (!has_clip || clip_frames == 0) {
            return;
        }
        if (frame >= clip_frames) {
            frame = clip_frames - 1;
        }
        clip_pos = static_cast<double>(frame);
        wsola_on = false;
        wsola.reset(clip_pos);
        if (playing || want_playing) {
            beginFadeIn();
        }
    }

    void seekNorm(float n) {
        if (!has_clip || clip_frames == 0) {
            return;
        }
        n = std::clamp(n, 0.f, 1.f);
        uint32_t frame = 0;
        if (n >= 1.f) {
            frame = clip_frames - 1;
        } else if (n > 0.f) {
            frame = static_cast<uint32_t>(std::llround(static_cast<double>(n) * static_cast<double>(clip_frames)));
            if (frame >= clip_frames) {
                frame = clip_frames - 1;
            }
        }
        seekFrames(frame);
    }

    void restart() {
        clip_pos = 0;
        step = 0;
        step_accum = 0;
        wsola_on = false;
        wsola.reset(0);
        if (want_playing || playing) {
            want_playing = true;
            playing = true;
            beginFadeIn();
        }
    }

    void start(float sr, uint8_t pat, float new_bpm) {
        setBpm(sr, new_bpm);
        pattern = pat;
        want_playing = true;
        playing = true;
        if (has_clip && clip_pos >= clip_frames) {
            clip_pos = 0;
        }
        if (!has_clip) {
            step = 0;
            step_accum = 0;
            for (auto &p : parts) {
                p.active = false;
            }
        }
        beginFadeIn();
    }

    void stop() {
        want_playing = false;
        if (!playing && fade_dir == 0) {
            return;
        }
        beginFadeOut();
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

    float readClipLinear(double inc) {
        if (!clip_pcm || clip_frames == 0) {
            return 0.f;
        }
        if (clip_pos >= clip_frames) {
            clip_pos = clip_frames;
            want_playing = false;
            playing = false;
            fade_dir = 0;
            wsola_on = false;
            return 0.f;
        }
        const auto i0 = static_cast<uint32_t>(clip_pos);
        const uint32_t i1 = (i0 + 1 < clip_frames) ? i0 + 1 : i0;
        const float frac = static_cast<float>(clip_pos - static_cast<double>(i0));
        const float l = clip_pcm[i0 * 2] + (clip_pcm[i1 * 2] - clip_pcm[i0 * 2]) * frac;
        const float r = clip_pcm[i0 * 2 + 1] + (clip_pcm[i1 * 2 + 1] - clip_pcm[i0 * 2 + 1]) * frac;
        clip_pos += inc;
        return (l + r) * 0.5f;
    }

    float readClip() {
        if (!clip_pcm || clip_frames == 0) {
            return 0.f;
        }
        const float target = targetRate();
        rate_z += (target - rate_z) * 0.004f;
        const bool stretch = std::fabs(rate_z - 1.f) > 0.0008f;
        if (!stretch) {
            wsola_on = false;
            return readClipLinear(1.0);
        }
        if (!wsola_on) {
            wsola.reset(clip_pos);
            wsola_on = true;
        }
        const float s = wsola.pull(clip_pcm, clip_frames, rate_z);
        clip_pos = wsola.playhead();
        if (wsola.ended || clip_pos >= clip_frames) {
            clip_pos = clip_frames;
            want_playing = false;
            playing = false;
            fade_dir = 0;
            wsola_on = false;
        }
        return s;
    }

    float tick(float sr) {
        sr_ = sr;
        fade_len = fadeFramesFor(sr);

        if (has_clip && playing && fade_dir == 0 && clip_frames > 0) {
            const auto remain = clip_frames - playheadFrame();
            const auto need = static_cast<uint32_t>(std::lround(static_cast<double>(fade_len) * std::max(0.5f, rate_z)));
            if (remain > 0 && remain <= need) {
                beginFadeOut();
            }
        }

        float s = 0.f;
        const bool audible = playing || fade_dir != 0;

        if (has_clip && audible) {
            s = readClip();
        } else {
            if (playing && !has_clip) {
                step_accum += 1.0;
                if (step_accum >= samples_per_step) {
                    step_accum -= samples_per_step;
                    fireStep(sr);
                }
            }
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
                    o = static_cast<float>(2.0 * (p.phase / (2.0 * 3.141592653589793) -
                                                  std::floor(p.phase / (2.0 * 3.141592653589793) + 0.5)));
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
        }

        s *= fadeGain();
        stepFade();

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
