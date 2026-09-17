project(darling_applications)

if (COMPONENT_gui)
	add_darling_executable(darling_applications main.m)
	set_target_properties(darling_applications PROPERTIES OUTPUT_NAME "Darling Applications")
	target_link_libraries(darling_applications AppKit Foundation objc)
	install(TARGETS darling_applications RUNTIME DESTINATION "libexec/darling/Applications/Darling Applications.app/Contents/MacOS")
	install(FILES Info.plist DESTINATION "libexec/darling/Applications/Darling Applications.app/Contents")

	# Install helper scripts to /usr/libexec/darling inside the guest
	install(PROGRAMS
		"${CMAKE_SOURCE_DIR}/tools/darling-applications/homebrew-bootstrap"
		"${CMAKE_SOURCE_DIR}/tools/darling-applications/brewfile-install"
		DESTINATION "libexec/darling/usr/libexec/darling"
	)
endif()
