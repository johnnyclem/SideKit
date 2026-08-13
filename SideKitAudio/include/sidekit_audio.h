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

/** Pattern ids posted by Swift. Keep in sync with Models.Pattern. */
enum {
    SK_PATTERN_KICK = 0,
    SK_PATTERN_BASS = 1,
    SK_PATTERN_HAT = 2,
    SK_PATTERN_SYNTH = 3,
    SK_PATTERN_BREAK = 4
};

const char *sk_engine_version(void);

SKEngine *sk_engine_create(double sample_rate, uint32_t channels);
void sk_engine_destroy(SKEngine *engine);

/**
 * Realtime render. Interleaved float32 [-1, 1].
 * Audio thread only. No allocations.
 */
uint32_t sk_engine_render(SKEngine *engine, float *interleaved, uint32_t frames);

SKRenderInfo sk_engine_last_info(const SKEngine *engine);

/** All setters are UI-thread. They enqueue lock-free SPSC commands. */
void sk_engine_set_master(SKEngine *engine, float linear);
void sk_engine_set_crossfader(SKEngine *engine, float xf);
void sk_engine_set_channel_mix(SKEngine *engine, uint32_t ch, float gain_db, float fader, int mute);
void sk_engine_set_channel_eq(SKEngine *engine, uint32_t ch, float lo, float mid, float hi, float style_mul);
void sk_engine_set_transport(SKEngine *engine, uint32_t ch, int playing, uint32_t pattern, float bpm);
void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz);
void sk_engine_set_output_gain(SKEngine *engine, float linear);

#ifdef __cplusplus
}
#endif
