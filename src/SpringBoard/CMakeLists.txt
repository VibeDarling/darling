project(SpringBoard)

add_definitions(-nostdinc)

add_darling_executable(SpringBoard SpringBoard.m)
target_compile_options(SpringBoard PRIVATE -fobjc-arc)
target_link_libraries(SpringBoard UIKit FrontBoardServices CoreGraphics Foundation objc)

install(TARGETS SpringBoard DESTINATION libexec/darling/System/Library/CoreServices/SpringBoard.app)
install(FILES Info.plist DESTINATION libexec/darling/System/Library/CoreServices/SpringBoard.app)
