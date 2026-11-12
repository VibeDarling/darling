project(Terminal)

add_definitions(-nostdinc)

add_darling_executable(Terminal Terminal.m TerminalScreen.m TerminalView.m)
# The rest of the tree builds at -O0; the escape sequence parser runs per
# byte of output, so this one is optimized.
target_compile_options(Terminal PRIVATE -fobjc-arc -O2)
target_link_libraries(Terminal UIKit AppKit CoreText CoreGraphics Foundation objc)

# An iOS app: its LC_BUILD_VERSION says platform iOS (2), minimum 14.0, so
# dyld treats it as one. It is linked for macOS like the rest of the tree
# and marked afterwards (see set-ios-platform.py for why).
find_package(Python3 COMPONENTS Interpreter)
if (Python3_FOUND)
	add_custom_command(TARGET Terminal POST_BUILD
		COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/set-ios-platform.py $<TARGET_FILE:Terminal> 14.0
		COMMENT "Marking Terminal as an iOS app")
else()
	message(WARNING "No Python 3: Terminal stays marked as a macOS binary (it still runs)")
endif()

set(TERMINAL_APP libexec/darling/Applications/Terminal.app)
install(TARGETS Terminal DESTINATION ${TERMINAL_APP})
install(FILES Info.plist AppIcon60x60.png AppIcon60x60@2x.png AppIcon60x60@3x.png
	DESTINATION ${TERMINAL_APP})
