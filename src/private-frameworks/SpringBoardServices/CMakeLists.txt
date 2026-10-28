project(SpringBoardServices)

remove_sdk_framework(SpringBoardServices
    PRIVATE
)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(SpringBoardServices
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/SpringBoardServices"
    PRIVATE
)

add_framework(SpringBoardServices
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/SpringBoardServices.m

    DEPENDENCIES
        system
        objc
        Foundation
        FrontBoardServices
)
# The Copy functions return retained objects, which is plainer without ARC.
target_include_directories(SpringBoardServices PRIVATE ../FrontBoardServices/include ../RunningBoardServices/include)
