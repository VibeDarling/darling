project(WebKitLegacy)

# iOS's legacy WebKit, the engine behind UIWebView: WebCore.framework and
# WebKit.framework under /System/iOSSupport/System/Library/PrivateFrameworks,
# where iOS apps (which link the private frameworks by those names) find them.
# Darling's macOS WebKit.framework is separate and untouched.

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "605.1.15")

set(FRAMEWORK_VERSION "A")

add_framework(WebCore
    TARGET_NAME WebCore_iOS
    FAT
    CURRENT_VERSION
    PRIVATE
    IOSSUPPORT
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/WebCore.m

    DEPENDENCIES
        system
        objc
        Foundation
        CoreFoundation
)
target_include_directories(WebCore_iOS PRIVATE include)
target_compile_options(WebCore_iOS PRIVATE -fobjc-arc)

add_framework(WebKit
    TARGET_NAME WebKitLegacy_iOS
    FAT
    CURRENT_VERSION
    PRIVATE
    IOSSUPPORT
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/WebKit.m

    DEPENDENCIES
        system
        objc
        Foundation
        CoreFoundation
        CoreGraphics
        WebCore_iOS
)
target_include_directories(WebKitLegacy_iOS PRIVATE include)
target_compile_options(WebKitLegacy_iOS PRIVATE -fobjc-arc)
