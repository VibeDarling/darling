project(Preferences)

# iOS's settings framework (PSListController and friends), which the Settings
# app and tweaks' preference bundles use. Under
# /System/iOSSupport/System/Library/PrivateFrameworks, where iOS apps find it.

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

add_framework(Preferences
    FAT
    CURRENT_VERSION
    PRIVATE
    IOSSUPPORT
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/PSSpecifier.m
        src/PSTableCell.m
        src/PSViewController.m
        src/PSListController.m

    DEPENDENCIES
        system
        objc
        Foundation
        CoreFoundation
        UIKit
        AppKit
)
target_include_directories(Preferences PRIVATE include ../../frameworks/UIKit/include)
target_compile_options(Preferences PRIVATE -fobjc-arc)
