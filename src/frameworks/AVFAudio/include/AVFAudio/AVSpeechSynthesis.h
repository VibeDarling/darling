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

#import <Foundation/Foundation.h>

@class AVSpeechSynthesizer, AVSpeechUtterance;

typedef NS_ENUM(NSInteger, AVSpeechBoundary) {
    AVSpeechBoundaryImmediate,
    AVSpeechBoundaryWord,
};

@protocol AVSpeechSynthesizerDelegate <NSObject>
@optional
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance;
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance;
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance;
@end

// Darling has no speech voices: an utterance is reported started and finished without sound.
@interface AVSpeechSynthesizer : NSObject
@property (nonatomic, assign) id <AVSpeechSynthesizerDelegate> delegate;
@property (nonatomic, readonly, getter=isSpeaking) BOOL speaking;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic) BOOL usesApplicationAudioSession;
@property (nonatomic) BOOL mixToTelephonyUplink;
- (void)speakUtterance:(AVSpeechUtterance *)utterance;
- (BOOL)stopSpeakingAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)pauseSpeakingAtBoundary:(AVSpeechBoundary)boundary;
- (BOOL)continueSpeaking;
@end
