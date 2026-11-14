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

// The value of kCGImageSourceSkipMetadata is its own name: observed on a real Mac (probe line 13) and
// as WebKit's ImageDecoderCG.cpp defines it. The option is accepted
// and has no effect: the decoders read metadata only when the properties are asked for.
const CFStringRef kCGImageSourceSkipMetadata = CFSTR("kCGImageSourceSkipMetadata");

// Observed on a real Mac (macOS 26.1, probe line 2-8): each is its own name, like the option keys above.
const CFStringRef kCGImageAuxiliaryDataTypeDepth = CFSTR("kCGImageAuxiliaryDataTypeDepth");
const CFStringRef kCGImageAuxiliaryDataTypeDisparity = CFSTR("kCGImageAuxiliaryDataTypeDisparity");
const CFStringRef kCGImageAuxiliaryDataTypeAlpha = CFSTR("kCGImageAuxiliaryDataTypeAlpha");
const CFStringRef kCGImageAuxiliaryDataTypeHDRGainMap = CFSTR("kCGImageAuxiliaryDataTypeHDRGainMap");
const CFStringRef kCGImageAuxiliaryDataTypeISOGainMap = CFSTR("kCGImageAuxiliaryDataTypeISOGainMap");
const CFStringRef kCGImageAuxiliaryDataInfoData = CFSTR("kCGImageAuxiliaryDataInfoData");
const CFStringRef kCGImageAuxiliaryDataInfoDataDescription = CFSTR("kCGImageAuxiliaryDataInfoDataDescription");

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

// Documented to return NULL when the image has no auxiliary data of the requested type. No decoder here reads auxiliary
// data (depth, disparity, alpha or gain maps), so for every source, index and type the answer is that there is none.
CFDictionaryRef CGImageSourceCopyAuxiliaryDataInfoAtIndex(CGImageSourceRef self, size_t index, CFStringRef auxiliaryImageDataType)
{
    return NULL;
}

// Documented: the uniform type identifiers the image sources support. These are the types of the Onyx2D decoders that
// O2ImageSource tries, in its order (+newImageSourceWithDataProvider:options:); the types the test reads back from real
// data of each format keep the two in step. All six are in the list a real Mac returns (macOS 26.1,
// probe line 54-115, 62 types). The other 56 are formats Darling cannot decode and are not listed: HEIC,
// HEIF, HEICS, AVIF, AVCI, AVIS, WebP, JPEG 2000, JPEG XL, OpenEXR, DDS, ICO, CUR, PICT, SGI, TGA, PBM, PVR, KTX, KTX2, ASTC,
// ATX, Radiance, DICOM, MPO, Photoshop, and the camera RAW types (com.adobe.raw-image and the vendor ones).
CFArrayRef CGImageSourceCopyTypeIdentifiers(void)
{
    const void *types[] = {
        CFSTR("public.png"), CFSTR("public.tiff"), CFSTR("public.jpeg"),
        CFSTR("com.microsoft.bmp"), CFSTR("com.compuserve.gif"), CFSTR("com.apple.icns")
    };
    return CFArrayCreate(NULL, types, sizeof types / sizeof types[0], &kCFTypeArrayCallBacks);
}

// Documented statuses (CGImageSource.h). No incremental source can be created here (there is no
// CGImageSourceCreateIncremental), so a source that exists was made from complete data of a recognised type. Observed on a
// real Mac (macOS 26.1, probe line 122-125): a complete PNG is 0, a PNG cut to half its bytes is 0, a PNG
// with 8 bytes of junk appended is 0, and NULL is -4 (kCGImageStatusInvalidData). The half and junk cases are Complete there
// too, so reporting Complete for every live source matches them. Not observed, so not covered: a source over data that is
// damaged in a way other than those two.
CGImageSourceStatus CGImageSourceGetStatus(CGImageSourceRef self)
{
    return self != NULL ? kCGImageStatusComplete : kCGImageStatusInvalidData;
}

// The public documentation has neither the prototype nor the meaning. Observed on a real Mac (macOS 26.1,
// probe line 133-136): the result is 0 for a PNG source in sRGB, in Display P3, in generic RGB and in
// Display P3 encoded with kCGImageDestinationOptimizeColorForSharing, called with the source alone and with (source, 0). That
// supports "false" for those, not a rule for when it is true, and it does not settle the arity. GUESS (not observed): false
// for every other source type and for NULL; bool (CGImageSourceRef) as the prototype, which is why it is not declared in the
// header. A false answer asks the caller to re-encode, which kCGImageDestinationOptimizeColorForSharing here does not change.
bool CGImageSourceIsColorOptimizedForSharing(CGImageSourceRef self)
{
    return false;
}
