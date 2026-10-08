/*
 * Copyright (c) 2011, 2012, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIImage.h>
#import <Foundation/NSException.h>
#import <ImageIO/CGImageDestination.h>
#include <math.h>

@implementation UIImage {
    CGImageRef _CGImage;
    CGFloat _scale;
    UIImageOrientation _orientation;
}
- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a CGImage initializer"];
    return nil;
}
- (instancetype)initWithCGImage:(CGImageRef)image
{
    return [self initWithCGImage:image scale:1 orientation:UIImageOrientationUp];
}
- (instancetype)initWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    if (image == NULL)
        return nil;
    if (!isfinite(scale) || scale <= 0)
        [NSException raise:NSInvalidArgumentException format:@"Image scale must be finite and positive"];
    switch (orientation) {
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"Unknown image orientation"];
    }
    if ((self = [super init])) {
        _CGImage = CGImageRetain(image);
        _scale = scale;
        _orientation = orientation;
    }
    return self;
}
+ (UIImage *)imageWithCGImage:(CGImageRef)image
{
    return [[self alloc] initWithCGImage:image];
}
+ (UIImage *)imageWithCGImage:(CGImageRef)image scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    return [[self alloc] initWithCGImage:image scale:scale orientation:orientation];
}
- (void)dealloc { CGImageRelease(_CGImage); }
- (CGImageRef)CGImage { return _CGImage; }
- (CGFloat)scale { return _scale; }
- (UIImageOrientation)imageOrientation { return _orientation; }
- (CGSize)size
{
    CGFloat width = CGImageGetWidth(_CGImage) / _scale;
    CGFloat height = CGImageGetHeight(_CGImage) / _scale;
    switch (_orientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            return CGSizeMake(height, width);
        default:
            return CGSizeMake(width, height);
    }
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

NSData *UIImagePNGRepresentation(UIImage *image)
{
    CGImageRef bitmap = image.CGImage;
    if (bitmap == NULL || image.imageOrientation != UIImageOrientationUp ||
        CGImageGetBitsPerComponent(bitmap) != 8 || CGImageGetBitsPerPixel(bitmap) != 32 ||
        CGImageGetAlphaInfo(bitmap) != kCGImageAlphaLast ||
        (CGImageGetBitmapInfo(bitmap) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big ||
        CGColorSpaceGetModel(CGImageGetColorSpace(bitmap)) != kCGColorSpaceModelRGB)
        return nil;
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    if (data == NULL)
        return nil;
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, CFSTR("public.png"), 1, NULL);
    if (destination == NULL) {
        CFRelease(data);
        return nil;
    }
    BOOL success;
    @try {
        CGImageDestinationAddImage(destination, bitmap, NULL);
        success = CGImageDestinationFinalize(destination);
    } @catch (NSException *exception) {
        CFRelease(destination);
        CFRelease(data);
        return nil;
    }
    CFRelease(destination);
    if (!success || CFDataGetLength(data) == 0) {
        CFRelease(data);
        return nil;
    }
    return CFBridgingRelease(data);
}
