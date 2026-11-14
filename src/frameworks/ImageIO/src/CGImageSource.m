#import <ImageIO/CGImageSource.h>
#import <Onyx2D/O2ImageSource.h>
#import <Onyx2D/O2BitmapContext.h>
#import <Onyx2D/O2ColorSpace.h>
#import <Onyx2D/O2Context.h>
#import <Onyx2D/O2Image.h>

const CFStringRef kCGImageSourceCreateThumbnailFromImageAlways = CFSTR("kCGImageSourceCreateThumbnailFromImageAlways");
const CFStringRef kCGImageSourceCreateThumbnailFromImageIfAbsent = CFSTR("kCGImageSourceCreateThumbnailFromImageIfAbsent");
const CFStringRef kCGImageSourceCreateThumbnailWithTransform = CFSTR("kCGImageSourceCreateThumbnailWithTransform");
const CFStringRef kCGImageSourceShouldAllowFloat = CFSTR("kCGImageSourceShouldAllowFloat");
const CFStringRef kCGImageSourceShouldCache = CFSTR("kCGImageSourceShouldCache");
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

static bool optionIsTrue(CFDictionaryRef options, CFStringRef key)
{
    CFTypeRef value = options != NULL ? CFDictionaryGetValue(options, key) : NULL;
    if (value == NULL) {
        return false;
    }
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        return CFBooleanGetValue((CFBooleanRef)value);
    }
    int number = 0;
    return CFGetTypeID(value) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &number) && number != 0;
}

// CGImageSource.h documents the options: a thumbnail is made from the full image when
// kCGImageSourceCreateThumbnailFromImageAlways is true, or when it is not stored in the file and
// kCGImageSourceCreateThumbnailFromImageIfAbsent is true; the thumbnail is limited to
// kCGImageSourceThumbnailMaxPixelSize pixels in width and height, and is as big as the image when the key is
// absent. The decoders here read no thumbnail stored in a file, so without one of the two "from image" options
// there is none to return and the result is NULL, as documented for an absent thumbnail.
// GUESS: the size is only reduced, never enlarged (the documentation says a thumbnail may be as big as the
// image itself), and the aspect ratio is kept with the larger side rounded to the limit.
// Not implemented: kCGImageSourceCreateThumbnailWithTransform (the orientation is not applied), and
// kCGImageSourceShouldCache and its relatives (decoding is always lazy here).
CGImageRef CGImageSourceCreateThumbnailAtIndex(CGImageSourceRef self, size_t index, CFDictionaryRef options)
{
    if (self == NULL || index >= CGImageSourceGetCount(self)) {
        return NULL;
    }
    if (!optionIsTrue(options, kCGImageSourceCreateThumbnailFromImageAlways) &&
        !optionIsTrue(options, kCGImageSourceCreateThumbnailFromImageIfAbsent)) {
        return NULL;
    }
    O2ImageRef image = (O2ImageRef)CGImageSourceCreateImageAtIndex(self, index, NULL);
    if (image == NULL) {
        return NULL;
    }
    size_t width = O2ImageGetWidth(image);
    size_t height = O2ImageGetHeight(image);
    size_t longest = width > height ? width : height;
    size_t limit = 0;
    CFTypeRef value = options != NULL ? CFDictionaryGetValue(options, kCGImageSourceThumbnailMaxPixelSize) : NULL;
    double requested = 0;
    if (value != NULL && CFGetTypeID(value) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &requested) && requested >= 1) {
        limit = (size_t)requested;
    }
    if (limit != 0 && limit < longest) {
        double scale = (double)limit / (double)longest;
        width = (size_t)(width * scale + 0.5);
        height = (size_t)(height * scale + 0.5);
        width = width != 0 ? width : 1;
        height = height != 0 ? height : 1;
    }

    O2ColorSpaceRef colorSpace = O2ColorSpaceCreateDeviceRGB();
    O2ContextRef context = O2BitmapContextCreate(NULL, width, height, 8, 0, colorSpace, kO2ImageAlphaPremultipliedLast | kO2BitmapByteOrder32Big);
    O2ColorSpaceRelease(colorSpace);
    CGImageRef thumbnail = NULL;
    if (context != NULL) {
        O2ContextSetInterpolationQuality(context, kO2InterpolationHigh);
        O2ContextDrawImage(context, O2RectMake(0, 0, width, height), image);
        thumbnail = (CGImageRef)O2BitmapContextCreateImage(context);
        O2ContextRelease(context);
    }
    O2ImageRelease(image);
    return thumbnail;
}
