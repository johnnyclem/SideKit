#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>

namespace sidekit {

inline constexpr uint32_t kPeakMagic = 0x4B504B53u; // 'SKPK'
inline constexpr uint32_t kPeakVersion = 1;
inline constexpr uint32_t kPeakBinsDefault = 320;

inline uint32_t buildPeaks(const float *interleaved, uint32_t frames, uint32_t channels, float *out_min,
                           float *out_max, uint32_t bins) {
    if (!interleaved || !out_min || !out_max || frames == 0 || bins == 0 || channels == 0) {
        return 0;
    }
    const uint32_t ch = channels;
    for (uint32_t b = 0; b < bins; ++b) {
        const uint32_t start = static_cast<uint32_t>((static_cast<uint64_t>(b) * frames) / bins);
        uint32_t end = static_cast<uint32_t>((static_cast<uint64_t>(b + 1) * frames) / bins);
        if (end <= start) {
            end = start + 1;
        }
        if (end > frames) {
            end = frames;
        }
        float mn = 1.f;
        float mx = -1.f;
        for (uint32_t i = start; i < end; ++i) {
            float s = 0.f;
            if (ch == 1) {
                s = interleaved[i];
            } else {
                s = 0.5f * (interleaved[i * ch] + interleaved[i * ch + 1]);
            }
            mn = std::min(mn, s);
            mx = std::max(mx, s);
        }
        out_min[b] = mn;
        out_max[b] = mx;
    }
    return bins;
}

inline int writePeaks(const char *path, uint32_t frames, const float *mn, const float *mx, uint32_t bins) {
    if (!path || !mn || !mx || bins == 0) {
        return 0;
    }
    FILE *f = std::fopen(path, "wb");
    if (!f) {
        return 0;
    }
    const uint32_t hdr[4] = {kPeakMagic, kPeakVersion, frames, bins};
    if (std::fwrite(hdr, sizeof(uint32_t), 4, f) != 4) {
        std::fclose(f);
        return 0;
    }
    for (uint32_t i = 0; i < bins; ++i) {
        const float pair[2] = {mn[i], mx[i]};
        if (std::fwrite(pair, sizeof(float), 2, f) != 2) {
            std::fclose(f);
            return 0;
        }
    }
    std::fclose(f);
    return 1;
}

inline int readPeaks(const char *path, uint32_t *frames, float *mn, float *mx, uint32_t bins_cap, uint32_t *bins_out) {
    if (!path || !frames || !mn || !mx || !bins_out || bins_cap == 0) {
        return 0;
    }
    FILE *f = std::fopen(path, "rb");
    if (!f) {
        return 0;
    }
    uint32_t hdr[4] = {0, 0, 0, 0};
    if (std::fread(hdr, sizeof(uint32_t), 4, f) != 4 || hdr[0] != kPeakMagic || hdr[1] != kPeakVersion || hdr[3] == 0 ||
        hdr[3] > bins_cap) {
        std::fclose(f);
        return 0;
    }
    *frames = hdr[2];
    *bins_out = hdr[3];
    for (uint32_t i = 0; i < hdr[3]; ++i) {
        float pair[2] = {0, 0};
        if (std::fread(pair, sizeof(float), 2, f) != 2) {
            std::fclose(f);
            return 0;
        }
        mn[i] = pair[0];
        mx[i] = pair[1];
    }
    std::fclose(f);
    return 1;
}

} // namespace sidekit
