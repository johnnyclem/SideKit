#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>

namespace sidekit {

template <typename T, std::size_t Capacity>
class SpscRing {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of two");

public:
    bool push(const T &item) {
        const auto h = head_.load(std::memory_order_relaxed);
        const auto n = (h + 1) & mask_;
        if (n == tail_.load(std::memory_order_acquire)) {
            return false;
        }
        buf_[h] = item;
        head_.store(n, std::memory_order_release);
        return true;
    }

    bool pop(T &out) {
        const auto t = tail_.load(std::memory_order_relaxed);
        if (t == head_.load(std::memory_order_acquire)) {
            return false;
        }
        out = buf_[t];
        tail_.store((t + 1) & mask_, std::memory_order_release);
        return true;
    }

private:
    static constexpr std::size_t mask_ = Capacity - 1;
    T buf_[Capacity]{};
    alignas(64) std::atomic<std::size_t> head_{0};
    alignas(64) std::atomic<std::size_t> tail_{0};
};

enum class ParamId : uint8_t {
    Master = 1,
    Crossfader = 2,
    ChannelMix = 3,
    ChannelEQ = 4,
    Transport = 5,
    TestToneEnable = 6,
    TestToneHz = 7,
    OutputGain = 8,
    LoadClip = 9,
    ClearClip = 10,
    ClipSeek = 11,
};

struct ParamCmd {
    ParamId id;
    uint8_t ch;
    float a;
    float b;
    float c;
    float d;
};

} // namespace sidekit
