project(DarlingBoard)

remove_sdk_framework(DarlingBoard
    PRIVATE
)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(DarlingBoard
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/DarlingBoard"
    PRIVATE
)

add_framework(DarlingBoard
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/DBApplicationService.m
        src/DBAppConnection.m
        src/DBProcess.m
        src/DBWire.m

    DEPENDENCIES
        system
        objc
        Foundation
)
target_compile_options(DarlingBoard PRIVATE -fobjc-arc)
