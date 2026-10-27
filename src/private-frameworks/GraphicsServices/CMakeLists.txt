project(GraphicsServices)

remove_sdk_framework(GraphicsServices
    PRIVATE
)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "14.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(GraphicsServices
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/GraphicsServices"
    PRIVATE
)

add_framework(GraphicsServices
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/GSEvent.c
        src/GSScreen.c

    DEPENDENCIES
        system
        CoreFoundation
)
