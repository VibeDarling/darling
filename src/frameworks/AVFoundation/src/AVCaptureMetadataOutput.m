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

#import <AVFoundation/AVCaptureMetadataOutput.h>

// Never sees a frame, so it never calls its delegate; it keeps what it is configured with.
@implementation AVCaptureMetadataOutput {
    id<AVCaptureMetadataOutputObjectsDelegate> _delegate;
    dispatch_queue_t _queue;
    NSArray *_types;
}

@synthesize rectOfInterest = _rectOfInterest;

+ (instancetype)new {
    return [[self alloc] init];
}

- (instancetype)init {
    if ((self = [super init])) {
        _types = [[NSArray alloc] init];
        _rectOfInterest = CGRectMake(0, 0, 1, 1);
    }
    return self;
}

- (void)dealloc {
    if (_queue)
        dispatch_release(_queue);
    [_types release];
    [super dealloc];
}

// The delegate is not retained, as in Apple's documentation for this class.
- (void)setMetadataObjectsDelegate:(id<AVCaptureMetadataOutputObjectsDelegate>)objectsDelegate
                             queue:(dispatch_queue_t)objectsCallbackQueue {
    if (objectsDelegate != nil && objectsCallbackQueue == NULL)
        [NSException raise:NSInvalidArgumentException format:@"%@: a delegate needs a callback queue", NSStringFromSelector(_cmd)];
    if (objectsCallbackQueue)
        dispatch_retain(objectsCallbackQueue);
    if (_queue)
        dispatch_release(_queue);
    _queue = objectsCallbackQueue;
    _delegate = objectsDelegate;
}

- (id<AVCaptureMetadataOutputObjectsDelegate>)metadataObjectsDelegate {
    return _delegate;
}

- (dispatch_queue_t)metadataObjectsCallbackQueue {
    return _queue;
}

- (NSArray *)availableMetadataObjectTypes {
    return [NSArray array];
}

- (NSArray *)metadataObjectTypes {
    return [[_types retain] autorelease];
}

- (void)setMetadataObjectTypes:(NSArray *)types {
    NSArray *copy = [types copy] ?: [[NSArray alloc] init];
    [_types release];
    _types = copy;
}

@end
