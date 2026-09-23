/*
 * Gracenote GNSDK Submit API emulation for Darling
 *
 * Implements the 17 symbols required by Apple Music.app.
 */

#include "gnsdk_submit.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct gnsdk_gdo_s {
    uint32_t magic;
    char* key;
    char* value;
    struct gnsdk_gdo_s* next;
    struct gnsdk_gdo_s* children_head;
};

struct gnsdk_parcel_s {
    uint32_t magic;
    int state;
    uint32_t sample_rate;
    uint32_t sample_size;
    uint32_t channels;
    size_t audio_bytes_written;
    struct gnsdk_gdo_s* gdo_head;
};

#define GDO_MAGIC    0x47444F31 /* "GDO1" */
#define PARCEL_MAGIC 0x50524331 /* "PRC1" */

static int g_submit_initialized = 0;

gnsdk_error_t gnsdk_submit_initialize(gnsdk_user_handle_t user_handle)
{
    (void)user_handle;
    g_submit_initialized = 1;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_shutdown(void)
{
    g_submit_initialized = 0;
    return GNSDK_SUCCESS;
}

const char* gnsdk_submit_get_version(void)
{
    return GNSDK_SUBMIT_VERSION;
}

gnsdk_error_t gnsdk_submit_edit_gdo_create_empty(gnsdk_gdo_handle_t* p_gdo_handle)
{
    if (!p_gdo_handle) return 1;

    struct gnsdk_gdo_s* gdo = (struct gnsdk_gdo_s*)calloc(1, sizeof(struct gnsdk_gdo_s));
    if (!gdo) return 2;

    gdo->magic = GDO_MAGIC;
    *p_gdo_handle = (gnsdk_gdo_handle_t)gdo;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_edit_gdo_child_add_empty(gnsdk_gdo_handle_t gdo_handle, const char* child_key, gnsdk_gdo_handle_t* p_child_gdo_handle)
{
    struct gnsdk_gdo_s* parent = (struct gnsdk_gdo_s*)gdo_handle;
    if (!parent || parent->magic != GDO_MAGIC || !p_child_gdo_handle) return 1;

    gnsdk_error_t err = gnsdk_submit_edit_gdo_create_empty(p_child_gdo_handle);
    if (err != GNSDK_SUCCESS) return err;

    struct gnsdk_gdo_s* child = (struct gnsdk_gdo_s*)*p_child_gdo_handle;
    child->key = child_key ? strdup(child_key) : NULL;
    child->next = parent->children_head;
    parent->children_head = child;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_edit_gdo_value_set(gnsdk_gdo_handle_t gdo_handle, const char* value_key, const char* value)
{
    struct gnsdk_gdo_s* gdo = (struct gnsdk_gdo_s*)gdo_handle;
    if (!gdo || gdo->magic != GDO_MAGIC) return 1;

    free(gdo->key);
    free(gdo->value);
    gdo->key = value_key ? strdup(value_key) : NULL;
    gdo->value = value ? strdup(value) : NULL;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_edit_gdo_list_value_set_by_submit_id(gnsdk_gdo_handle_t gdo_handle, const char* list_key, uint32_t submit_id)
{
    char buf[32];
    snprintf(buf, sizeof(buf), "%u", submit_id);
    return gnsdk_submit_edit_gdo_value_set(gdo_handle, list_key, buf);
}

gnsdk_error_t gnsdk_submit_parcel_create(gnsdk_user_handle_t user_handle, gnsdk_submit_parcel_handle_t* p_parcel_handle)
{
    (void)user_handle;
    if (!p_parcel_handle) return 1;

    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)calloc(1, sizeof(struct gnsdk_parcel_s));
    if (!parcel) return 2;

    parcel->magic = PARCEL_MAGIC;
    parcel->state = gnsdk_submit_status_unknown;
    *p_parcel_handle = (gnsdk_submit_parcel_handle_t)parcel;
    return GNSDK_SUCCESS;
}

static void free_gdo_tree(struct gnsdk_gdo_s* gdo)
{
    while (gdo) {
        struct gnsdk_gdo_s* next = gdo->next;
        if (gdo->children_head) {
            free_gdo_tree(gdo->children_head);
        }
        free(gdo->key);
        free(gdo->value);
        gdo->magic = 0;
        free(gdo);
        gdo = next;
    }
}

gnsdk_error_t gnsdk_submit_parcel_release(gnsdk_submit_parcel_handle_t parcel_handle)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    if (parcel->gdo_head) {
        free_gdo_tree(parcel->gdo_head);
        parcel->gdo_head = NULL;
    }

    parcel->magic = 0;
    free(parcel);
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_data_add_gdo(gnsdk_submit_parcel_handle_t parcel_handle, gnsdk_gdo_handle_t gdo_handle)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    struct gnsdk_gdo_s* gdo = (struct gnsdk_gdo_s*)gdo_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC || !gdo || gdo->magic != GDO_MAGIC) return 1;

    gdo->next = parcel->gdo_head;
    parcel->gdo_head = gdo;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_data_get_state(gnsdk_submit_parcel_handle_t parcel_handle, int* p_state)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC || !p_state) return 1;

    *p_state = parcel->state;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_data_init_features(gnsdk_submit_parcel_handle_t parcel_handle)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    parcel->state = gnsdk_submit_status_sending;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_feature_init_audio(gnsdk_submit_parcel_handle_t parcel_handle, uint32_t sample_rate, uint32_t sample_size, uint32_t channels)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    parcel->sample_rate = sample_rate;
    parcel->sample_size = sample_size;
    parcel->channels = channels;
    parcel->audio_bytes_written = 0;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_feature_write_audio_data(gnsdk_submit_parcel_handle_t parcel_handle, const void* audio_data, size_t audio_data_bytes)
{
    (void)audio_data;
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    parcel->audio_bytes_written += audio_data_bytes;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_feature_finalize(gnsdk_submit_parcel_handle_t parcel_handle)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    parcel->state = gnsdk_submit_status_complete;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_feature_option_set(gnsdk_submit_parcel_handle_t parcel_handle, const char* option_key, const char* option_value)
{
    (void)parcel_handle;
    (void)option_key;
    (void)option_value;
    return GNSDK_SUCCESS;
}

gnsdk_error_t gnsdk_submit_parcel_upload(gnsdk_submit_parcel_handle_t parcel_handle, void* callback, void* user_data)
{
    struct gnsdk_parcel_s* parcel = (struct gnsdk_parcel_s*)parcel_handle;
    if (!parcel || parcel->magic != PARCEL_MAGIC) return 1;

    parcel->state = gnsdk_submit_status_complete;

    /* If caller supplied an asynchronous status callback, notify it that upload completed */
    if (callback) {
        typedef void (*status_fn)(void* user_data, int status, double percent_complete, int* abort_flag);
        status_fn fn = (status_fn)callback;
        int abort_flag = 0;
        fn(user_data, gnsdk_submit_status_complete, 100.0, &abort_flag);
    }

    return GNSDK_SUCCESS;
}
