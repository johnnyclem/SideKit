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
    int playing;
    int fading;
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

/** Equal-power start/stop fade length. */
enum { SK_FADE_MS = 5 };

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

int sk_engine_load_clip(SKEngine *engine, uint32_t ch, const float *interleaved, uint32_t frames, uint32_t channels);
void sk_engine_clear_clip(SKEngine *engine, uint32_t ch);
SKClipInfo sk_engine_clip_info(const SKEngine *engine, uint32_t ch);
void sk_engine_set_clip_position(SKEngine *engine, uint32_t ch, float normalized);

/** Frame-accurate seek. Lands on `frame` (clamped) after the next render consume. */
void sk_engine_seek_frames(SKEngine *engine, uint32_t ch, uint32_t frame);

/** Return playhead to 0. Keeps playing (with a 5 ms fade-in) if the deck was on. */
void sk_engine_restart(SKEngine *engine, uint32_t ch);

uint32_t sk_resample_stereo(const float *in, uint32_t in_frames, uint32_t in_ch, double in_sr,
                            float *out, uint32_t out_capacity, double out_sr);

int sk_wav_decode_file(const char *path, float **out_interleaved, uint32_t *frames, uint32_t *channels, double *sr);
void sk_pcm_free(float *p);

#ifdef __cplusplus
}
#endif
