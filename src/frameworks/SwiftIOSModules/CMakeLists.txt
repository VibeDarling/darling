project(SwiftIOSModules)

# iOS-only Swift modules built from authored source against the public iOS
# SDK's interfaces (see build.sh): CoreTransferable, PhotosUI's Swift overlay
# and _PhotosUI_SwiftUI, plus UIKit's Swift overlay. They share the Foundation supplement's SDK settings.
option(DARLING_IOS_SWIFT_MODULES "Build the arm64 iOS-only Swift modules" OFF)
if(DARLING_IOS_SWIFT_MODULES)
    foreach(required IN ITEMS DARLING_SWIFT_TOOLCHAIN DARLING_SWIFT_IOS_STDLIB
            DARLING_FOUNDATION_SWIFT_SDK DARLING_FOUNDATION_SWIFT_SHIMS DARLING_FOUNDATION_SWIFT_APINOTES)
        if(NOT IS_DIRECTORY "${${required}}")
            message(FATAL_ERROR "${required} must name an existing directory")
        endif()
    endforeach()
    set(out "${CMAKE_CURRENT_BINARY_DIR}")
    set(outputs "${out}/CoreTransferable" "${out}/libswiftPhotosUI.dylib" "${out}/_PhotosUI_SwiftUI")
    add_custom_command(OUTPUT ${outputs}
        COMMAND ${CMAKE_COMMAND} -E env
            "OUT=${out}"
            "SWIFT_TOOLCHAIN=${DARLING_SWIFT_TOOLCHAIN}"
            "SWIFT_CORE_MODULES=${DARLING_SWIFT_IOS_STDLIB}"
            "SWIFT_SHIMS=${DARLING_FOUNDATION_SWIFT_SHIMS}"
            "SWIFT_APINOTES=${DARLING_FOUNDATION_SWIFT_APINOTES}"
            "IOS_SDK=${DARLING_FOUNDATION_SWIFT_SDK}"
            "LD_LIBRARY_PATH=${DARLING_SWIFT_HOST_LIBS}"
            bash "${CMAKE_CURRENT_SOURCE_DIR}/build.sh"
        DEPENDS build.sh CoreTransferable.swift PhotosUI.swift PhotosUISwiftUI.swift
            "${DARLING_SWIFT_TOOLCHAIN}/bin/swiftc"
        VERBATIM COMMENT "Building source-only iOS Swift modules")
    # UIKit's Swift overlay, from src/frameworks/UIKit/swift, with the same SDK and Swift modules.
    set(uikit_overlay "${out}/uikit/UIKit.framework/UIKit")
    add_custom_command(OUTPUT "${uikit_overlay}"
        COMMAND ${CMAKE_COMMAND} -E env
            "SWIFT_TOOLCHAIN=${DARLING_SWIFT_TOOLCHAIN}"
            "SWIFT_CORE_MODULES=${DARLING_SWIFT_IOS_STDLIB}"
            "SWIFT_SHIMS=${DARLING_FOUNDATION_SWIFT_SHIMS}"
            "SWIFT_APINOTES=${DARLING_FOUNDATION_SWIFT_APINOTES}"
            "IOS_SDK=${DARLING_FOUNDATION_SWIFT_SDK}"
            "LD_LIBRARY_PATH=${DARLING_SWIFT_HOST_LIBS}"
            INSTALL_NAME=/usr/lib/swift/libswiftUIKit.dylib LINK_NAME=swiftUIKit
            bash "${CMAKE_SOURCE_DIR}/src/frameworks/SwiftUI/abi/build-ios-swift-framework.sh"
            UIKit "${out}/uikit" "${CMAKE_SOURCE_DIR}/src/frameworks/UIKit/swift/UIKit.swift" -- -framework UIKit
        DEPENDS "${CMAKE_SOURCE_DIR}/src/frameworks/UIKit/swift/UIKit.swift"
            "${CMAKE_SOURCE_DIR}/src/frameworks/SwiftUI/abi/build-ios-swift-framework.sh"
        VERBATIM COMMENT "Building the UIKit Swift overlay")
    add_custom_target(SwiftIOSModules ALL DEPENDS ${outputs} "${uikit_overlay}")
    install(PROGRAMS "${uikit_overlay}" DESTINATION libexec/darling/usr/lib/swift RENAME libswiftUIKit.dylib)

    include(InstallSymlink)
    foreach(framework IN ITEMS CoreTransferable _PhotosUI_SwiftUI)
        if(framework STREQUAL "_PhotosUI_SwiftUI")
            # Beside SwiftUI, which it extends.
            set(dir "libexec/darling/System/iOSSupport/System/Library/Frameworks/${framework}.framework")
        else()
            set(dir "libexec/darling/System/Library/Frameworks/${framework}.framework")
        endif()
        install(PROGRAMS "${out}/${framework}" DESTINATION "${dir}/Versions/A")
        InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${dir}/Versions/Current")
        InstallSymlink("Versions/Current/${framework}" "${CMAKE_INSTALL_PREFIX}/${dir}/${framework}")
    endforeach()
    install(PROGRAMS "${out}/libswiftPhotosUI.dylib" DESTINATION libexec/darling/usr/lib/swift)
endif()
