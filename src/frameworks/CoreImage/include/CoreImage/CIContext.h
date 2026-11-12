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

#ifndef COREIMAGE_CICONTEXT_H
#define COREIMAGE_CICONTEXT_H

#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreVideo/CoreVideo.h>
#include <CoreImage/CIImage.h>

@class CIImage, EAGLContext;

typedef NSString *CIContextOption NS_TYPED_ENUM;
extern CIContextOption const kCIContextOutputColorSpace;
extern CIContextOption const kCIContextWorkingColorSpace;
extern CIContextOption const kCIContextUseSoftwareRenderer;
extern CIContextOption const kCIContextPriorityRequestLow;

@interface CIContext : NSObject

+ (CIContext *) contextWithCGContext: (CGContextRef) cgContext
                             options: (NSDictionary<CIContextOption, id> *) options;
+ (CIContext *) contextWithOptions: (NSDictionary<CIContextOption, id> *) options;
+ (CIContext *) context;
- (instancetype) initWithOptions: (NSDictionary<CIContextOption, id> *) options;
- (instancetype) init;
+ (CIContext *) contextWithEAGLContext: (EAGLContext *) eaglContext;
+ (CIContext *) contextWithEAGLContext: (EAGLContext *) eaglContext
                               options: (NSDictionary<CIContextOption, id> *) options;

- (CGImageRef) createCGImage: (CIImage *) image fromRect: (CGRect) fromRect CF_RETURNS_RETAINED;
- (void) render: (CIImage *) image toCVPixelBuffer: (CVPixelBufferRef) buffer;
- (void) render: (CIImage *) image
toCVPixelBuffer: (CVPixelBufferRef) buffer
         bounds: (CGRect) bounds
     colorSpace: (CGColorSpaceRef) colorSpace;
- (void) render: (CIImage *) image
       toBitmap: (void *) data
       rowBytes: (ptrdiff_t) rowBytes
         bounds: (CGRect) bounds
         format: (CIFormat) format
     colorSpace: (CGColorSpaceRef) colorSpace;

- (void) drawImage: (CIImage *) image
           atPoint: (CGPoint) atPoint
          fromRect: (CGRect) fromRect;
- (void) drawImage: (CIImage *) image
            inRect: (CGRect) inRect
          fromRect: (CGRect) fromRect;

@end

#endif
