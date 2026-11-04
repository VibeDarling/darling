project(BackgroundTasks)

remove_sdk_framework(BackgroundTasks)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(BackgroundTasks
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/BackgroundTasks"
)

add_framework(BackgroundTasks
    FAT
    CURRENT_VERSION
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/BackgroundTasks.m

    DEPENDENCIES
        system
        objc
        Foundation
)
