project(CydiaSubstrate)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# The hooking API. Rootful tweaks link it by this name, older ones as
# /usr/lib/libsubstrate.dylib; rootless ones find it through /var/jb,
# which the mobilesubstrate package links here.
set(DYLIB_INSTALL_NAME "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate")
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")
add_darling_library(CydiaSubstrate
	src/hook.c
	src/image.c
	src/message.c
)
make_fat(CydiaSubstrate)
set_target_properties(CydiaSubstrate PROPERTIES PREFIX "" SUFFIX "")
target_link_libraries(CydiaSubstrate system objc)
install(TARGETS CydiaSubstrate DESTINATION libexec/darling/Library/Frameworks/CydiaSubstrate.framework)
install(FILES include/substrate.h DESTINATION libexec/darling/Library/Frameworks/CydiaSubstrate.framework/Headers RENAME CydiaSubstrate.h)
InstallSymlink(/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate ${CMAKE_INSTALL_PREFIX}/libexec/darling/usr/lib/libsubstrate.dylib)

# Loads the tweaks; UIKit opens it at startup.
set(DYLIB_INSTALL_NAME "/usr/lib/substrate/SubstrateLoader.dylib")
add_darling_library(SubstrateLoader src/loader.c)
make_fat(SubstrateLoader)
set_target_properties(SubstrateLoader PROPERTIES PREFIX "")
target_link_libraries(SubstrateLoader system objc CoreFoundation)
install(TARGETS SubstrateLoader DESTINATION libexec/darling/usr/lib/substrate)
install(DIRECTORY DESTINATION libexec/darling/Library/MobileSubstrate/DynamicLibraries)
