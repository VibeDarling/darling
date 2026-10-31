project(HelloSwiftUI)

# A SwiftUI "Hello, world" built as an iOS app against Darling's SwiftUI
# (src/frameworks/SwiftUI). Built only when that is (see cmake/swift_ios.cmake).

include(swift_ios)
if (NOT DARLING_SWIFT_IOS)
	return()
endif()

set(HELLO_OBJECT "${CMAKE_CURRENT_BINARY_DIR}/HelloApp.swift.o")
add_swift_ios_object("${HELLO_OBJECT}"
	MODULE HelloSwiftUI
	SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/HelloApp.swift
	FLAGS -I "${SWIFTUI_MODULE_DIR}"
	DEPENDS SwiftUI_swiftmodule "${SWIFTUI_MODULE_DIR}/SwiftUI.swiftmodule")

add_darling_executable(HelloSwiftUI "${HELLO_OBJECT}" ${DARLING_SWIFT_IOS_RT_SOURCES})
set_target_properties(HelloSwiftUI PROPERTIES LINKER_LANGUAGE C)
target_link_libraries(HelloSwiftUI SwiftUI objc)
set_property(TARGET HelloSwiftUI APPEND_STRING PROPERTY
	LINK_FLAGS " -L${CMAKE_SOURCE_DIR}/src/external/swift ")

# Marked as an iOS app after linking, like Terminal (see its set-ios-platform.py).
find_package(Python3 COMPONENTS Interpreter)
if (Python3_FOUND)
	add_custom_command(TARGET HelloSwiftUI POST_BUILD
		COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/src/Terminal/set-ios-platform.py $<TARGET_FILE:HelloSwiftUI> 14.0
		COMMENT "Marking HelloSwiftUI as an iOS app")
endif()

set(HELLO_APP libexec/darling/Applications/HelloSwiftUI.app)
install(TARGETS HelloSwiftUI DESTINATION ${HELLO_APP})
install(FILES Info.plist DESTINATION ${HELLO_APP})
