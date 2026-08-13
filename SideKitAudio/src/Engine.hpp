#pragma once

#include "RingBuffer.hpp"
#include "sidekit_audio.h"

#include <cmath>
#include <cstdint>

namespace sidekit {

class Engine {
public:
    Engine(double sample_rate, uint32_t channels);
    uint32_t render(float *interleaved, uint32_t frames);
    void post(ParamCmd cmd);
    SKRenderInfo info() const { return info_; }

private:
    void consumeCommands();

    double sample_rate_;
    uint32_t channels_;
    double phase_ = 0.0;
    float tone_hz_ = 440.f;
    float gain_ = 0.0f;
    bool tone_on_ = false;
    uint64_t sample_time_ = 0;
    SKRenderInfo info_{};
    SpscRing<ParamCmd, 128> commands_;
};

} // namespace sidekit
