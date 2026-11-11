/*
 This file is part of Darling.

 Copyright (C) 2017 Lubos Dolezel

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

#import <AVFoundation/AVCaptureVideoPreviewLayer.h>
#import <AVFoundation/AVCaptureSession.h>

// Draws nothing: there are no frames to show.
@implementation AVCaptureVideoPreviewLayer

@synthesize session = _session;
@synthesize videoGravity = _videoGravity;

+ (instancetype)layerWithSession:(AVCaptureSession *)session {
    return [[[self alloc] initWithSession:session] autorelease];
}

- (instancetype)init {
    if ((self = [super init]))
        _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    return self;
}

- (instancetype)initWithSession:(AVCaptureSession *)session {
    if ((self = [self init]))
        _session = [session retain];
    return self;
}

- (void)dealloc {
    [_session release];
    [_videoGravity release];
    [super dealloc];
}

// A preview connection exists only between a session's video input and the layer, and a
// session here never has one.
- (AVCaptureConnection *)connection {
    return nil;
}

@end
