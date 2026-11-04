project(AVFAudio)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "2.0.0")
set(FRAMEWORK_VERSION "A")

remove_sdk_framework(AVFAudio
)

generate_sdk_framework(AVFAudio
	VERSION ${FRAMEWORK_VERSION}
	HEADER "include/AVFAudio"
)

add_framework(AVFAudio
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/AVFAudio.m
        src/AVAudioIONode.m
        src/AVAudioOutputNode.m
        src/AVAudioInputNode.m
        src/AVAudioEndpointDetector.m
        src/AVVoiceController.m
        src/SpeexEndpointer.m
        src/AVAudioUnitComponentManager.m
        src/AVAudioUnitTimeEffect.m
        src/AVAudioUnitDelay.m
        src/VoiceVerificationEndpointer.m
        src/AVAudioSequencer.m
        src/AVMusicTrack.m
        src/AVAudioUnitVarispeed.m
        src/AVAudioUnitReverb.m
        src/AVAudioUnitTimePitch.m
        src/AVAudioConnectionPoint.m
        src/AVAudioBuffer.m
        src/AVAudioPCMBuffer.m
        src/AVAudioCompressedBuffer.m
        src/AudioPlayerImpl.m
        src/AVAudioPlayer.m
        src/AVAudioUnitGenerator.m
        src/AVAudioRecorder.m
        src/AVAudioUnitComponent.m
        src/AVAudioConverter.m
        src/AVAudioUnitDistortion.m
        src/AVAudioMixerNode.m
        src/AVAudioClock.m
        src/AVAudioUnitSplitter.m
        src/AVMIDIPlayer.m
        src/AVAudioUnitMIDIInstrument.m
        src/AVAudioUnitEQFilterParameters.m
        src/AVAudioUnitEQ.m
        src/AVAudioUnitDSPGraph.m
        src/AVAudioFormat.m
        src/AVAudioSettings.m
        src/AVVCAudioDeviceManager.m
        src/AVAudioSession.m
        src/AVSpeechSynthesis.m
        src/AVVCAudioBuffer.m
        src/AVAudioEnvironmentDistanceAttenuationParameters.m
        src/AVAudioEnvironmentReverbParameters.m
        src/AVAudioEnvironmentNode.m
        src/AVAudioTime.m
        src/AVAudioFile.m
        src/AVVCMetricsManager.m
        src/AVAudioNode.m
        src/AVAudioMixingDestination.m
        src/AVAudioUnitSampler.m
        src/AVAudioUnitEffect.m
        src/AVAudioPlayerNode.m
        src/AVAudioSourceNode.m
        src/AVAudioUnit.m
        src/AVAudioEngine.m
        src/AVAudioChannelLayout.m

	DEPENDENCIES
		system
		objc
		Foundation
)

# AVFAudio is a subframework of AVFoundation on Darwin, so a client that links only
# AVFoundation still resolves the AVAudio classes. Games rely on this: Sky-Checkers
# imports _OBJC_CLASS_$_AVAudioEngine and four siblings, names dyld expects in
# AVFoundation, and aborts on the first one without them. They are all already
# implemented in AVFAudio, so this only has to re-export them.
#
# No cycle: AVFAudio depends on system, objc and Foundation, and imports no
# AVFoundation headers.
#
# Here and not in AVFoundation's directory: AVFAudio's is added after it, so
# there AVFAudio is not a target yet.
if (TARGET AVFoundation)
    reexport(AVFoundation AVFAudio ${CMAKE_CURRENT_BINARY_DIR}/AVFAudio)
endif()
