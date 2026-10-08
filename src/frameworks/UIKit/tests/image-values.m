#import <UIKit/UIImage.h>
#import <Foundation/NSString.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

static const unsigned char pixels[] = {
    255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255,
    10,20,30,128, 50,60,70,64, 80,90,100,0, 110,120,130,255
};
static CGImageRef createImage(CGImageAlphaInfo alpha)
{
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, sizeof(pixels), NULL);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(4, 2, 8, 32, 16, space,
            alpha | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    return image;
}
int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 3);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        CGImageRef raw = createImage(kCGImageAlphaLast);
        CHECK(raw != NULL);
        Class imageClass = NSClassFromString(@"UIImage");
        NSData *(*png)(UIImage *) = dlsym(library, "UIImagePNGRepresentation");
        CHECK(imageClass != Nil && png != NULL);
        UIImage *image;
        @autoreleasepool {
            image = [imageClass imageWithCGImage:raw];
            CHECK(image.CGImage == raw);
            UIImageOrientation orientations[] = {UIImageOrientationUp, UIImageOrientationDown,
                UIImageOrientationLeft, UIImageOrientationRight, UIImageOrientationUpMirrored,
                UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored};
            for (unsigned i = 0; i < 8; i++) {
                UIImage *scaled = [[imageClass alloc] initWithCGImage:raw scale:2 orientation:orientations[i]];
                CHECK(scaled.scale == 2 && scaled.imageOrientation == orientations[i] && scaled.CGImage == raw);
                BOOL sideways = orientations[i] == UIImageOrientationLeft || orientations[i] == UIImageOrientationRight ||
                    orientations[i] == UIImageOrientationLeftMirrored || orientations[i] == UIImageOrientationRightMirrored;
                CHECK(scaled.size.width == (sideways ? 1 : 2) && scaled.size.height == (sideways ? 2 : 1));
                UIImage *copy = [scaled copy];
                CHECK(copy.CGImage == raw && copy.imageOrientation == orientations[i] && copy.scale == 2);
            }
            CGImageRelease(raw);
        }
        CHECK(image.scale == 1 && image.imageOrientation == UIImageOrientationUp);
        CHECK(image.size.width == 4 && image.size.height == 2);
        CHECK(CGImageGetWidth(image.CGImage) == 4 && CGImageGetHeight(image.CGImage) == 2);
        UIImage *copy = [image copy];
        image = nil;
        CHECK(copy.size.width == 4 && copy.size.height == 2);
        NSData *data = png(copy);
        CHECK(data != nil && [data length] > 8);
        CHECK([data writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]);
        CHECK([imageClass imageWithCGImage:NULL] == nil);
        CHECK(png(nil) == nil);
        CHECK(png([imageClass imageWithCGImage:copy.CGImage scale:1 orientation:UIImageOrientationRight]) == nil);
        CGImageRef premultiplied = createImage(kCGImageAlphaPremultipliedLast);
        CHECK(premultiplied != NULL);
        CHECK(png([imageClass imageWithCGImage:premultiplied]) == nil);
        CGImageRelease(premultiplied);
        puts("PASS UIKit UIImage CGImage ownership, size/scale/orientation/copies and synthetic PNG output");
    }
    return 0;
}
