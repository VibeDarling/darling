project(load_only_frameworks)

# Roon 2.74 ARM64 links these images without binding symbols from them.
# Keep load-only targets separate from API implementations.
set(load_only_frameworks
    AVRouting
    Accessibility
    AdServices
    AdSupport
    AppTrackingTransparency
    AutomaticAssessmentConfiguration
    BackgroundAssets
    BusinessChat
    CallKit
    Cinematic
    ClassKit
    CoreHaptics
    CoreML
    CoreMotion
    CoreSpotlight
    DataDetection
    DeviceDiscoveryExtension
    ExecutionPolicy
    ExtensionKit
    ExternalAccessory
    FSKit
    FileProvider
    FileProviderUI
    GameSave
    GameplayKit
    HealthKit
    Intents
    IntentsUI
    JavaScriptCore
    LinkPresentation
    LocalAuthenticationEmbeddedUI
    MLCompute
    MailKit
    MediaExtension
    MetalFX
    MetalPerformanceShadersGraph
    MetricKit
    NaturalLanguage
    NearbyInteraction
    NetworkExtension
    OSLog
    PHASE
    PassKit
    PencilKit
    PhotosUI
    PushKit
    QuickLookThumbnailing
    ReplayKit
    SafariServices
    SafetyKit
    ScreenTime
    SecurityUI
    SensitiveContentAnalysis
    SharedWithYou
    SharedWithYouCore
    Social
    SoundAnalysis
    ThreadNetwork
    VideoSubscriberAccount
    iTunesLibrary
)

# Register after all normal targets, including optional JavaScriptCore. Match
# framework install paths rather than target names (Accessibility is also a dylib).
function(load_only_existing_frameworks directory result)
    get_property(targets DIRECTORY "${directory}" PROPERTY BUILDSYSTEM_TARGETS)
    set(paths)
    foreach(target IN LISTS targets)
        get_target_property(path "${target}" DYLIB_INSTALL_NAME)
        if(path)
            list(APPEND paths "${path}")
        endif()
    endforeach()
    get_property(children DIRECTORY "${directory}" PROPERTY SUBDIRECTORIES)
    foreach(child IN LISTS children)
        load_only_existing_frameworks("${child}" child_paths)
        list(APPEND paths ${child_paths})
    endforeach()
    set(${result} "${paths}" PARENT_SCOPE)
endfunction()

load_only_existing_frameworks("${CMAKE_SOURCE_DIR}" implemented_frameworks)
foreach(name IN LISTS load_only_frameworks)
    set(framework_root "/System/Library/Frameworks/${name}.framework/")
    set(implemented FALSE)
    foreach(path IN LISTS implemented_frameworks)
        string(FIND "${path}" "${framework_root}" prefix)
        if(prefix EQUAL 0)
            set(implemented TRUE)
            break()
        endif()
    endforeach()
    if(NOT implemented)
        add_framework(${name}
            FAT
            CURRENT_VERSION
            TARGET_NAME load_only_${name}
            VERSION A
            SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/empty.c
            DEPENDENCIES system
        )
    endif()
endforeach()

# Apple's PhotosUI carries its Swift API in the same image, and apps bind it there.
if(DARLING_IOS_SWIFT_MODULES)
    reexport(load_only_PhotosUI SwiftIOSModules ${CMAKE_BINARY_DIR}/src/frameworks/SwiftIOSModules/libswiftPhotosUI.dylib)
endif()
