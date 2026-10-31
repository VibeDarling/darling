project(SpringBoard)

add_definitions(-nostdinc)

add_darling_executable(SpringBoard SpringBoard.m SBNotifications.m)
target_compile_options(SpringBoard PRIVATE -fobjc-arc)
target_include_directories(SpringBoard PRIVATE ../frameworks/UserNotifications/src)
target_link_libraries(SpringBoard UIKit AppKit FrontBoardServices UserNotifications AudioToolbox CoreGraphics Foundation objc)

# Marked as an iOS app like Terminal (see ../Terminal/set-ios-platform.py):
# dyld loads iOS tweaks (MobileSubstrate dylibs) only into iOS processes.
find_package(Python3 COMPONENTS Interpreter)
if (Python3_FOUND)
	add_custom_command(TARGET SpringBoard POST_BUILD
		COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/../Terminal/set-ios-platform.py $<TARGET_FILE:SpringBoard> 14.0
		COMMENT "Marking SpringBoard as an iOS app")
endif()

install(TARGETS SpringBoard DESTINATION libexec/darling/System/Library/CoreServices/SpringBoard.app)
install(FILES Info.plist SBDockBG.png DESTINATION libexec/darling/System/Library/CoreServices/SpringBoard.app)
