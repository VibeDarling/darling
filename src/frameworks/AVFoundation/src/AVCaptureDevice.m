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

#import <AVFoundation/AVCaptureDevice.h>

@implementation AVCaptureDevice

+ (NSArray *)devices {
    return [NSArray array];
}

+ (NSArray *)devicesWithMediaType:(AVMediaType)mediaType {
    (void)mediaType;
    return [self devices];
}

+ (AVCaptureDevice *)defaultDeviceWithMediaType:(AVMediaType)mediaType {
    (void)mediaType;
    return nil;
}

+ (AVAuthorizationStatus)authorizationStatusForMediaType:(AVMediaType)mediaType
{
	// There is no capture hardware access and no consent store here; report
	// Denied so callers take their no-access path.
	(void)mediaType;
	return AVAuthorizationStatusDenied;
}

+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL))handler
{
	(void)mediaType;
	// Documented to run on an arbitrary queue and never re-entrantly: a caller
	// that blocks the main queue on the result from inside this call would
	// deadlock if the handler ran inline.
	if (handler)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			handler(NO);
		});
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
