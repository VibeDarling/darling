/* UIButton and what it draws with: the tint color views inherit, template
   images, attributed and shadowed titles, edge insets and the iOS layout
   hooks, the highlighted and disabled looks, and the info and add glyphs.
   One PASS/FAIL line per check; exits nonzero on any failure.  It then
   shows the buttons for a few seconds, for a screenshot; see
   ios-uibutton.md. */

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static BOOL sameColor(UIColor *a, UIColor *b)
{
	CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
	if (a == nil || b == nil || ![a getRed:&r1 green:&g1 blue:&b1 alpha:&a1] || ![b getRed:&r2 green:&g2 blue:&b2 alpha:&a2])
		return NO;
	return fabs(r1 - r2) < 0.01 && fabs(g1 - g2) < 0.01 && fabs(b1 - b2) < 0.01 && fabs(a1 - a2) < 0.01;
}

static NSString *rect(CGRect r)
{
	return [NSString stringWithFormat:@"{%g, %g, %g, %g}", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

/* A 20-point black disc on a transparent background. */
static UIImage *disc(void)
{
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 20, 20, 8, 80, space, kCGImageAlphaPremultipliedLast);
	CGContextSetRGBFillColor(context, 0, 0, 0, 1);
	CGContextFillEllipseInRect(context, CGRectMake(2, 2, 16, 16));
	CGImageRef image = CGBitmapContextCreateImage(context);
	UIImage *result = [UIImage imageWithCGImage:image];
	CGImageRelease(image);
	CGContextRelease(context);
	CGColorSpaceRelease(space);
	return result;
}

@interface TintWatcher : UIView
@property (nonatomic) int changes;
@end

@implementation TintWatcher
- (void)tintColorDidChange
{
	[super tintColorDidChange];
	_changes++;
}
@end

/* A subclass that moves its title with the iOS layout hook. */
@interface HookButton : UIButton
@end

@implementation HookButton
- (CGRect)titleRectForContentRect:(CGRect)contentRect
{
	return CGRectMake(1, 2, 30, 20);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (void)checks
{
	UIImage *image = disc();

	/* Tint. */
	UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
	TintWatcher *middle = [[TintWatcher alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
	[root addSubview:middle];
	UIButton *system = [UIButton buttonWithType:UIButtonTypeSystem];
	[system setTitle:@"Tap" forState:UIControlStateNormal];
	[middle addSubview:system];
	expect(sameColor([system tintColor], [UIColor systemBlueColor]), "default tint is the system blue", nil);
	expect(sameColor([system currentTitleColor], [UIColor systemBlueColor]), "system button title in the tint", nil);
	int before = [middle changes];
	[root setTintColor:[UIColor redColor]];
	expect([middle changes] == before + 1, "tintColorDidChange reaches inheriting views", nil);
	expect(sameColor([system tintColor], [UIColor redColor]), "tint inherited from an ancestor", nil);
	expect(sameColor([system currentTitleColor], [UIColor redColor]) && sameColor([[system titleLabel] textColor], [UIColor redColor]),
	       "system title follows the inherited tint", nil);
	[middle setTintColor:[UIColor greenColor]];
	before = [middle changes];
	[root setTintColor:[UIColor blueColor]];
	expect([middle changes] == before && sameColor([system tintColor], [UIColor greenColor]), "own tint stops inheritance", nil);
	[root setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
	expect([system tintAdjustmentMode] == UIViewTintAdjustmentModeDimmed && !sameColor([system tintColor], [UIColor greenColor]),
	       "dimmed tint adjustment is inherited", nil);
	UIButton *off = [UIButton buttonWithType:UIButtonTypeSystem];
	[off setEnabled:NO];
	expect(!sameColor([off currentTitleColor], [off tintColor]), "disabled system title is not the tint", nil);

	/* Images. */
	UIImage *template = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	expect([image renderingMode] == UIImageRenderingModeAutomatic && [template renderingMode] == UIImageRenderingModeAlwaysTemplate,
	       "imageWithRenderingMode:", nil);
	expect(CGSizeEqualToSize([template size], [image size]), "a template keeps the size", nil);
	UIImage *red = [image imageWithTintColor:[UIColor redColor]];
	expect(red != nil && CGSizeEqualToSize([red size], [image size]) && [red renderingMode] == UIImageRenderingModeAlwaysOriginal,
	       "imageWithTintColor:", nil);

	/* Layout: image then title, centred as a group. */
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setFrame:CGRectMake(0, 0, 200, 44)];
	[button setTitle:@"Hello" forState:UIControlStateNormal];
	[button setImage:image forState:UIControlStateNormal];
	[button layoutSubviews];
	CGRect imageFrame = [[button imageView] frame], titleFrame = [[button titleLabel] frame];
	CGFloat group = imageFrame.size.width + titleFrame.size.width - 1;
	expect(CGSizeEqualToSize(imageFrame.size, CGSizeMake(20, 20)) && fabs(imageFrame.origin.x - floor((200 - group) / 2)) <= 1 &&
	       fabs(CGRectGetMaxX(imageFrame) - titleFrame.origin.x) <= 1 && fabs(CGRectGetMidY(imageFrame) - 22) <= 1,
	       "image and title centred side by side", [NSString stringWithFormat:@"image %@ title %@", rect(imageFrame), rect(titleFrame)]);
	[button setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
	[button layoutSubviews];
	expect(fabs([[button titleLabel] frame].origin.x - (titleFrame.origin.x + 5)) <= 1 && CGRectEqualToRect([[button imageView] frame], imageFrame),
	       "titleEdgeInsets move only the title", rect([[button titleLabel] frame]));
	[button setTitleEdgeInsets:UIEdgeInsetsZero];
	[button setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 10)];
	[button layoutSubviews];
	expect(fabs([[button imageView] frame].origin.x - (imageFrame.origin.x - 5)) <= 1 && fabs([[button titleLabel] frame].origin.x - titleFrame.origin.x) <= 1,
	       "imageEdgeInsets move only the image", rect([[button imageView] frame]));
	[button setImageEdgeInsets:UIEdgeInsetsZero];
	[button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
	[button setContentVerticalAlignment:UIControlContentVerticalAlignmentTop];
	[button setContentEdgeInsets:UIEdgeInsetsMake(4, 8, 0, 0)];
	[button layoutSubviews];
	expect([[button imageView] frame].origin.x == 8 && [[button imageView] frame].origin.y == 4, "content insets and alignment",
	       rect([[button imageView] frame]));
	CGSize fits = [button sizeThatFits:CGSizeZero];
	expect(fits.width >= group + 8 && fits.height >= 24, "sizeThatFits counts the insets", NSStringFromCGSize(fits));
	HookButton *hook = [HookButton buttonWithType:UIButtonTypeCustom];
	[hook setFrame:CGRectMake(0, 0, 100, 40)];
	[hook setTitle:@"Hook" forState:UIControlStateNormal];
	[hook layoutSubviews];
	expect([[hook titleLabel] frame].origin.x == 1 && [[hook titleLabel] frame].origin.y == 2, "titleRectForContentRect: override", nil);

	/* Titles. */
	NSAttributedString *fancy = [[NSAttributedString alloc] initWithString:@"Fancy"
	    attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:22], NSForegroundColorAttributeName: [UIColor purpleColor] }];
	[button setAttributedTitle:fancy forState:UIControlStateNormal];
	[button setTitle:nil forState:UIControlStateNormal];
	expect([[button currentTitle] isEqualToString:@"Fancy"] && [[[button titleLabel] attributedText] isEqual:fancy], "attributed title", [button currentTitle]);
	UILabel *plain = [[UILabel alloc] initWithFrame:CGRectZero];
	[plain setText:@"Fancy"];
	[plain setFont:[UIFont systemFontOfSize:10]];
	expect([[button titleLabel] sizeThatFits:CGSizeZero].height > [plain sizeThatFits:CGSizeZero].height, "attributed font used for size", nil);
	[button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
	[button setReversesTitleShadowWhenHighlighted:YES];
	[[button titleLabel] setShadowOffset:CGSizeMake(0, 1)];
	expect(sameColor([[button titleLabel] shadowColor], [UIColor blackColor]), "title shadow color", nil);
	[button setHighlighted:YES];
	CGSize reversed = [[button titleLabel] shadowOffset];
	[button setHighlighted:NO];
	expect(reversed.height == -1 && [[button titleLabel] shadowOffset].height == 1, "reversesTitleShadowWhenHighlighted", nil);

	/* Highlight glow. */
	NSUInteger subviews = [[button subviews] count];
	[button setShowsTouchWhenHighlighted:YES];
	[button setHighlighted:YES];
	NSUInteger lit = [[button subviews] count];
	[button setHighlighted:NO];
	expect(lit == subviews + 1 && [[button subviews] count] == subviews, "showsTouchWhenHighlighted glow comes and goes", nil);

	/* Glyph buttons. */
	UIButton *info = [UIButton buttonWithType:UIButtonTypeInfoDark];
	UIButton *add = [UIButton buttonWithType:UIButtonTypeContactAdd];
	expect([info currentImage] != nil && [[info currentImage] renderingMode] == UIImageRenderingModeAlwaysTemplate &&
	       CGSizeEqualToSize([[info currentImage] size], CGSizeMake(22, 22)) && [[info currentTitle] length] == 0,
	       "info button draws a template glyph", nil);
	expect([add currentImage] != nil && [add currentImage] != [info currentImage], "add button has its own glyph", nil);
	UIButton *made = [UIButton systemButtonWithImage:image target:self action:@selector(checks)];
	expect([made buttonType] == UIButtonTypeSystem && [made currentImage] == image && [[made allTargets] containsObject:self],
	       "systemButtonWithImage:target:action:", nil);
}

- (UIButton *)showcase:(UIView *)view y:(CGFloat)y type:(UIButtonType)type title:(NSString *)title
{
	UIButton *button = [UIButton buttonWithType:type];
	if (title != nil)
		[button setTitle:title forState:UIControlStateNormal];
	[button setFrame:CGRectMake(20, y, type == UIButtonTypeCustom || type == UIButtonTypeSystem ? 200 : 22, type == UIButtonTypeCustom || type == UIButtonTypeSystem ? 40 : 22)];
	[view addSubview:button];
	return button;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	[self checks];

	_window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
	UIViewController *controller = [[UIViewController alloc] init];
	UIView *view = [controller view];
	[view setBackgroundColor:[UIColor whiteColor]];
	UIImage *image = disc();

	[self showcase:view y:40 type:UIButtonTypeSystem title:@"System"];
	UIButton *icon = [self showcase:view y:90 type:UIButtonTypeSystem title:@"Template image"];
	[icon setImage:image forState:UIControlStateNormal];
	[icon setTitleEdgeInsets:UIEdgeInsetsMake(0, 8, 0, 0)];
	UIButton *orange = [self showcase:view y:140 type:UIButtonTypeSystem title:@"Orange tint"];
	[orange setTintColor:[UIColor orangeColor]];
	[orange setImage:image forState:UIControlStateNormal];
	UIButton *dim = [self showcase:view y:190 type:UIButtonTypeSystem title:@"Highlighted"];
	[dim setHighlighted:YES];
	UIButton *off = [self showcase:view y:240 type:UIButtonTypeSystem title:@"Disabled"];
	[off setEnabled:NO];
	[self showcase:view y:300 type:UIButtonTypeInfoLight title:nil];
	UIButton *add = [self showcase:view y:300 type:UIButtonTypeContactAdd title:nil];
	[add setFrame:CGRectMake(60, 300, 22, 22)];
	UIButton *detail = [self showcase:view y:300 type:UIButtonTypeDetailDisclosure title:nil];
	[detail setFrame:CGRectMake(100, 300, 22, 22)];

	UIButton *custom = [self showcase:view y:340 type:UIButtonTypeCustom title:@"Custom, darkened"];
	[custom setBackgroundColor:[UIColor colorWithWhite:0.85 alpha:1]];
	[custom setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
	[custom setImage:[image imageWithTintColor:[UIColor redColor]] forState:UIControlStateNormal];
	[custom setHighlighted:YES];
	UIButton *glow = [self showcase:view y:390 type:UIButtonTypeCustom title:@"Glow"];
	[glow setBackgroundColor:[UIColor darkGrayColor]];
	[glow setShowsTouchWhenHighlighted:YES];
	[glow setHighlighted:YES];
	UIButton *fancy = [self showcase:view y:440 type:UIButtonTypeCustom title:nil];
	[fancy setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Attributed"
	    attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:22], NSForegroundColorAttributeName: [UIColor purpleColor] }]
	               forState:UIControlStateNormal];
	UIButton *shadow = [self showcase:view y:490 type:UIButtonTypeCustom title:@"Shadowed"];
	[shadow setBackgroundColor:[UIColor colorWithRed:0.3 green:0.5 blue:0.8 alpha:1]];
	[shadow setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
	[[shadow titleLabel] setShadowOffset:CGSizeMake(1, 1)];
	UIButton *left = [self showcase:view y:540 type:UIButtonTypeCustom title:@"Left, inset 12"];
	[left setBackgroundColor:[UIColor colorWithWhite:0.9 alpha:1]];
	[left setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
	[left setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
	[left setContentEdgeInsets:UIEdgeInsetsMake(0, 12, 0, 0)];
	[left setImage:[image imageWithTintColor:[UIColor colorWithRed:0 green:0.6 blue:0 alpha:1]] forState:UIControlStateNormal];

	_window.rootViewController = controller;
	[_window makeKeyAndVisible];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		printf("%d failure(s)\n", failures);
		fflush(stdout);
		exit(failures != 0);
	});
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
