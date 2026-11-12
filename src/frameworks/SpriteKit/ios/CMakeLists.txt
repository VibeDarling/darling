project(SpriteKit_iOS)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "49.2.0")

# iOS's SpriteKit, on UIKit, drawn with OpenGL ES (see src/SKView.m). The
# macOS framework in the parent directory stays the generated stubs.
add_framework(SpriteKit
    IOSSUPPORT
    CURRENT_VERSION
    TARGET_NAME SpriteKit_iOS
    VERSION A
    SOURCES
        src/SKNode.m
        src/SKScene.m
        src/SKSpriteNode.m
        src/SKTexture.m
        src/SKAction.m
        src/SKPhysics.m
        src/SKView.m
        src/SKSound.m
    DEPENDENCIES
        Foundation
        CoreFoundation
        UIKit
        AppKit # UIKit re-exports it
        CoreGraphics
        QuartzCore
        OpenGLES
        AudioToolbox
        objc
        system
)
target_include_directories(SpriteKit_iOS BEFORE PRIVATE include src
    ${CMAKE_SOURCE_DIR}/src/frameworks/UIKit/include
    ${CMAKE_SOURCE_DIR}/src/frameworks/OpenGLES/include)
target_compile_options(SpriteKit_iOS PRIVATE -fobjc-arc)
if(NOT CMAKE_BUILD_TYPE)
	target_compile_options(SpriteKit_iOS PRIVATE -O2)
endif()
