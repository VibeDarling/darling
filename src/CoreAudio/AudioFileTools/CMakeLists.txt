project(AudioFileTools)

include_directories(BEFORE ${CMAKE_CURRENT_BINARY_DIR})

include_directories(
	${CMAKE_CURRENT_SOURCE_DIR}/PublicUtility
	${CMAKE_CURRENT_SOURCE_DIR}/Utility
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility
)

set(sources
	PublicUtility/CAChannelMapper.cpp
	PublicUtility/CAChannelMappingPlayer.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAAudioUnit.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CABufferList.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAComponent.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAComponentDescription.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAAudioChannelLayout.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAAudioChannelLayoutObject.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAStreamBasicDescription.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAMutex.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAHostTimeBase.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAAudioFileFormats.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAXException.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAAUProcessor.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/CAFilePathUtils.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreAudioUtilityClasses/CoreAudio/PublicUtility/AUOutputBL.cpp
	PublicUtility/CAAudioFileStreamer.cpp
	PublicUtility/CAAudioFilePlayer.cpp
	PublicUtility/CAAudioFileRecorder.cpp
	PublicUtility/CABufferQueue.cpp
	PublicUtility/CAGuard.cpp
	PublicUtility/CAPThread.cpp
	Utility/CAAudioFileConverter.cpp
	Utility/CAChannelLayouts.cpp
	Utility/AFToolsCommon.cpp
)

add_library(AudioFileTools_util OBJECT ${sources})

add_darling_executable(afplay afplay.cpp $<TARGET_OBJECTS:AudioFileTools_util>)
target_link_libraries(afplay system AudioToolbox cxx CoreServices CoreAudio)

add_darling_executable(afrecord afrecord.cpp $<TARGET_OBJECTS:AudioFileTools_util>)
target_link_libraries(afrecord system AudioToolbox cxx CoreServices CoreAudio)

add_darling_executable(afinfo afinfo.cpp $<TARGET_OBJECTS:AudioFileTools_util>)
target_link_libraries(afinfo system AudioToolbox cxx CoreServices CoreAudio)

add_darling_executable(afconvert afconvert.cpp afconvert_main.cpp $<TARGET_OBJECTS:AudioFileTools_util>)
target_link_libraries(afconvert system AudioToolbox cxx CoreServices CoreAudio)

option(DARLING_COREAUDIO_TESTS "Build CoreAudio diagnostic tools (play_wav, ca_beep)" OFF)

if (DARLING_COREAUDIO_TESTS)
	add_darling_executable(play_wav play_wav.c)
	target_link_libraries(play_wav system CoreAudio CoreFoundation)

	add_darling_executable(ca_beep ca_beep.c)
	target_link_libraries(ca_beep system CoreAudio CoreFoundation m)
endif()

install(TARGETS afplay afrecord afinfo afconvert DESTINATION libexec/darling/usr/bin)


