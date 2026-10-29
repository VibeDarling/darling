/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIKit.h>
#import "UIKitPrivate.h"
#include <stdlib.h>
#include <string.h>

/*
 * UIKit here is far from all of iOS's. A message one of the common UIKit
 * classes does not implement is logged (once) and answers nil or zero,
 * instead of raising, so an app runs on to the next thing it needs and one
 * run shows everything it is missing. DARLING_UIKIT_STRICT=1 raises as iOS
 * would. respondsToSelector: still tells the truth.
 */

static BOOL UIKitStrict(void)
{
	static int strict = -1;
	if (strict < 0) {
		const char *value = getenv("DARLING_UIKIT_STRICT");
		strict = value != NULL && strcmp(value, "0") != 0;
	}
	return strict;
}

/* Every argument an object: only how many there are matters, and what
 * comes back is zero. */
static NSMethodSignature *UIKitStubSignature(SEL selector)
{
	if (UIKitStrict())
		return nil;
	const char *name = sel_getName(selector);
	char types[64] = "@@:";
	size_t length = strlen(types);
	for (const char *c = name; *c != '\0' && length < sizeof(types) - 1; c++)
		if (*c == ':')
			types[length++] = '@';
	types[length] = '\0';
	return [NSMethodSignature signatureWithObjCTypes:types];
}

static void UIKitStubInvoke(id receiver, NSInvocation *invocation, BOOL classMethod)
{
	static NSMutableSet *logged;
	Class cls = classMethod ? (Class)receiver : [receiver class];
	NSString *key = [NSString stringWithFormat:@"%c[%@ %@]", classMethod ? '+' : '-', NSStringFromClass(cls), NSStringFromSelector([invocation selector])];
	@synchronized ([NSMethodSignature class]) {
		if (logged == nil)
			logged = [NSMutableSet set];
		if (![logged containsObject:key]) {
			[logged addObject:key];
			NSLog(@"UIKit: unimplemented %@, answering nil", key);
		}
	}
	char zero[64] = { 0 };
	if ([[invocation methodSignature] methodReturnLength] <= sizeof(zero))
		[invocation setReturnValue:zero];
}

#define UIKIT_STUB_FORWARDING \
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector \
{ \
	return [super methodSignatureForSelector:selector] ?: UIKitStubSignature(selector); \
} \
\
- (void)forwardInvocation:(NSInvocation *)invocation \
{ \
	if ([self methodSignatureForSelector:[invocation selector]] == nil) \
		[super forwardInvocation:invocation]; \
	else \
		UIKitStubInvoke(self, invocation, NO); \
} \
\
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)selector \
{ \
	return [super methodSignatureForSelector:selector] ?: UIKitStubSignature(selector); \
} \
\
+ (void)forwardInvocation:(NSInvocation *)invocation \
{ \
	UIKitStubInvoke(self, invocation, YES); \
}

@implementation UIView (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIResponder (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIScreen (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIDevice (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIColor (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIFont (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIImage (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIBarItem (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UINavigationItem (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIGestureRecognizer (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UICollectionViewLayout (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UICollectionViewLayoutAttributes (UIKitStubs)
UIKIT_STUB_FORWARDING
@end

@implementation UIFontDescriptor (UIKitStubs)
UIKIT_STUB_FORWARDING
@end
