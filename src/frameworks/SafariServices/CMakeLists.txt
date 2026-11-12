project(SafariServices)

remove_sdk_framework(SafariServices)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(SafariServices
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/SafariServices"
)

# UIKit's view controllers, so it installs beside UIKit in iOSSupport.
add_framework(SafariServices
    IOSSUPPORT
    FAT
    CURRENT_VERSION
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/SafariServices.m

    DEPENDENCIES
        system
        objc
        Foundation
        UIKit
        AppKit # UIKit re-exports it
)
