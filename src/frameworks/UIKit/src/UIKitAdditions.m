/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * The smaller pieces of UIKit: string drawing, more colors and fonts,
 * UIDevice, the keyboard notification names, and functions older apps
 * import (UISetColor, _UIImageWithName).
 */

#import <UIKit/UIKit.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIStringDrawing.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSMutableParagraphStyle.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSImage.h>
#import "UIKitPrivate.h"

NSString *const UIKeyboardWillShowNotification = @"UIKeyboardWillShowNotification";
NSString *const UIKeyboardDidShowNotification = @"UIKeyboardDidShowNotification";
NSString *const UIKeyboardWillHideNotification = @"UIKeyboardWillHideNotification";
NSString *const UIKeyboardDidHideNotification = @"UIKeyboardDidHideNotification";
NSString *const UIKeyboardWillChangeFrameNotification = @"UIKeyboardWillChangeFrameNotification";
NSString *const UIKeyboardFrameBeginUserInfoKey = @"UIKeyboardFrameBeginUserInfoKey";
NSString *const UIKeyboardFrameEndUserInfoKey = @"UIKeyboardFrameEndUserInfoKey";
NSString *const UIKeyboardAnimationDurationUserInfoKey = @"UIKeyboardAnimationDurationUserInfoKey";
NSString *const UIKeyboardAnimationCurveUserInfoKey = @"UIKeyboardAnimationCurveUserInfoKey";
NSString *const UIKeyboardBoundsUserInfoKey = @"UIKeyboardBoundsUserInfoKey";
NSString *const UIKeyboardCenterBeginUserInfoKey = @"UIKeyboardCenterBeginUserInfoKey";
NSString *const UIKeyboardCenterEndUserInfoKey = @"UIKeyboardCenterEndUserInfoKey";
NSString *const UIApplicationDidReceiveMemoryWarningNotification = @"UIApplicationDidReceiveMemoryWarningNotification";
NSString *const UIApplicationLaunchOptionsURLKey = @"UIApplicationLaunchOptionsURLKey";
NSString *const UIApplicationLaunchOptionsSourceApplicationKey = @"UIApplicationLaunchOptionsSourceApplicationKey";

const CGFloat UIScrollViewDecelerationRateNormal = 0.998;
const CGFloat UIScrollViewDecelerationRateFast = 0.99;
const float UIWebViewGrowsAndShrinksToFitHeight = 0;
const float UIWebViewScalesToFitScale = -1;

/* The color the last -set, -setFill or UISetColor chose: UIKit's string
 * drawing uses the context's fill color, which AppKit's does not. */
static __thread CGFloat sDrawColor[4] = { 0, 0, 0, 1 };

void UIKitSetDrawColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
	sDrawColor[0] = red;
	sDrawColor[1] = green;
	sDrawColor[2] = blue;
	sDrawColor[3] = alpha;
}

static NSColor *UIKitDrawColor(void)
{
	return [NSColor colorWithCalibratedRed:sDrawColor[0] green:sDrawColor[1] blue:sDrawColor[2] alpha:sDrawColor[3]];
}

void UISetColor(CGColorRef color)
{
	if (color == NULL)
		return;
	const CGFloat *components = CGColorGetComponents(color);
	size_t count = CGColorGetNumberOfComponents(color);
	if (count >= 4)
		UIKitSetDrawColor(components[0], components[1], components[2], components[3]);
	else if (count == 2)
		UIKitSetDrawColor(components[0], components[0], components[0], components[1]);
	[UIKitDrawColor() set];
}

UIImage *_UIImageWithName(NSString *name)
{
	return [UIImage imageNamed:name];
}

void UIRectFill(CGRect rect)
{
	NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height));
}

void UIRectFrame(CGRect rect)
{
	NSFrameRect(NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height));
}

#pragma mark - String drawing

static NSDictionary *UIKitStringAttributes(UIFont *font, NSLineBreakMode lineBreakMode, NSTextAlignment alignment)
{
	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraph setLineBreakMode:lineBreakMode];
	[paragraph setAlignment:alignment];
	return @{
		NSFontAttributeName: [font ?: [UIFont systemFontOfSize:17] nsFont],
		NSForegroundColorAttributeName: UIKitDrawColor(),
		NSParagraphStyleAttributeName: paragraph,
	};
}

/* The string cut to fit width, with an ellipsis where the mode puts one. */
static NSString *UIKitTruncate(NSString *string, CGFloat width, NSDictionary *attributes, NSLineBreakMode mode)
{
	if (width <= 0 || [string sizeWithAttributes:attributes].width <= width)
		return string;
	if (mode == NSLineBreakByClipping || mode == NSLineBreakByWordWrapping || mode == NSLineBreakByCharWrapping)
		return string;
	NSString *ellipsis = @"…";
	NSUInteger low = 0, high = [string length];
	while (low < high) {
		NSUInteger mid = (low + high + 1) / 2;
		NSString *candidate;
		if (mode == NSLineBreakByTruncatingHead)
			candidate = [ellipsis stringByAppendingString:[string substringFromIndex:[string length] - mid]];
		else if (mode == NSLineBreakByTruncatingMiddle)
			candidate = [NSString stringWithFormat:@"%@%@%@", [string substringToIndex:mid / 2], ellipsis, [string substringFromIndex:[string length] - (mid - mid / 2)]];
		else
			candidate = [[string substringToIndex:mid] stringByAppendingString:ellipsis];
		if ([candidate sizeWithAttributes:attributes].width <= width)
			low = mid;
		else
			high = mid - 1;
	}
	if (mode == NSLineBreakByTruncatingHead)
		return [ellipsis stringByAppendingString:[string substringFromIndex:[string length] - low]];
	if (mode == NSLineBreakByTruncatingMiddle)
		return [NSString stringWithFormat:@"%@%@%@", [string substringToIndex:low / 2], ellipsis, [string substringFromIndex:[string length] - (low - low / 2)]];
	return [[string substringToIndex:low] stringByAppendingString:ellipsis];
}

@implementation NSString (UIStringDrawing)

- (CGSize)sizeWithFont:(UIFont *)font
{
	NSSize size = [self sizeWithAttributes:UIKitStringAttributes(font, NSLineBreakByClipping, NSTextAlignmentLeft)];
	return CGSizeMake(ceil(size.width), ceil(size.height));
}

- (CGSize)sizeWithFont:(UIFont *)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode
{
	NSDictionary *attributes = UIKitStringAttributes(font, lineBreakMode, NSTextAlignmentLeft);
	NSSize size = [UIKitTruncate(self, width, attributes, lineBreakMode) sizeWithAttributes:attributes];
	return CGSizeMake(MIN(ceil(size.width), width), ceil(size.height));
}

- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
{
	NSDictionary *attributes = UIKitStringAttributes(font, lineBreakMode, NSTextAlignmentLeft);
	NSRect rect = [self boundingRectWithSize:NSMakeSize(size.width, size.height)
	                                 options:NSStringDrawingUsesLineFragmentOrigin
	                              attributes:attributes];
	return CGSizeMake(MIN(ceil(rect.size.width), size.width), MIN(ceil(rect.size.height), size.height));
}

- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size
{
	return [self sizeWithFont:font constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
}

- (CGSize)sizeWithFont:(UIFont *)font minFontSize:(CGFloat)minFontSize actualFontSize:(CGFloat *)actualFontSize forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode
{
	if (actualFontSize != NULL)
		*actualFontSize = [font pointSize];
	return [self sizeWithFont:font forWidth:width lineBreakMode:lineBreakMode];
}

- (CGSize)drawAtPoint:(CGPoint)point withFont:(UIFont *)font
{
	NSDictionary *attributes = UIKitStringAttributes(font, NSLineBreakByClipping, NSTextAlignmentLeft);
	[self drawAtPoint:NSMakePoint(point.x, point.y) withAttributes:attributes];
	NSSize size = [self sizeWithAttributes:attributes];
	return CGSizeMake(size.width, size.height);
}

- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
{
	NSDictionary *attributes = UIKitStringAttributes(font, lineBreakMode, NSTextAlignmentLeft);
	NSString *string = UIKitTruncate(self, width, attributes, lineBreakMode);
	[string drawAtPoint:NSMakePoint(point.x, point.y) withAttributes:attributes];
	NSSize size = [string sizeWithAttributes:attributes];
	return CGSizeMake(MIN(size.width, width), size.height);
}

- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font fontSize:(CGFloat)fontSize lineBreakMode:(NSLineBreakMode)lineBreakMode baselineAdjustment:(NSInteger)baselineAdjustment
{
	return [self drawAtPoint:point forWidth:width withFont:[UIFont fontWithName:[font fontName] size:fontSize] lineBreakMode:lineBreakMode];
}

- (CGSize)drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font minFontSize:(CGFloat)minFontSize actualFontSize:(CGFloat *)actualFontSize lineBreakMode:(NSLineBreakMode)lineBreakMode baselineAdjustment:(NSInteger)baselineAdjustment
{
	if (actualFontSize != NULL)
		*actualFontSize = [font pointSize];
	return [self drawAtPoint:point forWidth:width withFont:font lineBreakMode:lineBreakMode];
}

- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment
{
	NSDictionary *attributes = UIKitStringAttributes(font, lineBreakMode, alignment);
	NSString *string = self;
	NSSize single = [self sizeWithAttributes:attributes];
	/* One line that does not fit: truncate it rather than wrap. */
	if (single.height >= rect.size.height - 1 || lineBreakMode >= NSLineBreakByTruncatingHead)
		string = UIKitTruncate(self, rect.size.width, attributes, lineBreakMode);
	[string drawInRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height) withAttributes:attributes];
	return [string sizeWithFont:font constrainedToSize:rect.size lineBreakMode:lineBreakMode];
}

- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode
{
	return [self drawInRect:rect withFont:font lineBreakMode:lineBreakMode alignment:NSTextAlignmentLeft];
}

- (CGSize)drawInRect:(CGRect)rect withFont:(UIFont *)font
{
	return [self drawInRect:rect withFont:font lineBreakMode:NSLineBreakByWordWrapping alignment:NSTextAlignmentLeft];
}

@end

#pragma mark - UIScreen

@implementation UIScreen (DarlingAdditions)

/* The screen less the status bar, which UIWindow draws along the top. */
- (CGRect)applicationFrame
{
	CGRect bounds = [self bounds];
	return CGRectMake(0, UIKitStatusBarHeight, bounds.size.width, bounds.size.height - UIKitStatusBarHeight);
}

- (CGFloat)brightness
{
	return 1;
}

- (void)setBrightness:(CGFloat)brightness
{
}

@end

#pragma mark - UIDevice

NSString *const UIDeviceOrientationDidChangeNotification = @"UIDeviceOrientationDidChangeNotification";

@implementation UIDevice

+ (UIDevice *)currentDevice
{
	static UIDevice *device;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		device = [[UIDevice alloc] init];
	});
	return device;
}

- (NSString *)name
{
	return [[NSProcessInfo processInfo] hostName] ?: @"Darling";
}

- (NSString *)model
{
	return @"iPhone";
}

- (NSString *)localizedModel
{
	return @"iPhone";
}

- (NSString *)systemName
{
	return @"iOS";
}

/* The release Darling's UIKit and WebKit (WebKit 605/608) correspond to. */
- (NSString *)systemVersion
{
	return @"13.7";
}

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
	return UIUserInterfaceIdiomPhone;
}

- (UIDeviceOrientation)orientation
{
	return UIDeviceOrientationPortrait;
}

- (BOOL)isGeneratingDeviceOrientationNotifications
{
	return NO;
}

- (void)beginGeneratingDeviceOrientationNotifications
{
}

- (void)endGeneratingDeviceOrientationNotifications
{
}

- (BOOL)isMultitaskingSupported
{
	return YES;
}

- (float)batteryLevel
{
	return -1;
}

- (UIDeviceBatteryState)batteryState
{
	return UIDeviceBatteryStateUnknown;
}

- (BOOL)isBatteryMonitoringEnabled
{
	return NO;
}

- (void)setBatteryMonitoringEnabled:(BOOL)enabled
{
}

- (BOOL)isProximityMonitoringEnabled
{
	return NO;
}

- (void)setProximityMonitoringEnabled:(BOOL)enabled
{
}

/* A stable per-machine identifier, the shape of a UDID (40 hex digits). */
- (NSString *)uniqueIdentifier
{
	static NSString *identifier;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSString *seed = [NSString stringWithContentsOfFile:@"/etc/machine-id" encoding:NSUTF8StringEncoding error:NULL];
		if (seed == nil)
			seed = [NSString stringWithContentsOfFile:@"/Volumes/SystemRoot/etc/machine-id" encoding:NSUTF8StringEncoding error:NULL];
		if (seed == nil)
			seed = [self name];
		NSData *data = [seed dataUsingEncoding:NSUTF8StringEncoding];
		const unsigned char *bytes = [data bytes];
		NSMutableString *hex = [NSMutableString string];
		unsigned hash = 2166136261u;
		for (int i = 0; i < 20; i++) {
			for (NSUInteger j = 0; j < [data length]; j++)
				hash = (hash ^ bytes[j]) * 16777619u;
			hash = (hash ^ (unsigned)i) * 16777619u;
			[hex appendFormat:@"%02x", hash & 0xff];
		}
		identifier = [hex copy];
	});
	return identifier;
}

- (NSUUID *)identifierForVendor
{
	return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-4000-8000-000000000000"];
}

- (void)playInputClick
{
}

@end

#pragma mark - UIPasteboard

@implementation UIPasteboard {
	NSString *_string;
}

+ (UIPasteboard *)generalPasteboard
{
	static UIPasteboard *pasteboard;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		pasteboard = [[UIPasteboard alloc] init];
	});
	return pasteboard;
}

- (NSString *)string
{
	return _string;
}

- (void)setString:(NSString *)string
{
	_string = [string copy];
}

- (NSURL *)URL
{
	return _string != nil ? [NSURL URLWithString:_string] : nil;
}

- (void)setURL:(NSURL *)URL
{
	_string = [URL absoluteString];
}

- (void)setValue:(id)value forPasteboardType:(NSString *)type
{
	if ([value isKindOfClass:[NSString class]])
		_string = [value copy];
}

@end
