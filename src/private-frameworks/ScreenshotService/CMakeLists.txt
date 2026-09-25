add_darling_executable(screenshotserviced src/main.c)

install(
    TARGETS screenshotserviced
    DESTINATION libexec/darling/usr/libexec
)

install(
    FILES resources/com.apple.systemuiserver.screencapture.plist
    DESTINATION libexec/darling/System/Library/LaunchDaemons
)
