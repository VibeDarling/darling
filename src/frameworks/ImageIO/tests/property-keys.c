#include <ImageIO/ImageIO.h>
#include <stdio.h>
#include <string.h>

// The documentation names these keys and what they mean; the strings below are the ones observed on a real Mac (macOS 26.1,
// probe line 14-46), pinned here.
int main(void) {
    #define KEY(name, value) { #name, name, value }
    const struct { const char *name; CFStringRef key; const char *value; } keys[] = {
        KEY(kCGImagePropertyWidth, "Width"),
        KEY(kCGImagePropertyHeight, "Height"),
        KEY(kCGImagePropertyDepth, "Depth"),
        KEY(kCGImagePropertyPixelFormat, "PixelFormat"),
        KEY(kCGImagePropertyColorModel, "ColorModel"),
        KEY(kCGImagePropertyColorModelRGB, "RGB"),
        KEY(kCGImagePropertyColorModelGray, "Gray"),
        KEY(kCGImagePropertyColorModelCMYK, "CMYK"),
        KEY(kCGImagePropertyGPSDictionary, "{GPS}"),
        KEY(kCGImagePropertyGPSLatitude, "Latitude"),
        KEY(kCGImagePropertyGPSLatitudeRef, "LatitudeRef"),
        KEY(kCGImagePropertyGPSLongitude, "Longitude"),
        KEY(kCGImagePropertyGPSLongitudeRef, "LongitudeRef"),
        KEY(kCGImagePropertyExifDateTimeOriginal, "DateTimeOriginal"),
        KEY(kCGImagePropertyExifOffsetTimeOriginal, "OffsetTimeOriginal"),
        KEY(kCGImagePropertyExifUserComment, "UserComment"),
        KEY(kCGImagePropertyHEICSDictionary, "{HEICS}"),
        KEY(kCGImagePropertyHEICSDelayTime, "DelayTime"),
        KEY(kCGImagePropertyHEICSUnclampedDelayTime, "UnclampedDelayTime"),
        KEY(kCGImagePropertyIPTCCity, "City"),
        KEY(kCGImagePropertyIPTCCredit, "Credit"),
        KEY(kCGImagePropertyIPTCSubLocation, "SubLocation"),
        KEY(kCGImagePropertyIPTCExtDigitalSourceType, "DigitalSourceType"),
        KEY(kCGImagePropertyIPTCExtLocationGPSAltitude, "GPSAltitude"),
        KEY(kCGImagePropertyIPTCExtLocationGPSLatitude, "GPSLatitude"),
        KEY(kCGImagePropertyIPTCExtLocationGPSLongitude, "GPSLongitude"),
        KEY(kCGImagePropertyTIFFArtist, "Artist"),
        KEY(kCGImagePropertyTIFFCopyright, "Copyright"),
        KEY(kCGImagePropertyTIFFDocumentName, "DocumentName"),
        KEY(kCGImagePropertyTIFFImageDescription, "ImageDescription"),
        KEY(kCGImagePropertyMakerAppleDictionary, "{MakerApple}"),
    };
    int failures = 0;
    size_t count = sizeof keys / sizeof keys[0];
    for (size_t i = 0; i < count; i++) {
        char buffer[64];
        if (keys[i].key == NULL || CFGetTypeID(keys[i].key) != CFStringGetTypeID()) {
            printf("FAIL: %s is not a CFString\n", keys[i].name);
            failures++;
            continue;
        }
        if (!CFStringGetCString(keys[i].key, buffer, sizeof buffer, kCFStringEncodingUTF8) || strcmp(buffer, keys[i].value) != 0) {
            printf("FAIL: %s is not \"%s\"\n", keys[i].name, keys[i].value);
            failures++;
        }
    }
    // The keys of one dictionary are looked up in the same table, so two of them sharing a string would alias.
    for (size_t i = 0; i < count; i++) {
        for (size_t j = i + 1; j < count; j++) {
            const char *a = strstr(keys[i].name, "kCGImageProperty") + 16, *b = strstr(keys[j].name, "kCGImageProperty") + 16;
            int sameGroup = (strncmp(a, "GPS", 3) == 0 && strncmp(b, "GPS", 3) == 0) || (strncmp(a, "IPTC", 4) == 0 && strncmp(b, "IPTC", 4) == 0) ||
                            (strncmp(a, "TIFF", 4) == 0 && strncmp(b, "TIFF", 4) == 0) || (strncmp(a, "Exif", 4) == 0 && strncmp(b, "Exif", 4) == 0) ||
                            (strncmp(a, "HEICS", 5) == 0 && strncmp(b, "HEICS", 5) == 0) || (strncmp(a, "ColorModel", 10) == 0 && strncmp(b, "ColorModel", 10) == 0);
            if (sameGroup && CFEqual(keys[i].key, keys[j].key)) {
                printf("FAIL: %s and %s share a string\n", keys[i].name, keys[j].name);
                failures++;
            }
        }
    }
    // The keys already defined stay distinct from the new dictionary names.
    if (CFEqual(kCGImagePropertyGPSDictionary, kCGImagePropertyExifDictionary) || CFEqual(kCGImagePropertyHEICSDictionary, kCGImagePropertyGIFDictionary) ||
        CFEqual(kCGImagePropertyMakerAppleDictionary, kCGImagePropertyTIFFDictionary)) {
        printf("FAIL: a new dictionary name collides with an existing one\n");
        failures++;
    }
    if (failures) return 1;
    printf("PASS: %zu property keys\n", count);
    return 0;
}
