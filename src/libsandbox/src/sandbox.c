/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/


#include <sandbox/sandbox.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static int verbose = 0;

__attribute__((constructor))
static void initme(void) {
    verbose = getenv("STUB_VERBOSE") != NULL;
}

/* There is no seatbelt compiler or enforcement here. Compiling a profile and
 * applying one fail with an error instead of pretending a sandbox is in force,
 * so a client such as a renderer does not run believing it is confined.
 * Shapes follow the documented SPI (profile and params are opaque here). */
#define SANDBOX_UNSUPPORTED "sandboxing is not supported on Darling"

static void set_unsupported(char **error)
{
    if (error != NULL)
        *error = strdup(SANDBOX_UNSUPPORTED);
}

int sandbox_apply(void *profile)
{
    if (verbose) puts("STUB: sandbox_apply called");
    (void)profile;
    return -1;
}

void* sandbox_apply_container(void)
{
    if (verbose) puts("STUB: sandbox_apply_container called");
    return NULL;
}

void* sandbox_compile_entitlements(void)
{
    if (verbose) puts("STUB: sandbox_compile_entitlements called");
    return NULL;
}

void* sandbox_compile_file(const char *path, void *params, char **error)
{
    if (verbose) puts("STUB: sandbox_compile_file called");
    (void)path; (void)params;
    set_unsupported(error);
    return NULL;
}

void* sandbox_compile_named(void)
{
    if (verbose) puts("STUB: sandbox_compile_named called");
    return NULL;
}

void* sandbox_compile_string(const char *data, void *params, char **error)
{
    if (verbose) puts("STUB: sandbox_compile_string called");
    (void)data; (void)params;
    set_unsupported(error);
    return NULL;
}

void* sandbox_container_paths_iterate_items(void)
{
    if (verbose) puts("STUB: sandbox_container_paths_iterate_items called");
    return NULL;
}

void* sandbox_create_params(void)
{
    if (verbose) puts("STUB: sandbox_create_params called");
    return NULL;
}

/* sandbox_create_params returns NULL, so there is never anything to free. */
void sandbox_free_params(void *params)
{
    if (verbose) puts("STUB: sandbox_free_params called");
    (void)params;
}

/* sandbox_compile_* never return a profile, so there is never anything to free. */
void sandbox_free_profile(void *profile)
{
    if (verbose) puts("STUB: sandbox_free_profile called");
    (void)profile;
}

void* sandbox_inspect_pid(void)
{
    if (verbose) puts("STUB: sandbox_inspect_pid called");
    return NULL;
}

void* sandbox_inspect_smemory(void)
{
    if (verbose) puts("STUB: sandbox_inspect_smemory called");
    return NULL;
}

void* sandbox_set_param(void)
{
    if (verbose) puts("STUB: sandbox_set_param called");
    return NULL;
}

void* sandbox_set_user_state_item(void)
{
    if (verbose) puts("STUB: sandbox_set_user_state_item called");
    return NULL;
}

void* sandbox_user_state_item_buffer_create(void)
{
    if (verbose) puts("STUB: sandbox_user_state_item_buffer_create called");
    return NULL;
}

void* sandbox_user_state_item_buffer_destroy(void)
{
    if (verbose) puts("STUB: sandbox_user_state_item_buffer_destroy called");
    return NULL;
}

void* sandbox_user_state_item_buffer_send(void)
{
    if (verbose) puts("STUB: sandbox_user_state_item_buffer_send called");
    return NULL;
}

void* sandbox_user_state_iterate_items(void)
{
    if (verbose) puts("STUB: sandbox_user_state_iterate_items called");
    return NULL;
}
