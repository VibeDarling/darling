project(CoreAudio)

include_directories(BEFORE ${CMAKE_CURRENT_BINARY_DIR})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
add_definitions(-DINSTALL_PREFIX="${CMAKE_INSTALL_PREFIX}")

set(coreaudio_sources
	AudioHardware.cpp
    AudioHardwareImpl.cpp
    HostTime.mm
    pulse/AudioHardwareImplPA.cpp
    pulse/AudioHardwareImplPAInput.cpp
    pulse/AudioHardwareImplPAOutput.cpp
    AudioHardwareStream.cpp
    pulse/AudioHardwareStreamPA.cpp
    pulse/PAThreadedMainLoop.cpp
    aaudio/AAudioLibrary.cpp
    aaudio/AudioHardwareImplAAudio.cpp
    aaudio/AudioHardwareStreamAAudio.cpp
)

include_directories(${CMAKE_SOURCE_DIR}/src/startup/mldr/elfcalls)

add_framework(CoreAudio
	FAT
    CURRENT_VERSION
    VERSION "A"

    SOURCES
        ${coreaudio_sources}

    DEPENDENCIES
        system
        cxx
        CoreFoundation
        pulse
)
