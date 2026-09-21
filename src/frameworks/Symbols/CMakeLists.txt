project(Symbols)

# Symbols.framework is macOS 14+ and Swift-only; it has never had a 32-bit slice.
set(DARLING_LIB_64BIT_ONLY TRUE)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "190.4.0")

set(FRAMEWORK_VERSION "A")

# No generate_sdk_framework/remove_sdk_framework pair, unlike most frameworks here: Symbols ships no
# headers, so there is nothing to publish into the SDK. remove_sdk_framework on its own would not be
# the harmless consistency it looks like, since it deletes the SDK framework directory outright and
# nothing would put one back.

add_framework(Symbols
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	# _$sBOWV (Builtin.NativeObject's value witnesses) and the empty dictionary singleton come from
	# libswiftCore at runtime; Darling has no link-time stub for them.
	LINK_FLAGS "-Wl,-U,'_\$sBOWV' -Wl,-U,__swiftEmptyDictionarySingleton"

	SOURCES
		src/Symbols.S

	DEPENDENCIES
		system
)

set_target_properties(Symbols PROPERTIES LINKER_LANGUAGE C)
