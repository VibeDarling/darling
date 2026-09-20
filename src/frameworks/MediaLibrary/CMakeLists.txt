project(MediaLibrary)

remove_sdk_framework(MediaLibrary)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "812.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(MediaLibrary
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/MediaLibrary"
)

add_framework(MediaLibrary
    FAT
    CURRENT_VERSION
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/MediaLibrary.c

    DEPENDENCIES
        system
)
