/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

#import <AVFAudio/AVSpeechSynthesis.h>

@implementation AVSpeechSynthesizer

@synthesize delegate = _delegate;
@synthesize usesApplicationAudioSession = _usesApplicationAudioSession;
@synthesize mixToTelephonyUplink = _mixToTelephonyUplink;

- (instancetype)init
{
    if ((self = [super init]) != nil)
        _usesApplicationAudioSession = YES;
    return self;
}

- (BOOL)isSpeaking { return NO; }
- (BOOL)isPaused { return NO; }

- (void)speakUtterance:(AVSpeechUtterance *)utterance
{
    [self retain];
    [utterance retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        id <AVSpeechSynthesizerDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(speechSynthesizer:didStartSpeechUtterance:)])
            [delegate speechSynthesizer:self didStartSpeechUtterance:utterance];
        if ([delegate respondsToSelector:@selector(speechSynthesizer:didFinishSpeechUtterance:)])
            [delegate speechSynthesizer:self didFinishSpeechUtterance:utterance];
        [utterance release];
        [self release];
    });
}

- (BOOL)stopSpeakingAtBoundary:(AVSpeechBoundary)boundary { return NO; }
- (BOOL)pauseSpeakingAtBoundary:(AVSpeechBoundary)boundary { return NO; }
- (BOOL)continueSpeaking { return NO; }

@end
