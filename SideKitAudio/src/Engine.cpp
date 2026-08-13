#include "Engine.hpp"

#include <algorithm>
#include <cstring>
#include <new>

namespace sidekit {

Engine::Engine(double sample_rate, uint32_t channels)
    : sample_rate_(sample_rate > 0 ? sample_rate : 48000.0)
    , channels_(channels == 0 ? 2 : channels) {}

void Engine::post(ParamCmd cmd) {
    commands_.push(cmd);
}

void Engine::consumeCommands() {
    ParamCmd cmd{};
    while (commands_.pop(cmd)) {
        switch (cmd.id) {
        case ParamId::TestToneEnable:
            tone_on_ = cmd.value > 0.5f;
            break;
        case ParamId::TestToneHz:
            tone_hz_ = std::clamp(cmd.value, 20.f, 12000.f);
            break;
        case ParamId::OutputGain:
            gain_ = std::clamp(cmd.value, 0.f, 1.f);
            break;
        }
    }
}

uint32_t Engine::render(float *interleaved, uint32_t frames) {
    if (!interleaved || frames == 0) {
        return 0;
    }

    consumeCommands();

    const double two_pi = 6.283185307179586;
    const double inc = two_pi * static_cast<double>(tone_hz_) / sample_rate_;
    float peak = 0.f;

    for (uint32_t i = 0; i < frames; ++i) {
        float s = 0.f;
        if (tone_on_ && gain_ > 0.f) {
            s = static_cast<float>(std::sin(phase_)) * gain_;
            phase_ += inc;
            if (phase_ >= two_pi) {
                phase_ -= two_pi;
            }
        }
        const float a = std::fabs(s);
        if (a > peak) {
            peak = a;
        }
        for (uint32_t c = 0; c < channels_; ++c) {
            interleaved[i * channels_ + c] = s;
        }
    }

    sample_time_ += frames;
    info_.frames_rendered = frames;
    info_.sample_time = sample_time_;
    info_.peak = peak;
    return frames;
}

} // namespace sidekit

extern "C" {

const char *sk_engine_version(void) { return "0.1.0-sk001"; }

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
        return SKRenderInfo{0, 0, 0.f};
    }
    return reinterpret_cast<const sidekit::Engine *>(engine)->info();
}

void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz) {
    if (!engine) {
        return;
    }
    auto *e = reinterpret_cast<sidekit::Engine *>(engine);
    e->post({sidekit::ParamId::TestToneEnable, enabled ? 1.f : 0.f});
    e->post({sidekit::ParamId::TestToneHz, hz});
}

void sk_engine_set_output_gain(SKEngine *engine, float linear) {
    if (!engine) {
        return;
    }
    reinterpret_cast<sidekit::Engine *>(engine)->post({sidekit::ParamId::OutputGain, linear});
}

} // extern "C"
