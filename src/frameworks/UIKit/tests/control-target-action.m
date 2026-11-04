#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

@interface Recorder : NSObject {
    NSMutableArray *_log;
}
@property(nonatomic, strong) NSMutableArray *log;
- (void)tapped;
- (void)tappedWithSender:(id)sender;
- (void)changedWithSender:(id)sender forEvent:(id)event;
@end
@implementation Recorder
- (instancetype)init { self = [super init]; _log = [NSMutableArray array]; return self; }
- (void)tapped { [_log addObject:@"tapped"]; }
- (void)tappedWithSender:(id)sender { [_log addObject:[NSString stringWithFormat:@"sender:%d", sender != nil]]; }
- (void)changedWithSender:(id)sender forEvent:(id)event { [_log addObject:@"changed"]; }
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class controlClass = NSClassFromString(@"UIControl");
        CHECK(controlClass != Nil);
        CHECK([controlClass isSubclassOfClass:NSClassFromString(@"UIView")]);

        // Selector spellings from the Apple Objective-C declarations.
        const char *selectors[] = { "addTarget:action:forControlEvents:", "removeTarget:action:forControlEvents:",
            "sendActionsForControlEvents:", "allTargets", "allControlEvents", "state", "isEnabled", "setEnabled:",
            "isSelected", "setSelected:", "isHighlighted", "setHighlighted:" };
        for (unsigned i = 0; i < sizeof selectors / sizeof *selectors; i++)
            CHECK([controlClass instancesRespondToSelector:NSSelectorFromString([NSString stringWithUTF8String:selectors[i]])]);

        UIControl *control = [[controlClass alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        // Documented defaults: enabled YES, selected NO, highlighted NO; state Normal.
        CHECK(control.enabled && !control.selected && !control.highlighted);
        CHECK(control.state == UIControlStateNormal);
        CHECK(control.allControlEvents == 0 && control.allTargets.count == 0);

        // state is a bitmask: enabled NO adds Disabled and enabling removes it again.
        control.enabled = NO;
        CHECK(control.state == UIControlStateDisabled && ![control isEnabled]);
        control.enabled = YES;
        CHECK(control.state == UIControlStateNormal);
        control.highlighted = YES; control.selected = YES;
        CHECK(control.state == (UIControlStateHighlighted | UIControlStateSelected));
        control.enabled = NO;
        CHECK(control.state == (UIControlStateHighlighted | UIControlStateSelected | UIControlStateDisabled));
        control.enabled = YES; control.highlighted = NO; control.selected = NO;
        CHECK(control.state == UIControlStateNormal);

        Recorder *one = [[Recorder alloc] init];
        Recorder *two = [[Recorder alloc] init];
        [control addTarget:one action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        CHECK(control.allControlEvents == UIControlEventTouchUpInside);
        CHECK([control.allTargets isEqualToSet:[NSSet setWithObject:one]]);

        // An event that is not registered delivers nothing.
        [control sendActionsForControlEvents:UIControlEventTouchDown];
        CHECK(one.log.count == 0);
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        CHECK([one.log isEqualToArray:@[@"tapped"]]);

        // Repeating the same target and action is safe and does not call twice.
        [control addTarget:one action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        [one.log removeAllObjects];
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        CHECK(one.log.count == 1);

        // Several targets and several actions for one event; the mask may combine events.
        [control addTarget:two action:@selector(tappedWithSender:) forControlEvents:UIControlEventTouchUpInside | UIControlEventValueChanged];
        [control addTarget:one action:@selector(changedWithSender:forEvent:) forControlEvents:UIControlEventValueChanged];
        CHECK(control.allControlEvents == (UIControlEventTouchUpInside | UIControlEventValueChanged));
        CHECK(control.allTargets.count == 2);
        [one.log removeAllObjects];
        [control sendActionsForControlEvents:UIControlEventValueChanged];
        CHECK([one.log isEqualToArray:@[@"changed"]]);
        CHECK([two.log isEqualToArray:@[@"sender:1"]]);   // rung 6: the control is passed as sender
        [one.log removeAllObjects]; [two.log removeAllObjects];
        [control sendActionsForControlEvents:UIControlEventAllEvents];
        CHECK(one.log.count == 2 && two.log.count == 1);

        // removeTarget stops delivery of the given events to every action of that target.
        [control removeTarget:two action:NULL forControlEvents:UIControlEventValueChanged];
        [one.log removeAllObjects]; [two.log removeAllObjects];
        [control sendActionsForControlEvents:UIControlEventValueChanged];
        CHECK(two.log.count == 0 && one.log.count == 1);
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        CHECK(two.log.count == 1);

        // A nil target removes the events for all targets; an emptied target leaves allTargets.
        [control removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        CHECK(control.allControlEvents == 0 && control.allTargets.count == 0);
        [one.log removeAllObjects]; [two.log removeAllObjects];
        [control sendActionsForControlEvents:UIControlEventAllEvents];
        CHECK(one.log.count == 0 && two.log.count == 0);

        // The target is not retained (documented): the weak reference clears once the caller's
        // last reference goes, while the registration is still in place.
        __weak Recorder *weakTarget;
        @autoreleasepool {
            Recorder *temp = [[Recorder alloc] init];
            weakTarget = temp;
            [control addTarget:temp action:@selector(tapped) forControlEvents:UIControlEventTouchDown];
        }
        CHECK(weakTarget == nil);
        [control removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];

        // Registering zero events records nothing (rung 6).
        [control addTarget:one action:@selector(tapped) forControlEvents:0];
        CHECK(control.allTargets.count == 0 && control.allControlEvents == 0);

        // nil target (rung 6): the action is found along the responder chain, starting at the
        // control and continuing through its superview. A runtime subclass of UIView supplies
        // the action because the harness links no UIKit.
        static int chainCalls;
        Class holderClass = objc_allocateClassPair(NSClassFromString(@"UIView"), "ControlTestHolder", 0);
        class_addMethod(holderClass, @selector(tapped), imp_implementationWithBlock(^(__unsafe_unretained id self_) { chainCalls++; }), "v@:");
        objc_registerClassPair(holderClass);
        UIView *holder = [[holderClass alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        UIControl *child = [[controlClass alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [holder addSubview:child];
        [child addTarget:nil action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        CHECK([child.allTargets containsObject:[NSNull null]]);
        [child sendActionsForControlEvents:UIControlEventTouchUpInside];
        CHECK(chainCalls == 1);
        // Without a responder that handles the action nothing is called and nothing raises.
        [child removeFromSuperview];
        [child sendActionsForControlEvents:UIControlEventTouchUpInside];
        CHECK(chainCalls == 1);

        // A NULL action is rejected (rung 6).
        BOOL raised = NO;
        @try { [control addTarget:one action:NULL forControlEvents:UIControlEventTouchDown]; }
        @catch (NSException *e) { raised = [e.name isEqualToString:NSInvalidArgumentException]; }
        CHECK(raised);
        printf("PASS control\n");
    }
    return 0;
}
