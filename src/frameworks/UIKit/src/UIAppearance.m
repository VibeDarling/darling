/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIAppearance.h>
#import <UIKit/UIView.h>
#import <UIKit/UIBarButtonItem.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <stdarg.h>

/*
 * An appearance proxy records the setters sent to it. A view gets them, from
 * its most general class's proxies to its own, when it first goes on screen
 * (as on iOS); a bar item when it is made. Proxies for containers apply only
 * to views inside views of those classes, nearest container first.
 */

@interface UIKitAppearanceProxy : NSObject {
@public
	Class _targetClass;
	NSArray<Class> *_containers;
	NSMutableArray<NSInvocation *> *_invocations;
}
@end

/* Proxies by class name, each list in the order they were asked for. */
static NSMutableDictionary<NSString *, NSMutableArray<UIKitAppearanceProxy *> *> *sProxies;

@implementation UIKitAppearanceProxy

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	NSMethodSignature *signature = [_targetClass instanceMethodSignatureForSelector:selector];
	if (signature != nil)
		return signature;
	/* Not one this class has: swallowed, so only the argument count matters. */
	NSMutableString *types = [NSMutableString stringWithString:@"v@:"];
	for (const char *c = sel_getName(selector); *c != '\0'; c++)
		if (*c == ':')
			[types appendString:@"@"];
	return [NSMethodSignature signatureWithObjCTypes:[types UTF8String]];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	if (![_targetClass instancesRespondToSelector:[invocation selector]])
		return;
	/* Getters answer nothing; setters are kept to replay. */
	if ([[invocation methodSignature] methodReturnLength] > 0) {
		char zero[64] = { 0 };
		if ([[invocation methodSignature] methodReturnLength] <= sizeof(zero))
			[invocation setReturnValue:zero];
		return;
	}
	[invocation setTarget:nil];
	[invocation retainArguments];
	@synchronized (sProxies) {
		[_invocations addObject:invocation];
	}
}

@end

static UIKitAppearanceProxy *UIKitAppearanceFor(Class cls, NSArray *containers)
{
	@synchronized ([UIKitAppearanceProxy class]) {
		if (sProxies == nil)
			sProxies = [NSMutableDictionary dictionary];
		NSString *key = NSStringFromClass(cls);
		NSMutableArray *proxies = [sProxies objectForKey:key];
		if (proxies == nil) {
			proxies = [NSMutableArray array];
			[sProxies setObject:proxies forKey:key];
		}
		for (UIKitAppearanceProxy *proxy in proxies)
			if (proxy->_targetClass == cls && [proxy->_containers isEqualToArray:containers])
				return proxy;
		UIKitAppearanceProxy *proxy = [[UIKitAppearanceProxy alloc] init];
		proxy->_targetClass = cls;
		proxy->_containers = [containers copy];
		proxy->_invocations = [NSMutableArray array];
		[proxies addObject:proxy];
		return proxy;
	}
}

static NSArray *UIKitContainersFromList(Class first, va_list list)
{
	NSMutableArray *containers = [NSMutableArray array];
	for (Class cls = first; cls != Nil; cls = va_arg(list, Class))
		[containers addObject:cls];
	return containers;
}

/* Whether view sits inside the containers, the first nearest. */
static BOOL UIKitInContainers(NSView *view, NSArray<Class> *containers)
{
	NSView *ancestor = [view superview];
	for (Class container in containers) {
		while (ancestor != nil && ![ancestor isKindOfClass:container])
			ancestor = [ancestor superview];
		if (ancestor == nil)
			return NO;
		ancestor = [ancestor superview];
	}
	return YES;
}

void UIKitApplyAppearance(id object)
{
	NSMutableArray<Class> *lineage = [NSMutableArray array];
	for (Class cls = [object class]; cls != Nil; cls = [cls superclass])
		[lineage insertObject:cls atIndex:0];
	NSMutableArray<NSInvocation *> *replay = [NSMutableArray array];
	@synchronized ([UIKitAppearanceProxy class]) {
		for (Class cls in lineage) {
			NSArray *proxies = [sProxies objectForKey:NSStringFromClass(cls)];
			/* Unconditional ones first, so contained ones win. */
			for (int pass = 0; pass < 2; pass++)
				for (UIKitAppearanceProxy *proxy in proxies) {
					BOOL contained = [proxy->_containers count] > 0;
					if (contained != (pass == 1))
						continue;
					if (contained && (![object isKindOfClass:[NSView class]] || !UIKitInContainers(object, proxy->_containers)))
						continue;
					@synchronized (sProxies) {
						[replay addObjectsFromArray:proxy->_invocations];
					}
				}
		}
	}
	for (NSInvocation *invocation in replay) {
		if (![object respondsToSelector:[invocation selector]])
			continue;
		[invocation invokeWithTarget:object];
	}
}

#define UIKIT_APPEARANCE_METHODS \
+ (instancetype)appearance \
{ \
	return (id)UIKitAppearanceFor(self, @[]); \
} \
\
+ (instancetype)appearanceWhenContainedIn:(Class)containerClass, ... \
{ \
	va_list list; \
	va_start(list, containerClass); \
	NSArray *containers = UIKitContainersFromList(containerClass, list); \
	va_end(list); \
	return (id)UIKitAppearanceFor(self, containers); \
} \
\
+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray *)containerTypes \
{ \
	return (id)UIKitAppearanceFor(self, containerTypes ?: @[]); \
} \
\
+ (instancetype)appearanceForTraitCollection:(id)trait \
{ \
	return [self appearance]; \
} \
\
+ (instancetype)appearanceForTraitCollection:(id)trait whenContainedIn:(Class)containerClass, ... \
{ \
	va_list list; \
	va_start(list, containerClass); \
	NSArray *containers = UIKitContainersFromList(containerClass, list); \
	va_end(list); \
	return (id)UIKitAppearanceFor(self, containers); \
} \
\
+ (instancetype)appearanceForTraitCollection:(id)trait whenContainedInInstancesOfClasses:(NSArray *)containerTypes \
{ \
	return [self appearanceWhenContainedInInstancesOfClasses:containerTypes]; \
}

@implementation UIView (UIAppearance)
UIKIT_APPEARANCE_METHODS
@end

@implementation UIBarItem (UIAppearance)
UIKIT_APPEARANCE_METHODS
@end
