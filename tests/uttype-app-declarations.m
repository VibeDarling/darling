#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <stdio.h>
#include <stdlib.h>

NSString *const UTTagClassFilenameExtension = @"public.filename-extension";
NSString *const UTTagClassMIMEType = @"public.mime-type";

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); return 1; } } while (0)
int main(void)
{
    @autoreleasepool {
        UTType *child = [UTType typeWithIdentifier:@"org.darling.probe.child"];
        CHECK(child != nil && child.declared);
        CHECK([child.preferredFilenameExtension isEqual:@"darlingprobe"]);
        CHECK([child.preferredMIMEType isEqual:@"application/x-darling-probe"]);
        CHECK([child.localizedDescription isEqual:@"Probe document"]);
        CHECK([child conformsToType:UTTypeData]);
        CHECK([child conformsToType:[UTType typeWithIdentifier:@"org.darling.probe.parent"]]);
        CHECK([[UTType typeWithFilenameExtension:@"DARLINGPROBE"] isEqual:child]);
        CHECK([[UTType typeWithFilenameExtension:@"txt"] isEqual:child]);
        CHECK([[UTType typeWithMIMEType:@"application/x-darling-probe"] isEqual:child]);
        CHECK([UTType typeWithIdentifier:@"org.darling.probe.imported"] != nil);
        CHECK([UTType typeWithIdentifier:@"invalid identifier"] == nil);
        CHECK([UTType typeWithIdentifier:@"public.data"] == UTTypeData);
        CHECK([UTTypePNG conformsToType:UTTypeImage]);
        UTType *dynamic = [UTType typeWithFilenameExtension:@"darling-unregistered-extension"];
        CHECK(dynamic.dynamic);
        CHECK([[UTType typeWithIdentifier:dynamic.identifier] isEqual:dynamic]);
        puts("PASS: merged UTType app declarations and built-in registry");
    }
    return 0;
}
