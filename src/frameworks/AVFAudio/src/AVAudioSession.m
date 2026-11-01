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

#import <AVFAudio/AVAudioSession.h>
#import <objc/runtime.h>
#import "AVFAudioStub.h"
#include <stdio.h>

/* Categories */
NSString *const AVAudioSessionCategoryAmbient = @"AVAudioSessionCategoryAmbient";
NSString *const AVAudioSessionCategorySoloAmbient = @"AVAudioSessionCategorySoloAmbient";
NSString *const AVAudioSessionCategoryPlayback = @"AVAudioSessionCategoryPlayback";
NSString *const AVAudioSessionCategoryRecord = @"AVAudioSessionCategoryRecord";
NSString *const AVAudioSessionCategoryPlayAndRecord = @"AVAudioSessionCategoryPlayAndRecord";
NSString *const AVAudioSessionCategoryMultiRoute = @"AVAudioSessionCategoryMultiRoute";

/* Modes */
NSString *const AVAudioSessionModeDefault = @"AVAudioSessionModeDefault";
NSString *const AVAudioSessionModeVoiceChat = @"AVAudioSessionModeVoiceChat";
NSString *const AVAudioSessionModeGameChat = @"AVAudioSessionModeGameChat";
NSString *const AVAudioSessionModeVideoRecording = @"AVAudioSessionModeVideoRecording";
NSString *const AVAudioSessionModeMeasurement = @"AVAudioSessionModeMeasurement";
NSString *const AVAudioSessionModeMoviePlayback = @"AVAudioSessionModeMoviePlayback";
NSString *const AVAudioSessionModeVideoChat = @"AVAudioSessionModeVideoChat";
NSString *const AVAudioSessionModeSpokenAudio = @"AVAudioSessionModeSpokenAudio";
NSString *const AVAudioSessionModeSpatialCapture = @"AVAudioSessionModeSpatialCapture";
NSString *const AVAudioSessionModeVoicePrompt = @"AVAudioSessionModeVoicePrompt";

/* Notifications */
NSString *const AVAudioSessionInterruptionNotification = @"AVAudioSessionInterruptionNotification";
NSString *const AVAudioSessionRouteChangeNotification = @"AVAudioSessionRouteChangeNotification";
NSString *const AVAudioSessionMediaServicesWereLostNotification = @"AVAudioSessionMediaServicesWereLostNotification";
NSString *const AVAudioSessionMediaServicesWereResetNotification = @"AVAudioSessionMediaServicesWereResetNotification";
NSString *const AVAudioSessionSilenceSecondaryAudioHintNotification = @"AVAudioSessionSilenceSecondaryAudioHintNotification";

/* Notification userInfo Keys */
NSString *const AVAudioSessionInterruptionTypeKey = @"AVAudioSessionInterruptionTypeKey";
NSString *const AVAudioSessionInterruptionOptionKey = @"AVAudioSessionInterruptionOptionKey";
NSString *const AVAudioSessionInterruptionReasonKey = @"AVAudioSessionInterruptionReasonKey";
NSString *const AVAudioSessionRouteChangeReasonKey = @"AVAudioSessionRouteChangeReasonKey";
NSString *const AVAudioSessionRouteChangePreviousRouteKey = @"AVAudioSessionRouteChangePreviousRouteKey";
NSString *const AVAudioSessionSilenceSecondaryAudioHintTypeKey = @"AVAudioSessionSilenceSecondaryAudioHintTypeKey";

/* Port types */
NSString *const AVAudioSessionPortBuiltInMic = @"AVAudioSessionPortBuiltInMic";
NSString *const AVAudioSessionPortBuiltInSpeaker = @"AVAudioSessionPortBuiltInSpeaker";
NSString *const AVAudioSessionPortBuiltInReceiver = @"AVAudioSessionPortBuiltInReceiver";
NSString *const AVAudioSessionPortHeadphones = @"AVAudioSessionPortHeadphones";
NSString *const AVAudioSessionPortBluetoothHFP = @"AVAudioSessionPortBluetoothHFP";
NSString *const AVAudioSessionPortBluetoothA2DP = @"AVAudioSessionPortBluetoothA2DP";
NSString *const AVAudioSessionPortBluetoothLE = @"AVAudioSessionPortBluetoothLE";
NSString *const AVAudioSessionPortCarAudio = @"AVAudioSessionPortCarAudio";
NSString *const AVAudioSessionPortAirPlay = @"AVAudioSessionPortAirPlay";
NSString *const AVAudioSessionPortLineIn = @"AVAudioSessionPortLineIn";
NSString *const AVAudioSessionPortLineOut = @"AVAudioSessionPortLineOut";
NSString *const AVAudioSessionPortHDMI = @"AVAudioSessionPortHDMI";
NSString *const AVAudioSessionPortDisplayPort = @"AVAudioSessionPortDisplayPort";
NSString *const AVAudioSessionPortUSBAudio = @"AVAudioSessionPortUSBAudio";

/* Orientations */
NSString *const AVAudioSessionOrientationBack = @"AVAudioSessionOrientationBack";
NSString *const AVAudioSessionOrientationFront = @"AVAudioSessionOrientationFront";
NSString *const AVAudioSessionOrientationTop = @"AVAudioSessionOrientationTop";
NSString *const AVAudioSessionOrientationBottom = @"AVAudioSessionOrientationBottom";

/* Polar patterns */
NSString *const AVAudioSessionPolarPatternStereo = @"AVAudioSessionPolarPatternStereo";
NSString *const AVAudioSessionPolarPatternCardioid = @"AVAudioSessionPolarPatternCardioid";
NSString *const AVAudioSessionPolarPatternOmnidirectional = @"AVAudioSessionPolarPatternOmnidirectional";
NSString *const AVAudioSessionPolarPatternSubcardioid = @"AVAudioSessionPolarPatternSubcardioid";

/*
 * Singleton session state.
 * Note: Access is kept simple and static here; on modern macOS AVAudioSession
 * is thread-safe. Audio playback is single-threaded in Darling's current stubs.
 */
static NSString *g_category = nil;
static NSString *g_mode = nil;
static BOOL g_active = NO;

@implementation AVAudioSessionPortDescription {
    NSString *_portType;
    NSString *_portName;
    NSString *_UID;
}

- (instancetype)_initWithType:(NSString *)type name:(NSString *)name UID:(NSString *)uid
{
    if ((self = [super init]) != nil) {
        _portType = [type copy];
        _portName = [name copy];
        _UID = [uid copy];
    }
    return self;
}

- (void)dealloc
{
    [_portType release];
    [_portName release];
    [_UID release];
    [super dealloc];
}

- (NSString *)portType { return _portType; }
- (NSString *)portName { return _portName; }
- (NSString *)UID { return _UID; }
- (BOOL)hasHardwareVoiceCallProcessing { return NO; }
- (BOOL)isSpatialAudioEnabled { return NO; }
- (NSArray *)channels { return nil; }
- (NSArray *)dataSources { return nil; }
- (id)selectedDataSource { return nil; }
- (id)preferredDataSource { return nil; }

- (BOOL)setPreferredDataSource:(id)dataSource error:(NSError **)outError
{
    if (outError) *outError = nil;
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, type = %@; name = %@; UID = %@; selectedDataSource = (null)>",
            [self class], self, _portType, _portName, _UID];
}

@end

static AVAudioSessionPortDescription *builtInMicrophone(void)
{
    static AVAudioSessionPortDescription *port;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        port = [[AVAudioSessionPortDescription alloc] _initWithType:AVAudioSessionPortBuiltInMic name:@"iPhone Microphone" UID:@"Built-In Microphone"];
    });
    return port;
}

static AVAudioSessionPortDescription *builtInSpeaker(void)
{
    static AVAudioSessionPortDescription *port;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        port = [[AVAudioSessionPortDescription alloc] _initWithType:AVAudioSessionPortBuiltInSpeaker name:@"Speaker" UID:@"Speaker"];
    });
    return port;
}

@implementation AVAudioSessionRouteDescription

- (NSArray *)inputs { return @[ builtInMicrophone() ]; }
- (NSArray *)outputs { return @[ builtInSpeaker() ]; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, \ninputs = %@; \noutputs = %@>", [self class], self, [self inputs], [self outputs]];
}

@end

@implementation AVAudioSession

+ (AVAudioSession *)sharedInstance
{
    static AVAudioSession *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        g_category = [AVAudioSessionCategoryPlayback copy];
        g_mode = [AVAudioSessionModeDefault copy];
        g_active = NO;
    });
    return instance;
}

- (BOOL)setActive:(BOOL)active error:(NSError **)outError
{
    g_active = active;
    if (outError) *outError = nil;
    return YES;
}

- (BOOL)setActive:(BOOL)active withOptions:(NSUInteger)options error:(NSError **)outError
{
    (void)options;
    return [self setActive:active error:outError];
}

- (BOOL)setCategory:(NSString *)category error:(NSError **)outError
{
    if (g_category != category) {
        [g_category release];
        g_category = [category copy];
    }
    if (outError) *outError = nil;
    return YES;
}

/* iOS's: the options (mixing with others, ducking, the speaker) change nothing here. */
- (BOOL)setCategory:(NSString *)category withOptions:(NSUInteger)options error:(NSError **)outError
{
    (void)options;
    return [self setCategory:category error:outError];
}

- (BOOL)setCategory:(NSString *)category mode:(NSString *)mode options:(NSUInteger)options error:(NSError **)outError
{
    (void)options;
    return [self setCategory:category error:outError] && [self setMode:mode error:outError];
}

- (NSString *)category
{
    return g_category ?: AVAudioSessionCategoryPlayback;
}

- (BOOL)setMode:(NSString *)mode error:(NSError **)outError
{
    if (g_mode != mode) {
        [g_mode release];
        g_mode = [mode copy];
    }
    if (outError) *outError = nil;
    return YES;
}

- (NSString *)mode
{
    return g_mode ?: AVAudioSessionModeDefault;
}

- (double)sampleRate
{
    return 44100.0;
}

- (NSInteger)inputNumberOfChannels
{
    return 1;
}

- (NSInteger)outputNumberOfChannels
{
    return 2;
}

- (AVAudioSessionRouteDescription *)currentRoute
{
    return [[[AVAudioSessionRouteDescription alloc] init] autorelease];
}

- (NSArray *)availableInputs
{
    return @[ builtInMicrophone() ];
}

- (float)outputVolume { return 0.5f; }
- (NSTimeInterval)IOBufferDuration { return 1024 / 44100.0; }
- (NSTimeInterval)outputLatency { return 0.01; }
- (NSTimeInterval)inputLatency { return 0.01; }
- (double)preferredSampleRate { return 0; }
- (NSTimeInterval)preferredIOBufferDuration { return 0; }
- (BOOL)isOtherAudioPlaying { return NO; }
- (BOOL)secondaryAudioShouldBeSilencedHint { return NO; }
- (BOOL)isInputAvailable { return YES; }

/* Recording is not wired to a microphone: permission is never granted. */
- (AVAudioSessionRecordPermission)recordPermission
{
    return AVAudioSessionRecordPermissionDenied;
}

- (void)requestRecordPermission:(void (^)(BOOL granted))response
{
    if (response == nil)
        return;
    void (^copy)(BOOL) = [response copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        copy(NO);
        [copy release];
    });
}

- (BOOL)setPreferredSampleRate:(double)sampleRate error:(NSError **)outError
{
    if (outError) *outError = nil;
    return YES;
}

- (BOOL)setPreferredIOBufferDuration:(NSTimeInterval)duration error:(NSError **)outError
{
    if (outError) *outError = nil;
    return YES;
}

- (BOOL)setPreferredInput:(AVAudioSessionPortDescription *)inPort error:(NSError **)outError
{
    if (outError) *outError = nil;
    return YES;
}

- (BOOL)overrideOutputAudioPort:(NSUInteger)portOverride error:(NSError **)outError
{
    if (outError) *outError = nil;
    return YES;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return AVAudioStubSignature(aSelector);
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    static bool should_log = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        should_log = (getenv("DARLING_LOG_STUBS") != NULL);
    });

    if (should_log) {
        fprintf(stderr, "[AVFAudio stub] %s called on %s\n",
                sel_getName([anInvocation selector]),
                class_getName([self class]));
    }
}

@end
