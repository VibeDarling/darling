project(libmd)

set(DYLIB_INSTALL_NAME "/usr/lib/libmd.dylib")
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

add_darling_library(md SHARED
	src/md.c
)
make_fat(md)
target_link_libraries(md system)

install(TARGETS md DESTINATION libexec/darling/usr/lib)
