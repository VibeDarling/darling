#import <UIKit/UIDevice.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSCharacterSet.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class deviceClass = NSClassFromString(@"UIDevice");
        CHECK(deviceClass != Nil);
        UIDevice *device = [deviceClass currentDevice];
        CHECK(device != nil && device == [deviceClass currentDevice]);

        CHECK([device.name isEqualToString:device.model]);
        CHECK([device.model isEqualToString:@"Mac"]);

        // systemVersion is the host OS version as dotted decimal.
        NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *prefix = [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
        CHECK([device.systemVersion hasPrefix:prefix]);
        CHECK([device.systemVersion rangeOfCharacterFromSet:
               [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet]].location == NSNotFound);

        CHECK(device.orientation == UIDeviceOrientationUnknown);
        CHECK(device.multitaskingSupported);
        CHECK(!device.generatesDeviceOrientationNotifications);
        [device beginGeneratingDeviceOrientationNotifications];
        [device beginGeneratingDeviceOrientationNotifications];
        [device endGeneratingDeviceOrientationNotifications];
        CHECK(!device.generatesDeviceOrientationNotifications);
        [device endGeneratingDeviceOrientationNotifications];

        CHECK(UIDeviceOrientationUnknown == 0 && UIDeviceOrientationPortrait == 1 &&
              UIDeviceOrientationPortraitUpsideDown == 2 && UIDeviceOrientationLandscapeLeft == 3 &&
              UIDeviceOrientationLandscapeRight == 4 && UIDeviceOrientationFaceUp == 5 &&
              UIDeviceOrientationFaceDown == 6);
        void *notification = dlsym(library, "UIDeviceOrientationDidChangeNotification");
        CHECK(notification);
        CHECK([*(__unsafe_unretained NSString **)notification length] > 0);

        // Properties whose values the public docs do not fix are not implemented.
        CHECK(![device respondsToSelector:@selector(systemName)]);
        CHECK(![device respondsToSelector:@selector(userInterfaceIdiom)]);
        CHECK(![device respondsToSelector:@selector(identifierForVendor)]);
        CHECK(![device respondsToSelector:@selector(localizedModel)]);
        puts("PASS UIKit UIDevice values");
    }
    return 0;
}
