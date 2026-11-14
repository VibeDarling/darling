#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// A 40x20 RGBA PNG made for this test: the left half is red, the right half is blue.
static const unsigned char png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x14, 0x08, 0x06, 0x00, 0x00, 0x00, 0xff, 0x46, 0x7f,
    0xbb, 0x00, 0x00, 0x00, 0x2c, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0xed, 0xce, 0xb1, 0x0d, 0x00,
    0x00, 0x0c, 0xc2, 0x30, 0xfe, 0x7f, 0x9a, 0x3e, 0xc1, 0x54, 0x79, 0xc8, 0x1a, 0x39, 0x4d, 0xba,
    0x6c, 0xbc, 0x6b, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x3f, 0x03,
    0x0f, 0x6c, 0x6e, 0x3a, 0x1b, 0x4a, 0xb4, 0x79, 0x4a, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
    0x44, 0xae, 0x42, 0x60, 0x82};

static CFDictionaryRef options(CFTypeRef always, CFTypeRef ifAbsent, int maxPixelSize) {
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (always) CFDictionarySetValue(dictionary, kCGImageSourceCreateThumbnailFromImageAlways, always);
    if (ifAbsent) CFDictionarySetValue(dictionary, kCGImageSourceCreateThumbnailFromImageIfAbsent, ifAbsent);
    if (maxPixelSize) {
        CFNumberRef number = CFNumberCreate(NULL, kCFNumberIntType, &maxPixelSize);
        CFDictionarySetValue(dictionary, kCGImageSourceThumbnailMaxPixelSize, number);
        CFRelease(number);
    }
    return dictionary;
}

// The red and blue channels of the pixel at (x, y) of an image, drawn into an RGBA bitmap of its own size.
static int channels(CGImageRef image, size_t x, size_t y, unsigned char *red, unsigned char *blue) {
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    unsigned char pixels[64 * 64 * 4] = {0};
    if (width > 64 || height > 64) return 0;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    *red = pixels[(y * width + x) * 4];
    *blue = pixels[(y * width + x) * 4 + 2];
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return 1;
}

// CGImageSourceCreateThumbnailAtIndex (CGImageSource.h): a thumbnail is created from the full image when
// kCGImageSourceCreateThumbnailFromImageAlways is true, or when none is stored and ...IfAbsent is true; it is
// limited to kCGImageSourceThumbnailMaxPixelSize in width and height, and is as big as the image without that
// key. A PNG stores no thumbnail, so without either option the result is NULL.
int main(void) {
    CFDataRef data = CFDataCreate(NULL, png, sizeof png);
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    EXPECT(source != NULL, "the PNG opens");

    EXPECT(CGImageSourceCreateThumbnailAtIndex(source, 0, NULL) == NULL, "no options, no stored thumbnail: NULL");
    CFDictionaryRef off = options(kCFBooleanFalse, kCFBooleanFalse, 10);
    EXPECT(CGImageSourceCreateThumbnailAtIndex(source, 0, off) == NULL, "both options false: NULL");
    CFRelease(off);

    CFDictionaryRef always = options(kCFBooleanTrue, NULL, 10);
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, always);
    EXPECT(thumbnail != NULL, "FromImageAlways makes a thumbnail");
    EXPECT(CGImageGetWidth(thumbnail) == 10 && CGImageGetHeight(thumbnail) == 5, "the 40x20 image is limited to 10 pixels, aspect kept");
    unsigned char red, blue;
    EXPECT(channels(thumbnail, 1, 2, &red, &blue) && red > 200 && blue < 50, "the left of the thumbnail is red");
    EXPECT(channels(thumbnail, 8, 2, &red, &blue) && red < 50 && blue > 200, "the right of the thumbnail is blue");
    CGImageRelease(thumbnail);
    CFRelease(always);

    CFDictionaryRef ifAbsent = options(NULL, kCFBooleanTrue, 0);
    thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, ifAbsent);
    EXPECT(thumbnail != NULL && CGImageGetWidth(thumbnail) == 40 && CGImageGetHeight(thumbnail) == 20, "IfAbsent without a limit: the image's size");
    CGImageRelease(thumbnail);
    CFRelease(ifAbsent);

    CFDictionaryRef large = options(kCFBooleanTrue, NULL, 100);
    thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, large);
    EXPECT(thumbnail != NULL && CGImageGetWidth(thumbnail) == 40 && CGImageGetHeight(thumbnail) == 20, "a limit above the image's size does not enlarge it");
    CGImageRelease(thumbnail);
    CFRelease(large);

    CFDictionaryRef tall = options(kCFBooleanTrue, NULL, 1);
    thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, tall);
    EXPECT(thumbnail != NULL && CGImageGetWidth(thumbnail) == 1 && CGImageGetHeight(thumbnail) == 1, "the smaller side never drops below one pixel");
    CGImageRelease(thumbnail);
    CFRelease(tall);

    CFDictionaryRef opts = options(kCFBooleanTrue, NULL, 10);
    EXPECT(CGImageSourceCreateThumbnailAtIndex(source, 1, opts) == NULL, "an index past the last image: NULL");
    EXPECT(CGImageSourceCreateThumbnailAtIndex(NULL, 0, opts) == NULL, "no source: NULL");
    CFRelease(opts);
    CFRelease(source);
    CFRelease(data);
    printf("PASS: CGImageSourceCreateThumbnailAtIndex\n");
    return 0;
}
