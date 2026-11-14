project(cfprefsd)

add_darling_executable(cfprefsd cfprefsd.c paths.c store.c)
target_link_libraries(cfprefsd system CoreFoundation)

install(TARGETS cfprefsd DESTINATION libexec/darling/usr/sbin)
install(FILES com.apple.cfprefsd.daemon.plist DESTINATION libexec/darling/System/Library/LaunchDaemons)
