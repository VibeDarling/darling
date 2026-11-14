#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
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

// A 1x1 24-bit BMP and a 1x1 GIF, written byte by byte from the file format descriptions.
static const unsigned char bmp[] = {
    'B', 'M', 58, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 24, 0,
    0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0, 0, 0};
static const unsigned char gif[] = {
    'G', 'I', 'F', '8', '9', 'a', 1, 0, 1, 0, 0x80, 0, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0x21, 0xf9, 4, 1, 0, 0, 0, 0,
    0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x44, 1, 0, 0x3b};

static CFStringRef typeOf(CFDataRef data) {
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    return source ? CGImageSourceGetType(source) : NULL;
}

static CFDataRef encode(CGImageRef image, CFStringRef type) {
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, type, 1, NULL);
    if (destination == NULL) return NULL;
    CGImageDestinationAddImage(destination, image, NULL);
    return CGImageDestinationFinalize(destination) ? data : NULL;
}

// CGImageSourceCopyTypeIdentifiers (documented): the uniform type identifiers the sources support. CGImageSourceGetStatus:
// observed on a real Mac (probe line 122-125) 0 for a complete PNG and for a PNG cut to half its bytes
// or followed by junk, -4 for NULL. CGImageSourceIsColorOptimizedForSharing: observed 0 for PNG sources (lines 133-136).
int main(void) {
    CFDataRef pngData = CFDataCreate(NULL, png, sizeof png);
    CGImageSourceRef source = CGImageSourceCreateWithData(pngData, NULL);
    EXPECT(source != NULL, "the PNG opens");
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    EXPECT(image != NULL, "the PNG decodes");

    // The types the decoders report for data of each format they read must be exactly the ones the list names.
    CFDataRef samples[] = { pngData, encode(image, CFSTR("public.jpeg")), encode(image, CFSTR("public.tiff")),
                            CFDataCreate(NULL, bmp, sizeof bmp), CFDataCreate(NULL, gif, sizeof gif) };
    CFMutableSetRef seen = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
    for (size_t i = 0; i < sizeof samples / sizeof samples[0]; i++) {
        EXPECT(samples[i] != NULL, "a sample of every readable format could be made");
        CFStringRef type = typeOf(samples[i]);
        EXPECT(type != NULL, "every sample is recognised");
        CFSetAddValue(seen, type);
    }
    EXPECT(CFSetGetCount(seen) == 5, "five samples, five distinct types");

    CFArrayRef types = CGImageSourceCopyTypeIdentifiers();
    EXPECT(types != NULL, "the list exists");
    CFIndex count = CFArrayGetCount(types);
    CFMutableSetRef listed = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
    for (CFIndex i = 0; i < count; i++) {
        CFTypeRef type = CFArrayGetValueAtIndex(types, i);
        EXPECT(CFGetTypeID(type) == CFStringGetTypeID(), "every entry is a string");
        EXPECT(!CFSetContainsValue(listed, type), "no type is listed twice");
        CFSetAddValue(listed, type);
    }
    const void *values[8];
    CFSetGetValues(seen, values);
    for (CFIndex i = 0; i < 5; i++) EXPECT(CFSetContainsValue(listed, values[i]), "every type a decoder reports is listed");
    // ICNS is the sixth decoder; it has no sample here, so it is checked by name.
    EXPECT(CFSetContainsValue(listed, CFSTR("com.apple.icns")), "com.apple.icns is listed");
    EXPECT(count == 6, "the list holds the six decoder types and nothing else");

    EXPECT(CGImageSourceGetStatus(source) == kCGImageStatusComplete, "a PNG source is complete");
    EXPECT(kCGImageStatusComplete == 0 && kCGImageStatusIncomplete == -1 && kCGImageStatusReadingHeader == -2 &&
           kCGImageStatusUnknownType == -3 && kCGImageStatusInvalidData == -4 && kCGImageStatusUnexpectedEOF == -5,
           "the documented status values");
    CGImageSourceRef gifSource = CGImageSourceCreateWithData(samples[4], NULL);
    EXPECT(CGImageSourceGetStatus(gifSource) == kCGImageStatusComplete, "a GIF source is complete");
    EXPECT(CGImageSourceGetStatus(NULL) == -4 && CGImageSourceGetStatus(NULL) == kCGImageStatusInvalidData, "no source: -4, invalid data (observed)");
    CFDataRef half = CFDataCreate(NULL, png, sizeof png / 2);
    CGImageSourceRef halfSource = CGImageSourceCreateWithData(half, NULL);
    EXPECT(halfSource != NULL && CGImageSourceGetStatus(halfSource) == 0, "a PNG cut to half its bytes: source made, status 0 (observed)");
    CFMutableDataRef junk = CFDataCreateMutableCopy(NULL, 0, pngData);
    CFDataAppendBytes(junk, (const UInt8 *)"JUNKJUNK", 8);
    CGImageSourceRef junkSource = CGImageSourceCreateWithData(junk, NULL);
    EXPECT(junkSource != NULL && CGImageSourceGetStatus(junkSource) == 0, "a PNG followed by junk: source made, status 0 (observed)");

    // Observed 0 for PNG sources, with the source alone and with (source, 0). The prototype is not public, so it is looked up.
    bool (*optimized)(CGImageSourceRef) = (bool (*)(CGImageSourceRef))dlsym(RTLD_DEFAULT, "CGImageSourceIsColorOptimizedForSharing");
    EXPECT(optimized != NULL, "CGImageSourceIsColorOptimizedForSharing is exported");
    bool (*optimizedAt)(CGImageSourceRef, size_t) = (bool (*)(CGImageSourceRef, size_t))optimized;
    EXPECT(!optimized(source) && !optimizedAt(source, 0), "a PNG source is not color optimized for sharing, with one or two arguments");
    EXPECT(!optimized(gifSource), "a GIF source is not either (GUESS, not observed)");
    EXPECT(!optimized(NULL), "NULL is not color optimized for sharing (GUESS, not observed)");
    printf("PASS: CopyTypeIdentifiers, GetStatus, IsColorOptimizedForSharing\n");
    return 0;
}
