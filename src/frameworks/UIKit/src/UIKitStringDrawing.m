/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIKit.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSAttributedString.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>

/*
 * iOS apps draw strings with UIFonts and UIColors in the attributes; AppKit,
 * which draws them here, wants NSFonts and NSColors. UIKit wraps AppKit's
 * string drawing so either works, and adds iOS 7's methods that take a
 * drawing context.
 */

static id UIKitAppKitValue(id value)
{
	if ([value isKindOfClass:[UIFont class]])
		return [(UIFont *)value nsFont];
	if ([value isKindOfClass:[UIColor class]])
		return [(UIColor *)value nsColor];
	return value;
}

NSDictionary *UIKitAppKitAttributes(NSDictionary *attributes)
{
	__block NSMutableDictionary *converted = nil;
	[attributes enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		id appKit = UIKitAppKitValue(value);
		if (appKit == value)
			return;
		if (converted == nil)
			converted = [attributes mutableCopy];
		[converted setObject:appKit forKey:key];
	}];
	return converted ?: attributes;
}

NSAttributedString *UIKitAppKitAttributedString(NSAttributedString *string)
{
	__block NSMutableAttributedString *converted = nil;
	[string enumerateAttributesInRange:NSMakeRange(0, [string length]) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
		NSDictionary *appKit = UIKitAppKitAttributes(attributes);
		if (appKit == attributes)
			return;
		if (converted == nil)
			converted = [string mutableCopy];
		[converted setAttributes:appKit range:range];
	}];
	return converted ?: string;
}

static NSSize (*sSizeWithAttributes)(id, SEL, NSDictionary *);
static void (*sDrawAtPointWithAttributes)(id, SEL, NSPoint, NSDictionary *);
static void (*sDrawInRectWithAttributes)(id, SEL, NSRect, NSDictionary *);
static NSRect (*sBoundingRectWithAttributes)(id, SEL, NSSize, NSStringDrawingOptions, NSDictionary *);
static void (*sAttributedDrawAtPoint)(id, SEL, NSPoint);
static void (*sAttributedDrawInRect)(id, SEL, NSRect);
static void (*sAttributedDrawWithRect)(id, SEL, NSRect, NSStringDrawingOptions);
static NSSize (*sAttributedSize)(id, SEL);
static NSRect (*sAttributedBoundingRect)(id, SEL, NSSize, NSStringDrawingOptions);

static NSSize UIKitSizeWithAttributes(id self, SEL _cmd, NSDictionary *attributes)
{
	return sSizeWithAttributes(self, _cmd, UIKitAppKitAttributes(attributes));
}

static void UIKitDrawAtPointWithAttributes(id self, SEL _cmd, NSPoint point, NSDictionary *attributes)
{
	sDrawAtPointWithAttributes(self, _cmd, point, UIKitAppKitAttributes(attributes));
}

static void UIKitDrawInRectWithAttributes(id self, SEL _cmd, NSRect rect, NSDictionary *attributes)
{
	sDrawInRectWithAttributes(self, _cmd, rect, UIKitAppKitAttributes(attributes));
}

static NSRect UIKitBoundingRectWithAttributes(id self, SEL _cmd, NSSize size, NSStringDrawingOptions options, NSDictionary *attributes)
{
	return sBoundingRectWithAttributes(self, _cmd, size, options, UIKitAppKitAttributes(attributes));
}

static void UIKitAttributedDrawAtPoint(id self, SEL _cmd, NSPoint point)
{
	sAttributedDrawAtPoint(UIKitAppKitAttributedString(self), _cmd, point);
}

static void UIKitAttributedDrawInRect(id self, SEL _cmd, NSRect rect)
{
	sAttributedDrawInRect(UIKitAppKitAttributedString(self), _cmd, rect);
}

static void UIKitAttributedDrawWithRect(id self, SEL _cmd, NSRect rect, NSStringDrawingOptions options)
{
	sAttributedDrawWithRect(UIKitAppKitAttributedString(self), _cmd, rect, options);
}

static NSSize UIKitAttributedSize(id self, SEL _cmd)
{
	return sAttributedSize(UIKitAppKitAttributedString(self), _cmd);
}

static NSRect UIKitAttributedBoundingRect(id self, SEL _cmd, NSSize size, NSStringDrawingOptions options)
{
	return sAttributedBoundingRect(UIKitAppKitAttributedString(self), _cmd, size, options);
}

static void UIKitWrap(Class cls, SEL selector, IMP replacement, IMP *original)
{
	Method method = class_getInstanceMethod(cls, selector);
	if (method == NULL) {
		NSLog(@"UIKit: AppKit has no -[%@ %@] to wrap", cls, NSStringFromSelector(selector));
		return;
	}
	*original = method_setImplementation(method, replacement);
}

__attribute__((constructor))
static void UIKitWrapStringDrawing(void)
{
	Class string = [NSString class], attributed = [NSAttributedString class];
	UIKitWrap(string, @selector(sizeWithAttributes:), (IMP)UIKitSizeWithAttributes, (IMP *)&sSizeWithAttributes);
	UIKitWrap(string, @selector(drawAtPoint:withAttributes:), (IMP)UIKitDrawAtPointWithAttributes, (IMP *)&sDrawAtPointWithAttributes);
	UIKitWrap(string, @selector(drawInRect:withAttributes:), (IMP)UIKitDrawInRectWithAttributes, (IMP *)&sDrawInRectWithAttributes);
	UIKitWrap(string, @selector(boundingRectWithSize:options:attributes:), (IMP)UIKitBoundingRectWithAttributes, (IMP *)&sBoundingRectWithAttributes);
	UIKitWrap(attributed, @selector(drawAtPoint:), (IMP)UIKitAttributedDrawAtPoint, (IMP *)&sAttributedDrawAtPoint);
	UIKitWrap(attributed, @selector(drawInRect:), (IMP)UIKitAttributedDrawInRect, (IMP *)&sAttributedDrawInRect);
	UIKitWrap(attributed, @selector(drawWithRect:options:), (IMP)UIKitAttributedDrawWithRect, (IMP *)&sAttributedDrawWithRect);
	UIKitWrap(attributed, @selector(size), (IMP)UIKitAttributedSize, (IMP *)&sAttributedSize);
	UIKitWrap(attributed, @selector(boundingRectWithSize:options:), (IMP)UIKitAttributedBoundingRect, (IMP *)&sAttributedBoundingRect);
}

/* What a context asks for, string drawing does not do: it is ignored. */
@implementation NSString (UIKitStringDrawing)

- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context
{
	return NSRectToCGRect([self boundingRectWithSize:NSMakeSize(size.width, size.height) options:options attributes:attributes]);
}

- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context
{
	NSAttributedString *string = [[NSAttributedString alloc] initWithString:self attributes:attributes ?: @{}];
	[string drawWithRect:NSRectFromCGRect(rect) options:options];
}

@end

@implementation NSAttributedString (UIKitStringDrawing)

- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options context:(NSStringDrawingContext *)context
{
	return NSRectToCGRect([self boundingRectWithSize:NSMakeSize(size.width, size.height) options:options]);
}

@end
