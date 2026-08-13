#pragma once

#include "RingBuffer.hpp"
#include "Voice.hpp"
#include "sidekit_audio.h"

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
    ChannelVoice &voice(uint8_t ch);

    double sample_rate_;
    uint32_t channels_;
    ChannelVoice ch1_{};
    ChannelVoice ch2_{};
    float master_ = 0.82f;
    float xf_ = 0.5f;
    double phase_ = 0.0;
    float tone_hz_ = 440.f;
    float tone_gain_ = 0.f;
    bool tone_on_ = false;
    uint64_t sample_time_ = 0;
    uint32_t commands_applied_ = 0;
    SKRenderInfo info_{};
    SpscRing<ParamCmd, 256> commands_;
};

} // namespace sidekit
