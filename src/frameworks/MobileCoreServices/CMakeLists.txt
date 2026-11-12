project(MobileCoreServices)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

# iOS's MobileCoreServices: uniform type identifiers and the app workspace
# (LSApplicationWorkspace, LSApplicationProxy). macOS keeps both in
# CoreServices, which this re-exports, as the Mac Catalyst one does.
add_framework(MobileCoreServices
    IOSSUPPORT
    CURRENT_VERSION
    FAT
    VERSION A
    SOURCES
        src/MobileCoreServices.c
    DEPENDENCIES
        system
)

reexport(MobileCoreServices CoreServices ${CMAKE_BINARY_DIR}/src/frameworks/CoreServices/CoreServices)
