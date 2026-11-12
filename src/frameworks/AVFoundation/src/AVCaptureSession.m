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

#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVCaptureInput.h>
#import <AVFoundation/AVCaptureOutput.h>

// There is no capture hardware: a session keeps its configuration, and running it delivers nothing.
@implementation AVCaptureSession {
    NSMutableArray *_inputs;
    NSMutableArray *_outputs;
}

@synthesize sessionPreset = _sessionPreset;

- (instancetype)init {
    if ((self = [super init])) {
        _inputs = [[NSMutableArray alloc] init];
        _outputs = [[NSMutableArray alloc] init];
        _sessionPreset = [AVCaptureSessionPresetHigh copy];
    }
    return self;
}

- (void)dealloc {
    [_inputs release];
    [_outputs release];
    [_sessionPreset release];
    [super dealloc];
}

- (BOOL)canSetSessionPreset:(AVCaptureSessionPreset)preset {
    return preset != nil;
}

- (NSArray *)inputs {
    return [[_inputs copy] autorelease];
}

- (BOOL)canAddInput:(AVCaptureInput *)input {
    return input != nil && ![_inputs containsObject:input];
}

- (void)addInput:(AVCaptureInput *)input {
    if ([self canAddInput:input])
        [_inputs addObject:input];
}

- (void)removeInput:(AVCaptureInput *)input {
    [_inputs removeObject:input];
}

- (NSArray *)outputs {
    return [[_outputs copy] autorelease];
}

- (BOOL)canAddOutput:(AVCaptureOutput *)output {
    return output != nil && ![_outputs containsObject:output];
}

- (void)addOutput:(AVCaptureOutput *)output {
    if ([self canAddOutput:output])
        [_outputs addObject:output];
}

- (void)removeOutput:(AVCaptureOutput *)output {
    [_outputs removeObject:output];
}

- (void)beginConfiguration {
}

- (void)commitConfiguration {
}

- (BOOL)isRunning {
    return NO;
}

- (BOOL)isInterrupted {
    return NO;
}

- (void)startRunning {
}

- (void)stopRunning {
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    return signature ?: [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
