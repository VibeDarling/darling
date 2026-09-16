project(darling_applications)

if (COMPONENT_gui)
	add_executable(darling_applications main.m)
	set_target_properties(darling_applications PROPERTIES OUTPUT_NAME "Darling Applications")
	target_link_libraries(darling_applications AppKit Foundation objc)
	install(TARGETS darling_applications RUNTIME DESTINATION "Applications/Darling Applications.app/Contents/MacOS")
	install(FILES Info.plist DESTINATION "Applications/Darling Applications.app/Contents")
endif()
