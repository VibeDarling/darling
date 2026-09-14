#include <elfcalls.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

extern struct elf_calls* _elfcalls;
extern int _dyld_func_lookup(const char* dyld_func_name, void **address) __attribute__((weak_import));
extern char*** _NSGetEnviron(void) __attribute__((weak_import));

static void* lib_handle = NULL;

char pcap_version[256] = "libpcap version 1.10 (Darling ELF bridge)";

static struct elf_calls* get_elfcalls(void) {
	if (_elfcalls)
		return _elfcalls;

	if (_dyld_func_lookup) {
		void* (*get_ptr)(void) = NULL;
		if (_dyld_func_lookup("__dyld_get_elfcalls", (void**)&get_ptr) && get_ptr) {
			_elfcalls = (struct elf_calls*)get_ptr();
			if (_elfcalls)
				return _elfcalls;
		}
	}

	if (_NSGetEnviron) {
		char*** penv = _NSGetEnviron();
		if (penv && *penv) {
			char** env = *penv;
			while (*env) env++;
			char** applep = env + 1;
			while (*applep) {
				if (strncmp(*applep, "elf_calls=", 10) == 0) {
					uintptr_t val = 0;
					const char* s = *applep + 10;
					if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
					while (*s) {
						val <<= 4;
						if (*s >= '0' && *s <= '9') val |= (*s - '0');
						else if (*s >= 'a' && *s <= 'f') val |= (*s - 'a' + 10);
						else if (*s >= 'A' && *s <= 'F') val |= (*s - 'A' + 10);
						s++;
					}
					_elfcalls = (struct elf_calls*)val;
					return _elfcalls;
				}
				applep++;
			}
		}
	}

	return _elfcalls;
}

static void* get_lib_handle(void) {
	if (lib_handle)
		return lib_handle;

	struct elf_calls* calls = get_elfcalls();
	if (!calls)
		return NULL;

	const char* candidates[] = {
		"libpcap.so.1",
		"libpcap.so.0.8",
		"libpcap.so",
		NULL
	};
	for (int i = 0; candidates[i]; i++) {
		lib_handle = calls->dlopen(candidates[i]);
		if (lib_handle) break;
	}
	if (!lib_handle) {
		lib_handle = calls->dlopen_fatal("libpcap.so.0.8");
	}
	return lib_handle;
}

static inline void* resolve_sym(const char* sym) {
	struct elf_calls* calls = get_elfcalls();
	void* handle = get_lib_handle();
	return calls->dlsym_fatal(handle, sym);
}

__attribute__((constructor)) static void initializer(void) {
	void* handle = get_lib_handle();
	struct elf_calls* calls = get_elfcalls();
	if (handle && calls) {
		const char* (*ver_fn)(void) = (const char* (*)(void))calls->dlsym(handle, "pcap_lib_version");
		if (ver_fn) {
			const char* v = ver_fn();
			if (v) {
				size_t i = 0;
				while (v[i] && i < sizeof(pcap_version) - 1) {
					pcap_version[i] = v[i];
					i++;
				}
				pcap_version[i] = '\0';
			}
		}
	}
}

__attribute__((destructor)) static void destructor(void) {
	if (lib_handle && _elfcalls) {
		_elfcalls->dlclose(lib_handle);
		lib_handle = NULL;
	}
}

void* bpf_dump() {
	__asm__(".symbol_resolver _bpf_dump");
	return resolve_sym( "bpf_dump");
}

void* bpf_filter() {
	__asm__(".symbol_resolver _bpf_filter");
	return resolve_sym( "bpf_filter");
}

void* bpf_image() {
	__asm__(".symbol_resolver _bpf_image");
	return resolve_sym( "bpf_image");
}

void* bpf_validate() {
	__asm__(".symbol_resolver _bpf_validate");
	return resolve_sym( "bpf_validate");
}

void* pcap_activate() {
	__asm__(".symbol_resolver _pcap_activate");
	return resolve_sym( "pcap_activate");
}

void* pcap_breakloop() {
	__asm__(".symbol_resolver _pcap_breakloop");
	return resolve_sym( "pcap_breakloop");
}

void* pcap_bufsize() {
	__asm__(".symbol_resolver _pcap_bufsize");
	return resolve_sym( "pcap_bufsize");
}

void* pcap_can_set_rfmon() {
	__asm__(".symbol_resolver _pcap_can_set_rfmon");
	return resolve_sym( "pcap_can_set_rfmon");
}

void* pcap_close() {
	__asm__(".symbol_resolver _pcap_close");
	return resolve_sym( "pcap_close");
}

void* pcap_compile() {
	__asm__(".symbol_resolver _pcap_compile");
	return resolve_sym( "pcap_compile");
}

void* pcap_compile_nopcap() {
	__asm__(".symbol_resolver _pcap_compile_nopcap");
	return resolve_sym( "pcap_compile_nopcap");
}

void* pcap_create() {
	__asm__(".symbol_resolver _pcap_create");
	return resolve_sym( "pcap_create");
}

void* pcap_datalink() {
	__asm__(".symbol_resolver _pcap_datalink");
	return resolve_sym( "pcap_datalink");
}

void* pcap_datalink_ext() {
	__asm__(".symbol_resolver _pcap_datalink_ext");
	return resolve_sym( "pcap_datalink_ext");
}

void* pcap_datalink_name_to_val() {
	__asm__(".symbol_resolver _pcap_datalink_name_to_val");
	return resolve_sym( "pcap_datalink_name_to_val");
}

void* pcap_datalink_val_to_description() {
	__asm__(".symbol_resolver _pcap_datalink_val_to_description");
	return resolve_sym( "pcap_datalink_val_to_description");
}

void* pcap_datalink_val_to_description_or_dlt() {
	__asm__(".symbol_resolver _pcap_datalink_val_to_description_or_dlt");
	return resolve_sym( "pcap_datalink_val_to_description_or_dlt");
}

void* pcap_datalink_val_to_name() {
	__asm__(".symbol_resolver _pcap_datalink_val_to_name");
	return resolve_sym( "pcap_datalink_val_to_name");
}

void* pcap_dispatch() {
	__asm__(".symbol_resolver _pcap_dispatch");
	return resolve_sym( "pcap_dispatch");
}

void* pcap_dump() {
	__asm__(".symbol_resolver _pcap_dump");
	return resolve_sym( "pcap_dump");
}

void* pcap_dump_close() {
	__asm__(".symbol_resolver _pcap_dump_close");
	return resolve_sym( "pcap_dump_close");
}

void* pcap_dump_file() {
	__asm__(".symbol_resolver _pcap_dump_file");
	return resolve_sym( "pcap_dump_file");
}

void* pcap_dump_flush() {
	__asm__(".symbol_resolver _pcap_dump_flush");
	return resolve_sym( "pcap_dump_flush");
}

void* pcap_dump_fopen() {
	__asm__(".symbol_resolver _pcap_dump_fopen");
	return resolve_sym( "pcap_dump_fopen");
}

void* pcap_dump_ftell() {
	__asm__(".symbol_resolver _pcap_dump_ftell");
	return resolve_sym( "pcap_dump_ftell");
}

void* pcap_dump_ftell64() {
	__asm__(".symbol_resolver _pcap_dump_ftell64");
	return resolve_sym( "pcap_dump_ftell64");
}

void* pcap_dump_open() {
	__asm__(".symbol_resolver _pcap_dump_open");
	return resolve_sym( "pcap_dump_open");
}

void* pcap_dump_open_append() {
	__asm__(".symbol_resolver _pcap_dump_open_append");
	return resolve_sym( "pcap_dump_open_append");
}

void* pcap_ether_aton() {
	__asm__(".symbol_resolver _pcap_ether_aton");
	return resolve_sym( "pcap_ether_aton");
}

void* pcap_ether_hostton() {
	__asm__(".symbol_resolver _pcap_ether_hostton");
	return resolve_sym( "pcap_ether_hostton");
}

void* pcap_file() {
	__asm__(".symbol_resolver _pcap_file");
	return resolve_sym( "pcap_file");
}

void* pcap_fileno() {
	__asm__(".symbol_resolver _pcap_fileno");
	return resolve_sym( "pcap_fileno");
}

void* pcap_findalldevs() {
	__asm__(".symbol_resolver _pcap_findalldevs");
	return resolve_sym( "pcap_findalldevs");
}

void* pcap_fopen_offline() {
	__asm__(".symbol_resolver _pcap_fopen_offline");
	return resolve_sym( "pcap_fopen_offline");
}

void* pcap_fopen_offline_with_tstamp_precision() {
	__asm__(".symbol_resolver _pcap_fopen_offline_with_tstamp_precision");
	return resolve_sym( "pcap_fopen_offline_with_tstamp_precision");
}

void* pcap_free_datalinks() {
	__asm__(".symbol_resolver _pcap_free_datalinks");
	return resolve_sym( "pcap_free_datalinks");
}

void* pcap_free_tstamp_types() {
	__asm__(".symbol_resolver _pcap_free_tstamp_types");
	return resolve_sym( "pcap_free_tstamp_types");
}

void* pcap_freealldevs() {
	__asm__(".symbol_resolver _pcap_freealldevs");
	return resolve_sym( "pcap_freealldevs");
}

void* pcap_freecode() {
	__asm__(".symbol_resolver _pcap_freecode");
	return resolve_sym( "pcap_freecode");
}

void* pcap_get_required_select_timeout() {
	__asm__(".symbol_resolver _pcap_get_required_select_timeout");
	return resolve_sym( "pcap_get_required_select_timeout");
}

void* pcap_get_selectable_fd() {
	__asm__(".symbol_resolver _pcap_get_selectable_fd");
	return resolve_sym( "pcap_get_selectable_fd");
}

void* pcap_get_tstamp_precision() {
	__asm__(".symbol_resolver _pcap_get_tstamp_precision");
	return resolve_sym( "pcap_get_tstamp_precision");
}

void* pcap_geterr() {
	__asm__(".symbol_resolver _pcap_geterr");
	return resolve_sym( "pcap_geterr");
}

void* pcap_getnonblock() {
	__asm__(".symbol_resolver _pcap_getnonblock");
	return resolve_sym( "pcap_getnonblock");
}

void* pcap_init() {
	__asm__(".symbol_resolver _pcap_init");
	return resolve_sym( "pcap_init");
}

void* pcap_inject() {
	__asm__(".symbol_resolver _pcap_inject");
	return resolve_sym( "pcap_inject");
}

void* pcap_is_swapped() {
	__asm__(".symbol_resolver _pcap_is_swapped");
	return resolve_sym( "pcap_is_swapped");
}

void* pcap_lib_version() {
	__asm__(".symbol_resolver _pcap_lib_version");
	return resolve_sym( "pcap_lib_version");
}

void* pcap_list_datalinks() {
	__asm__(".symbol_resolver _pcap_list_datalinks");
	return resolve_sym( "pcap_list_datalinks");
}

void* pcap_list_tstamp_types() {
	__asm__(".symbol_resolver _pcap_list_tstamp_types");
	return resolve_sym( "pcap_list_tstamp_types");
}

void* pcap_lookupdev() {
	__asm__(".symbol_resolver _pcap_lookupdev");
	return resolve_sym( "pcap_lookupdev");
}

void* pcap_lookupnet() {
	__asm__(".symbol_resolver _pcap_lookupnet");
	return resolve_sym( "pcap_lookupnet");
}

void* pcap_loop() {
	__asm__(".symbol_resolver _pcap_loop");
	return resolve_sym( "pcap_loop");
}

void* pcap_major_version() {
	__asm__(".symbol_resolver _pcap_major_version");
	return resolve_sym( "pcap_major_version");
}

void* pcap_minor_version() {
	__asm__(".symbol_resolver _pcap_minor_version");
	return resolve_sym( "pcap_minor_version");
}

void* pcap_nametoaddr() {
	__asm__(".symbol_resolver _pcap_nametoaddr");
	return resolve_sym( "pcap_nametoaddr");
}

void* pcap_nametoaddrinfo() {
	__asm__(".symbol_resolver _pcap_nametoaddrinfo");
	return resolve_sym( "pcap_nametoaddrinfo");
}

void* pcap_nametoeproto() {
	__asm__(".symbol_resolver _pcap_nametoeproto");
	return resolve_sym( "pcap_nametoeproto");
}

void* pcap_nametollc() {
	__asm__(".symbol_resolver _pcap_nametollc");
	return resolve_sym( "pcap_nametollc");
}

void* pcap_nametonetaddr() {
	__asm__(".symbol_resolver _pcap_nametonetaddr");
	return resolve_sym( "pcap_nametonetaddr");
}

void* pcap_nametoport() {
	__asm__(".symbol_resolver _pcap_nametoport");
	return resolve_sym( "pcap_nametoport");
}

void* pcap_nametoportrange() {
	__asm__(".symbol_resolver _pcap_nametoportrange");
	return resolve_sym( "pcap_nametoportrange");
}

void* pcap_nametoproto() {
	__asm__(".symbol_resolver _pcap_nametoproto");
	return resolve_sym( "pcap_nametoproto");
}

void* pcap_next() {
	__asm__(".symbol_resolver _pcap_next");
	return resolve_sym( "pcap_next");
}

void* pcap_next_etherent() {
	__asm__(".symbol_resolver _pcap_next_etherent");
	return resolve_sym( "pcap_next_etherent");
}

void* pcap_next_ex() {
	__asm__(".symbol_resolver _pcap_next_ex");
	return resolve_sym( "pcap_next_ex");
}

void* pcap_offline_filter() {
	__asm__(".symbol_resolver _pcap_offline_filter");
	return resolve_sym( "pcap_offline_filter");
}

void* pcap_open_dead() {
	__asm__(".symbol_resolver _pcap_open_dead");
	return resolve_sym( "pcap_open_dead");
}

void* pcap_open_dead_with_tstamp_precision() {
	__asm__(".symbol_resolver _pcap_open_dead_with_tstamp_precision");
	return resolve_sym( "pcap_open_dead_with_tstamp_precision");
}

void* pcap_open_live() {
	__asm__(".symbol_resolver _pcap_open_live");
	return resolve_sym( "pcap_open_live");
}

void* pcap_open_offline() {
	__asm__(".symbol_resolver _pcap_open_offline");
	return resolve_sym( "pcap_open_offline");
}

void* pcap_open_offline_with_tstamp_precision() {
	__asm__(".symbol_resolver _pcap_open_offline_with_tstamp_precision");
	return resolve_sym( "pcap_open_offline_with_tstamp_precision");
}

void* pcap_perror() {
	__asm__(".symbol_resolver _pcap_perror");
	return resolve_sym( "pcap_perror");
}

void* pcap_sendpacket() {
	__asm__(".symbol_resolver _pcap_sendpacket");
	return resolve_sym( "pcap_sendpacket");
}

void* pcap_set_buffer_size() {
	__asm__(".symbol_resolver _pcap_set_buffer_size");
	return resolve_sym( "pcap_set_buffer_size");
}

void* pcap_set_datalink() {
	__asm__(".symbol_resolver _pcap_set_datalink");
	return resolve_sym( "pcap_set_datalink");
}

void* pcap_set_immediate_mode() {
	__asm__(".symbol_resolver _pcap_set_immediate_mode");
	return resolve_sym( "pcap_set_immediate_mode");
}

void* pcap_set_promisc() {
	__asm__(".symbol_resolver _pcap_set_promisc");
	return resolve_sym( "pcap_set_promisc");
}

void* pcap_set_protocol_linux() {
	__asm__(".symbol_resolver _pcap_set_protocol_linux");
	return resolve_sym( "pcap_set_protocol_linux");
}

void* pcap_set_rfmon() {
	__asm__(".symbol_resolver _pcap_set_rfmon");
	return resolve_sym( "pcap_set_rfmon");
}

void* pcap_set_snaplen() {
	__asm__(".symbol_resolver _pcap_set_snaplen");
	return resolve_sym( "pcap_set_snaplen");
}

void* pcap_set_timeout() {
	__asm__(".symbol_resolver _pcap_set_timeout");
	return resolve_sym( "pcap_set_timeout");
}

void* pcap_set_tstamp_precision() {
	__asm__(".symbol_resolver _pcap_set_tstamp_precision");
	return resolve_sym( "pcap_set_tstamp_precision");
}

void* pcap_set_tstamp_type() {
	__asm__(".symbol_resolver _pcap_set_tstamp_type");
	return resolve_sym( "pcap_set_tstamp_type");
}

void* pcap_setdirection() {
	__asm__(".symbol_resolver _pcap_setdirection");
	return resolve_sym( "pcap_setdirection");
}

void* pcap_setfilter() {
	__asm__(".symbol_resolver _pcap_setfilter");
	return resolve_sym( "pcap_setfilter");
}

void* pcap_setnonblock() {
	__asm__(".symbol_resolver _pcap_setnonblock");
	return resolve_sym( "pcap_setnonblock");
}

void* pcap_snapshot() {
	__asm__(".symbol_resolver _pcap_snapshot");
	return resolve_sym( "pcap_snapshot");
}

void* pcap_stats() {
	__asm__(".symbol_resolver _pcap_stats");
	return resolve_sym( "pcap_stats");
}

void* pcap_statustostr() {
	__asm__(".symbol_resolver _pcap_statustostr");
	return resolve_sym( "pcap_statustostr");
}

void* pcap_strerror() {
	__asm__(".symbol_resolver _pcap_strerror");
	return resolve_sym( "pcap_strerror");
}

void* pcap_tstamp_type_name_to_val() {
	__asm__(".symbol_resolver _pcap_tstamp_type_name_to_val");
	return resolve_sym( "pcap_tstamp_type_name_to_val");
}

void* pcap_tstamp_type_val_to_description() {
	__asm__(".symbol_resolver _pcap_tstamp_type_val_to_description");
	return resolve_sym( "pcap_tstamp_type_val_to_description");
}

void* pcap_tstamp_type_val_to_name() {
	__asm__(".symbol_resolver _pcap_tstamp_type_val_to_name");
	return resolve_sym( "pcap_tstamp_type_val_to_name");
}


void* __elf_get_eproto_db(void) {
	return resolve_sym( "eproto_db");
}

void* __elf_get_pcap_version(void) {
	return pcap_version;
}
