#include "Engine.hpp"

#include <algorithm>
#include <cmath>
#include <new>

namespace sidekit {

namespace {
float dbToLin(float db) { return std::pow(10.f, db / 20.f); }

float equalPower(float x) {
    x = std::clamp(x, 0.f, 1.f);
    return std::cos((1.f - x) * 0.5f * 3.14159265f);
}
} // namespace

Engine::Engine(double sample_rate, uint32_t channels)
    : sample_rate_(sample_rate > 0 ? sample_rate : 48000.0)
    , channels_(channels == 0 ? 2 : channels) {
    ch1_.updateEQ(static_cast<float>(sample_rate_));
    ch2_.updateEQ(static_cast<float>(sample_rate_));
    ch1_.setBpm(static_cast<float>(sample_rate_), 120.f);
    ch2_.setBpm(static_cast<float>(sample_rate_), 128.f);
}

ChannelVoice &Engine::voice(uint8_t ch) { return ch == 2 ? ch2_ : ch1_; }

void Engine::post(ParamCmd cmd) { commands_.push(cmd); }

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

const char *sk_engine_version(void) { return "0.2.0-sk004"; }

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
        reinterpret_cast<sidekit::Engine *>(engine)->post({sidekit::ParamId::Master, 0, linear, 0, 0, 0});
    }
}

void sk_engine_set_crossfader(SKEngine *engine, float xf) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post({sidekit::ParamId::Crossfader, 0, xf, 0, 0, 0});
    }
}

void sk_engine_set_channel_mix(SKEngine *engine, uint32_t ch, float gain_db, float fader, int mute) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(
            {sidekit::ParamId::ChannelMix, static_cast<uint8_t>(ch), gain_db, fader, mute ? 1.f : 0.f, 0});
    }
}

void sk_engine_set_channel_eq(SKEngine *engine, uint32_t ch, float lo, float mid, float hi, float style_mul) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(
            {sidekit::ParamId::ChannelEQ, static_cast<uint8_t>(ch), lo, mid, hi, style_mul});
    }
}

void sk_engine_set_transport(SKEngine *engine, uint32_t ch, int playing, uint32_t pattern, float bpm) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post(
            {sidekit::ParamId::Transport, static_cast<uint8_t>(ch), playing ? 1.f : 0.f,
             static_cast<float>(pattern), bpm, 0});
    }
}

void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz) {
    if (!engine) {
        return;
    }
    auto *e = reinterpret_cast<sidekit::Engine *>(engine);
    e->post({sidekit::ParamId::TestToneEnable, 0, enabled ? 1.f : 0.f, 0, 0, 0});
    e->post({sidekit::ParamId::TestToneHz, 0, hz, 0, 0, 0});
}

void sk_engine_set_output_gain(SKEngine *engine, float linear) {
    if (engine) {
        reinterpret_cast<sidekit::Engine *>(engine)->post({sidekit::ParamId::OutputGain, 0, linear, 0, 0, 0});
    }
}

} // extern "C"
