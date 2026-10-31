project(MobileTimer)

add_definitions(-nostdinc)

add_darling_executable(MobileTimer MobileTimer.m)
target_compile_options(MobileTimer PRIVATE -fobjc-arc)
target_link_libraries(MobileTimer UserNotifications UIKit AppKit CoreGraphics Foundation objc)

# Marked as an iOS app like Terminal (see ../Terminal/set-ios-platform.py).
find_package(Python3 COMPONENTS Interpreter)
if (Python3_FOUND)
	add_custom_command(TARGET MobileTimer POST_BUILD
		COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/../Terminal/set-ios-platform.py $<TARGET_FILE:MobileTimer> 14.0
		COMMENT "Marking Clock as an iOS app")
endif()

# Where iOS keeps it, with its bundle identifier and executable name.
set(CLOCK_APP libexec/darling/Applications/MobileTimer.app)
install(TARGETS MobileTimer DESTINATION ${CLOCK_APP})
install(FILES Info.plist AppIcon60x60.png AppIcon60x60@2x.png AppIcon60x60@3x.png
	DESTINATION ${CLOCK_APP})
