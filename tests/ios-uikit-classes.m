/* The UIKit classes file managers such as FileBrowser and Filza need:
   gesture recognizers (driven by real pointer events), UITableViewController,
   UICollectionView and its flow layout, UIToolbar, the value controls,
   pickers, UITextView, UIBezierPath and image contexts, the container
   controllers, UIAppearance, Auto Layout guides, UIPasteboard items, iOS 7
   string drawing and the log-and-nil fallback. One PASS/FAIL line per check;
   exits nonzero on any failure. It then shows some of the classes for a few
   seconds, for a screenshot; see ios-uikit-classes.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static BOOL near(CGFloat a, CGFloat b)
{
	return fabs(a - b) < 0.5;
}

static NSString *rect(CGRect r)
{
	return [NSString stringWithFormat:@"{%g,%g %gx%g}", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

/* A pointer event at a point of view, in its window. */
static NSEvent *pointer(NSEventType type, UIView *view, CGPoint point, NSTimeInterval time)
{
	NSPoint inWindow = [view convertPoint:NSMakePoint(point.x, point.y) toView:nil];
	return [NSEvent mouseEventWithType:type location:inWindow modifierFlags:0 timestamp:time
	                      windowNumber:[[view window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
}

static NSTimeInterval sClock = 1000;

/* Presses at from, drags through the steps to to, and lets go. */
static void drag(UIView *view, CGPoint from, CGPoint to, int steps)
{
	[view mouseDown:pointer(NSLeftMouseDown, view, from, sClock += 0.01)];
	for (int i = 1; i <= steps; i++) {
		CGPoint point = CGPointMake(from.x + (to.x - from.x) * i / steps, from.y + (to.y - from.y) * i / steps);
		[view mouseDragged:pointer(NSLeftMouseDragged, view, point, sClock += 0.01)];
	}
	[view mouseUp:pointer(NSLeftMouseUp, view, to, sClock += 0.01)];
}

static void tap(UIView *view, CGPoint point)
{
	drag(view, point, point, 0);
}

static void spin(NSTimeInterval seconds)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

/* Runs the run loop until done says so, for at most ten seconds: timers
   are late on a slow (emulated) machine. */
static void spinUntil(BOOL (^done)(void))
{
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (!done() && [limit timeIntervalSinceNow] > 0)
		spin(0.05);
}

/* Counts the touches it is sent and the gesture actions. */
@interface Pad : UIView
@property (nonatomic) int began, ended, cancelled;
@end

@implementation Pad
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { _began++; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { _ended++; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { _cancelled++; }
@end

@interface Recorder : NSObject
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation Recorder
- (instancetype)init { if ((self = [super init])) _events = [NSMutableArray array]; return self; }
- (void)fired:(UIGestureRecognizer *)recognizer
{
	[_events addObject:[NSString stringWithFormat:@"%@:%ld", NSStringFromClass([recognizer class]), (long)[recognizer state]]];
}
- (void)single:(UIGestureRecognizer *)recognizer { [_events addObject:@"single"]; }
- (void)twice:(UIGestureRecognizer *)recognizer { [_events addObject:@"double"]; }
- (void)button:(id)sender { [_events addObject:@"button"]; }
@end

/* Overrides -init to call -initWithStyle:, as many apps do. */
@interface Files : UITableViewController
@end

@implementation Files
- (instancetype)init { return [super initWithStyle:UITableViewStyleGrouped]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	[[cell textLabel] setText:[NSString stringWithFormat:@"File %ld", (long)[indexPath row]]];
	return cell;
}
@end

/* Counts how often it is drawn. */
@interface Tile : UICollectionViewCell
@end

static int sTileDraws;

@implementation Tile
- (void)drawRect:(NSRect)rect
{
	sTileDraws++;
	[super drawRect:rect];
}
@end

@interface Grid : NSObject <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic) NSInteger count;
@property (nonatomic, strong) NSIndexPath *selected;
@end

@implementation Grid
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return _count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	[cell setBackgroundColor:[UIColor colorWithHue:[indexPath item] / 12.0 saturation:0.6 brightness:0.9 alpha:1]];
	return cell;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath { _selected = indexPath; }
@end

@interface Wheel : NSObject <UIPickerViewDataSource, UIPickerViewDelegate>
@end

@implementation Wheel
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 2; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component { return component == 0 ? 10 : 3; }
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return component == 0 ? [NSString stringWithFormat:@"%ld", (long)row] : @[ @"KB", @"MB", @"GB" ][row];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate {
	Recorder *_recorder;
	Grid *_grid;
	Wheel *_wheel;
}

- (void)gestureChecksIn:(UIView *)stage
{
	_recorder = [[Recorder alloc] init];

	Pad *pad = [[Pad alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
	[stage addSubview:pad];
	UITapGestureRecognizer *tapper = [[UITapGestureRecognizer alloc] initWithTarget:_recorder action:@selector(fired:)];
	[pad addGestureRecognizer:tapper];
	expect([[pad gestureRecognizers] containsObject:tapper] && [tapper view] == pad, "addGestureRecognizer:", nil);
	tap(pad, CGPointMake(50, 50));
	expect([_recorder.events isEqual:@[ @"UITapGestureRecognizer:3" ]], "a tap recognizes", [_recorder.events description]);
	expect(pad.began == 1 && pad.ended == 0 && pad.cancelled == 1, "recognizing cancels the view's touches",
	       [NSString stringWithFormat:@"%d %d %d", pad.began, pad.ended, pad.cancelled]);
	expect([tapper state] == UIGestureRecognizerStatePossible, "recognizers reset after the touch", nil);

	[tapper setCancelsTouchesInView:NO];
	pad.began = pad.ended = pad.cancelled = 0;
	[_recorder.events removeAllObjects];
	tap(pad, CGPointMake(50, 50));
	expect([_recorder.events count] == 1 && pad.ended == 1 && pad.cancelled == 0, "cancelsTouchesInView NO lets touches through", nil);

	[_recorder.events removeAllObjects];
	drag(pad, CGPointMake(20, 20), CGPointMake(80, 20), 4);
	expect([_recorder.events count] == 0, "a drag is not a tap", [_recorder.events description]);
	[pad removeGestureRecognizer:tapper];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:_recorder action:@selector(fired:)];
	[pad addGestureRecognizer:pan];
	__block CGPoint translation = CGPointZero;
	[_recorder.events removeAllObjects];
	[pad mouseDown:pointer(NSLeftMouseDown, pad, CGPointMake(10, 50), sClock += 0.01)];
	[pad mouseDragged:pointer(NSLeftMouseDragged, pad, CGPointMake(30, 50), sClock += 0.01)];
	[pad mouseDragged:pointer(NSLeftMouseDragged, pad, CGPointMake(60, 50), sClock += 0.01)];
	translation = [pan translationInView:pad];
	[pad mouseUp:pointer(NSLeftMouseUp, pad, CGPointMake(60, 50), sClock += 0.01)];
	expect([_recorder.events isEqual:@[ @"UIPanGestureRecognizer:1", @"UIPanGestureRecognizer:2", @"UIPanGestureRecognizer:3" ]],
	       "pan begins, changes and ends", [_recorder.events description]);
	expect(near(translation.x, 50) && near(translation.y, 0), "pan translation", NSStringFromCGPoint(translation));
	[pad removeGestureRecognizer:pan];

	/* A single tap that waits for a double tap to fail. */
	UITapGestureRecognizer *single = [[UITapGestureRecognizer alloc] initWithTarget:_recorder action:@selector(single:)];
	UITapGestureRecognizer *twice = [[UITapGestureRecognizer alloc] initWithTarget:_recorder action:@selector(twice:)];
	[twice setNumberOfTapsRequired:2];
	[single requireGestureRecognizerToFail:twice];
	[pad addGestureRecognizer:single];
	[pad addGestureRecognizer:twice];
	[_recorder.events removeAllObjects];
	tap(pad, CGPointMake(50, 50));
	tap(pad, CGPointMake(50, 50));
	spin(0.5);
	expect([_recorder.events isEqual:@[ @"double" ]], "a double tap wins over the single tap", [_recorder.events description]);
	[_recorder.events removeAllObjects];
	tap(pad, CGPointMake(50, 50));
	expect([_recorder.events count] == 0, "the single tap waits", [_recorder.events description]);
	Recorder *recorder = _recorder;
	spinUntil(^{ return (BOOL)([recorder.events count] > 0); });
	expect([_recorder.events isEqual:@[ @"single" ]], "the single tap recognizes once the double tap fails", [_recorder.events description]);
	[pad removeGestureRecognizer:single];
	[pad removeGestureRecognizer:twice];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:_recorder action:@selector(fired:)];
	[hold setMinimumPressDuration:0.2];
	[pad addGestureRecognizer:hold];
	[_recorder.events removeAllObjects];
	[pad mouseDown:pointer(NSLeftMouseDown, pad, CGPointMake(50, 50), sClock += 0.01)];
	spinUntil(^{ return (BOOL)([recorder.events count] > 0); });
	[pad mouseUp:pointer(NSLeftMouseUp, pad, CGPointMake(50, 50), sClock += 0.4)];
	expect([_recorder.events isEqual:@[ @"UILongPressGestureRecognizer:1", @"UILongPressGestureRecognizer:3" ]], "long press", [_recorder.events description]);
	[pad removeGestureRecognizer:hold];

	UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:_recorder action:@selector(fired:)];
	[swipe setDirection:UISwipeGestureRecognizerDirectionLeft];
	[pad addGestureRecognizer:swipe];
	[_recorder.events removeAllObjects];
	drag(pad, CGPointMake(90, 50), CGPointMake(20, 52), 3);
	drag(pad, CGPointMake(20, 50), CGPointMake(90, 50), 3);
	expect([_recorder.events isEqual:@[ @"UISwipeGestureRecognizer:3" ]], "swipe left, not right", [_recorder.events description]);
	[pad removeGestureRecognizer:swipe];

	/* A button's own tap wins over a single tap recognizer above it. */
	UITapGestureRecognizer *above = [[UITapGestureRecognizer alloc] initWithTarget:_recorder action:@selector(fired:)];
	[stage addGestureRecognizer:above];
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	[button setFrame:CGRectMake(150, 0, 80, 40)];
	[button addTarget:_recorder action:@selector(button:) forControlEvents:UIControlEventTouchUpInside];
	[stage addSubview:button];
	[_recorder.events removeAllObjects];
	tap(button, CGPointMake(40, 20));
	expect([_recorder.events isEqual:@[ @"button" ]], "a control's tap beats a recognizer above it", [_recorder.events description]);
	[stage removeGestureRecognizer:above];
	[button removeFromSuperview];
	[pad removeFromSuperview];
}

- (void)checks
{
	/* UIViewController: -init is -initWithNibName:nil bundle:nil. */
	UIViewController *named = [[UIViewController alloc] initWithNibName:@"Main" bundle:[NSBundle mainBundle]];
	expect([[named nibName] isEqualToString:@"Main"] && [named nibBundle] == [NSBundle mainBundle], "initWithNibName:bundle: keeps the nib", nil);

	Files *files = [[Files alloc] init];
	UITableView *table = [files tableView];
	expect(table != nil && [files view] == table && [table dataSource] == files && [table delegate] == files, "UITableViewController owns its table", nil);
	expect([table style] == UITableViewStyleGrouped, "initWithStyle: from an -init override", nil);
	expect([files clearsSelectionOnViewWillAppear], "clears selection by default", nil);
	[files viewWillAppear:NO];
	expect([table numberOfRowsInSection:0] == 3, "the table has the subclass's rows", nil);
	[table selectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
	[files viewWillAppear:NO];
	expect([table indexPathForSelectedRow] == nil, "appearing again clears the selection", nil);
	[files setEditing:YES animated:NO];
	expect([table isEditing], "editing reaches the table", nil);

	UITableViewHeaderFooterView *header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"h"];
	[[header textLabel] setText:@"Section"];
	expect([[header reuseIdentifier] isEqualToString:@"h"] && [[header textLabel] superview] == [header contentView], "UITableViewHeaderFooterView", nil);
	[table registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"h"];
	expect([[table dequeueReusableHeaderFooterViewWithIdentifier:@"h"] isKindOfClass:[UITableViewHeaderFooterView class]], "header views dequeue", nil);

	/* Flow layout: 50-point items, 10 apart, inset 10, in 320 points: 5 a
	   row, 4 rows; 150 points tall shows the first 2. */
	UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
	[flow setItemSize:CGSizeMake(50, 50)];
	[flow setSectionInset:UIEdgeInsetsMake(10, 10, 10, 10)];
	[flow setHeaderReferenceSize:CGSizeMake(0, 30)];
	UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 150) collectionViewLayout:flow];
	[collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
	_grid = [[Grid alloc] init];
	_grid.count = 20;
	[collection setDataSource:_grid];
	[collection setDelegate:_grid];
	[collection layoutIfNeeded];
	CGRect first = [[collection layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]] frame];
	CGRect fifth = [[collection layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:4 inSection:0]] frame];
	CGRect sixth = [[collection layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:5 inSection:0]] frame];
	expect(CGRectEqualToRect(first, CGRectMake(10, 40, 50, 50)), "first item below the header and inset", rect(first));
	expect(near(CGRectGetMaxX(fifth), 310) && near(sixth.origin.x, 10) && near(sixth.origin.y, 100), "items wrap into rows", rect(sixth));
	CGSize content = [collection contentSize];
	expect(near(content.height, 40 + 4 * 50 + 3 * 10 + 10) && near(content.width, 320), "content size", NSStringFromCGSize(content));
	expect([[collection visibleCells] count] == 10, "only cells in sight have views", [NSString stringWithFormat:@"%lu", (unsigned long)[[collection visibleCells] count]]);
	[collection setContentOffset:CGPointMake(0, 100)];
	expect([collection cellForItemAtIndexPath:[NSIndexPath indexPathForItem:19 inSection:0]] != nil
	       && [collection cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]] == nil, "scrolling reuses cells", nil);
	[collection setContentOffset:CGPointZero];
	expect([[collection indexPathForItemAtPoint:CGPointMake(75, 45)] item] == 1, "indexPathForItemAtPoint:", nil);

	/* Toolbar: a flexible space pushes the last item to the edge. */
	UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:nil action:NULL];
	UIBarButtonItem *right = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:nil action:NULL];
	UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
	[toolbar setItems:@[ left, space, right ]];
	[toolbar layoutSubviews];
	NSArray *bars = [toolbar subviews];
	CGRect leftFrame = [(UIView *)[bars firstObject] frame], rightFrame = [(UIView *)[bars lastObject] frame];
	expect([bars count] == 2 && near(leftFrame.origin.x, 8) && near(CGRectGetMaxX(rightFrame), 312), "toolbar items around a flexible space",
	       [NSString stringWithFormat:@"%@ %@", rect(leftFrame), rect(rightFrame)]);

	UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 31)];
	[slider setMinimumValue:10];
	[slider setMaximumValue:20];
	[slider setValue:25];
	expect([slider value] == 20, "slider values clamp", nil);
	UIProgressView *progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	[progress setProgress:1.5];
	expect([progress progress] == 1, "progress clamps", nil);
	UIPageControl *pages = [[UIPageControl alloc] init];
	[pages setNumberOfPages:3];
	[pages setCurrentPage:5];
	expect([pages currentPage] == 2, "page control clamps the page", nil);

	_wheel = [[Wheel alloc] init];
	UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectZero];
	[picker setDataSource:_wheel];
	[picker setDelegate:_wheel];
	[picker reloadAllComponents];
	[picker selectRow:7 inComponent:0 animated:NO];
	[picker selectRow:9 inComponent:1 animated:NO];
	expect([picker numberOfComponents] == 2 && [picker selectedRowInComponent:0] == 7 && [picker selectedRowInComponent:1] == 2,
	       "picker components and selection", nil);

	UITextView *text = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
	[text setText:@"Hello\nworld"];
	[text setFont:[UIFont systemFontOfSize:15]];
	expect([[text text] isEqualToString:@"Hello\nworld"] && [text isEditable], "UITextView text", [text text]);
	expect([[text textStorage] length] == 11 && [text layoutManager] != nil, "UITextView text storage", nil);

	/* UIBezierPath and an image context. */
	UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 100, 50) cornerRadius:10];
	expect(CGRectEqualToRect(CGRectIntegral([box bounds]), CGRectMake(0, 0, 100, 50)), "rounded rect bounds", rect([box bounds]));
	expect([box containsPoint:CGPointMake(50, 25)] && ![box containsPoint:CGPointMake(1, 1)], "rounded corners are outside", nil);
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 10), NO, 2);
	[[UIColor redColor] setFill];
	[[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 10, 10)] fill];
	UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	expect(drawn != nil && CGSizeEqualToSize([drawn size], CGSizeMake(20, 10)) && [drawn scale] == 2, "image context size and scale",
	       NSStringFromCGSize([drawn size]));
	CGImageRef pixels = [drawn CGImage];
	CFDataRef data = pixels != NULL ? CGDataProviderCopyData(CGImageGetDataProvider(pixels)) : NULL;
	if (data != NULL) {
		const uint8_t *bytes = CFDataGetBytePtr(data);
		size_t row = CGImageGetBytesPerRow(pixels);
		/* 40x20 pixels, little-endian ARGB (BGRA in memory): the left half
		   red, the right half clear. */
		const uint8_t *leftPixel = bytes + 10 * row + 5 * 4, *rightPixel = bytes + 10 * row + 30 * 4;
		expect(CGImageGetWidth(pixels) == 40 && CGImageGetHeight(pixels) == 20, "image context pixel size",
		       [NSString stringWithFormat:@"%zux%zu", CGImageGetWidth(pixels), CGImageGetHeight(pixels)]);
		expect(leftPixel[2] > 200 && leftPixel[1] < 50 && leftPixel[3] > 200 && rightPixel[3] == 0, "image context pixels",
		       [NSString stringWithFormat:@"%d %d %d %d / %d", leftPixel[0], leftPixel[1], leftPixel[2], leftPixel[3], rightPixel[3]]);
		CFRelease(data);
	} else {
		expect(NO, "image context pixels", @"no data");
	}

	/* Containers. */
	UINavigationController *primary = [[UINavigationController alloc] initWithRootViewController:[[UIViewController alloc] init]];
	UISplitViewController *split = [[UISplitViewController alloc] init];
	[split setViewControllers:@[ primary ]];
	UIViewController *detail = [[UIViewController alloc] init];
	[split showDetailViewController:detail sender:nil];
	expect([primary topViewController] == detail && [detail splitViewController] == split, "a phone split view pushes the detail", nil);
	UIPageViewController *pager = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
	                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	UIViewController *page = [[UIViewController alloc] init];
	[pager setViewControllers:@[ page ] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
	[pager view];
	expect([[pager viewControllers] firstObject] == page && [[page view] superview] == [pager view] && [[pager gestureRecognizers] count] == 2,
	       "page view controller shows its page", nil);
	__block BOOL performed = NO;
	UIStoryboardSegue *segue = [UIStoryboardSegue segueWithIdentifier:@"open" source:split destination:detail performHandler:^{ performed = YES; }];
	[segue perform];
	expect(performed && [[segue identifier] isEqualToString:@"open"] && [segue destinationViewController] == detail, "storyboard segue", nil);

	/* Pasteboard items. */
	UIPasteboard *board = [UIPasteboard pasteboardWithUniqueName];
	[board setItems:@[ @{ @"public.utf8-plain-text": @"a" }, @{ @"public.url": [NSURL URLWithString:@"file:///b"] }, @{ @"public.utf8-plain-text": @"c" } ]];
	NSIndexSet *strings = [board itemSetWithPasteboardTypes:@[ @"public.utf8-plain-text" ]];
	expect([board numberOfItems] == 3 && [strings count] == 2 && [strings containsIndex:2], "itemSetWithPasteboardTypes:", nil);
	expect([[board strings] isEqual:@[ @"a", @"c" ]] && [[[board URL] path] isEqualToString:@"/b"], "strings and URL of the items", nil);
	NSInteger changes = [board changeCount];
	[board setString:@"x"];
	expect([board changeCount] == changes + 1 && [board numberOfItems] == 1 && [board hasStrings] && ![board hasURLs], "setString: replaces the items", nil);

	/* Appearance, applied when a view goes on screen. */
	[[UILabel appearance] setTextColor:[UIColor redColor]];
	[[UILabel appearanceWhenContainedInInstancesOfClasses:@[ [UIToolbar class] ]] setTextColor:[UIColor greenColor]];
	UILabel *plain = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
	UILabel *inBar = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
	[bar addSubview:inBar];
	[_window addSubview:plain];
	[_window addSubview:bar];
	CGFloat r, g, b, a;
	[[plain textColor] getRed:&r green:&g blue:&b alpha:&a];
	expect(r > 0.9 && g < 0.1, "appearance proxy", nil);
	[[inBar textColor] getRed:&r green:&g blue:&b alpha:&a];
	expect(g > 0.9 && r < 0.1, "contained appearance wins", nil);
	[plain removeFromSuperview];
	[bar removeFromSuperview];

	/* Auto Layout through guides. */
	UIView *frame = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
	UIView *child = [[UIView alloc] initWithFrame:CGRectZero];
	[child setTranslatesAutoresizingMaskIntoConstraints:NO];
	[frame addSubview:child];
	[frame setLayoutMargins:UIEdgeInsetsMake(5, 20, 5, 20)];
	[NSLayoutConstraint activateConstraints:@[
		[[child leadingAnchor] constraintEqualToAnchor:[[frame layoutMarginsGuide] leadingAnchor]],
		[[child trailingAnchor] constraintEqualToAnchor:[[frame layoutMarginsGuide] trailingAnchor]],
		[[child topAnchor] constraintEqualToAnchor:[[frame safeAreaLayoutGuide] topAnchor] constant:10],
		[[child heightAnchor] constraintEqualToConstant:30],
	]];
	[frame layoutIfNeeded];
	expect(CGRectEqualToRect([child frame], CGRectMake(20, 10, 160, 30)), "constraints to layout guides", rect([child frame]));
	expect(CGRectEqualToRect([[frame layoutMarginsGuide] layoutFrame], CGRectMake(20, 5, 160, 90)), "a guide's frame", rect([[frame layoutMarginsGuide] layoutFrame]));
	UILabel *sized = [[UILabel alloc] initWithFrame:CGRectZero];
	[sized setText:@"Intrinsic"];
	NSSize intrinsic = [sized intrinsicContentSize];
	expect(intrinsic.width > 20 && intrinsic.height > 10, "a label's intrinsic size", NSStringFromSize(intrinsic));

	/* iOS 7 string drawing with UIKit's fonts. */
	CGRect bounds = [@"Measure me" boundingRectWithSize:CGSizeMake(300, 100) options:NSStringDrawingUsesLineFragmentOrigin
	                                         attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:20] } context:nil];
	CGSize small = [@"Measure me" sizeWithAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:10] }];
	expect(bounds.size.width > small.width && bounds.size.height > small.height, "string sizes with UIFonts",
	       [NSString stringWithFormat:@"%@ %@", rect(bounds), NSStringFromCGSize(small)]);
	expect([[UIFont preferredFontForTextStyle:UIFontTextStyleBody] pointSize] == 17, "preferredFontForTextStyle:", nil);
	expect([UIColor labelColor] != nil && [UIColor systemBackgroundColor] != nil, "iOS 13 system colors", nil);

	/* What UIKit lacks answers nil instead of raising. */
	BOOL raised = NO;
	id answer = @"unset";
	@try {
		answer = ((id (*)(id, SEL))objc_msgSend)(frame, NSSelectorFromString(@"notAUIKitMethodYet"));
	} @catch (NSException *exception) {
		raised = YES;
	}
	expect(!raised && answer == nil && ![frame respondsToSelector:NSSelectorFromString(@"notAUIKitMethodYet")], "unimplemented methods answer nil", nil);
}

- (void)checkScreen:(UICollectionView *)grid toolbar:(UIToolbar *)toolbar started:(NSDate *)started
{
	if (sTileDraws < 20 && -[started timeIntervalSinceNow] < 30) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 4), dispatch_get_main_queue(), ^{
			[self checkScreen:grid toolbar:toolbar started:started];
		});
		return;
	}
	NSUInteger shown = 0;
	for (UICollectionViewCell *cell in [grid visibleCells])
		if ([cell window] != nil && ![cell isHidden] && [cell frame].size.width == 60)
			shown++;
	expect(shown == [[grid visibleCells] count] && shown == 20, "the grid's cells are on screen",
	       [NSString stringWithFormat:@"%lu of %lu", (unsigned long)shown, (unsigned long)[[grid visibleCells] count]]);
	expect(sTileDraws >= 20, "the grid's cells are drawn", [NSString stringWithFormat:@"%d draws after %.1f s", sTileDraws, -[started timeIntervalSinceNow]]);
	NSMutableArray *frames = [NSMutableArray array];
	for (UIView *item in [toolbar subviews])
		[frames addObject:rect([item frame])];
	expect([[toolbar subviews] count] == 3 && [[[toolbar subviews] lastObject] frame].size.width > 0, "toolbar items laid out on screen",
	       [frames componentsJoinedByString:@" "]);
	/* Left up a little longer, for a screenshot. */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		printf("%d failure(s)\n", failures);
		fflush(stdout);
		exit(failures != 0);
	});
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	NSString *version = [[UIDevice currentDevice] systemVersion];
	expect([version isEqualToString:@"14.0"] && [[[UIDevice currentDevice] systemName] isEqualToString:@"iOS"],
	       "the device reports iOS 14", version);
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIViewController *controller = [[UIViewController alloc] init];
	UIView *view = [controller view];
	[view setBackgroundColor:[UIColor whiteColor]];
	_window.rootViewController = controller;
	[_window makeKeyAndVisible];

	[self checks];
	[self gestureChecksIn:view];

	/* A showcase for the screenshot. */
	UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, [view bounds].size.width, 44)];
	[toolbar setItems:@[
		[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:nil action:NULL],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
		[[UIBarButtonItem alloc] initWithTitle:@"Toolbar" style:UIBarButtonItemStylePlain target:nil action:NULL],
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL],
		[[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:nil action:NULL],
	]];
	[view addSubview:toolbar];
	UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(20, 60, 280, 31)];
	[slider setValue:0.35];
	[view addSubview:slider];
	UIProgressView *progress = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 105, 280, 2)];
	[progress setProgress:0.6];
	[view addSubview:progress];
	UIPageControl *pages = [[UIPageControl alloc] initWithFrame:CGRectMake(20, 115, 280, 30)];
	[pages setNumberOfPages:5];
	[pages setCurrentPage:1];
	[pages setPageIndicatorTintColor:[UIColor lightGrayColor]];
	[pages setCurrentPageIndicatorTintColor:[UIColor darkGrayColor]];
	[view addSubview:pages];
	UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 150, [view bounds].size.width, 160)];
	[picker setDataSource:_wheel];
	[picker setDelegate:_wheel];
	[picker selectRow:4 inComponent:0 animated:NO];
	[picker selectRow:1 inComponent:1 animated:NO];
	[view addSubview:picker];
	UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
	[flow setItemSize:CGSizeMake(60, 60)];
	[flow setSectionInset:UIEdgeInsetsMake(10, 10, 10, 10)];
	UICollectionView *grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 320, [view bounds].size.width, 160) collectionViewLayout:flow];
	[grid setBackgroundColor:[UIColor colorWithWhite:0.95 alpha:1]];
	[grid registerClass:[Tile class] forCellWithReuseIdentifier:@"cell"];
	[grid setDataSource:_grid];
	[grid setDelegate:_grid];
	[view addSubview:grid];
	UITextView *text = [[UITextView alloc] initWithFrame:CGRectMake(20, 490, 280, 60)];
	[text setFont:[UIFont systemFontOfSize:15]];
	[text setText:@"A UITextView: AppKit's text system, scrolled by UIKit."];
	[text setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:0.9 alpha:1]];
	[view addSubview:text];

	/* Once the run loop has laid them out and drawn them, they are on
	   screen. Software rendering in a VM can take a while, so this waits
	   for the drawing rather than a fixed time. */
	[self checkScreen:grid toolbar:toolbar started:[NSDate date]];
	return YES;
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
