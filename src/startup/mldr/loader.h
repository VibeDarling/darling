#ifndef _MLDR_LOADER_H_
#define _MLDR_LOADER_H_

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Size of the Darwin main stack mapping, in pages (capped by RLIMIT_STACK).
#define MLDR_MAIN_STACK_PAGES 16
// The argv/envp/apple pointer arrays may use at most 1/N of that mapping.
#define MLDR_STACK_ARGS_DIVISOR 2

struct load_results {
	unsigned long mh;
	unsigned long entry_point;
	unsigned long stack_size;
	unsigned long main_stack_size;
	unsigned long dyld_all_image_location;
	unsigned long dyld_all_image_size;
	uint8_t uuid[16];

	unsigned long vm_addr_max;
	bool _32on64;
	unsigned long base;
	uint32_t bprefs[4];
	char* root_path;
	size_t root_path_length;
	// The executable path mldr was given is a vchroot-expanded host path (from sys_execve).
	bool executable_path_is_host_path;
	unsigned long stack_top;
	char* socket_path;
	int kernfd;
	int lifetime_pipe;

	size_t argc;
	size_t envc;
	char** argv;
	char** envp;

	// Set when the executable has MH_HAS_TLV_DESCRIPTORS; mldr will log a
	// warning on Android where __tlv_bootstrap is not yet implemented in dyld.
	bool has_tlv_descriptors;
};

// Returns true if `fixed_words + argc + envc` machine words fit in the share of a
// `stack_bytes`-sized stack reserved for the argument block.
static inline bool mldr_stack_args_fit(size_t stack_bytes, size_t word_size, size_t argc, size_t envc, size_t fixed_words) {
	size_t max_words = stack_bytes / MLDR_STACK_ARGS_DIVISOR / word_size;

	return argc < max_words && envc < max_words && fixed_words <= max_words && argc + envc <= max_words - fixed_words;
}

#endif // _MLDR_LOADER_H_
