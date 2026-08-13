#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SKEngine SKEngine;

typedef struct SKRenderInfo {
    uint32_t frames_rendered;
    uint64_t sample_time;
    float peak;
    float peak_ch1;
    float peak_ch2;
    uint32_t commands_applied;
} SKRenderInfo;

typedef struct SKClipInfo {
    uint32_t frames;
    uint32_t playhead;
    uint32_t channels;
    int loaded;
} SKClipInfo;

enum {
    SK_PATTERN_KICK = 0,
    SK_PATTERN_BASS = 1,
    SK_PATTERN_HAT = 2,
    SK_PATTERN_SYNTH = 3,
    SK_PATTERN_BREAK = 4
};

enum {
    SK_OK = 1,
    SK_ERR = 0
};

const char *sk_engine_version(void);

SKEngine *sk_engine_create(double sample_rate, uint32_t channels);
void sk_engine_destroy(SKEngine *engine);

uint32_t sk_engine_render(SKEngine *engine, float *interleaved, uint32_t frames);
SKRenderInfo sk_engine_last_info(const SKEngine *engine);

void sk_engine_set_master(SKEngine *engine, float linear);
void sk_engine_set_crossfader(SKEngine *engine, float xf);
void sk_engine_set_channel_mix(SKEngine *engine, uint32_t ch, float gain_db, float fader, int mute);
void sk_engine_set_channel_eq(SKEngine *engine, uint32_t ch, float lo, float mid, float hi, float style_mul);
void sk_engine_set_transport(SKEngine *engine, uint32_t ch, int playing, uint32_t pattern, float bpm);
void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz);
void sk_engine_set_output_gain(SKEngine *engine, float linear);

/**
 * Load interleaved float32 PCM onto a deck. Copied on the caller thread
 * into a double-buffered slot; the audio thread only swaps a pointer.
 * `channels` 1 or 2. Sample rate must already be the engine rate (48 kHz).
 * Returns SK_OK / SK_ERR.
 */
int sk_engine_load_clip(SKEngine *engine, uint32_t ch, const float *interleaved, uint32_t frames, uint32_t channels);
void sk_engine_clear_clip(SKEngine *engine, uint32_t ch);
SKClipInfo sk_engine_clip_info(const SKEngine *engine, uint32_t ch);
void sk_engine_set_clip_position(SKEngine *engine, uint32_t ch, float normalized);

/** Offline linear resample → interleaved stereo. Returns frames written, or 0. */
uint32_t sk_resample_stereo(const float *in, uint32_t in_frames, uint32_t in_ch, double in_sr,
                            float *out, uint32_t out_capacity, double out_sr);

/**
 * Host / fallback WAV decode (PCM 16/24/32 or float32). Allocates *out.
 * Free with sk_pcm_free. Returns SK_OK / SK_ERR.
 */
int sk_wav_decode_file(const char *path, float **out_interleaved, uint32_t *frames, uint32_t *channels, double *sr);
void sk_pcm_free(float *p);

#ifdef __cplusplus
}
#endif
