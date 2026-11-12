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

#ifndef COREIMAGE_CIIMAGE_H
#define COREIMAGE_CIIMAGE_H

#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreVideo/CoreVideo.h>
#include <ImageIO/CGImageProperties.h>

typedef NSString *CIImageOption NS_TYPED_ENUM;

typedef int CIFormat;

extern const CIFormat kCIFormatARGB8;
extern const CIFormat kCIFormatRGBA8;
extern const CIFormat kCIFormatBGRA8;
extern const CIFormat kCIFormatABGR8;
extern const CIFormat kCIFormatRGBAh;
extern const CIFormat kCIFormatRGBA16;
extern const CIFormat kCIFormatRGBAf;

@interface CIImage : NSObject {
    /* Named as <QuartzCore/CIImage.h> names it, so a subclass built against either
       header finds the ivar. See the commit body. */
    CGImageRef _cgImage;
}

+ (CIImage *) emptyImage;
+ (CIImage *) imageWithCGImage: (CGImageRef) image;

- initWithCGImage: (CGImageRef) cgImage;

+ (CIImage *) imageWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer;
+ (CIImage *) imageWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer options: (NSDictionary<CIImageOption, id> *) options;
+ (CIImage *) imageWithCVImageBuffer: (CVImageBufferRef) imageBuffer;
+ (CIImage *) imageWithCVImageBuffer: (CVImageBufferRef) imageBuffer options: (NSDictionary<CIImageOption, id> *) options;
- (instancetype) initWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer;
- (instancetype) initWithCVPixelBuffer: (CVPixelBufferRef) pixelBuffer options: (NSDictionary<CIImageOption, id> *) options;
- (instancetype) initWithCVImageBuffer: (CVImageBufferRef) imageBuffer;
- (instancetype) initWithCVImageBuffer: (CVImageBufferRef) imageBuffer options: (NSDictionary<CIImageOption, id> *) options;

@property (readonly) CGImageRef CGImage;

- (CIImage *) imageByApplyingOrientation: (int) orientation;
- (CIImage *) imageByApplyingCGOrientation: (CGImagePropertyOrientation) orientation;
- (CGAffineTransform) imageTransformForOrientation: (int) orientation;
- (CGAffineTransform) imageTransformForCGOrientation: (CGImagePropertyOrientation) orientation;

- (CGRect) extent;

@end

#endif
