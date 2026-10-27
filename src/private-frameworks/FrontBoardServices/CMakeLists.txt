project(FrontBoardServices)

remove_sdk_framework(FrontBoardServices
    PRIVATE
)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(FrontBoardServices
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/FrontBoardServices"
    PRIVATE
)

add_framework(FrontBoardServices
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/FBSSystemService.m
        src/FBSSceneSettings.m
        src/FBSWorkspace.m
        src/FBSLite.m

    DEPENDENCIES
        system
        objc
        Foundation
        RunningBoardServices
)
target_compile_options(FrontBoardServices PRIVATE -fobjc-arc)
target_include_directories(FrontBoardServices PRIVATE ../RunningBoardServices/include)
