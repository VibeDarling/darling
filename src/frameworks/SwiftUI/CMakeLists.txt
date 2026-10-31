project(SwiftUI)

# Darling's SwiftUI: a source-compatible SwiftUI written for Darling (Sources/),
# drawn with Darling's UIKit through a small C/Objective-C backend
# (backend/). Not Apple's SwiftUI, and not ABI-compatible with it: apps are
# built from source against this module. Needs a host Swift compiler; see
# cmake/swift_ios.cmake and README.md.

include(swift_ios)
if (NOT DARLING_SWIFT_IOS)
	message(STATUS "SwiftUI: skipped (set DARLING_SWIFT_TOOLCHAIN and DARLING_SWIFT_IOS_STDLIB to build it)")
	return()
endif()

set(SWIFTUI_SOURCES
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/App.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/Modifiers.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/Render.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/State.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/Style.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/View.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/ViewBuilder.swift
	${CMAKE_CURRENT_SOURCE_DIR}/Sources/Views.swift
)
# Where apps' Swift compiles find `import SwiftUI` (SWIFTUI_MODULE_DIR).
set(SWIFTUI_MODULE_DIR "${CMAKE_CURRENT_BINARY_DIR}/modules" CACHE INTERNAL "")
set(SWIFTUI_SWIFTMODULE "${SWIFTUI_MODULE_DIR}/SwiftUI.swiftmodule")
set(SWIFTUI_SWIFTINTERFACE "${SWIFTUI_MODULE_DIR}/SwiftUI.swiftinterface")
set(SWIFTUI_OBJECT "${CMAKE_CURRENT_BINARY_DIR}/SwiftUI.swift.o")
file(MAKE_DIRECTORY "${SWIFTUI_MODULE_DIR}")

# Library evolution, as Apple builds SwiftUI: clients then never need the
# backend's Clang module, which the Swift code imports internally.
add_swift_ios_object("${SWIFTUI_OBJECT}"
	MODULE SwiftUI
	SOURCES ${SWIFTUI_SOURCES}
	FLAGS -enable-library-evolution
		-I "${CMAKE_CURRENT_SOURCE_DIR}/backend"
		-emit-module-path "${SWIFTUI_SWIFTMODULE}"
		-emit-module-interface-path "${SWIFTUI_SWIFTINTERFACE}"
	OUTPUTS "${SWIFTUI_SWIFTMODULE}" "${SWIFTUI_SWIFTINTERFACE}"
	DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/backend/SwiftUIBackend.h ${CMAKE_CURRENT_SOURCE_DIR}/backend/module.modulemap)
add_custom_target(SwiftUI_swiftmodule DEPENDS "${SWIFTUI_OBJECT}" "${SWIFTUI_SWIFTMODULE}")

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

add_framework(SwiftUI
	IOSSUPPORT
	CURRENT_VERSION
	VERSION A
	SOURCES
		backend/SwiftUIBackend.m
		${DARLING_SWIFT_IOS_RT_SOURCES}
	OBJECTS
		"${SWIFTUI_OBJECT}"
	DEPENDENCIES
		UIKit
		AppKit
		Foundation
		objc
		system
)
target_include_directories(SwiftUI PRIVATE backend)
target_compile_options(SwiftUI PRIVATE -fobjc-arc)
add_dependencies(SwiftUI SwiftUI_swiftmodule)
# The Swift object autolinks libswiftCore (mapped to src/external/swift by
# add_swift_dylib_map); -L lets ld64 resolve the -lswiftCore it names.
set_property(TARGET SwiftUI APPEND_STRING PROPERTY
	LINK_FLAGS " -L${CMAKE_SOURCE_DIR}/src/external/swift ")

# The module, for building apps against the installed framework.
install(FILES "${SWIFTUI_SWIFTMODULE}"
	DESTINATION "libexec/darling/System/iOSSupport/System/Library/Frameworks/SwiftUI.framework/Versions/A/Modules/SwiftUI.swiftmodule"
	RENAME arm64-apple-ios.swiftmodule)
install(FILES "${SWIFTUI_SWIFTINTERFACE}"
	DESTINATION "libexec/darling/System/iOSSupport/System/Library/Frameworks/SwiftUI.framework/Versions/A/Modules/SwiftUI.swiftmodule"
	RENAME arm64-apple-ios.swiftinterface)
InstallSymlink(Versions/Current/Modules
	"${CMAKE_INSTALL_PREFIX}/libexec/darling/System/iOSSupport/System/Library/Frameworks/SwiftUI.framework/Modules")
