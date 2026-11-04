#import <UIKit/UIGraphicsImageContext.h>
#import <UIKit/UIGraphicsContext.h>
#import <CoreGraphics/CGBitmapContext.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyValueCoding.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        void (*begin)(CGSize, BOOL, CGFloat) = dlsym(library, "UIGraphicsBeginImageContextWithOptions");
        void (*end)(void) = dlsym(library, "UIGraphicsEndImageContext");
        UIImage *(*image)(void) = dlsym(library, "UIGraphicsGetImageFromCurrentImageContext");
        CGContextRef (*current)(void) = dlsym(library, "UIGraphicsGetCurrentContext");
        void (*push)(CGContextRef) = dlsym(library, "UIGraphicsPushContext");
        void (*pop)(void) = dlsym(library, "UIGraphicsPopContext");
        NSData *(*png)(UIImage *) = dlsym(library, "UIImagePNGRepresentation");
        CHECK(begin && end && image && current && push && pop && png);
        CHECK(current() == NULL && image() == nil);
        end();
        begin(CGSizeMake(4, 3), YES, 2);
        CGContextRef outer = current();
        CHECK(outer && CGBitmapContextGetWidth(outer) == 8 && CGBitmapContextGetHeight(outer) == 6);
        CHECK(CGBitmapContextGetAlphaInfo(outer) == kCGImageAlphaNoneSkipFirst);
        CGAffineTransform transform = CGContextGetCTM(outer);
        CHECK(transform.a == 2 && transform.d == -2 && transform.tx == 0 && transform.ty == 6);
        CGContextSetRGBFillColor(outer, 0, 0, 1, 1);
        CGContextFillRect(outer, CGRectMake(0, 0, 4, 3));
        CGContextSetRGBFillColor(outer, 1, 0, 0, 1);
        CGContextFillRect(outer, CGRectMake(0, 0, 1, 1));
        unsigned char *bytes = CGBitmapContextGetData(outer);
        size_t stride = CGBitmapContextGetBytesPerRow(outer);
        unsigned red = 0, blue = 0;
        for (unsigned y = 0; y < 6; y++) for (unsigned x = 0; x < 8; x++) {
            unsigned char *pixel = bytes + y * stride + x * 4;
            if (pixel[0] == 0 && pixel[1] == 0 && pixel[2] == 255) red++;
            if (pixel[0] == 255 && pixel[1] == 0 && pixel[2] == 0) blue++;
        }
        CHECK(red == 4 && blue == 44);
        UIImage *snapshot = image();
        CHECK(snapshot.scale == 2 && snapshot.size.width == 4 && snapshot.size.height == 3);
        CHECK(png(snapshot) == nil);
        begin(CGSizeMake(2, 1), NO, 1);
        CGContextRef inner = current();
        CHECK(inner != outer && CGBitmapContextGetAlphaInfo(inner) == kCGImageAlphaPremultipliedFirst);
        CGContextSetRGBFillColor(inner, 1, 0, 0, 0.5);
        CGContextFillRect(inner, CGRectMake(0, 0, 2, 1));
        bytes = CGBitmapContextGetData(inner);
        CHECK(bytes[0] == 0 && bytes[1] == 0 && bytes[2] >= 127 && bytes[2] <= 128 && bytes[3] >= 127 && bytes[3] <= 128);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef foreign = CGBitmapContextCreate(NULL, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(space);
        CHECK(foreign);
        push(foreign);
        CHECK(image() == nil);
        BOOL endRaised = NO;
        @try { end(); } @catch (NSException *exception) { endRaised = YES; }
        CHECK(endRaised && current() == foreign);
        pop();
        CHECK(current() == inner);
        end();
        CHECK(current() == outer && image().scale == 2);
        end();
        CHECK(current() == NULL && image() == nil);
        CHECK(CGImageGetWidth(snapshot.CGImage) == 8 && CGImageGetHeight(snapshot.CGImage) == 6);
        CFDataRef snapshotBytes = CGDataProviderCopyData(CGImageGetDataProvider(snapshot.CGImage));
        CHECK(snapshotBytes != NULL && CFDataGetLength(snapshotBytes) >= 8 * 6 * 4);
        CFRelease(snapshotBytes);
        CGContextRelease(foreign);
        Class screenClass = NSClassFromString(@"UIScreen");
        CHECK(screenClass != Nil);
        CGFloat screenScale = [[[screenClass performSelector:@selector(mainScreen)] valueForKey:@"scale"] doubleValue];
        CHECK(screenScale > 0);
        begin(CGSizeMake(3, 2), YES, 0);
        CHECK(CGBitmapContextGetWidth(current()) == (size_t)ceil(3 * screenScale) && image().scale == screenScale);
        end();
        begin(CGSizeMake(1.5, 1), YES, 1);
        CHECK(CGBitmapContextGetWidth(current()) == 2 && CGBitmapContextGetHeight(current()) == 1);
        end();
        BOOL rejected = NO;
        @try { begin(CGSizeMake(1, 1), NO, -1); }
        @catch (NSException *exception) { rejected = YES; }
        CHECK(rejected && current() == NULL);
        CGSize badSizes[] = {{NAN, 1}, {1, NAN}, {0, 1}, {1, 0}, {-1, 1}, {1, -1}, {INFINITY, 1}, {1, INFINITY}};
        for (unsigned i = 0; i < sizeof(badSizes) / sizeof(badSizes[0]); i++) {
            rejected = NO;
            @try { begin(badSizes[i], YES, 1); } @catch (NSException *exception) { rejected = YES; }
            CHECK(rejected && current() == NULL);
        }
        rejected = NO;
        @try { begin(CGSizeMake(1, 1), YES, NAN); } @catch (NSException *exception) { rejected = YES; }
        CHECK(rejected && current() == NULL);
        begin(CGSizeMake(100.0000001, 1), YES, 1);
        CHECK(CGBitmapContextGetWidth(current()) == 101 && CGBitmapContextGetHeight(current()) == 1);
        end();
        CHECK(current() == NULL);
        puts("PASS UIKit bitmap contexts: pixels, scale, opaque/alpha, nested/foreign restoration, snapshot ownership, scale 0 as main-screen scale, ceil of fractional pixels, end with a foreign context raising, non-finite/zero/negative sizes, 100.0000001 ceil to 101");
    }
    return 0;
}
