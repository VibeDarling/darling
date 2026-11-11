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

#import <AVFoundation/AVCaptureDeviceInput.h>
#import <AVFoundation/AVCaptureDevice.h>

@implementation AVCaptureDeviceInput

@synthesize device = _device;

+ (instancetype)deviceInputWithDevice:(AVCaptureDevice *)device error:(NSError **)outError {
    return [[[self alloc] initWithDevice:device error:outError] autorelease];
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device error:(NSError **)outError {
    if (device == nil) {
        if (outError)
            *outError = [NSError errorWithDomain:@"AVFoundationErrorDomain" code:-11814 userInfo:nil];
        [self release];
        return nil;
    }
    if ((self = [super init]))
        _device = [device retain];
    return self;
}

- (void)dealloc {
    [_device release];
    [super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    return signature ?: [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
