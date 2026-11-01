/*
 This file is part of Darling.

 Copyright (C) 2025-2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>

#ifndef NS_TYPED_ENUM
#define NS_TYPED_ENUM
#endif

typedef NSString * AVAudioSessionCategory NS_TYPED_ENUM;
typedef NSString * AVAudioSessionMode NS_TYPED_ENUM;
typedef NSString * AVAudioSessionPort NS_TYPED_ENUM;

/* Categories */
extern NSString *const AVAudioSessionCategoryAmbient;
extern NSString *const AVAudioSessionCategorySoloAmbient;
extern NSString *const AVAudioSessionCategoryPlayback;
extern NSString *const AVAudioSessionCategoryRecord;
extern NSString *const AVAudioSessionCategoryPlayAndRecord;
extern NSString *const AVAudioSessionCategoryMultiRoute;

/* Modes */
extern NSString *const AVAudioSessionModeDefault;
extern NSString *const AVAudioSessionModeVoiceChat;
extern NSString *const AVAudioSessionModeGameChat;
extern NSString *const AVAudioSessionModeVideoRecording;
extern NSString *const AVAudioSessionModeMeasurement;
extern NSString *const AVAudioSessionModeMoviePlayback;
extern NSString *const AVAudioSessionModeVideoChat;
extern NSString *const AVAudioSessionModeSpokenAudio;
extern NSString *const AVAudioSessionModeSpatialCapture;
extern NSString *const AVAudioSessionModeVoicePrompt;

/* Notifications */
extern NSString *const AVAudioSessionInterruptionNotification;
extern NSString *const AVAudioSessionRouteChangeNotification;
extern NSString *const AVAudioSessionMediaServicesWereLostNotification;
extern NSString *const AVAudioSessionMediaServicesWereResetNotification;
extern NSString *const AVAudioSessionSilenceSecondaryAudioHintNotification;

/* Notification userInfo Keys */
extern NSString *const AVAudioSessionInterruptionTypeKey;
extern NSString *const AVAudioSessionInterruptionOptionKey;
extern NSString *const AVAudioSessionInterruptionReasonKey;
extern NSString *const AVAudioSessionRouteChangeReasonKey;
extern NSString *const AVAudioSessionRouteChangePreviousRouteKey;
extern NSString *const AVAudioSessionSilenceSecondaryAudioHintTypeKey;

/* Port types */
extern NSString *const AVAudioSessionPortBuiltInMic;
extern NSString *const AVAudioSessionPortBuiltInSpeaker;
extern NSString *const AVAudioSessionPortBuiltInReceiver;
extern NSString *const AVAudioSessionPortHeadphones;
extern NSString *const AVAudioSessionPortBluetoothHFP;
extern NSString *const AVAudioSessionPortBluetoothA2DP;
extern NSString *const AVAudioSessionPortBluetoothLE;
extern NSString *const AVAudioSessionPortCarAudio;
extern NSString *const AVAudioSessionPortAirPlay;
extern NSString *const AVAudioSessionPortLineIn;
extern NSString *const AVAudioSessionPortLineOut;
extern NSString *const AVAudioSessionPortHDMI;
extern NSString *const AVAudioSessionPortDisplayPort;
extern NSString *const AVAudioSessionPortUSBAudio;

/* Orientations */
extern NSString *const AVAudioSessionOrientationBack;
extern NSString *const AVAudioSessionOrientationFront;
extern NSString *const AVAudioSessionOrientationTop;
extern NSString *const AVAudioSessionOrientationBottom;

/* Polar patterns */
extern NSString *const AVAudioSessionPolarPatternStereo;
extern NSString *const AVAudioSessionPolarPatternCardioid;
extern NSString *const AVAudioSessionPolarPatternOmnidirectional;
extern NSString *const AVAudioSessionPolarPatternSubcardioid;

// A port of the audio route. Darling reports the route of an iPhone without accessories: the
// built-in microphone in, the built-in speaker out.
@interface AVAudioSessionPortDescription : NSObject
@property (readonly) NSString *portType;
@property (readonly) NSString *portName;
@property (readonly) NSString *UID;
@property (readonly) BOOL hasHardwareVoiceCallProcessing;
@property (readonly, getter=isSpatialAudioEnabled) BOOL spatialAudioEnabled;
@property (readonly) NSArray *channels;
@property (readonly) NSArray *dataSources;
@property (readonly) id selectedDataSource;
@property (readonly) id preferredDataSource;
- (BOOL)setPreferredDataSource:(id)dataSource error:(NSError **)outError;
@end

@interface AVAudioSessionRouteDescription : NSObject
@property (readonly) NSArray<AVAudioSessionPortDescription *> *inputs;
@property (readonly) NSArray<AVAudioSessionPortDescription *> *outputs;
@end

typedef NS_ENUM(NSUInteger, AVAudioSessionRecordPermission) {
    AVAudioSessionRecordPermissionUndetermined = 'undt',
    AVAudioSessionRecordPermissionDenied = 'deny',
    AVAudioSessionRecordPermissionGranted = 'grnt',
};

@interface AVAudioSession : NSObject

+ (AVAudioSession *)sharedInstance;

- (BOOL)setActive:(BOOL)active error:(NSError **)outError;
- (BOOL)setActive:(BOOL)active withOptions:(NSUInteger)options error:(NSError **)outError;

- (BOOL)setCategory:(NSString *)category error:(NSError **)outError;
- (BOOL)setCategory:(NSString *)category withOptions:(NSUInteger)options error:(NSError **)outError;
- (BOOL)setCategory:(NSString *)category mode:(NSString *)mode options:(NSUInteger)options error:(NSError **)outError;
- (NSString *)category;

- (BOOL)setMode:(NSString *)mode error:(NSError **)outError;
- (NSString *)mode;

- (double)sampleRate;
- (NSInteger)inputNumberOfChannels;
- (NSInteger)outputNumberOfChannels;

@property (readonly) AVAudioSessionRouteDescription *currentRoute;
@property (readonly) NSArray<AVAudioSessionPortDescription *> *availableInputs;
@property (readonly) float outputVolume;
@property (readonly) NSTimeInterval IOBufferDuration;
@property (readonly) NSTimeInterval outputLatency;
@property (readonly) NSTimeInterval inputLatency;
@property (readonly) double preferredSampleRate;
@property (readonly) NSTimeInterval preferredIOBufferDuration;
@property (readonly, getter=isOtherAudioPlaying) BOOL otherAudioPlaying;
@property (readonly) BOOL secondaryAudioShouldBeSilencedHint;
@property (readonly, getter=isInputAvailable) BOOL inputAvailable;
@property (readonly) AVAudioSessionRecordPermission recordPermission;
- (void)requestRecordPermission:(void (^)(BOOL granted))response;
- (BOOL)setPreferredSampleRate:(double)sampleRate error:(NSError **)outError;
- (BOOL)setPreferredIOBufferDuration:(NSTimeInterval)duration error:(NSError **)outError;
- (BOOL)setPreferredInput:(AVAudioSessionPortDescription *)inPort error:(NSError **)outError;
- (BOOL)overrideOutputAudioPort:(NSUInteger)portOverride error:(NSError **)outError;

@end
