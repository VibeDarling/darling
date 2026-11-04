#import <ImageIO/CGImageSource.h>
#import <Onyx2D/O2ImageSource.h>
#import <Onyx2D/O2BitmapContext.h>
#import <Onyx2D/O2ColorSpace.h>
#import <CoreFoundation/CFNumber.h>

const CFStringRef kCGImageSourceCreateThumbnailFromImageAlways = CFSTR("kCGImageSourceCreateThumbnailFromImageAlways");
const CFStringRef kCGImageSourceCreateThumbnailFromImageIfAbsent = CFSTR("kCGImageSourceCreateThumbnailFromImageIfAbsent");
const CFStringRef kCGImageSourceCreateThumbnailWithTransform = CFSTR("kCGImageSourceCreateThumbnailWithTransform");
const CFStringRef kCGImageSourceShouldAllowFloat = CFSTR("kCGImageSourceShouldAllowFloat");
const CFStringRef kCGImageSourceShouldCache = CFSTR("kCGImageSourceShouldCache");
const CFStringRef kCGImageSourceShouldCacheImmediately = CFSTR("kCGImageSourceShouldCacheImmediately");
const CFStringRef kCGImageSourceThumbnailMaxPixelSize = CFSTR("kCGImageSourceThumbnailMaxPixelSize");

@interface _O2ImageSource : O2ImageSource
@end

CGImageSourceRef CGImageSourceCreateWithData(CFDataRef data,CFDictionaryRef options) {
	return (CGImageSourceRef)[O2ImageSource newImageSourceWithData:data options:options];
}

CGImageSourceRef CGImageSourceCreateWithURL(CFURLRef url,CFDictionaryRef options) {
	return (CGImageSourceRef)[O2ImageSource newImageSourceWithURL:(NSURL *)url options:options];
}

size_t CGImageSourceGetCount(CGImageSourceRef self) {
   return [self count];
}

CGImageRef CGImageSourceCreateImageAtIndex(CGImageSourceRef self,size_t index,CFDictionaryRef options) {
   return (CGImageRef)[self createImageAtIndex:index options:options];
}

// The full image, scaled down so its longer side is at most
// kCGImageSourceThumbnailMaxPixelSize. Images carry no embedded thumbnail
// here, so this always creates one from the image, and it does not apply
// kCGImageSourceCreateThumbnailWithTransform's orientation.
CGImageRef CGImageSourceCreateThumbnailAtIndex(CGImageSourceRef self, size_t index, CFDictionaryRef options) {
   O2ImageRef image = (O2ImageRef)CGImageSourceCreateImageAtIndex(self, index, options);
   if (image == NULL)
      return NULL;
   CFNumberRef limit = options ? CFDictionaryGetValue(options, kCGImageSourceThumbnailMaxPixelSize) : NULL;
   double maxSize = 0;
   if (limit == NULL || !CFNumberGetValue(limit, kCFNumberDoubleType, &maxSize) || maxSize <= 0)
      return (CGImageRef)image;
   size_t width = O2ImageGetWidth(image), height = O2ImageGetHeight(image);
   size_t longer = width > height ? width : height;
   if (longer <= maxSize)
      return (CGImageRef)image;
   double scale = maxSize / longer;
   size_t newWidth = width * scale + 0.5, newHeight = height * scale + 0.5;
   if (newWidth < 1) newWidth = 1;
   if (newHeight < 1) newHeight = 1;
   O2ColorSpaceRef colorSpace = O2ColorSpaceCreateDeviceRGB();
   O2ContextRef context = O2BitmapContextCreate(NULL, newWidth, newHeight, 8, 0, colorSpace,
      kO2ImageAlphaPremultipliedLast | kO2BitmapByteOrder32Big);
   O2ColorSpaceRelease(colorSpace);
   if (context == NULL)
      return (CGImageRef)image;
   O2ContextSetInterpolationQuality(context, kO2InterpolationHigh);
   O2ContextDrawImage(context, O2RectMake(0, 0, newWidth, newHeight), image);
   O2ImageRef thumbnail = O2BitmapContextCreateImage(context);
   O2ContextRelease(context);
   O2ImageRelease(image);
   return (CGImageRef)thumbnail;
}

CFDictionaryRef CGImageSourceCopyPropertiesAtIndex(CGImageSourceRef self, size_t index,CFDictionaryRef options) {
   return (CFDictionaryRef)[self copyPropertiesAtIndex:index options:options];
}

CFDictionaryRef CGImageSourceCopyProperties(CGImageSourceRef self, CFDictionaryRef options) {
   if (!self) return NULL;
   if ([self count] > 0) {
      return CGImageSourceCopyPropertiesAtIndex(self, 0, options);
   }
   return NULL;
}

CFStringRef CGImageSourceGetType(CGImageSourceRef self)
{
    return [(O2ImageSource*)self type];
}

CGImageSourceRef CGImageSourceCreateWithDataProvider(CGDataProviderRef provider, CFDictionaryRef options)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}
