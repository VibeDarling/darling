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

/*
 * Classes of newer iOS releases that apps reference but Darling's UIKit has no
 * behaviour for yet. They exist so the apps link and can allocate them; every
 * message answers nil or zero through the forwarding above.
 */
@interface UIBarAppearance : NSObject @end
@implementation UIBarAppearance
UIKIT_STUB_FORWARDING
@end
@interface UINavigationBarAppearance : UIBarAppearance @end
@implementation UINavigationBarAppearance @end
@interface UITabBarAppearance : UIBarAppearance @end
@implementation UITabBarAppearance @end
@interface UITabBarItemAppearance : NSObject @end
@implementation UITabBarItemAppearance
UIKIT_STUB_FORWARDING
@end
@interface UIImageConfiguration : NSObject @end
@implementation UIImageConfiguration
UIKIT_STUB_FORWARDING
@end
@interface UIImageSymbolConfiguration : UIImageConfiguration @end
@implementation UIImageSymbolConfiguration @end
@interface UIHoverGestureRecognizer : UIGestureRecognizer @end
@implementation UIHoverGestureRecognizer @end
@interface UIPress : NSObject @end
@implementation UIPress
UIKIT_STUB_FORWARDING
@end
@interface UIPointerStyle : NSObject @end
@implementation UIPointerStyle
UIKIT_STUB_FORWARDING
@end
@interface UIContextualAction : NSObject @end
@implementation UIContextualAction
UIKIT_STUB_FORWARDING
@end
@interface UISwipeActionsConfiguration : NSObject @end
@implementation UISwipeActionsConfiguration
UIKIT_STUB_FORWARDING
@end
@interface UISheetPresentationControllerDetent : NSObject @end
@implementation UISheetPresentationControllerDetent
UIKIT_STUB_FORWARDING
@end
@interface UITab : NSObject @end
@implementation UITab
UIKIT_STUB_FORWARDING
@end
@interface UITabAccessory : NSObject @end
@implementation UITabAccessory
UIKIT_STUB_FORWARDING
@end
@interface UIWindowSceneGeometryPreferences : NSObject @end
@implementation UIWindowSceneGeometryPreferences
UIKIT_STUB_FORWARDING
@end
@interface UIWindowSceneGeometryPreferencesIOS : UIWindowSceneGeometryPreferences @end
@implementation UIWindowSceneGeometryPreferencesIOS @end
@interface UIDocumentPickerViewController : UIViewController @end
@implementation UIDocumentPickerViewController @end

/* UIGraphicsImageRenderer draws through the UIGraphics image context. */
@interface UIGraphicsRendererFormat : NSObject
@property (nonatomic) CGFloat scale;
@property (nonatomic) BOOL opaque;
@end
@implementation UIGraphicsRendererFormat
UIKIT_STUB_FORWARDING
+ (instancetype)defaultFormat { return [[self alloc] init]; }
+ (instancetype)preferredFormat { return [self defaultFormat]; }
- (instancetype)init
{
	if ((self = [super init]))
		_scale = [[UIScreen mainScreen] scale];
	return self;
}
@end
@interface UIGraphicsImageRendererFormat : UIGraphicsRendererFormat @end
@implementation UIGraphicsImageRendererFormat @end

@interface UIGraphicsImageRendererContext : NSObject
@end
@implementation UIGraphicsImageRendererContext
UIKIT_STUB_FORWARDING
- (CGContextRef)CGContext { return UIGraphicsGetCurrentContext(); }
- (UIImage *)currentImage { return UIGraphicsGetImageFromCurrentImageContext(); }
- (void)fillRect:(CGRect)rect { UIRectFill(rect); }
- (void)strokeRect:(CGRect)rect { UIRectFrame(rect); }
@end

@interface UIGraphicsImageRenderer : NSObject {
	CGSize _size;
	UIGraphicsImageRendererFormat *_format;
}
@end
@implementation UIGraphicsImageRenderer
UIKIT_STUB_FORWARDING
- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format
{
	if ((self = [super init])) {
		_size = size;
		_format = format ?: [UIGraphicsImageRendererFormat defaultFormat];
	}
	return self;
}
- (instancetype)initWithSize:(CGSize)size { return [self initWithSize:size format:nil]; }
- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsImageRendererFormat *)format { return [self initWithSize:bounds.size format:format]; }
- (instancetype)initWithBounds:(CGRect)bounds { return [self initWithSize:bounds.size format:nil]; }
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *))actions
{
	UIGraphicsBeginImageContextWithOptions(_size, [_format opaque], [_format scale]);
	UIGraphicsImageRendererContext *context = [[UIGraphicsImageRendererContext alloc] init];
	if (actions)
		actions(context);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}
- (NSData *)PNGDataWithActions:(void (^)(UIGraphicsImageRendererContext *))actions
{
	return UIImagePNGRepresentation([self imageWithActions:actions]);
}
- (NSData *)JPEGDataWithCompressionQuality:(CGFloat)quality actions:(void (^)(UIGraphicsImageRendererContext *))actions
{
	return UIImageJPEGRepresentation([self imageWithActions:actions], quality);
}
@end
