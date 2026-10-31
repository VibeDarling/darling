/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

/* SwiftUI's UIKit backend: the views the Swift side lays out are plain
   UIViews, UILabels and a tap control. The Swift side does all layout and
   only ever sets frames; see Sources/Render.swift. */

#import <UIKit/UIKit.h>
#import <AppKit/NSStringDrawing.h>
#include <dispatch/dispatch.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "SwiftUIBackend.h"

static SUICallback sLaunched;
static void *sLaunchedContext;

void SUILog(const char *message)
{
	fprintf(stderr, "SwiftUI: %s\n", message);
}

int SUIDebugEnabled(void)
{
	static int enabled = -1;
	if (enabled < 0)
		enabled = getenv("DARLING_SWIFTUI_DEBUG") != NULL;
	return enabled;
}

#pragma mark - Application

@interface SUIAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SUIAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	if (sLaunched != NULL)
		sLaunched(sLaunchedContext);
	return YES;
}

@end

int SUIApplicationMain(int argc, char **argv, SUICallback launched, void *context)
{
	sLaunched = launched;
	sLaunchedContext = context;
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([SUIAppDelegate class]));
	}
}

void SUIRunOnMainQueue(SUICallback callback, void *context)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		callback(context);
	});
}

#pragma mark - Host

/* The root of the SwiftUI view tree: it reports its safe area to the Swift
   side, which lays the tree out in it. */
@interface SUIHostView : UIView {
@public
	SUILayoutCallback _layout;
	void *_context;
	CGRect _lastSafeRect;
}
@end

@implementation SUIHostView

- (void)safeAreaInsetsDidChange
{
	[self setNeedsLayout];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = [self bounds];
	UIEdgeInsets insets = [self safeAreaInsets];
	CGRect safe = CGRectMake(insets.left, insets.top,
		MAX(0, bounds.size.width - insets.left - insets.right),
		MAX(0, bounds.size.height - insets.top - insets.bottom));
	_lastSafeRect = safe;
	if (_layout != NULL)
		_layout(_context, safe.origin.x, safe.origin.y, safe.size.width, safe.size.height);
}

@end

@interface SUIHostController : UIViewController
@property (nonatomic, strong) SUIHostView *host;
@end

@implementation SUIHostController

- (void)loadView
{
	[self setView:self.host];
}

@end

/* Kept for the life of the app, like the window UIKit apps keep in their
   delegate. */
static UIWindow *sWindow;

SUIViewRef SUIHostCreate(SUILayoutCallback layout, void *context)
{
	CGRect screen = [[UIScreen mainScreen] bounds];
	SUIHostView *host = [[SUIHostView alloc] initWithFrame:screen];
	host->_layout = layout;
	host->_context = context;
	[host setBackgroundColor:[UIColor whiteColor]];
	SUIHostController *controller = [[SUIHostController alloc] init];
	controller.host = host;

	sWindow = [[UIWindow alloc] initWithFrame:screen];
	[sWindow setBackgroundColor:[UIColor whiteColor]];
	sWindow.rootViewController = controller;
	[sWindow makeKeyAndVisible];
	/* The safe area is known once the window is on screen. */
	dispatch_async(dispatch_get_main_queue(), ^{
		[host layoutSubviews];
	});
	return (__bridge void *)host;
}

#pragma mark - Views

static inline UIView *V(SUIViewRef ref)
{
	return (__bridge UIView *)ref;
}

SUIViewRef SUIViewCreate(void)
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
	[view setBackgroundColor:[UIColor clearColor]];
	return (__bridge_retained void *)view;
}

SUIViewRef SUILabelCreate(void)
{
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	[label setBackgroundColor:[UIColor clearColor]];
	[label setTextColor:[UIColor blackColor]];
	[label setFont:[UIFont systemFontOfSize:17]];
	[label setNumberOfLines:0];
	return (__bridge_retained void *)label;
}

void SUIViewRelease(SUIViewRef ref)
{
	UIView *view = (__bridge_transfer UIView *)ref;
	[view removeFromSuperview];
	view = nil;
}

void SUIViewSetSubviews(SUIViewRef parentRef, SUIViewRef *children, int count)
{
	UIView *parent = V(parentRef);
	NSArray *current = [parent subviews];
	BOOL same = [current count] == (NSUInteger)count;
	for (int i = 0; same && i < count; i++)
		same = [current objectAtIndex:i] == V(children[i]);
	if (same)
		return;
	for (int i = 0; i < count; i++) {
		UIView *child = V(children[i]);
		if ([child superview] == parent)
			[child removeFromSuperview];
		[parent addSubview:child];
	}
}

void SUIViewSetFrame(SUIViewRef ref, double x, double y, double width, double height)
{
	UIView *view = V(ref);
	CGRect frame = CGRectMake(x, y, width, height);
	if (!CGRectEqualToRect([view frame], frame))
		[view setFrame:frame];
}

void SUIViewSetBackgroundColor(SUIViewRef ref, double red, double green, double blue, double alpha)
{
	[V(ref) setBackgroundColor:[UIColor colorWithRed:red green:green blue:blue alpha:alpha]];
}

void SUIViewSetAlpha(SUIViewRef ref, double alpha)
{
	[V(ref) setAlpha:alpha];
}

#pragma mark - Labels

static inline UILabel *L(SUIViewRef ref)
{
	return (__bridge UILabel *)ref;
}

void SUILabelSetText(SUIViewRef ref, const char *utf8)
{
	NSString *text = [NSString stringWithUTF8String:utf8 ? utf8 : ""];
	if (![[L(ref) text] isEqualToString:text])
		[L(ref) setText:text];
}

void SUILabelSetFont(SUIViewRef ref, double size, int weight, int italic)
{
	UIFont *font;
	if (italic)
		font = [UIFont italicSystemFontOfSize:size];
	else if (weight >= 600)
		font = [UIFont boldSystemFontOfSize:size];
	else
		font = [UIFont systemFontOfSize:size];
	UIFont *old = [L(ref) font];
	if (old == nil || [old pointSize] != [font pointSize] || ![[old fontName] isEqualToString:[font fontName]])
		[L(ref) setFont:font];
}

void SUILabelSetTextColor(SUIViewRef ref, double red, double green, double blue, double alpha)
{
	[L(ref) setTextColor:[UIColor colorWithRed:red green:green blue:blue alpha:alpha]];
}

void SUILabelSetAlignment(SUIViewRef ref, int alignment)
{
	NSTextAlignment value = alignment == 1 ? NSTextAlignmentCenter
		: alignment == 2 ? NSTextAlignmentRight : NSTextAlignmentLeft;
	if ([L(ref) textAlignment] != value)
		[L(ref) setTextAlignment:value];
}

void SUILabelSetLineLimit(SUIViewRef ref, int lines)
{
	if ([L(ref) numberOfLines] != lines)
		[L(ref) setNumberOfLines:lines];
}

void SUILabelMeasure(SUIViewRef ref, double maxWidth, double *width, double *height)
{
	UILabel *label = L(ref);
	NSString *text = [label text];
	if ([text length] == 0) {
		*width = 0;
		*height = 0;
		return;
	}
	UIFont *font = [label font];
	CGSize line = [label sizeThatFits:CGSizeZero];
	CGFloat w = ceil(line.width), h = ceil(line.height);
	if (w > maxWidth && [label numberOfLines] != 1) {
		CGRect rect = [text boundingRectWithSize:CGSizeMake(maxWidth, 1e7)
			options:NSStringDrawingUsesLineFragmentOrigin
			attributes:@{ NSFontAttributeName: font }
			context:nil];
		w = MIN(ceil(rect.size.width), maxWidth);
		h = ceil(rect.size.height);
		NSInteger lines = [label numberOfLines];
		if (lines > 1 && [font lineHeight] > 0)
			h = MIN(h, ceil(lines * [font lineHeight]));
	} else if (w > maxWidth) {
		w = maxWidth;
	}
	*width = w;
	*height = h;
}

#pragma mark - Buttons

@interface SUITapControl : UIControl {
@public
	SUICallback _action;
	void *_context;
}
@end

@implementation SUITapControl

- (void)fire:(id)sender
{
	if (_action != NULL)
		_action(_context);
}

/* A pressed button dims its label, like a system button. */
- (void)setHighlighted:(BOOL)highlighted
{
	[super setHighlighted:highlighted];
	for (UIView *sibling in [[self superview] subviews]) {
		if (sibling != self)
			[sibling setAlpha:highlighted ? 0.4 : 1.0];
	}
}

@end

SUIViewRef SUITapControlCreate(SUICallback action, void *context)
{
	SUITapControl *control = [[SUITapControl alloc] initWithFrame:CGRectZero];
	control->_action = action;
	control->_context = context;
	[control setBackgroundColor:[UIColor clearColor]];
	[control addTarget:control action:@selector(fire:) forControlEvents:UIControlEventTouchUpInside];
	return (__bridge_retained void *)control;
}
