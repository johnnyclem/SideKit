#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Opaque C++ engine handle. Swift talks only to this C ABI. */
typedef struct SKEngine SKEngine;

typedef struct SKRenderInfo {
    uint32_t frames_rendered;
    uint64_t sample_time;
    float peak;
} SKRenderInfo;

/** Semantic version of the native audio core. */
const char *sk_engine_version(void);

SKEngine *sk_engine_create(double sample_rate, uint32_t channels);
void sk_engine_destroy(SKEngine *engine);

/**
 * Realtime render callback. Fills interleaved float32 [-1, 1].
 * Must be called from the audio thread. No allocations.
 * Returns frames written (always `frames` on success, 0 if engine is null).
 */
uint32_t sk_engine_render(SKEngine *engine, float *interleaved, uint32_t frames);

SKRenderInfo sk_engine_last_info(const SKEngine *engine);

/** Off-thread control. Commands travel through a lock-free SPSC queue. */
void sk_engine_set_test_tone(SKEngine *engine, int enabled, float hz);
void sk_engine_set_output_gain(SKEngine *engine, float linear);

#ifdef __cplusplus
}
#endif
