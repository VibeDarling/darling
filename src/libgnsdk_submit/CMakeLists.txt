project(gnsdk_submit)

set(DYLIB_INSTALL_NAME "/usr/lib/libgnsdk_submit.3.06.dylib")
set(DYLIB_COMPAT_VERSION "3.06.0")
set(DYLIB_CURRENT_VERSION "3.06.0")

include_directories(include)

add_darling_library(gnsdk_submit.3.06 SHARED
    src/gnsdk_submit.c
)
make_fat(gnsdk_submit.3.06)
target_link_libraries(gnsdk_submit.3.06 system)
install(TARGETS gnsdk_submit.3.06 DESTINATION libexec/darling/usr/lib)
