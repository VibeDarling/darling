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

#import <CoreImage/CIContext.h>

CIContextOption const kCIContextOutputColorSpace = @"output_color_space";
CIContextOption const kCIContextPriorityRequestLow = @"priority_request_low";
CIContextOption const kCIContextUseSoftwareRenderer = @"software_renderer";
CIContextOption const kCIContextWorkingColorSpace = @"working_color_space";

/*
 * A Core Graphics renderer. Images are CGImage-backed, so drawing one is drawing its CGImage;
 * an EAGL context makes the same CPU renderer, which renders into pixel buffers and bitmaps as
 * Apple's GPU one does.
 */
@implementation CIContext {
    CGContextRef _cgContext;
    NSDictionary *_options;
}

+ (CIContext *) contextWithCGContext: (CGContextRef) cgContext options: (NSDictionary *) options {
    CIContext *context = [[[self alloc] initWithOptions: options] autorelease];
    context->_cgContext = CGContextRetain(cgContext);
    return context;
}

+ (CIContext *) contextWithOptions: (NSDictionary *) options {
    return [[[self alloc] initWithOptions: options] autorelease];
}

+ (CIContext *) context {
    return [[[self alloc] initWithOptions: nil] autorelease];
}

+ (CIContext *) contextWithEAGLContext: (EAGLContext *) eaglContext {
    return [self contextWithEAGLContext: eaglContext options: nil];
}

+ (CIContext *) contextWithEAGLContext: (EAGLContext *) eaglContext options: (NSDictionary *) options {
    if (eaglContext == nil)
        return nil;
    return [self contextWithOptions: options];
}

- (instancetype) init {
    return [self initWithOptions: nil];
}

- (instancetype) initWithOptions: (NSDictionary *) options {
    if ((self = [super init]))
        _options = [options copy];
    return self;
}

- (void) dealloc {
    if (_cgContext != NULL)
        CGContextRelease(_cgContext);
    [_options release];
    [super dealloc];
}

/* The part of the image in fromRect, in the image's own coordinates (origin bottom left). */
static CGImageRef createCroppedImage(CIImage *image, CGRect fromRect) {
    CGImageRef source = [image CGImage];
    if (source == NULL)
        return NULL;
    CGRect extent = [image extent];
    CGRect rect = CGRectIntersection(CGRectIntegral(fromRect), extent);
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect))
        return NULL;
    if (CGRectEqualToRect(rect, extent))
        return CGImageRetain(source);
    /* CGImage rows run top down. */
    CGRect flipped = CGRectMake(rect.origin.x - extent.origin.x,
                                CGRectGetMaxY(extent) - CGRectGetMaxY(rect), rect.size.width, rect.size.height);
    return CGImageCreateWithImageInRect(source, flipped);
}

- (CGImageRef) createCGImage: (CIImage *) image fromRect: (CGRect) fromRect {
    return createCroppedImage(image, fromRect);
}

- (void) drawImage: (CIImage *) image inRect: (CGRect) inRect fromRect: (CGRect) fromRect {
    if (_cgContext == NULL)
        return;
    CGImageRef cropped = createCroppedImage(image, fromRect);
    if (cropped == NULL)
        return;
    CGContextDrawImage(_cgContext, inRect, cropped);
    CGImageRelease(cropped);
}

- (void) drawImage: (CIImage *) image atPoint: (CGPoint) atPoint fromRect: (CGRect) fromRect {
    [self drawImage: image
             inRect: CGRectMake(atPoint.x, atPoint.y, fromRect.size.width, fromRect.size.height)
           fromRect: fromRect];
}

static BOOL bitmapInfoForFormat(CIFormat format, CGBitmapInfo *info) {
    if (format == kCIFormatBGRA8)
        *info = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
    else if (format == kCIFormatARGB8)
        *info = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedFirst;
    else if (format == kCIFormatRGBA8)
        *info = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
    else if (format == kCIFormatABGR8)
        *info = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast;
    else
        return NO;
    return YES;
}

/* Draws the image's bounds part into a bitmap of bounds' size. */
- (void) render: (CIImage *) image
       toBitmap: (void *) data
       rowBytes: (ptrdiff_t) rowBytes
         bounds: (CGRect) bounds
         format: (CIFormat) format
     colorSpace: (CGColorSpaceRef) colorSpace {
    CGBitmapInfo info;
    if (data == NULL || !bitmapInfoForFormat(format, &info))
        return;
    CGColorSpaceRef space = colorSpace ? CGColorSpaceRetain(colorSpace) : CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(data, (size_t)bounds.size.width, (size_t)bounds.size.height, 8,
                                                rowBytes, space, info);
    CGColorSpaceRelease(space);
    if (bitmap == NULL)
        return;
    CGImageRef cropped = createCroppedImage(image, bounds);
    if (cropped != NULL) {
        CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
        CGRect drawn = CGRectIntersection(bounds, [image extent]);
        CGContextDrawImage(bitmap, CGRectOffset(drawn, -bounds.origin.x, -bounds.origin.y), cropped);
        CGImageRelease(cropped);
    }
    CGContextRelease(bitmap);
}

static BOOL formatForPixelBuffer(CVPixelBufferRef buffer, CIFormat *format) {
    switch (CVPixelBufferGetPixelFormatType(buffer)) {
    case kCVPixelFormatType_32BGRA: *format = kCIFormatBGRA8; return YES;
    case kCVPixelFormatType_32ARGB: *format = kCIFormatARGB8; return YES;
    case kCVPixelFormatType_32RGBA: *format = kCIFormatRGBA8; return YES;
    case kCVPixelFormatType_32ABGR: *format = kCIFormatABGR8; return YES;
    default: return NO;
    }
}

- (void) render: (CIImage *) image
toCVPixelBuffer: (CVPixelBufferRef) buffer
         bounds: (CGRect) bounds
     colorSpace: (CGColorSpaceRef) colorSpace {
    CIFormat format;
    if (buffer == NULL || !formatForPixelBuffer(buffer, &format))
        return;
    if (CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess)
        return;
    CGRect whole = CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer));
    CGRect target = CGRectIntersection(bounds, whole);
    if (!CGRectIsNull(target) && !CGRectIsEmpty(target)) {
        size_t rowBytes = CVPixelBufferGetBytesPerRow(buffer);
        /* The buffer's rows run top down; bounds is measured from its bottom left. */
        size_t top = (size_t)(whole.size.height - CGRectGetMaxY(target));
        char *origin = (char *)CVPixelBufferGetBaseAddress(buffer) + top * rowBytes + (size_t)target.origin.x * 4;
        [self render: image toBitmap: origin rowBytes: rowBytes bounds: target format: format colorSpace: colorSpace];
    }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
}

- (void) render: (CIImage *) image toCVPixelBuffer: (CVPixelBufferRef) buffer {
    if (buffer == NULL)
        return;
    [self render: image
 toCVPixelBuffer: buffer
          bounds: CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))
      colorSpace: NULL];
}

@end
