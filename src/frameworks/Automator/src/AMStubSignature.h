#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <string.h>

// Signature for a message a stub class does not implement: an object return (nil once forwarded)
// and one object slot per selector argument, so NSInvocation accepts calls that pass arguments.
static inline NSMethodSignature *AMStubSignature(SEL sel)
{
    const char *name = sel_getName(sel);
    size_t args = 0;
    for (const char *p = name; *p; p++)
        if (*p == ':')
            args++;
    char types[args + 4];
    memcpy(types, "@@:", 3);
    memset(types + 3, '@', args);
    types[args + 3] = '\0';
    return [NSMethodSignature signatureWithObjCTypes: types];
}

// Workflow documents cannot be read or written: the workflow format is not implemented.
static inline NSError *AMWorkflowFormatUnsupportedError(void)
{
    return [NSError errorWithDomain: NSCocoaErrorDomain code: NSFeatureUnsupportedError
                           userInfo: @{ NSLocalizedDescriptionKey: @"Automator workflow documents are not supported yet." }];
}

// Implemented methods (and KVO's NSKVONotifying_ setters) keep their real signatures. The runtime lookup
// skips superclasses that are still generated stubs answering "v@:" for everything.
#define AM_STUB_FORWARDING \
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel \
{ \
    Method method = class_getInstanceMethod(object_getClass(self), sel); \
    return method ? [NSMethodSignature signatureWithObjCTypes: method_getTypeEncoding(method)] : AMStubSignature(sel); \
} \
\
- (void)forwardInvocation:(NSInvocation *)anInvocation \
{ \
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]); \
} \
\
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)sel \
{ \
    Method method = class_getClassMethod(self, sel); \
    return method ? [NSMethodSignature signatureWithObjCTypes: method_getTypeEncoding(method)] : AMStubSignature(sel); \
} \
\
+ (void)forwardInvocation:(NSInvocation *)anInvocation \
{ \
    NSLog(@"Stub called: +%@ in %@", NSStringFromSelector([anInvocation selector]), self); \
}

// A lazily created shared instance for the stub registries Automator.app reaches through class methods.
#define AM_STUB_SHARED_INSTANCE(name) \
+ (instancetype)name \
{ \
    static id shared; \
    static dispatch_once_t once; \
    dispatch_once(&once, ^{ \
        shared = [[self alloc] init]; \
    }); \
    return shared; \
}
