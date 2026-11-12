project(usernotificationsd)

add_definitions(-nostdinc)

add_darling_executable(usernotificationsd usernotificationsd.m)
target_compile_options(usernotificationsd PRIVATE -fobjc-arc)
target_include_directories(usernotificationsd PRIVATE
	../frameworks/UserNotifications/src
	../private-frameworks/DarlingBoard/src
)
target_link_libraries(usernotificationsd UserNotifications DarlingBoard Foundation objc)

install(TARGETS usernotificationsd DESTINATION libexec/darling/usr/libexec)
