project(CryptoKit)

# CryptoKit is a pure-Swift framework: no ObjC/C headers, so no SDK framework is generated for it.
# Swift on macOS is 64-bit only and CryptoKit never shipped for i386, so this is not a FAT target;
# DARLING_LIB_64BIT_ONLY keeps add_darling_library from adding an i386 slice, matching the other
# hand-written Swift-ABI stubs in src/external/swift.
set(DARLING_LIB_64BIT_ONLY TRUE)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

add_framework(CryptoKit
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/CryptoKit.S
		src/unavailable.c

	DEPENDENCIES
		system
)
