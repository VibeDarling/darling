project(installd)

add_definitions(-nostdinc)

add_darling_executable(installd installd.m)
target_compile_options(installd PRIVATE -fobjc-arc)
target_link_libraries(installd Foundation objc)

install(TARGETS installd DESTINATION libexec/darling/usr/libexec)
