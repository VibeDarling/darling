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

/* SpringBoard-lite: the home screen. A UIKit app like any other, except
   that frontboardd treats it as the system app: it is in front whenever no
   other app is, and it hears about Home button presses. It shows the
   installed apps as pages of icons with a dock, launches them through
   FrontBoardServices, and on a double press of Home shows the running apps
   in a switcher, from which they can be brought back or closed.

   The layout follows the iPhone home screen: a status bar, a grid of
   rounded icons with their names under them, page dots, and a dock.
   Everything is drawn with UIKit views and Core Graphics; icons are the
   apps' own PNGs when they have them. */

#import <UIKit/UIKit.h>
#import <FrontBoardServices/FrontBoardServices.h>
#include <stdio.h>

static void SBLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "SpringBoard: %s\n", [line UTF8String]);
}

/* Pointer travel beyond which a touch is a swipe, not a tap. */
static const CGFloat SBTapSlop = 12;
/* Horizontal travel that turns the page. */
static const CGFloat SBPageSwipeDistance = 60;
static const CGFloat SBStatusBarHeight = 24;
static const CGFloat SBLabelHeight = 18;

#pragma mark - Drawing helpers

static void SBAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
	CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect);
	CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
	CGContextMoveToPoint(context, minX + radius, minY);
	CGContextAddArcToPoint(context, maxX, minY, maxX, maxY, radius);
	CGContextAddArcToPoint(context, maxX, maxY, minX, maxY, radius);
	CGContextAddArcToPoint(context, minX, maxY, minX, minY, radius);
	CGContextAddArcToPoint(context, minX, minY, maxX, minY, radius);
	CGContextClosePath(context);
}

/* Runs draw once per horizontal strip of a rounded rect, clipped to the
   strip narrowed to the rounded outline. Darling's Core Graphics clips to
   a path's bounding box only, but clips to rectangles exactly, so this is
   how icons get their rounded corners. Corner rows are a pixel high. */
static void SBClipToRoundedRect(CGContextRef context, CGRect rect, CGFloat radius, void (^draw)(CGRect strip))
{
	radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2);
	CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
	void (^strip)(CGFloat, CGFloat, CGFloat) = ^(CGFloat y, CGFloat height, CGFloat inset) {
		CGRect clip = CGRectMake(rect.origin.x + inset, y, rect.size.width - 2 * inset, height);
		CGContextSaveGState(context);
		CGContextClipToRect(context, clip);
		draw(clip);
		CGContextRestoreGState(context);
	};
	for (CGFloat row = 0; row < radius; row++) {
		/* How far the arc stands in from the side at the middle of this row. */
		CGFloat dy = radius - row - 0.5;
		CGFloat inset = radius - sqrt(MAX(0, radius * radius - dy * dy));
		strip(minY + row, 1, inset);
		strip(maxY - row - 1, 1, inset);
	}
	strip(minY + radius, rect.size.height - 2 * radius, 0);
}

typedef struct { CGFloat r, g, b; } SBRGB;

/* A stable color per app, for apps without an icon of their own. */
static SBRGB SBColorForIdentifier(NSString *identifier)
{
	static const SBRGB palette[] = {
		{ 0.94, 0.33, 0.31 }, { 0.98, 0.60, 0.20 }, { 0.30, 0.75, 0.40 },
		{ 0.20, 0.60, 0.95 }, { 0.55, 0.40, 0.90 }, { 0.95, 0.35, 0.60 },
		{ 0.15, 0.70, 0.70 }, { 0.45, 0.50, 0.58 },
	};
	NSUInteger hash = 5381;
	for (NSUInteger i = 0; i < [identifier length]; i++)
		hash = hash * 33 + [identifier characterAtIndex:i];
	return palette[hash % (sizeof(palette) / sizeof(*palette))];
}

/* Vertical bands approximate a gradient without depending on CGGradient.
   Only the bands that cross within are filled. */
static void SBFillVerticalGradientWithin(CGContextRef context, CGRect rect, CGRect within, SBRGB top, SBRGB bottom, CGFloat alpha)
{
	const int bands = 48;
	CGFloat bandHeight = rect.size.height / bands;
	int first = MAX(0, (int)floor((CGRectGetMinY(within) - rect.origin.y) / bandHeight));
	int last = MIN(bands - 1, (int)ceil((CGRectGetMaxY(within) - rect.origin.y) / bandHeight));
	for (int i = first; i <= last; i++) {
		CGFloat t = (CGFloat)i / (bands - 1);
		CGContextSetRGBFillColor(context, top.r + (bottom.r - top.r) * t, top.g + (bottom.g - top.g) * t,
			top.b + (bottom.b - top.b) * t, alpha);
		CGContextFillRect(context, CGRectIntersection(within, CGRectMake(rect.origin.x, rect.origin.y + i * bandHeight, rect.size.width, bandHeight + 1)));
	}
}


#pragma mark - Applications

@interface SBApplication : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, strong) UIImage *icon;
+ (instancetype)applicationWithBundle:(NSBundle *)bundle;
@end

@implementation SBApplication

/* The icon file names an iOS bundle may declare, largest last as Xcode
   writes them, and the names asset catalogs compile app icons to. */
+ (NSArray<NSString *> *)iconNamesForBundle:(NSBundle *)bundle
{
	NSDictionary *info = [bundle infoDictionary];
	NSMutableArray<NSString *> *names = [NSMutableArray array];
	NSArray *primary = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
	if ([primary isKindOfClass:[NSArray class]])
		[names addObjectsFromArray:[[primary reverseObjectEnumerator] allObjects]];
	NSArray *files = info[@"CFBundleIconFiles"];
	if ([files isKindOfClass:[NSArray class]])
		[names addObjectsFromArray:[[files reverseObjectEnumerator] allObjects]];
	if ([info[@"CFBundleIconFile"] isKindOfClass:[NSString class]])
		[names addObject:info[@"CFBundleIconFile"]];
	[names addObjectsFromArray:@[ @"AppIcon60x60", @"Icon", @"icon" ]];
	return names;
}

+ (UIImage *)iconForBundle:(NSBundle *)bundle
{
	NSString *root = [bundle bundlePath];
	for (NSString *name in [self iconNamesForBundle:bundle]) {
		NSString *base = [name stringByDeletingPathExtension];
		for (NSString *suffix in @[ @"@3x.png", @"@2x.png", @".png", @"" ]) {
			NSString *path = [root stringByAppendingPathComponent:[base stringByAppendingString:suffix]];
			if (![[NSFileManager defaultManager] fileExistsAtPath:path])
				continue;
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (image != nil)
				return image;
		}
	}
	return nil;
}

+ (instancetype)applicationWithBundle:(NSBundle *)bundle
{
	NSDictionary *info = [bundle infoDictionary];
	SBApplication *application = [[self alloc] init];
	application.bundleIdentifier = [bundle bundleIdentifier];
	application.displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"]
		?: [[[bundle bundlePath] lastPathComponent] stringByDeletingPathExtension];
	application.icon = [self iconForBundle:bundle];
	return application;
}

@end

#pragma mark - Icons

@class SBIconView;

@protocol SBIconViewDelegate <NSObject>
- (void)iconViewWasTapped:(SBIconView *)iconView;
@end

/* One app: the rounded icon, its name under it, and a dot when it runs. */
@interface SBIconView : UIView
@property (nonatomic, strong, readonly) SBApplication *application;
@property (nonatomic, weak) id<SBIconViewDelegate> delegate;
@property (nonatomic) CGFloat iconSize;
@property (nonatomic, getter=isRunning) BOOL running;
- (instancetype)initWithApplication:(SBApplication *)application iconSize:(CGFloat)iconSize;
@end

@implementation SBIconView {
	UILabel *_label;
	UILabel *_monogram;
	BOOL _highlighted;
	BOOL _tracking;
	CGPoint _touchStart;
}

- (instancetype)initWithApplication:(SBApplication *)application iconSize:(CGFloat)iconSize
{
	CGFloat width = iconSize + 28;
	if ((self = [super initWithFrame:CGRectMake(0, 0, width, iconSize + 8 + SBLabelHeight + 8)])) {
		_application = application;
		_iconSize = iconSize;

		_label = [[UILabel alloc] initWithFrame:CGRectMake(0, iconSize + 6, width, SBLabelHeight)];
		_label.text = application.displayName;
		_label.font = [UIFont systemFontOfSize:12];
		_label.textColor = [UIColor whiteColor];
		_label.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_label];

		if (application.icon == nil) {
			_monogram = [[UILabel alloc] initWithFrame:[self iconRect]];
			_monogram.text = [[application.displayName substringToIndex:MIN((NSUInteger)1, [application.displayName length])] uppercaseString];
			_monogram.font = [UIFont systemFontOfSize:iconSize * 0.45];
			_monogram.textColor = [UIColor whiteColor];
			_monogram.textAlignment = NSTextAlignmentCenter;
			[self addSubview:_monogram];
		}
	}
	return self;
}

- (CGRect)iconRect
{
	return CGRectMake(([self bounds].size.width - _iconSize) / 2, 0, _iconSize, _iconSize);
}

- (void)setRunning:(BOOL)running
{
	if (_running == running)
		return;
	_running = running;
	[self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)highlighted
{
	_highlighted = highlighted;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect icon = [self iconRect];
	CGFloat radius = _iconSize * 0.225;

	UIImage *image = _application.icon;
	SBRGB color = SBColorForIdentifier(_application.bundleIdentifier);
	SBRGB light = { MIN(1, color.r + 0.15), MIN(1, color.g + 0.15), MIN(1, color.b + 0.15) };
	BOOL highlighted = _highlighted;
	SBClipToRoundedRect(context, icon, radius, ^(CGRect strip) {
		if (image != nil)
			[image drawInRect:icon];
		else
			SBFillVerticalGradientWithin(context, icon, strip, light, color, 1);
		if (highlighted) {
			CGContextSetRGBFillColor(context, 0, 0, 0, 0.4);
			CGContextFillRect(context, strip);
		}
	});

	if (_running) {
		CGFloat size = 5;
		CGContextSetRGBFillColor(context, 1, 1, 1, 0.9);
		CGContextFillEllipseInRect(context, CGRectMake(floor(CGRectGetMidX(icon) - size / 2), CGRectGetMaxY(icon) + 6 + SBLabelHeight + 2, size, size));
	}
}

/* Touches go on to the superview too, so a swipe that starts on an icon
   still turns the page; only a touch that stays put is a tap. */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_touchStart = [[touches anyObject] locationInView:self];
	_tracking = YES;
	[self setHighlighted:YES];
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [[touches anyObject] locationInView:self];
	if (_tracking && hypot(point.x - _touchStart.x, point.y - _touchStart.y) > SBTapSlop) {
		_tracking = NO;
		[self setHighlighted:NO];
	}
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	BOOL tapped = _tracking;
	_tracking = NO;
	[self setHighlighted:NO];
	[super touchesEnded:touches withEvent:event];
	if (tapped)
		[_delegate iconViewWasTapped:self];
}

@end

#pragma mark - Page dots and dock

@interface SBPageDotsView : UIView
@property (nonatomic) NSUInteger numberOfPages;
@property (nonatomic) NSUInteger currentPage;
@end

@implementation SBPageDotsView

- (void)setNumberOfPages:(NSUInteger)numberOfPages
{
	_numberOfPages = numberOfPages;
	[self setNeedsDisplay:YES];
}

- (void)setCurrentPage:(NSUInteger)currentPage
{
	_currentPage = currentPage;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	if (_numberOfPages < 2)
		return;
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat size = 7, gap = 9;
	CGFloat width = _numberOfPages * size + (_numberOfPages - 1) * gap;
	CGFloat x = ([self bounds].size.width - width) / 2;
	CGFloat y = ([self bounds].size.height - size) / 2;
	for (NSUInteger i = 0; i < _numberOfPages; i++) {
		CGContextSetRGBFillColor(context, 1, 1, 1, i == _currentPage ? 1 : 0.4);
		CGContextFillEllipseInRect(context, CGRectMake(x + i * (size + gap), y, size, size));
	}
}

@end

/* The frosted shelf the dock icons sit on. */
@interface SBDockView : UIView
@end

@implementation SBDockView

- (void)drawRect:(NSRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	SBAddRoundedRect(context, CGRectInset([self bounds], 8, 4), 26);
	CGContextSetRGBFillColor(context, 1, 1, 1, 0.25);
	CGContextFillPath(context);
}

@end

#pragma mark - App switcher

@class SBSwitcherView;

@protocol SBSwitcherViewDelegate <NSObject>
- (void)switcher:(SBSwitcherView *)switcher didSelectApplication:(SBApplication *)application;
- (void)switcher:(SBSwitcherView *)switcher didCloseApplication:(SBApplication *)application;
- (void)switcherDidDismiss:(SBSwitcherView *)switcher;
@end

/* A card per running app; tapping a card brings the app back, tapping its
   close mark ends it, tapping anywhere else dismisses the switcher. */
@interface SBSwitcherCardView : UIView
@property (nonatomic, strong) SBApplication *application;
@property (nonatomic) CGRect closeRect;
@end

@implementation SBSwitcherCardView

- (void)drawRect:(NSRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect card = CGRectMake(0, 24, [self bounds].size.width, [self bounds].size.height - 24);
	SBRGB color = SBColorForIdentifier(_application.bundleIdentifier);
	SBClipToRoundedRect(context, card, 18, ^(CGRect strip) {
		SBFillVerticalGradientWithin(context, card, strip, (SBRGB){ 0.97, 0.97, 0.98 }, (SBRGB){ 0.85, 0.86, 0.9 }, 1);
		CGContextSetRGBFillColor(context, color.r, color.g, color.b, 1);
		CGContextFillRect(context, CGRectIntersection(strip, CGRectMake(card.origin.x, card.origin.y, card.size.width, 40)));
	});

	/* The close mark: a dark disc with a cross. */
	CGRect close = _closeRect;
	CGContextSetRGBFillColor(context, 0.15, 0.15, 0.17, 0.95);
	CGContextFillEllipseInRect(context, close);
	CGContextSetRGBStrokeColor(context, 1, 1, 1, 1);
	CGContextSetLineWidth(context, 2.5);
	CGFloat inset = close.size.width * 0.3;
	CGContextMoveToPoint(context, CGRectGetMinX(close) + inset, CGRectGetMinY(close) + inset);
	CGContextAddLineToPoint(context, CGRectGetMaxX(close) - inset, CGRectGetMaxY(close) - inset);
	CGContextMoveToPoint(context, CGRectGetMaxX(close) - inset, CGRectGetMinY(close) + inset);
	CGContextAddLineToPoint(context, CGRectGetMinX(close) + inset, CGRectGetMaxY(close) - inset);
	CGContextStrokePath(context);
}

@end

@interface SBSwitcherView : UIView
@property (nonatomic, weak) id<SBSwitcherViewDelegate> delegate;
- (void)showApplications:(NSArray<SBApplication *> *)applications;
@end

@implementation SBSwitcherView {
	NSMutableArray<SBSwitcherCardView *> *_cards;
	UILabel *_emptyLabel;
}

- (void)showApplications:(NSArray<SBApplication *> *)applications
{
	for (UIView *card in _cards)
		[card removeFromSuperview];
	_cards = [NSMutableArray array];
	[_emptyLabel removeFromSuperview];
	_emptyLabel = nil;

	CGSize size = [self bounds].size;
	if ([applications count] == 0) {
		_emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height / 2 - 20, size.width, 40)];
		_emptyLabel.text = @"No Recent Apps";
		_emptyLabel.font = [UIFont systemFontOfSize:20];
		_emptyLabel.textColor = [UIColor whiteColor];
		_emptyLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_emptyLabel];
		return;
	}

	CGFloat cardWidth = MIN(220, size.width * 0.6 / MAX((NSUInteger)1, MIN([applications count], (NSUInteger)4)));
	CGFloat cardHeight = MIN(size.height * 0.6, cardWidth * 1.6) + 24;
	CGFloat gap = 24;
	CGFloat total = [applications count] * cardWidth + ([applications count] - 1) * gap;
	CGFloat x = MAX(gap, (size.width - total) / 2);
	CGFloat y = (size.height - cardHeight) / 2;
	for (SBApplication *application in applications) {
		SBSwitcherCardView *card = [[SBSwitcherCardView alloc] initWithFrame:CGRectMake(floor(x), floor(y), floor(cardWidth), floor(cardHeight))];
		card.application = application;
		card.closeRect = CGRectMake(0, 4, 32, 32);

		UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(8, 24 + 50, cardWidth - 16, 24)];
		name.text = application.displayName;
		name.font = [UIFont systemFontOfSize:16];
		name.textColor = [UIColor colorWithWhite:0.15 alpha:1];
		name.textAlignment = NSTextAlignmentCenter;
		name.userInteractionEnabled = NO;
		[card addSubview:name];

		[self addSubview:card];
		[_cards addObject:card];
		x += cardWidth + gap;
	}
}

- (void)drawRect:(NSRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetRGBFillColor(context, 0, 0, 0, 0.6);
	CGContextFillRect(context, [self bounds]);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	for (SBSwitcherCardView *card in _cards) {
		CGPoint point = [touch locationInView:card];
		if (CGRectContainsPoint(CGRectInset(card.closeRect, -6, -6), point)) {
			[_delegate switcher:self didCloseApplication:card.application];
			return;
		}
		if (CGRectContainsPoint([card bounds], point)) {
			[_delegate switcher:self didSelectApplication:card.application];
			return;
		}
	}
	[_delegate switcherDidDismiss:self];
}

@end

#pragma mark - Home screen

@interface SBHomeView : UIView <SBIconViewDelegate, SBSwitcherViewDelegate>
@end

@implementation SBHomeView {
	NSArray<SBApplication *> *_applications;
	NSMutableArray<SBIconView *> *_iconViews;
	UIView *_pagesView;
	SBPageDotsView *_dots;
	SBDockView *_dock;
	UILabel *_clock;
	SBSwitcherView *_switcher;
	NSUInteger _numberOfPages;
	NSUInteger _currentPage;
	CGPoint _swipeStart;
	CGFloat _pageWidth;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

		_clock = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, frame.size.width, SBStatusBarHeight - 4)];
		_clock.font = [UIFont systemFontOfSize:14];
		_clock.textColor = [UIColor whiteColor];
		_clock.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_clock];

		UILabel *carrier = [[UILabel alloc] initWithFrame:CGRectMake(12, 2, 200, SBStatusBarHeight - 4)];
		carrier.text = @"Darling";
		carrier.font = [UIFont systemFontOfSize:13];
		carrier.textColor = [UIColor whiteColor];
		[self addSubview:carrier];

		[self updateClock];
		[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(updateClock) userInfo:nil repeats:YES];
		[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateRunningApplications) userInfo:nil repeats:YES];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceEvent:) name:FBSWorkspaceEventNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

- (void)updateClock
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm"];
	_clock.text = [formatter stringFromDate:[NSDate date]];
}

- (void)drawRect:(NSRect)rect
{
	/* The wallpaper. */
	SBFillVerticalGradientWithin(UIGraphicsGetCurrentContext(), [self bounds], NSRectToCGRect(rect),
		(SBRGB){ 0.16, 0.20, 0.42 }, (SBRGB){ 0.55, 0.30, 0.55 }, 1);
}

#pragma mark Layout

- (NSArray<NSString *> *)dockIdentifiers
{
	NSArray *configured = [[NSUserDefaults standardUserDefaults] arrayForKey:@"SBDockApplications"];
	return [configured isKindOfClass:[NSArray class]] ? configured : @[];
}

- (void)reloadApplications
{
	NSMutableArray<SBApplication *> *applications = [NSMutableArray array];
	for (NSBundle *bundle in FBSInstalledApplications()) {
		NSArray *tags = [bundle infoDictionary][@"SBAppTags"];
		if ([tags isKindOfClass:[NSArray class]] && [tags containsObject:@"hidden"])
			continue;
		[applications addObject:[SBApplication applicationWithBundle:bundle]];
	}
	NSArray *identifiers = [applications valueForKey:@"bundleIdentifier"];
	if ([identifiers isEqualToArray:[_applications valueForKey:@"bundleIdentifier"]]) {
		[self updateRunningApplications];
		return;
	}
	_applications = applications;
	SBLog(@"%lu applications installed", (unsigned long)[applications count]);
	[self layoutIcons];
	[self updateRunningApplications];
}

- (void)layoutIcons
{
	for (UIView *view in _iconViews)
		[view removeFromSuperview];
	[_pagesView removeFromSuperview];
	[_dots removeFromSuperview];
	[_dock removeFromSuperview];
	_iconViews = [NSMutableArray array];

	CGSize size = [self bounds].size;
	NSUInteger columns = size.width > size.height ? 6 : 4;
	CGFloat cellWidth = size.width / columns;
	CGFloat iconSize = floor(MIN(72, cellWidth * 0.6));
	CGFloat cellHeight = iconSize + SBLabelHeight + 30;
	CGFloat dockHeight = iconSize + SBLabelHeight + 30;
	CGFloat dotsHeight = 20;
	CGFloat gridTop = SBStatusBarHeight + 16;
	CGFloat gridHeight = size.height - gridTop - dotsHeight - dockHeight - 8;
	NSUInteger rows = MAX((NSUInteger)1, (NSUInteger)floor(gridHeight / cellHeight));
	NSUInteger perPage = rows * columns;

	NSArray<NSString *> *dockIdentifiers = [self dockIdentifiers];
	NSMutableArray<SBApplication *> *dockApplications = [NSMutableArray array];
	NSMutableArray<SBApplication *> *gridApplications = [NSMutableArray array];
	for (SBApplication *application in _applications) {
		if ([dockIdentifiers containsObject:application.bundleIdentifier] && [dockApplications count] < columns)
			[dockApplications addObject:application];
		else
			[gridApplications addObject:application];
	}

	_numberOfPages = MAX((NSUInteger)1, ([gridApplications count] + perPage - 1) / perPage);
	_currentPage = MIN(_currentPage, _numberOfPages - 1);
	_pageWidth = size.width;

	/* All pages side by side; turning the page moves this view. */
	_pagesView = [[UIView alloc] initWithFrame:CGRectMake(-(CGFloat)_currentPage * _pageWidth, gridTop, _pageWidth * _numberOfPages, rows * cellHeight)];
	[self addSubview:_pagesView];
	[gridApplications enumerateObjectsUsingBlock:^(SBApplication *application, NSUInteger index, BOOL *stop) {
		NSUInteger page = index / perPage, slot = index % perPage;
		SBIconView *iconView = [self iconViewForApplication:application iconSize:iconSize];
		CGRect frame = [iconView frame];
		/* Whole pixels: a view at a fractional origin leaves seams when
		   the wallpaper under it is partly redrawn. */
		frame.origin.x = floor(page * self->_pageWidth + (slot % columns) * cellWidth + (cellWidth - frame.size.width) / 2);
		frame.origin.y = floor((slot / columns) * cellHeight);
		[iconView setFrame:frame];
		[self->_pagesView addSubview:iconView];
	}];

	_dots = [[SBPageDotsView alloc] initWithFrame:CGRectMake(0, size.height - dockHeight - dotsHeight - 4, size.width, dotsHeight)];
	_dots.numberOfPages = _numberOfPages;
	_dots.currentPage = _currentPage;
	_dots.userInteractionEnabled = NO;
	[self addSubview:_dots];

	_dock = [[SBDockView alloc] initWithFrame:CGRectMake(0, size.height - dockHeight, size.width, dockHeight)];
	[self addSubview:_dock];
	CGFloat dockCell = size.width / MAX((NSUInteger)4, [dockApplications count]);
	CGFloat dockX = (size.width - dockCell * [dockApplications count]) / 2;
	for (SBApplication *application in dockApplications) {
		SBIconView *iconView = [self iconViewForApplication:application iconSize:iconSize];
		CGRect frame = [iconView frame];
		frame.origin.x = floor(dockX + (dockCell - frame.size.width) / 2);
		frame.origin.y = 12;
		[iconView setFrame:frame];
		[_dock addSubview:iconView];
		dockX += dockCell;
	}

	if (_switcher != nil)
		[self addSubview:_switcher];
	[self setNeedsDisplay:YES];
}

- (SBIconView *)iconViewForApplication:(SBApplication *)application iconSize:(CGFloat)iconSize
{
	SBIconView *iconView = [[SBIconView alloc] initWithApplication:application iconSize:iconSize];
	iconView.delegate = self;
	[_iconViews addObject:iconView];
	return iconView;
}

- (void)showPage:(NSUInteger)page
{
	page = MIN(page, _numberOfPages - 1);
	if (page == _currentPage)
		return;
	SBLog(@"page %lu of %lu", (unsigned long)page + 1, (unsigned long)_numberOfPages);
	_currentPage = page;
	_dots.currentPage = page;
	CGRect frame = [_pagesView frame];
	frame.origin.x = -(CGFloat)page * _pageWidth;
	[_pagesView setFrame:frame];
	[self setNeedsDisplay:YES];
}

#pragma mark Running apps

- (NSArray<NSDictionary *> *)runningProcesses
{
	NSMutableArray *running = [NSMutableArray array];
	NSString *me = [[NSBundle mainBundle] bundleIdentifier];
	for (NSDictionary *process in [[FBSSystemService sharedService] applicationStates])
		if (![process[@"bundleIdentifier"] isEqualToString:me])
			[running addObject:process];
	return running;
}

- (void)updateRunningApplications
{
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
		return;
	NSMutableSet<NSString *> *running = [NSMutableSet set];
	for (NSDictionary *process in [self runningProcesses])
		[running addObject:process[@"bundleIdentifier"]];
	for (SBIconView *iconView in _iconViews)
		iconView.running = [running containsObject:iconView.application.bundleIdentifier];
}

- (SBApplication *)applicationWithIdentifier:(NSString *)bundleIdentifier
{
	for (SBApplication *application in _applications)
		if ([application.bundleIdentifier isEqualToString:bundleIdentifier])
			return application;
	SBApplication *application = [[SBApplication alloc] init];
	application.bundleIdentifier = bundleIdentifier;
	application.displayName = [[bundleIdentifier componentsSeparatedByString:@"."] lastObject];
	return application;
}

#pragma mark Launching

- (void)openApplication:(SBApplication *)application
{
	SBLog(@"opening %@", application.bundleIdentifier);
	[[FBSSystemService sharedService] openApplication:application.bundleIdentifier options:nil withResult:^(NSError *error) {
		if (error != nil)
			SBLog(@"cannot open %@: %@", application.bundleIdentifier, [error localizedFailureReason] ?: error);
	}];
}

- (void)iconViewWasTapped:(SBIconView *)iconView
{
	[self openApplication:iconView.application];
}

#pragma mark Switcher

- (void)showSwitcher
{
	NSMutableArray<SBApplication *> *applications = [NSMutableArray array];
	for (NSDictionary *process in [self runningProcesses])
		[applications addObject:[self applicationWithIdentifier:process[@"bundleIdentifier"]]];
	SBLog(@"switcher shows %lu apps", (unsigned long)[applications count]);

	if (_switcher == nil) {
		_switcher = [[SBSwitcherView alloc] initWithFrame:[self bounds]];
		_switcher.delegate = self;
		[self addSubview:_switcher];
	}
	[_switcher showApplications:applications];
	[_switcher setNeedsDisplay:YES];
}

- (void)hideSwitcher
{
	if (_switcher == nil)
		return;
	SBLog(@"switcher hidden");
	[_switcher removeFromSuperview];
	_switcher = nil;
	[self setNeedsDisplay:YES];
}

- (void)switcher:(SBSwitcherView *)switcher didSelectApplication:(SBApplication *)application
{
	[self hideSwitcher];
	[self openApplication:application];
}

- (void)switcher:(SBSwitcherView *)switcher didCloseApplication:(SBApplication *)application
{
	SBLog(@"closing %@", application.bundleIdentifier);
	[[FBSSystemService sharedService] terminateApplication:application.bundleIdentifier forReason:1 andReport:NO withDescription:@"closed in the app switcher" completion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			SBLog(@"closed %@", application.bundleIdentifier);
			if (self->_switcher != nil)
				[self showSwitcher];
			[self updateRunningApplications];
		});
	}];
}

- (void)switcherDidDismiss:(SBSwitcherView *)switcher
{
	[self hideSwitcher];
}

#pragma mark Events

- (void)workspaceEvent:(NSNotification *)notification
{
	NSDictionary *event = [notification userInfo];
	if (![event[@"event"] isEqualToString:@"button"] || ![event[@"button"] isEqualToString:@"home"])
		return;
	NSInteger count = [event[@"count"] integerValue];
	SBLog(@"home button, %ld press(es)", (long)count);
	if (count >= 2)
		[self showSwitcher];
	else if (_switcher != nil)
		[self hideSwitcher];
	else
		[self showPage:0];
}

- (void)didBecomeActive:(NSNotification *)notification
{
	[self reloadApplications];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	_swipeStart = [[touches anyObject] locationInView:self];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	CGPoint end = [[touches anyObject] locationInView:self];
	CGFloat dx = end.x - _swipeStart.x;
	if (fabs(dx) < SBPageSwipeDistance || fabs(dx) < fabs(end.y - _swipeStart.y))
		return;
	if (dx < 0 && _currentPage + 1 < _numberOfPages)
		[self showPage:_currentPage + 1];
	else if (dx > 0 && _currentPage > 0)
		[self showPage:_currentPage - 1];
}

@end

#pragma mark - Application

@interface SBAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	CGRect bounds = [[UIScreen mainScreen] bounds];
	self.window = [[UIWindow alloc] initWithFrame:bounds];
	UIViewController *controller = [[UIViewController alloc] init];
	[controller.view addSubview:[[SBHomeView alloc] initWithFrame:bounds]];
	self.window.rootViewController = controller;
	[self.window makeKeyAndVisible];
	return YES;
}

@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([SBAppDelegate class]));
	}
}
