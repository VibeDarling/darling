#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class controllerClass = NSClassFromString(@"UIAlertController");
        Class actionClass = NSClassFromString(@"UIAlertAction");
        CHECK(controllerClass != Nil && actionClass != Nil);

        // Selector spellings from the Apple Objective-C declarations.
        CHECK([controllerClass respondsToSelector:NSSelectorFromString(@"alertControllerWithTitle:message:preferredStyle:")]);
        CHECK([actionClass respondsToSelector:NSSelectorFromString(@"actionWithTitle:style:handler:")]);
        const char *selectors[] = { "title", "setTitle:", "message", "setMessage:", "preferredStyle", "addAction:", "actions" };
        for (unsigned i = 0; i < sizeof selectors / sizeof *selectors; i++)
            CHECK([controllerClass instancesRespondToSelector:NSSelectorFromString([NSString stringWithUTF8String:selectors[i]])]);
        CHECK([actionClass instancesRespondToSelector:NSSelectorFromString(@"title")]);
        CHECK([actionClass instancesRespondToSelector:NSSelectorFromString(@"style")]);

        __block int handlerCalls = 0;
        UIAlertAction *ok = [actionClass actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { handlerCalls++; }];
        UIAlertAction *cancel = [actionClass actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *remove = [actionClass actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:nil];
        CHECK([ok.title isEqualToString:@"OK"] && ok.style == UIAlertActionStyleDefault);
        CHECK([cancel.title isEqualToString:@"Cancel"] && cancel.style == UIAlertActionStyleCancel);
        CHECK(remove.style == UIAlertActionStyleDestructive);
        CHECK(handlerCalls == 0);   // nothing selects an action without presentation

        UIAlertController *alert = [controllerClass alertControllerWithTitle:@"Title" message:@"Body"
                                                              preferredStyle:UIAlertControllerStyleAlert];
        CHECK([alert isKindOfClass:controllerClass]);
        CHECK([controllerClass isSubclassOfClass:NSClassFromString(@"UIViewController")]);
        CHECK([alert.title isEqualToString:@"Title"] && [alert.message isEqualToString:@"Body"]);
        CHECK(alert.preferredStyle == UIAlertControllerStyleAlert);
        CHECK(alert.actions.count == 0);

        UIAlertController *sheet = [controllerClass alertControllerWithTitle:nil message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
        CHECK(sheet.preferredStyle == UIAlertControllerStyleActionSheet);
        CHECK(sheet.title == nil && sheet.message == nil);
        CHECK(UIAlertControllerStyleAlert != UIAlertControllerStyleActionSheet);

        // Actions keep the order in which they were added (documented).
        [alert addAction:ok]; [alert addAction:cancel]; [alert addAction:remove];
        NSArray *expected = @[ok, cancel, remove];
        CHECK([alert.actions isEqualToArray:expected]);
        CHECK(sheet.actions.count == 0);

        // title and message are settable and copied.
        NSMutableString *title = [NSMutableString stringWithString:@"A"];
        alert.title = title; [title appendString:@"B"];
        CHECK([alert.title isEqualToString:@"A"]);
        alert.message = nil; CHECK(alert.message == nil);

        // Rung 6: a nil action raises and leaves the list unchanged.
        BOOL raised = NO;
        @try { [alert addAction:nil]; }
        @catch (NSException *e) { raised = [e.name isEqualToString:NSInvalidArgumentException]; }
        CHECK(raised && alert.actions.count == 3);

        // A plain alloc/init controller keeps added actions and never returns a nil list (rung 6).
        UIAlertController *plain = [[controllerClass alloc] init];
        CHECK(plain.actions != nil && plain.actions.count == 0);
        [plain addAction:ok];
        CHECK([plain.actions isEqualToArray:@[ok]]);

        // The returned array is a snapshot (rung 6).
        NSArray *snapshot = alert.actions;
        [alert addAction:[actionClass actionWithTitle:@"More" style:UIAlertActionStyleDefault handler:nil]];
        CHECK(snapshot.count == 3 && alert.actions.count == 4);
        printf("PASS alert-controller\n");
    }
    return 0;
}
