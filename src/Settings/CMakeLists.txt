project(Settings)

add_definitions(-nostdinc)

add_darling_executable(Settings Settings.m)
target_compile_options(Settings PRIVATE -fobjc-arc)
target_include_directories(Settings PRIVATE ../private-frameworks/Preferences/include ../frameworks/UIKit/include)
target_link_libraries(Settings Preferences UIKit AppKit CoreGraphics Foundation objc)
# The executable is Preferences, as on iOS (tweak filters name it).
set_target_properties(Settings PROPERTIES OUTPUT_NAME Preferences)

# Marked as an iOS app like Terminal (see ../Terminal/set-ios-platform.py).
find_package(Python3 COMPONENTS Interpreter)
if (Python3_FOUND)
	add_custom_command(TARGET Settings POST_BUILD
		COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/../Terminal/set-ios-platform.py $<TARGET_FILE:Settings> 14.0
		COMMENT "Marking Settings as an iOS app")
endif()

# Where iOS keeps it, with the bundle identifier tweaks expect.
set(SETTINGS_APP libexec/darling/Applications/Preferences.app)
install(TARGETS Settings DESTINATION ${SETTINGS_APP})
install(FILES Info.plist AppIcon60x60.png AppIcon60x60@2x.png AppIcon60x60@3x.png
	DESTINATION ${SETTINGS_APP})
install(DIRECTORY DESTINATION libexec/darling/Library/PreferenceLoader/Preferences)
install(DIRECTORY DESTINATION libexec/darling/Library/PreferenceBundles)
