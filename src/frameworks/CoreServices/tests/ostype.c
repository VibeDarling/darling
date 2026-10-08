#include <CoreFoundation/CFURL.h>
#include <LaunchServices/UTType.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;

    if (strcmp(argv[1], "create") == 0) {
        CFStringRef tag = UTCreateStringForOSType(0x54455854);
        if (!tag || CFStringCompare(tag, CFSTR("TEXT"), 0) != kCFCompareEqualTo) {
            fprintf(stderr, "FAIL: OSType TEXT did not produce four-character TEXT\n");
            if (tag) CFRelease(tag);
            return 1;
        }
        OSType value = UTGetOSTypeFromString(tag);
        CFRelease(tag);
        if (value != 0x54455854) {
            fprintf(stderr, "FAIL: created TEXT roundtrip returned 0x%08x\n", value);
            return 1;
        }
    } else if (strcmp(argv[1], "decode") == 0) {
        OSType value = UTGetOSTypeFromString(CFSTR("TEXT"));
        if (value != 0x54455854) {
            fprintf(stderr, "FAIL: literal TEXT decoded as 0x%08x\n", value);
            return 1;
        }
    } else if (strcmp(argv[1], "indirect") == 0) {
        UniChar characters[] = {'T', 'E', 'X', 'T'};
        CFMutableStringRef tag = CFStringCreateMutableWithExternalCharactersNoCopy(
            NULL, characters, 4, 4, kCFAllocatorNull);
        if (!tag || CFStringGetCStringPtr(tag, kCFStringEncodingASCII) != NULL) {
            fprintf(stderr, "FAIL: fixture must have no direct ASCII storage\n");
            if (tag) CFRelease(tag);
            return 1;
        }
        puts("fixture: no direct ASCII storage");
        fflush(stdout);
        OSType value = UTGetOSTypeFromString(tag);
        CFRelease(tag);
        if (value != 0x54455854) {
            fprintf(stderr, "FAIL: indirect TEXT decoded as 0x%08x\n", value);
            return 1;
        }
        CFStringRef encoded = UTCreateStringForOSType(value);
        int valid = encoded && CFStringCompare(encoded, CFSTR("TEXT"), 0) == kCFCompareEqualTo;
        if (encoded) CFRelease(encoded);
        if (!valid) {
            fprintf(stderr, "FAIL: indirect TEXT roundtrip\n");
            return 1;
        }
    } else {
        return 2;
    }
    puts("PASS: OSType TEXT conversion");
    return 0;
}
