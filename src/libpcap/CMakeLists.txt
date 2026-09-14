project(pcap)

include(darling_lib)
include(InstallSymlink)

set(DYLIB_INSTALL_NAME "/usr/lib/libpcap.A.dylib")
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.10.6")

include_directories(${CMAKE_SOURCE_DIR}/src/startup/mldr/elfcalls)

add_darling_library(pcap SHARED
	src/pcap.c
)
make_fat(pcap)
target_link_libraries(pcap system)
set_target_properties(pcap PROPERTIES LINKER_LANGUAGE C OUTPUT_NAME "pcap.A")

install(TARGETS pcap DESTINATION libexec/darling/usr/lib)
InstallSymlink("libpcap.A.dylib" "${CMAKE_INSTALL_PREFIX}/libexec/darling/usr/lib/libpcap.dylib")
