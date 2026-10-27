project(frontboardd)

add_definitions(-nostdinc)

add_darling_executable(frontboardd frontboardd.m)
target_compile_options(frontboardd PRIVATE -fobjc-arc)
target_include_directories(frontboardd PRIVATE ../private-frameworks/FrontBoardServices/src)
target_link_libraries(frontboardd FrontBoardServices RunningBoardServices Foundation objc)

install(TARGETS frontboardd DESTINATION libexec/darling/usr/libexec)
