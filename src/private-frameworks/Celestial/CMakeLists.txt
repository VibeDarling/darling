project(Celestial)

# iOS's media framework before AVFoundation took over. Old tweaks link it
# (WinterBoard does, for video wallpapers it no longer plays) without
# calling anything in it; this is the framework for them to find.

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

add_framework(Celestial
    FAT
    CURRENT_VERSION
    PRIVATE
    IOSSUPPORT
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/Celestial.c

    DEPENDENCIES
        system
)
