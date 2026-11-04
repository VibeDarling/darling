#import <UIKit/UIKit.h>
#import <Foundation/NSString.h>
#include <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
static char nextKey, allowedSenderKey;
static unsigned invoked, validated;
static id observedSender;
static SEL observedAction;

static id nextResponder(__unsafe_unretained id self, SEL selector)
{
    return objc_getAssociatedObject(self, &nextKey);
}
static void syntheticAction(__unsafe_unretained id self, SEL selector, id sender) { invoked++; }
static BOOL accepts(__unsafe_unretained id self, SEL selector) { return YES; }
static BOOL refuses(__unsafe_unretained id self, SEL selector) { return NO; }
static BOOL validate(__unsafe_unretained id self, SEL selector, SEL action, id sender)
{
    validated++;
    observedAction = action;
    observedSender = sender;
    return sel_isEqual(action, @selector(syntheticAction:)) && sender == objc_getAssociatedObject(self, &allowedSenderKey);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class base = NSClassFromString(@"UIResponder");
        CHECK(base != Nil);
        UIResponder *plain = [base new];
        CHECK([plain nextResponder] == nil);
        CHECK(![plain canBecomeFirstResponder] && [plain canResignFirstResponder]);
        CHECK(![plain canPerformAction:@selector(syntheticAction:) withSender:nil]);
        Class chainClass = objc_allocateClassPair(base, "AuthoredChainResponder", 0);
        CHECK(chainClass);
        CHECK(class_addMethod(chainClass, @selector(nextResponder), (IMP)nextResponder, "@@:"));
        objc_registerClassPair(chainClass);
        Class handlerClass = objc_allocateClassPair(chainClass, "AuthoredActionResponder", 0);
        CHECK(handlerClass);
        CHECK(class_addMethod(handlerClass, @selector(syntheticAction:), (IMP)syntheticAction, "v@:@"));
        objc_registerClassPair(handlerClass);
        char boolMethod[16], validationMethod[16];
        snprintf(boolMethod, sizeof(boolMethod), "%s@:", @encode(BOOL));
        snprintf(validationMethod, sizeof(validationMethod), "%s@::@", @encode(BOOL));
        Class inheritedClass = objc_allocateClassPair(handlerClass, "AuthoredInheritedResponder", 0);
        CHECK(inheritedClass);
        CHECK(class_addMethod(inheritedClass, @selector(canBecomeFirstResponder), (IMP)accepts, boolMethod));
        CHECK(class_addMethod(inheritedClass, @selector(canResignFirstResponder), (IMP)refuses, boolMethod));
        objc_registerClassPair(inheritedClass);
        UIResponder *head = [chainClass new], *middle = [chainClass new], *handler = [inheritedClass new];
        objc_setAssociatedObject(head, &nextKey, middle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(middle, &nextKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CHECK([head nextResponder] == middle && [middle nextResponder] == handler);
        CHECK([handler nextResponder] == nil);
        CHECK([handler canBecomeFirstResponder] && ![handler canResignFirstResponder]);
        CHECK([handler canPerformAction:@selector(syntheticAction:) withSender:nil]);
        CHECK([head canPerformAction:@selector(syntheticAction:) withSender:nil]);
        CHECK(![head canPerformAction:@selector(absentAction:) withSender:nil]);
        CHECK(invoked == 0);

        Class validatorClass = objc_allocateClassPair(handlerClass, "AuthoredValidatedResponder", 0);
        CHECK(validatorClass);
        CHECK(class_addMethod(validatorClass, @selector(canPerformAction:withSender:), (IMP)validate, validationMethod));
        objc_registerClassPair(validatorClass);
        UIResponder *gate = [validatorClass new];
        id acceptedSender = [NSObject new], otherSender = [NSObject new];
        objc_setAssociatedObject(gate, &allowedSenderKey, acceptedSender, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(middle, &nextKey, gate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CHECK([head canPerformAction:@selector(syntheticAction:) withSender:acceptedSender]);
        CHECK(validated == 1 && observedSender == acceptedSender && sel_isEqual(observedAction, @selector(syntheticAction:)));
        CHECK(![head canPerformAction:@selector(syntheticAction:) withSender:otherSender]);
        CHECK(validated == 2 && observedSender == otherSender);
        CHECK(![head canPerformAction:@selector(absentAction:) withSender:acceptedSender]);
        CHECK(validated == 3 && sel_isEqual(observedAction, @selector(absentAction:)));
        CHECK(invoked == 0);
        objc_setAssociatedObject(middle, &nextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CHECK(![head canPerformAction:@selector(syntheticAction:) withSender:acceptedSender]);
        CHECK(validated == 3 && invoked == 0);
        puts("PASS UIResponder defaults, real subclass chain, inherited actions, sender-preserving validation");
    }
    return 0;
}
