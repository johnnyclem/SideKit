#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>

namespace sidekit {

/// Single-producer / single-consumer ring. Capacity must be power of two.
/// Producer = main/UI thread. Consumer = audio thread. No allocations after ctor.
template <typename T, std::size_t Capacity>
class SpscRing {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of two");

public:
    bool push(const T &item) {
        const auto h = head_.load(std::memory_order_relaxed);
        const auto n = (h + 1) & mask_;
        if (n == tail_.load(std::memory_order_acquire)) {
            return false; // full
        }
        buf_[h] = item;
        head_.store(n, std::memory_order_release);
        return true;
    }

    bool pop(T &out) {
        const auto t = tail_.load(std::memory_order_relaxed);
        if (t == head_.load(std::memory_order_acquire)) {
            return false; // empty
        }
        out = buf_[t];
        tail_.store((t + 1) & mask_, std::memory_order_release);
        return true;
    }

    void drain(void (*fn)(const T &, void *), void *ctx) {
        T item{};
        while (pop(item)) {
            fn(item, ctx);
        }
    }

private:
    static constexpr std::size_t mask_ = Capacity - 1;
    T buf_[Capacity]{};
    alignas(64) std::atomic<std::size_t> head_{0};
    alignas(64) std::atomic<std::size_t> tail_{0};
};

enum class ParamId : uint8_t {
    TestToneEnable = 1,
    TestToneHz = 2,
    OutputGain = 3,
};

struct ParamCmd {
    ParamId id;
    float value;
};

} // namespace sidekit
