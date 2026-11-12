project(RunningBoardServices)

remove_sdk_framework(RunningBoardServices
    PRIVATE
)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(RunningBoardServices
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/RunningBoardServices"
    PRIVATE
)

add_framework(RunningBoardServices
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/RunningBoardServices.c

    DEPENDENCIES
        system
)
