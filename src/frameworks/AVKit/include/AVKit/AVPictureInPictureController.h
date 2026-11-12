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
#import <CoreMedia/CMTime.h>
#import <CoreMedia/CMTimeRange.h>
#import <CoreMedia/CMFormatDescription.h>

@class AVPlayerLayer, AVSampleBufferDisplayLayer, AVPictureInPictureControllerContentSource;
@protocol AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate;

@interface AVPictureInPictureController : NSObject

+ (BOOL)isPictureInPictureSupported;

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource;
- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer;

@property (nonatomic, strong) AVPictureInPictureControllerContentSource *contentSource;
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, weak) id<AVPictureInPictureControllerDelegate> delegate;

- (void)startPictureInPicture;
- (void)stopPictureInPicture;
- (void)invalidatePlaybackState;

@property (nonatomic, readonly, getter=isPictureInPicturePossible) BOOL pictureInPicturePossible;
@property (nonatomic, readonly, getter=isPictureInPictureActive) BOOL pictureInPictureActive;
@property (nonatomic, readonly, getter=isPictureInPictureSuspended) BOOL pictureInPictureSuspended;
@property (nonatomic) BOOL requiresLinearPlayback;
@property (nonatomic) BOOL canStartPictureInPictureAutomaticallyFromInline;

@end

@interface AVPictureInPictureControllerContentSource : NSObject

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer;
- (instancetype)initWithSampleBufferDisplayLayer:(AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer
                                playbackDelegate:(id<AVPictureInPictureSampleBufferPlaybackDelegate>)playbackDelegate;

@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, readonly) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property (nonatomic, weak, readonly) id<AVPictureInPictureSampleBufferPlaybackDelegate> sampleBufferPlaybackDelegate;

@end

@protocol AVPictureInPictureControllerDelegate <NSObject>
@optional
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController;
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController;
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
    failedToStartPictureInPictureWithError:(NSError *)error;
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController;
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController;
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler;
@end

@protocol AVPictureInPictureSampleBufferPlaybackDelegate <NSObject>
@required
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController setPlaying:(BOOL)playing;
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)pictureInPictureController;
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)pictureInPictureController;
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
         didTransitionToRenderSize:(CMVideoDimensions)newRenderSize;
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
                    skipByInterval:(CMTime)skipInterval
                 completionHandler:(void (^)(void))completionHandler;
@optional
- (BOOL)pictureInPictureControllerShouldProhibitBackgroundAudioPlayback:(AVPictureInPictureController *)pictureInPictureController;
@end
