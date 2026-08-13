#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

namespace sidekit {

inline constexpr uint32_t kEngineRate = 48000;
inline constexpr uint32_t kMaxClipFrames = 48000u * 60u * 12u; // 12 min

/// Linear resample to interleaved stereo. Returns output frames, or 0 on error.
inline uint32_t resampleStereo(const float *in, uint32_t in_frames, uint32_t in_ch, double in_sr,
                               float *out, uint32_t out_cap, double out_sr) {
    if (!in || !out || in_frames == 0 || in_ch == 0 || in_sr <= 0 || out_sr <= 0) {
        return 0;
    }
    const auto out_frames = static_cast<uint32_t>(std::llround(static_cast<double>(in_frames) * (out_sr / in_sr)));
    if (out_frames == 0 || out_frames > out_cap) {
        return 0;
    }
    const double ratio = in_sr / out_sr;
    const uint32_t last = in_frames - 1;
    for (uint32_t i = 0; i < out_frames; ++i) {
        const double src = static_cast<double>(i) * ratio;
        auto i0 = static_cast<uint32_t>(src);
        if (i0 > last) {
            i0 = last;
        }
        const uint32_t i1 = i0 < last ? i0 + 1 : last;
        const float frac = static_cast<float>(src - static_cast<double>(i0));
        float l0, r0, l1, r1;
        if (in_ch == 1) {
            l0 = r0 = in[i0];
            l1 = r1 = in[i1];
        } else {
            l0 = in[i0 * in_ch];
            r0 = in[i0 * in_ch + 1];
            l1 = in[i1 * in_ch];
            r1 = in[i1 * in_ch + 1];
        }
        out[i * 2] = l0 + (l1 - l0) * frac;
        out[i * 2 + 1] = r0 + (r1 - r0) * frac;
    }
    return out_frames;
}

inline void upmixToStereo(const float *in, uint32_t frames, uint32_t in_ch, float *out) {
    for (uint32_t i = 0; i < frames; ++i) {
        if (in_ch == 1) {
            out[i * 2] = out[i * 2 + 1] = in[i];
        } else {
            out[i * 2] = in[i * in_ch];
            out[i * 2 + 1] = in[i * in_ch + 1];
        }
    }
}

struct WavData {
    std::vector<float> pcm; // interleaved, source channel count
    uint32_t frames = 0;
    uint32_t channels = 0;
    double sample_rate = 0;
};

inline bool writeWavS16(const char *path, const float *interleaved, uint32_t frames, uint32_t channels,
                        uint32_t sample_rate) {
    if (!path || !interleaved || frames == 0 || channels == 0) {
        return false;
    }
    FILE *f = std::fopen(path, "wb");
    if (!f) {
        return false;
    }
    const uint32_t data_bytes = frames * channels * 2;
    const uint32_t riff_size = 36 + data_bytes;
    const uint16_t audio_fmt = 1;
    const uint16_t ch = static_cast<uint16_t>(channels);
    const uint16_t bps = 16;
    const uint32_t byte_rate = sample_rate * channels * 2;
    const uint16_t block = static_cast<uint16_t>(channels * 2);
    auto wr = [&](const void *p, size_t n) { std::fwrite(p, 1, n, f); };
    wr("RIFF", 4);
    wr(&riff_size, 4);
    wr("WAVE", 4);
    wr("fmt ", 4);
    const uint32_t fmt_size = 16;
    wr(&fmt_size, 4);
    wr(&audio_fmt, 2);
    wr(&ch, 2);
    wr(&sample_rate, 4);
    wr(&byte_rate, 4);
    wr(&block, 2);
    wr(&bps, 2);
    wr("data", 4);
    wr(&data_bytes, 4);
    for (uint32_t i = 0; i < frames * channels; ++i) {
        float s = std::clamp(interleaved[i], -1.f, 1.f);
        auto v = static_cast<int16_t>(std::lrint(s * 32767.f));
        wr(&v, 2);
    }
    std::fclose(f);
    return true;
}

inline bool decodeWav(const char *path, WavData &out) {
    out = {};
    FILE *f = std::fopen(path, "rb");
    if (!f) {
        return false;
    }
    auto rd = [&](void *p, size_t n) -> bool { return std::fread(p, 1, n, f) == n; };
    char riff[4], wave[4];
    uint32_t riff_size = 0;
    if (!rd(riff, 4) || std::memcmp(riff, "RIFF", 4) != 0 || !rd(&riff_size, 4) || !rd(wave, 4) ||
        std::memcmp(wave, "WAVE", 4) != 0) {
        std::fclose(f);
        return false;
    }

    uint16_t audio_fmt = 0, channels = 0, bits = 0;
    uint32_t sample_rate = 0, data_bytes = 0;
    bool have_fmt = false, have_data = false;
    long data_pos = 0;

    while (!have_data) {
        char id[4];
        uint32_t sz = 0;
        if (!rd(id, 4) || !rd(&sz, 4)) {
            break;
        }
        if (std::memcmp(id, "fmt ", 4) == 0) {
            uint16_t block = 0;
            uint32_t byte_rate = 0;
            if (sz < 16 || !rd(&audio_fmt, 2) || !rd(&channels, 2) || !rd(&sample_rate, 4) || !rd(&byte_rate, 4) ||
                !rd(&block, 2) || !rd(&bits, 2)) {
                std::fclose(f);
                return false;
            }
            if (sz > 16) {
                std::fseek(f, static_cast<long>(sz - 16), SEEK_CUR);
            }
            have_fmt = true;
        } else if (std::memcmp(id, "data", 4) == 0) {
            data_bytes = sz;
            data_pos = std::ftell(f);
            have_data = true;
            break;
        } else {
            std::fseek(f, static_cast<long>(sz), SEEK_CUR);
        }
    }

    if (!have_fmt || !have_data || channels == 0 || sample_rate == 0 || (audio_fmt != 1 && audio_fmt != 3)) {
        std::fclose(f);
        return false;
    }
    if (audio_fmt == 1 && bits != 16 && bits != 24 && bits != 32) {
        std::fclose(f);
        return false;
    }
    if (audio_fmt == 3 && bits != 32) {
        std::fclose(f);
        return false;
    }

    const uint32_t sample_bytes = bits / 8;
    const uint32_t frames = data_bytes / (sample_bytes * channels);
    if (frames == 0 || frames > kMaxClipFrames) {
        std::fclose(f);
        return false;
    }

    std::fseek(f, data_pos, SEEK_SET);
    out.pcm.resize(static_cast<size_t>(frames) * channels);
    out.frames = frames;
    out.channels = channels;
    out.sample_rate = sample_rate;

    for (uint32_t i = 0; i < frames * channels; ++i) {
        if (audio_fmt == 3) {
            float v = 0;
            if (!rd(&v, 4)) {
                std::fclose(f);
                return false;
            }
            out.pcm[i] = v;
        } else if (bits == 16) {
            int16_t v = 0;
            if (!rd(&v, 2)) {
                std::fclose(f);
                return false;
            }
            out.pcm[i] = static_cast<float>(v) / 32768.f;
        } else if (bits == 24) {
            unsigned char b[3];
            if (!rd(b, 3)) {
                std::fclose(f);
                return false;
            }
            int32_t v = (int32_t(b[2]) << 16) | (int32_t(b[1]) << 8) | int32_t(b[0]);
            if (v & 0x800000) {
                v |= ~0xFFFFFF;
            }
            out.pcm[i] = static_cast<float>(v) / 8388608.f;
        } else {
            int32_t v = 0;
            if (!rd(&v, 4)) {
                std::fclose(f);
                return false;
            }
            out.pcm[i] = static_cast<float>(v) / 2147483648.f;
        }
    }
    std::fclose(f);
    return true;
}

} // namespace sidekit
