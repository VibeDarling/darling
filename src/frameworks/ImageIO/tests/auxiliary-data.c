#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// A 40x20 RGBA PNG made for the thumbnail test: the left half is red, the right half is blue.
static const unsigned char png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x14, 0x08, 0x06, 0x00, 0x00, 0x00, 0xff, 0x46, 0x7f,
    0xbb, 0x00, 0x00, 0x00, 0x2c, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0xed, 0xce, 0xb1, 0x0d, 0x00,
    0x00, 0x0c, 0xc2, 0x30, 0xfe, 0x7f, 0x9a, 0x3e, 0xc1, 0x54, 0x79, 0xc8, 0x1a, 0x39, 0x4d, 0xba,
    0x6c, 0xbc, 0x6b, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x3f, 0x03,
    0x0f, 0x6c, 0x6e, 0x3a, 0x1b, 0x4a, 0xb4, 0x79, 0x4a, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
    0x44, 0xae, 0x42, 0x60, 0x82};

static int hasValue(CFStringRef key, const char *expected) {
    char buffer[64];
    return key != NULL && CFGetTypeID(key) == CFStringGetTypeID() &&
           CFStringGetCString(key, buffer, sizeof buffer, kCFStringEncodingUTF8) && strcmp(buffer, expected) == 0;
}

// CGImageSourceCopyAuxiliaryDataInfoAtIndex returns NULL when the image has no auxiliary data of the type. The decoders
// here read none, so every request is answered with NULL. The key strings are the ones observed on a real Mac (probe line 2-13).
int main(void) {
    const struct { const char *name; CFStringRef key; } keys[] = {
        { "kCGImageAuxiliaryDataTypeDepth", kCGImageAuxiliaryDataTypeDepth },
        { "kCGImageAuxiliaryDataTypeDisparity", kCGImageAuxiliaryDataTypeDisparity },
        { "kCGImageAuxiliaryDataTypeAlpha", kCGImageAuxiliaryDataTypeAlpha },
        { "kCGImageAuxiliaryDataTypeHDRGainMap", kCGImageAuxiliaryDataTypeHDRGainMap },
        { "kCGImageAuxiliaryDataTypeISOGainMap", kCGImageAuxiliaryDataTypeISOGainMap },
        { "kCGImageAuxiliaryDataInfoData", kCGImageAuxiliaryDataInfoData },
        { "kCGImageAuxiliaryDataInfoDataDescription", kCGImageAuxiliaryDataInfoDataDescription },
        { "kCGImageDestinationImageMaxPixelSize", kCGImageDestinationImageMaxPixelSize },
        { "kCGImageDestinationOptimizeColorForSharing", kCGImageDestinationOptimizeColorForSharing },
        { "kCGImageDestinationPreserveGainMap", kCGImageDestinationPreserveGainMap },
        { "kCGImageSourceSkipMetadata", kCGImageSourceSkipMetadata },
    };
    size_t count = sizeof keys / sizeof keys[0];
    for (size_t i = 0; i < count; i++) {
        char message[96];
        snprintf(message, sizeof message, "%s is a CFString with its own name as the value", keys[i].name);
        EXPECT(hasValue(keys[i].key, keys[i].name), message);
        for (size_t j = i + 1; j < count; j++) EXPECT(!CFEqual(keys[i].key, keys[j].key), "the keys are distinct");
    }

    CFDataRef data = CFDataCreate(NULL, png, sizeof png);
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    EXPECT(source != NULL, "the PNG opens");
    for (size_t i = 0; i < 5; i++) {
        CFDictionaryRef info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, keys[i].key);
        EXPECT(info == NULL, "a PNG has no auxiliary data of any type: NULL");
    }
    EXPECT(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 1, kCGImageAuxiliaryDataTypeDepth) == NULL, "an index past the last image: NULL");
    EXPECT(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, CFSTR("not an auxiliary data type")) == NULL, "an unknown type: NULL");
    EXPECT(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, NULL) == NULL, "no type: NULL");
    EXPECT(CGImageSourceCopyAuxiliaryDataInfoAtIndex(NULL, 0, kCGImageAuxiliaryDataTypeDepth) == NULL, "no source: NULL");

    // The destination options are accepted: the image is still encoded and reads back at its own size.
    int limit = 10;
    CFNumberRef maxPixelSize = CFNumberCreate(NULL, kCFNumberIntType, &limit);
    CFMutableDictionaryRef options = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(options, kCGImageDestinationImageMaxPixelSize, maxPixelSize);
    CFDictionarySetValue(options, kCGImageDestinationOptimizeColorForSharing, kCFBooleanTrue);
    CFDictionarySetValue(options, kCGImageDestinationPreserveGainMap, kCFBooleanTrue);
    CFDictionarySetValue(options, kCGImageSourceSkipMetadata, kCFBooleanTrue);
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, options);
    EXPECT(image != NULL && CGImageGetWidth(image) == 40 && CGImageGetHeight(image) == 20, "SkipMetadata is accepted by the source");
    CFMutableDataRef encoded = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(encoded, CFSTR("public.png"), 1, options);
    EXPECT(destination != NULL, "a PNG destination with the options is created");
    CGImageDestinationAddImage(destination, image, options);
    EXPECT(CGImageDestinationFinalize(destination), "the destination finalizes with the options");
    CGImageSourceRef again = CGImageSourceCreateWithData(encoded, NULL);
    CGImageRef back = again ? CGImageSourceCreateImageAtIndex(again, 0, NULL) : NULL;
    EXPECT(back != NULL && CGImageGetWidth(back) == 40 && CGImageGetHeight(back) == 20, "the options have no effect on the encoded image");
    printf("PASS: auxiliary data keys, destination options and CopyAuxiliaryDataInfoAtIndex\n");
    return 0;
}
