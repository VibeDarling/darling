#ifndef _GNSDK_SUBMIT_H_
#define _GNSDK_SUBMIT_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint32_t gnsdk_error_t;
typedef void* gnsdk_handle_t;
typedef gnsdk_handle_t gnsdk_user_handle_t;
typedef gnsdk_handle_t gnsdk_gdo_handle_t;
typedef gnsdk_handle_t gnsdk_submit_parcel_handle_t;

#define GNSDK_SUCCESS 0
#define GNSDK_SUBMIT_VERSION "3.06.0"

/* Status callback codes */
enum {
    gnsdk_submit_status_unknown = 0,
    gnsdk_submit_status_sending,
    gnsdk_submit_status_complete,
    gnsdk_submit_status_error
};

/* GNSDK Submit API */
gnsdk_error_t gnsdk_submit_initialize(gnsdk_user_handle_t user_handle);
gnsdk_error_t gnsdk_submit_shutdown(void);
const char*   gnsdk_submit_get_version(void);

/* GDO Editing */
gnsdk_error_t gnsdk_submit_edit_gdo_create_empty(gnsdk_gdo_handle_t* p_gdo_handle);
gnsdk_error_t gnsdk_submit_edit_gdo_child_add_empty(gnsdk_gdo_handle_t gdo_handle, const char* child_key, gnsdk_gdo_handle_t* p_child_gdo_handle);
gnsdk_error_t gnsdk_submit_edit_gdo_value_set(gnsdk_gdo_handle_t gdo_handle, const char* value_key, const char* value);
gnsdk_error_t gnsdk_submit_edit_gdo_list_value_set_by_submit_id(gnsdk_gdo_handle_t gdo_handle, const char* list_key, uint32_t submit_id);

/* Parcel Management */
gnsdk_error_t gnsdk_submit_parcel_create(gnsdk_user_handle_t user_handle, gnsdk_submit_parcel_handle_t* p_parcel_handle);
gnsdk_error_t gnsdk_submit_parcel_release(gnsdk_submit_parcel_handle_t parcel_handle);
gnsdk_error_t gnsdk_submit_parcel_data_add_gdo(gnsdk_submit_parcel_handle_t parcel_handle, gnsdk_gdo_handle_t gdo_handle);
gnsdk_error_t gnsdk_submit_parcel_data_get_state(gnsdk_submit_parcel_handle_t parcel_handle, int* p_state);
gnsdk_error_t gnsdk_submit_parcel_data_init_features(gnsdk_submit_parcel_handle_t parcel_handle);
gnsdk_error_t gnsdk_submit_parcel_feature_init_audio(gnsdk_submit_parcel_handle_t parcel_handle, uint32_t sample_rate, uint32_t sample_size, uint32_t channels);
gnsdk_error_t gnsdk_submit_parcel_feature_write_audio_data(gnsdk_submit_parcel_handle_t parcel_handle, const void* audio_data, size_t audio_data_bytes);
gnsdk_error_t gnsdk_submit_parcel_feature_finalize(gnsdk_submit_parcel_handle_t parcel_handle);
gnsdk_error_t gnsdk_submit_parcel_feature_option_set(gnsdk_submit_parcel_handle_t parcel_handle, const char* option_key, const char* option_value);
gnsdk_error_t gnsdk_submit_parcel_upload(gnsdk_submit_parcel_handle_t parcel_handle, void* callback, void* user_data);

#ifdef __cplusplus
}
#endif

#endif /* _GNSDK_SUBMIT_H_ */
