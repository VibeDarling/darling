# Compiling Swift for iOS apps and frameworks (arm64 only).
#
# Darling's own toolchain has no Swift compiler, so Swift sources are compiled
# with a host swiftc (the Linux release of the Swift version Darling's
# libswiftCore comes from, 6.3.3) into Mach-O objects that the usual Darling
# targets then link with ld64. Two cache variables enable it:
#
#   DARLING_SWIFT_TOOLCHAIN    usr/ of the Swift 6.3.3 toolchain (bin/swiftc)
#   DARLING_SWIFT_IOS_STDLIB   a directory holding Swift.swiftmodule built for
#                              arm64-apple-ios (6.3.3; see
#                              src/frameworks/SwiftUI/README.md for how to
#                              make one)
#   DARLING_SWIFT_HOST_LIBS    optional: LD_LIBRARY_PATH for swiftc (e.g. a
#                              libncurses.so.6 the host lacks)
#
# Without them DARLING_SWIFT_IOS is OFF and Swift targets are skipped.

set(DARLING_SWIFT_TOOLCHAIN "" CACHE PATH "usr/ directory of a Swift 6.3.3 toolchain, for iOS Swift code")
set(DARLING_SWIFT_IOS_STDLIB "" CACHE PATH "Directory containing Swift.swiftmodule for arm64-apple-ios (Swift 6.3.3)")
set(DARLING_SWIFT_HOST_LIBS "" CACHE PATH "Extra LD_LIBRARY_PATH for the host swiftc")

set(DARLING_SWIFT_IOS OFF)
if (TARGET_ARM64 AND DARLING_SWIFT_TOOLCHAIN AND DARLING_SWIFT_IOS_STDLIB)
	if (EXISTS "${DARLING_SWIFT_TOOLCHAIN}/bin/swiftc" AND EXISTS "${DARLING_SWIFT_IOS_STDLIB}/Swift.swiftmodule")
		set(DARLING_SWIFT_IOS ON)
	else()
		message(WARNING "DARLING_SWIFT_TOOLCHAIN or DARLING_SWIFT_IOS_STDLIB is wrong: no bin/swiftc or Swift.swiftmodule; iOS Swift code is skipped")
	endif()
endif()

set(DARLING_SWIFT_IOS_TARGET "arm64-apple-ios14.0")
# Add to every binary with Swift objects: `#available` checks call into it.
set(DARLING_SWIFT_IOS_RT_SOURCES "${CMAKE_SOURCE_DIR}/src/frameworks/SwiftUI/backend/os_version_check.c")

# add_swift_ios_object(<output .o> MODULE <name> SOURCES <.swift...>
#                      [FLAGS <swiftc -frontend flags...>] [DEPENDS <files/targets...>]
#                      [OUTPUTS <other files the flags make, e.g. the .swiftmodule>])
# The objects need no Swift compatibility libraries, concurrency or string
# processing modules, which Darling's runtime set does not have for iOS.
function(add_swift_ios_object output)
	cmake_parse_arguments(SWIFT "" "MODULE" "SOURCES;FLAGS;DEPENDS;OUTPUTS" ${ARGN})
	set(env "")
	if (DARLING_SWIFT_HOST_LIBS)
		set(env "LD_LIBRARY_PATH=${DARLING_SWIFT_HOST_LIBS}")
	endif()
	add_custom_command(
		OUTPUT "${output}" ${SWIFT_OUTPUTS}
		COMMAND ${CMAKE_COMMAND} -E env ${env}
			"${DARLING_SWIFT_TOOLCHAIN}/bin/swiftc" -frontend -c ${SWIFT_SOURCES}
			-target ${DARLING_SWIFT_IOS_TARGET} -module-name ${SWIFT_MODULE}
			-swift-version 5 -O -parse-as-library
			# ARMv8.0 (no LSE atomics, no RCpc): phones like the Exynos 9810 and
			# the Pi 4's Cortex-A72 lack them. apple-a7 is also swiftc's default
			# for iOS; spelled out so it stays the baseline.
			-Xcc -mcpu=apple-a7
			-runtime-compatibility-version none
			-disable-autolinking-runtime-compatibility-dynamic-replacements
			-disable-implicit-concurrency-module-import
			-disable-implicit-string-processing-module-import
			-I "${DARLING_SWIFT_IOS_STDLIB}"
			-module-cache-path "${CMAKE_BINARY_DIR}/swift-module-cache"
			${SWIFT_FLAGS}
			-o "${output}"
		DEPENDS ${SWIFT_SOURCES} ${SWIFT_DEPENDS}
		COMMENT "Compiling Swift module ${SWIFT_MODULE} for iOS"
		VERBATIM)
	set_source_files_properties("${output}" PROPERTIES GENERATED TRUE EXTERNAL_OBJECT TRUE)
endfunction()
