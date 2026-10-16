#pragma once

#include "RingBuffer.hpp"
#include "Voice.hpp"
#include "sidekit_audio.h"

#include <cstdint>

namespace sidekit {

struct ClipBank {
    static constexpr int kSlots = 2;
    float *pcm[kSlots] = {nullptr, nullptr};
    uint32_t frames[kSlots] = {0, 0};
    uint32_t live = 0;

    ~ClipBank() {
        delete[] pcm[0];
        delete[] pcm[1];
    }

    ClipBank() = default;
    ClipBank(const ClipBank &) = delete;
    ClipBank &operator=(const ClipBank &) = delete;
};

class Engine {
public:
    Engine(double sample_rate, uint32_t channels);
    ~Engine() = default;
    uint32_t render(float *interleaved, uint32_t frames);
    void post(ParamCmd cmd);
    int loadClip(uint8_t ch, const float *interleaved, uint32_t frames, uint32_t channels);
    void requestClearClip(uint8_t ch);
    SKClipInfo clipInfo(uint8_t ch) const;
    SKRenderInfo info() const { return info_; }

private:
    void consumeCommands();
    ChannelVoice &voice(uint8_t ch);
    const ChannelVoice &voice(uint8_t ch) const;
    ClipBank &bank(uint8_t ch);

    double sample_rate_;
    uint32_t channels_;
    ChannelVoice ch1_{};
    ChannelVoice ch2_{};
    ClipBank clip1_{};
    ClipBank clip2_{};
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
