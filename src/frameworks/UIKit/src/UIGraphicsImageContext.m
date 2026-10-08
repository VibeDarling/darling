/*
 * Copyright (c) 2011, The Iconfactory. All rights reserved.
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

#import <UIKit/UIGraphicsImageContext.h>
#import <UIKit/UIGraphicsContext.h>
#import <CoreGraphics/CGBitmapContext.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSThread.h>
#include <math.h>
#include <stdint.h>

@interface UIBitmapImageContextFrame : NSObject
@property(nonatomic, readonly) CGContextRef context;
@property(nonatomic, readonly) CGFloat scale;
- (instancetype)initWithContext:(CGContextRef)context scale:(CGFloat)scale;
@end
@implementation UIBitmapImageContextFrame {
    CGContextRef _context;
    CGFloat _scale;
}
- (instancetype)initWithContext:(CGContextRef)context scale:(CGFloat)scale
{
    if ((self = [super init])) {
        _context = CGContextRetain(context);
        _scale = scale;
    }
    return self;
}
- (void)dealloc { CGContextRelease(_context); }
- (CGContextRef)context { return _context; }
- (CGFloat)scale { return _scale; }
@end

static NSString *const imageStackKey = @"org.darling.UIKit.imageContextStack";

static NSMutableArray *UIBitmapImageStack(void)
{
    return [[[NSThread currentThread] threadDictionary] objectForKey:imageStackKey];
}

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
    if (scale == 0)
        [NSException raise:NSInternalInconsistencyException format:@"Main-screen scale is unavailable"];
    if (!isfinite(scale) || scale < 0 || !isfinite(size.width) || !isfinite(size.height) ||
        size.width <= 0 || size.height <= 0)
        [NSException raise:NSInvalidArgumentException format:@"Bitmap size and scale must be finite and positive"];
    CGFloat pixelWidth = size.width * scale;
    CGFloat pixelHeight = size.height * scale;
    if (!isfinite(pixelWidth) || !isfinite(pixelHeight) || pixelWidth >= (CGFloat)SIZE_MAX ||
        pixelHeight >= (CGFloat)SIZE_MAX || pixelWidth < 1 || pixelHeight < 1 ||
        floor(pixelWidth) != pixelWidth || floor(pixelHeight) != pixelHeight)
        [NSException raise:NSInvalidArgumentException format:@"Bitmap pixel dimensions must be representable integers"];
    size_t width = (size_t)pixelWidth;
    size_t height = (size_t)pixelHeight;
    if (width > SIZE_MAX / 4 || height > SIZE_MAX / (width * 4))
        [NSException raise:NSInvalidArgumentException format:@"Bitmap allocation size overflows"];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    if (space == NULL)
        [NSException raise:NSInternalInconsistencyException format:@"CoreGraphics RGB space is unavailable"];
    CGBitmapInfo format = kCGBitmapByteOrder32Host |
        (opaque ? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, format);
    CGColorSpaceRelease(space);
    if (context == NULL)
        [NSException raise:NSInternalInconsistencyException format:@"CoreGraphics bitmap allocation failed"];
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -scale);
    UIBitmapImageContextFrame *frame = [[UIBitmapImageContextFrame alloc] initWithContext:context scale:scale];
    @try {
        UIGraphicsPushContext(context);
    } @finally {
        CGContextRelease(context);
    }
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    NSMutableArray *stack = UIBitmapImageStack();
    if (stack == nil) {
        stack = [NSMutableArray array];
        [dictionary setObject:stack forKey:imageStackKey];
    }
    [stack addObject:frame];
}

UIImage *UIGraphicsGetImageFromCurrentImageContext(void)
{
    UIBitmapImageContextFrame *frame = [UIBitmapImageStack() lastObject];
    if (frame == nil || frame.context != UIGraphicsGetCurrentContext())
        return nil;
    CGImageRef bitmap = CGBitmapContextCreateImage(frame.context);
    if (bitmap == NULL)
        return nil;
    UIImage *image = [UIImage imageWithCGImage:bitmap scale:frame.scale orientation:UIImageOrientationUp];
    CGImageRelease(bitmap);
    return image;
}

void UIGraphicsEndImageContext(void)
{
    NSMutableArray *stack = UIBitmapImageStack();
    UIBitmapImageContextFrame *frame = [stack lastObject];
    if (frame == nil || frame.context != UIGraphicsGetCurrentContext())
        return;
    UIGraphicsPopContext();
    [stack removeLastObject];
    if ([stack count] == 0)
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:imageStackKey];
}
