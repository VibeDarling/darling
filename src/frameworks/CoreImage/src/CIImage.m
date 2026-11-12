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

#import <CoreImage/CIImage.h>

@implementation CIImage

+ (CIImage *) emptyImage {
    return [[[self alloc] initWithCGImage: NULL] autorelease];
}

+ (CIImage *) imageWithCGImage: (CGImageRef) image {
    return [[[self alloc] initWithCGImage: image] autorelease];
}

/* The bitmap layout of the 32-bit RGB pixel formats CoreGraphics draws directly; 0 for the
   others (biplanar YCbCr among them), which need a conversion this image cannot make yet. */
static CGBitmapInfo bitmapInfoForPixelFormat(OSType format) {
    switch (format) {
    case kCVPixelFormatType_32BGRA:
        return kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
    case kCVPixelFormatType_32ARGB:
        return kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedFirst;
    case kCVPixelFormatType_32RGBA:
        return kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
    case kCVPixelFormatType_32ABGR:
        return kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast;
    default:
        return 0;
    }
}

/* An image of the pixel buffer's contents as they are now: a copy, which Apple's image is not,
   but which a caller that reuses the buffer (a pool, a decoder) cannot tell apart. */
static CGImageRef createImageFromPixelBuffer(CVPixelBufferRef buffer) {
    if (buffer == NULL || CFGetTypeID(buffer) != CVPixelBufferGetTypeID())
        return NULL;
    CGBitmapInfo info = bitmapInfoForPixelFormat(CVPixelBufferGetPixelFormatType(buffer));
    if (info == 0)
        return NULL;
    if (CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess)
        return NULL;
    size_t width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer);
    size_t rowBytes = CVPixelBufferGetBytesPerRow(buffer);
    CFDataRef data = CFDataCreate(NULL, CVPixelBufferGetBaseAddress(buffer), rowBytes * height);
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    if (data == NULL)
        return NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, space, info, provider, NULL, false,
                                     kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return image;
}

+ (CIImage *) imageWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer {
    return [[[self alloc] initWithCVPixelBuffer: pixelBuffer options: nil] autorelease];
}

+ (CIImage *) imageWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer options: (NSDictionary *) options {
    return [[[self alloc] initWithCVPixelBuffer: pixelBuffer options: options] autorelease];
}

+ (CIImage *) imageWithCVImageBuffer: (CVImageBufferRef) imageBuffer {
    return [[[self alloc] initWithCVImageBuffer: imageBuffer options: nil] autorelease];
}

+ (CIImage *) imageWithCVImageBuffer: (CVImageBufferRef) imageBuffer options: (NSDictionary *) options {
    return [[[self alloc] initWithCVImageBuffer: imageBuffer options: options] autorelease];
}

- (instancetype) initWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer {
    return [self initWithCVPixelBuffer: pixelBuffer options: nil];
}

- (instancetype) initWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer options: (NSDictionary *) options {
    CGImageRef image = createImageFromPixelBuffer(pixelBuffer);
    if (image == NULL) {
        [self release];
        return nil;
    }
    self = [self initWithCGImage: image];
    CGImageRelease(image);
    return self;
}

- (instancetype) initWithCVImageBuffer: (CVImageBufferRef) imageBuffer {
    return [self initWithCVPixelBuffer: imageBuffer options: nil];
}

- (instancetype) initWithCVImageBuffer: (CVImageBufferRef) imageBuffer options: (NSDictionary *) options {
    return [self initWithCVPixelBuffer: imageBuffer options: options];
}

- (CGImageRef) CGImage {
    return _cgImage;
}

/* The transform that shows an image stored in the EXIF orientation upright, in Core Image's
   coordinates (origin bottom left), its result's origin at zero. */
- (CGAffineTransform) imageTransformForCGOrientation: (CGImagePropertyOrientation) orientation {
    CGRect extent = [self extent];
    if (CGRectIsInfinite(extent))
        return CGAffineTransformIdentity;
    CGFloat w = extent.size.width, h = extent.size.height;
    switch (orientation) {
    case kCGImagePropertyOrientationUpMirrored:    return CGAffineTransformMake(-1, 0, 0, 1, w, 0);
    case kCGImagePropertyOrientationDown:          return CGAffineTransformMake(-1, 0, 0, -1, w, h);
    case kCGImagePropertyOrientationDownMirrored:  return CGAffineTransformMake(1, 0, 0, -1, 0, h);
    case kCGImagePropertyOrientationLeftMirrored:  return CGAffineTransformMake(0, -1, -1, 0, h, w);
    case kCGImagePropertyOrientationRight:         return CGAffineTransformMake(0, -1, 1, 0, 0, w);
    case kCGImagePropertyOrientationRightMirrored: return CGAffineTransformMake(0, 1, 1, 0, 0, 0);
    case kCGImagePropertyOrientationLeft:          return CGAffineTransformMake(0, 1, -1, 0, h, 0);
    case kCGImagePropertyOrientationUp:
    default:                                       return CGAffineTransformIdentity;
    }
}

- (CGAffineTransform) imageTransformForOrientation: (int) orientation {
    return [self imageTransformForCGOrientation: (CGImagePropertyOrientation)orientation];
}

- (CIImage *) imageByApplyingCGOrientation: (CGImagePropertyOrientation) orientation {
    if (_cgImage == NULL || orientation == kCGImagePropertyOrientationUp || orientation < 1 || orientation > 8)
        return self;
    CGAffineTransform transform = [self imageTransformForCGOrientation: orientation];
    CGRect bounds = CGRectApplyAffineTransform([self extent], transform);
    size_t width = (size_t)bounds.size.width, height = (size_t)bounds.size.height;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
                                                kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(space);
    if (bitmap == NULL)
        return nil;
    CGContextConcatCTM(bitmap, transform);
    CGContextDrawImage(bitmap, [self extent], _cgImage);
    CGImageRef oriented = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage *image = [CIImage imageWithCGImage: oriented];
    CGImageRelease(oriented);
    return image;
}

- (CIImage *) imageByApplyingOrientation: (int) orientation {
    return [self imageByApplyingCGOrientation: (CGImagePropertyOrientation)orientation];
}

- (instancetype) initWithCGImage: (CGImageRef) cgImage {
    if ((self = [super init])) {
        _cgImage = CGImageRetain(cgImage);
    }
    return self;
}

- (void) dealloc {
    CGImageRelease(_cgImage);
    [super dealloc];
}

/* An image with no CGImage behind it has no bounding box. CGRectZero is
   indistinguishable from a genuinely 0x0 image, so the infinite rect is used for "no
   bounds", which is Core Image's own idiom: its working space is "in theory infinite"
   in the Core Image Programming Guide. Apple never states the empty image's extent
   outright, so this one value is an inference. See the commit body. */
- (CGRect) extent {
    if (_cgImage == NULL) {
        return CGRectInfinite;
    }

    return CGRectMake(0, 0, CGImageGetWidth(_cgImage), CGImageGetHeight(_cgImage));
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
