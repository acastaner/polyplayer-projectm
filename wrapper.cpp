/*
 * Polyplayer's projectM wrapper: a thin layer over projectM's own C API (projectM-4), built
 * with libprojectM into one WebAssembly module (build.sh). It holds one projectM instance for the
 * WebGL 2 context the page made current, and exposes what the page's Visualizer host calls:
 * create at a size, feed PCM, render a frame, load a preset's text with or without a soft
 * transition, resize and destroy. Nothing else is compiled into the module.
 *
 * Copyright (C) 2026 Polyplayer's authors.
 *
 * This library is free software; you can redistribute it and/or modify it under the terms of the
 * GNU Lesser General Public License as published by the Free Software Foundation; either version
 * 2.1 of the License, or (at your option) any later version. See LICENSE.
 */
#include <emscripten/emscripten.h>
#include <projectM-4/projectM.h>
#include <stddef.h>

extern "C" {

static projectm_handle instance = nullptr;

/* Set by projectM when a preset fails to load; read and cleared by pm_load and pm_failed. */
static int failed = 0;

static void on_failed(const char* preset_filename, const char* message, void* user_data)
{
    (void)preset_filename;
    (void)message;
    (void)user_data;
    failed = 1;
}

/*
 * Starts projectM at width x height on the current WebGL 2 context. Presets change only when the
 * page loads one: projectM's own timer and beat-driven hard cuts are off. 1 on success.
 */
EMSCRIPTEN_KEEPALIVE int pm_create(int width, int height, double soft_cut_seconds)
{
    if (instance != nullptr) return 1;
    instance = projectm_create();
    if (instance == nullptr) return 0;
    projectm_set_window_size(instance, (size_t)width, (size_t)height);
    projectm_set_fps(instance, 60);
    projectm_set_preset_locked(instance, true);
    projectm_set_hard_cut_enabled(instance, false);
    projectm_set_preset_duration(instance, 86400.0);
    projectm_set_soft_cut_duration(instance, soft_cut_seconds);
    projectm_set_preset_switch_failed_event_callback(instance, on_failed, nullptr);
    return 1;
}

EMSCRIPTEN_KEEPALIVE void pm_destroy(void)
{
    if (instance == nullptr) return;
    projectm_destroy(instance);
    instance = nullptr;
}

/* Loads a preset from its text (a .milk file), blending into it when smooth. 1 unless it failed. */
EMSCRIPTEN_KEEPALIVE int pm_load(const char* text, int smooth)
{
    if (instance == nullptr) return 0;
    failed = 0;
    projectm_load_preset_data(instance, text, smooth != 0);
    int ok = !failed;
    failed = 0;
    return ok;
}

/* Whether a preset failed since the last call (projectM may report it while rendering). */
EMSCRIPTEN_KEEPALIVE int pm_failed(void)
{
    int was = failed;
    failed = 0;
    return was;
}

/* Adds frames of interleaved stereo float samples (left, right), -1 to 1. */
EMSCRIPTEN_KEEPALIVE void pm_pcm(const float* samples, unsigned int frames)
{
    if (instance == nullptr) return;
    projectm_pcm_add_float(instance, samples, frames, PROJECTM_STEREO);
}

/* Draws one frame into the current context's default framebuffer. */
EMSCRIPTEN_KEEPALIVE void pm_render(void)
{
    if (instance == nullptr) return;
    projectm_opengl_render_frame(instance);
}

EMSCRIPTEN_KEEPALIVE void pm_resize(int width, int height)
{
    if (instance == nullptr) return;
    projectm_set_window_size(instance, (size_t)width, (size_t)height);
}

}  // extern "C"
