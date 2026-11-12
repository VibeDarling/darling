/*
 This file is part of Darling.

 Copyright (C) 2017-2026 Darling Developers

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

#import <AVKit/AVPictureInPictureController.h>

/*
 * Darling shows no picture in picture: isPictureInPictureSupported is NO, a controller is never
 * possible, and starting one fails with the reason, as on a device without it.
 */
@implementation AVPictureInPictureController {
    AVPictureInPictureControllerContentSource *_contentSource;
    id<AVPictureInPictureControllerDelegate> _delegate; /* not retained */
    BOOL _requiresLinearPlayback;
    BOOL _canStartPictureInPictureAutomaticallyFromInline;
}

+ (BOOL)isPictureInPictureSupported
{
    return NO;
}

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    if ((self = [super init]) != nil)
        _contentSource = [contentSource retain];
    return self;
}

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    AVPictureInPictureControllerContentSource *source =
        [[[AVPictureInPictureControllerContentSource alloc] initWithPlayerLayer:playerLayer] autorelease];
    return [self initWithContentSource:source];
}

- (void)dealloc
{
    [_contentSource release];
    [super dealloc];
}

- (AVPictureInPictureControllerContentSource *)contentSource { return _contentSource; }

- (void)setContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    [contentSource retain];
    [_contentSource release];
    _contentSource = contentSource;
}

- (AVPlayerLayer *)playerLayer { return _contentSource.playerLayer; }
- (id<AVPictureInPictureControllerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate { _delegate = delegate; }

- (void)startPictureInPicture
{
    id<AVPictureInPictureControllerDelegate> delegate = _delegate;
    if (![delegate respondsToSelector:@selector(pictureInPictureController:failedToStartPictureInPictureWithError:)])
        return;
    NSError *error = [NSError errorWithDomain:@"AVKitErrorDomain" code:-1000 /* AVKitErrorUnknown */
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Picture in Picture is not supported" }];
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate pictureInPictureController:self failedToStartPictureInPictureWithError:error];
    });
}

- (void)stopPictureInPicture { }
- (void)invalidatePlaybackState { }
- (BOOL)isPictureInPicturePossible { return NO; }
- (BOOL)isPictureInPictureActive { return NO; }
- (BOOL)isPictureInPictureSuspended { return NO; }

@synthesize requiresLinearPlayback = _requiresLinearPlayback,
    canStartPictureInPictureAutomaticallyFromInline = _canStartPictureInPictureAutomaticallyFromInline;

@end

@implementation AVPictureInPictureControllerContentSource {
    AVPlayerLayer *_playerLayer;
    AVSampleBufferDisplayLayer *_sampleBufferDisplayLayer;
    id<AVPictureInPictureSampleBufferPlaybackDelegate> _sampleBufferPlaybackDelegate; /* not retained */
}

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    if ((self = [super init]) != nil)
        _playerLayer = [(id)playerLayer retain];
    return self;
}

- (instancetype)initWithSampleBufferDisplayLayer:(AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer
                                playbackDelegate:(id<AVPictureInPictureSampleBufferPlaybackDelegate>)playbackDelegate
{
    if ((self = [super init]) != nil) {
        _sampleBufferDisplayLayer = [(id)sampleBufferDisplayLayer retain];
        _sampleBufferPlaybackDelegate = playbackDelegate;
    }
    return self;
}

- (void)dealloc
{
    [(id)_playerLayer release];
    [(id)_sampleBufferDisplayLayer release];
    [super dealloc];
}

- (AVPlayerLayer *)playerLayer { return _playerLayer; }
- (AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer { return _sampleBufferDisplayLayer; }
- (id<AVPictureInPictureSampleBufferPlaybackDelegate>)sampleBufferPlaybackDelegate { return _sampleBufferPlaybackDelegate; }

@end
