#import <UIKit/UISceneConfiguration.h>
#import <Foundation/NSException.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class configClass = NSClassFromString(@"UISceneConfiguration");
        CHECK(configClass != Nil);
        void *applicationSymbol = dlsym(library, "UIWindowSceneSessionRoleApplication");
        CHECK(applicationSymbol);
        NSString *application = *(__unsafe_unretained NSString **)applicationSymbol;
        CHECK([application isEqualToString:@"UIWindowSceneSessionRoleApplication"]);
        CHECK(dlsym(library, "UIWindowSceneSessionRoleExternalDisplayNonInteractive") == NULL);
        CHECK(dlsym(library, "UIWindowSceneSessionRoleAssistiveAccessApplication") == NULL);

        NSMutableString *name = [NSMutableString stringWithString:@"Default"];
        NSMutableString *role = [NSMutableString stringWithString:application];
        UISceneConfiguration *config = [configClass configurationWithName:name sessionRole:role];
        [name appendString:@"-changed"];
        [role appendString:@"-changed"];
        CHECK([config.name isEqualToString:@"Default"]);
        CHECK([config.role isEqualToString:application]);
        CHECK(config.sceneClass == Nil && config.delegateClass == Nil);

        config.sceneClass = [NSObject class];
        config.delegateClass = [NSString class];
        UISceneConfiguration *copy = [config copy];
        CHECK(copy != config && [copy isKindOfClass:configClass]);
        CHECK([copy.name isEqualToString:@"Default"] && [copy.role isEqualToString:application]);
        CHECK(copy.sceneClass == [NSObject class] && copy.delegateClass == [NSString class]);
        config.sceneClass = Nil;
        CHECK(copy.sceneClass == [NSObject class]);
        copy.delegateClass = Nil;
        CHECK(config.delegateClass == [NSString class]);

        UISceneConfiguration *unnamed = [configClass configurationWithName:nil sessionRole:@"custom-role"];
        CHECK(unnamed.name == nil && [unnamed.role isEqualToString:@"custom-role"]);

        UISceneSessionRole nilRole = nil;
        BOOL raised = NO;
        @try { (void)[[configClass alloc] initWithName:@"x" sessionRole:nilRole]; }
        @catch (NSException *e) { raised = [e.name isEqualToString:NSInvalidArgumentException]; }
        CHECK(raised);
        raised = NO;
        @try { (void)[[configClass alloc] init]; }
        @catch (NSException *e) { raised = [e.name isEqualToString:NSInvalidArgumentException]; }
        CHECK(raised);
        puts("PASS UIKit scene configuration values, role constants, copies and rejection");
    }
    return 0;
}
