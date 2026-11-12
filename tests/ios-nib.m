/* Compiled nibs and storyboards, as Xcode builds them for iOS: views and
   controls with their archived properties, File's Owner's outlets and
   actions, an app's own classes (made with -initWithCoder:, never
   -initWithFrame:), awakeFromNib, Auto Layout constraints, images, cells
   from a registered nib, a view controller's view found by its class's
   name, and a storyboard: its entry point (the app's main storyboard),
   scenes by identifier and a segue a button performs. The interface files
   are written by ios-nib-make.py into NibTest.app; see ios-nib.md.

   With DARLING_NIB_FILES=a.nib:b.nib it instead loads those nibs (an
   app's own) and prints what each one holds. */

#import <UIKit/UIKit.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static NSString *rect(CGRect r)
{
	return [NSString stringWithFormat:@"{%g,%g %gx%g}", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static int sCustomFrameInits, sCustomCoderInits;

@interface NibCustomView : UIView
@property (nonatomic, weak) id owner;
@property (nonatomic) BOOL awoke;
@property (nonatomic) BOOL ownerWhenAwoke;
@end

@implementation NibCustomView

- (instancetype)initWithFrame:(CGRect)frame
{
	sCustomFrameInits++;
	return [super initWithFrame:frame];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	sCustomCoderInits++;
	return [super initWithCoder:coder];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	_awoke = YES;
	_ownerWhenAwoke = _owner != nil;
}

@end

@interface NibController : UIViewController
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) IBOutlet UIButton *button;
@property (nonatomic, strong) IBOutlet UITextField *field;
@property (nonatomic, strong) IBOutlet UISwitch *toggle;
@property (nonatomic, strong) IBOutlet UIImageView *image;
@property (nonatomic, strong) IBOutlet NibCustomView *custom;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *toolItem;
@property (nonatomic) int presses, toolPresses, loads;
@end

@implementation NibController
- (void)viewDidLoad { [super viewDidLoad]; _loads++; }
- (IBAction)pressed:(id)sender { _presses++; }
- (IBAction)toolPressed:(id)sender { _toolPresses++; }
@end

@interface NibAutoController : UIViewController
@end
@implementation NibAutoController
@end

@interface NibCell : UITableViewCell
@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@end
@implementation NibCell
@end

@interface NibFirstController : UIViewController
@property (nonatomic, strong) IBOutlet UIButton *nextButton;
@property (nonatomic, copy) NSString *preparedIdentifier;
@property (nonatomic, strong) UIViewController *preparedDestination;
@property (nonatomic) int prepares;
@end

@implementation NibFirstController
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	_prepares++;
	_preparedIdentifier = [segue identifier];
	_preparedDestination = [segue destinationViewController];
}
@end

@interface NibSecondController : UIViewController
@end
@implementation NibSecondController
@end

/* An owner that takes any outlet, for an app's nibs. */
@interface NibAnyOwner : UIViewController
@property (nonatomic) NSUInteger outlets;
@end

@implementation NibAnyOwner
- (void)setValue:(id)value forUndefinedKey:(NSString *)key { _outlets++; }
- (id)valueForUndefinedKey:(NSString *)key { return nil; }
@end

static int loadNibFiles(NSString *list)
{
	int broken = 0;
	for (NSString *path in [list componentsSeparatedByString:@":"]) {
		NSString *file = path;
		BOOL directory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] && directory)
			file = [path stringByAppendingPathComponent:@"runtime.nib"];
		NSData *data = [NSData dataWithContentsOfFile:file];
		NibAnyOwner *owner = [[NibAnyOwner alloc] init];
		NSArray *objects = nil;
		@try {
			objects = [[UINib nibWithData:data bundle:nil] instantiateWithOwner:owner options:nil];
		} @catch (NSException *exception) {
			printf("NIB %s: %s\n", [[path lastPathComponent] UTF8String], [[exception reason] UTF8String]);
			broken++;
			continue;
		}
		NSMutableArray *names = [NSMutableArray array];
		NSUInteger views = 0;
		for (id object in objects) {
			[names addObject:NSStringFromClass([object class])];
			if ([object isKindOfClass:[UIView class]]) {
				NSMutableArray *stack = [NSMutableArray arrayWithObject:object];
				while ([stack count] > 0) {
					NSView *view = [stack lastObject];
					[stack removeLastObject];
					views++;
					[stack addObjectsFromArray:[view subviews]];
				}
			}
		}
		printf("NIB %s: top level %s; %lu views; %lu outlets to File's Owner%s\n", [[path lastPathComponent] UTF8String],
		       [[names componentsJoinedByString:@", "] UTF8String], (unsigned long)views, (unsigned long)[owner outlets],
		       [owner isViewLoaded] ? ", its view connected" : "");
	}
	return broken;
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (void)nibChecks
{
	expect([UINib nibWithNibName:@"Missing" bundle:nil] == nil, "no nib for a name the bundle lacks", nil);

	NibController *controller = [[NibController alloc] initWithNibName:@"Panel" bundle:nil];
	UIView *view = [controller view];
	expect([controller isViewLoaded] && [controller loads] == 1 && view != nil && [view tag] == 0,
	       "a view controller's view comes from its nib", [view description]);
	expect(CGRectEqualToRect([view frame], CGRectMake(0, 0, 320, 480)), "the view's frame (from bounds and center)", rect([view frame]));
	expect([[view subviews] count] == 7, "its subviews, in order", [NSString stringWithFormat:@"%lu", (unsigned long)[[view subviews] count]]);
	CGFloat white = 0, alpha = 0;
	[[view backgroundColor] getWhite:&white alpha:&alpha];
	expect(white > 0.99 && alpha > 0.99, "a named system color (systemBackgroundColor)", [[view backgroundColor] description]);

	UILabel *label = [controller label];
	expect([label isKindOfClass:[UILabel class]] && [[label text] isEqualToString:@"Hello nib"], "a label outlet and its text", [label text]);
	expect([[label font] pointSize] == 20 && [label numberOfLines] == 2 && [label textAlignment] == NSTextAlignmentCenter && [label tag] == 1,
	       "the label's font, lines, alignment and tag",
	       [NSString stringWithFormat:@"%g %ld %ld %ld", [[label font] pointSize], (long)[label numberOfLines], (long)[label textAlignment], (long)[label tag]]);
	CGFloat red = 0, green = 0, blue = 0;
	[[label textColor] getRed:&red green:&green blue:&blue alpha:&alpha];
	expect(red > 0.99 && green < 0.01 && blue < 0.01, "the label's text color", [[label textColor] description]);

	UIButton *button = [controller button];
	expect([button buttonType] == UIButtonTypeSystem && [[button titleForState:UIControlStateNormal] isEqualToString:@"Press"],
	       "a system button and its title", [button titleForState:UIControlStateNormal]);
	[button sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect([controller presses] == 1, "the button's action reaches File's Owner", [NSString stringWithFormat:@"%d", [controller presses]]);
	expect([[[controller field] placeholder] isEqualToString:@"Type here"] && [[controller field] borderStyle] == UITextBorderStyleRoundedRect,
	       "a text field's placeholder and border", [[controller field] placeholder]);
	expect([[controller toggle] isOn], "a switch that is on", nil);
	expect([[[controller image] image] size].width == 16, "an image by name (UIImageNibPlaceholder)",
	       NSStringFromCGSize([[[controller image] image] size]));

	NibCustomView *custom = [controller custom];
	expect([custom isKindOfClass:[NibCustomView class]], "an app's class (UIClassSwapper)", NSStringFromClass([custom class]));
	expect(sCustomCoderInits == 1 && sCustomFrameInits == 0, "it is made with initWithCoder:, never initWithFrame:",
	       [NSString stringWithFormat:@"coder %d, frame %d", sCustomCoderInits, sCustomFrameInits]);
	expect([custom awoke] && [custom ownerWhenAwoke] && [custom owner] == controller,
	       "awakeFromNib comes after the outlets are connected", nil);

	UIToolbar *toolbar = (UIToolbar *)[[view subviews] lastObject];
	expect([toolbar isKindOfClass:[UIToolbar class]] && [[toolbar items] count] == 2 && [[[toolbar items] lastObject] title] != nil,
	       "a toolbar with its items", [[toolbar items] description]);
	UIBarButtonItem *item = [controller toolItem];
	[[item target] performSelector:[item action] withObject:item];
	expect([controller toolPresses] == 1, "a bar button item's action", nil);

	NSArray *constraints = [view constraints];
	NSLayoutConstraint *constraint = [constraints firstObject];
	expect([constraints count] == 1 && [constraint firstItem] == label && [constraint secondItem] == view && [constraint constant] == 20,
	       "a constraint, installed on its view", [constraints description]);
	[_window addSubview:view];
	[view layoutIfNeeded];
	expect([label frame].origin.x == 20, "the constraint lays the label out", rect([label frame]));
	[view removeFromSuperview];

	NibAutoController *automatic = [[NibAutoController alloc] init];
	expect([[automatic view] tag] == 77, "a view controller without a nib name finds one named after its class", nil);

	UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStylePlain];
	[table registerNib:[UINib nibWithNibName:@"Cell" bundle:nil] forCellReuseIdentifier:@"Cell"];
	NibCell *cell = (NibCell *)[table dequeueReusableCellWithIdentifier:@"Cell"];
	expect([cell isKindOfClass:[NibCell class]] && [[cell reuseIdentifier] isEqualToString:@"Cell"],
	       "a table cell from a registered nib", NSStringFromClass([cell class]));
	expect([[[cell nameLabel] text] isEqualToString:@"Cell label"] && [[cell nameLabel] superview] == [cell contentView],
	       "the cell's outlet, inside its content view", [[cell nameLabel] text]);

	NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"NibAuto" owner:nil options:nil];
	expect([objects count] == 1 && [[objects firstObject] tag] == 77, "loadNibNamed:owner:options: leaves out the placeholders",
	       [objects description]);
}

- (void)storyboardChecks
{
	UIViewController *root = [_window rootViewController];
	expect([root isKindOfClass:[NibFirstController class]] && [[root title] isEqualToString:@"First"],
	       "the main storyboard's entry point is the root view controller", NSStringFromClass([root class]));
	expect([root storyboard] != nil, "it knows its storyboard", nil);
	expect([[root view] tag] == 10, "its view comes from the scene's view nib", nil);

	NibFirstController *first = (NibFirstController *)root;
	[[first nextButton] sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect([first prepares] == 1 && [[first preparedIdentifier] isEqualToString:@"next"]
	           && [[first preparedDestination] isKindOfClass:[NibSecondController class]],
	       "a button performs its segue, after prepareForSegue:", [first preparedIdentifier]);
	expect([first presentedViewController] == [first preparedDestination], "the segue presents the destination", nil);
	[first dismissViewControllerAnimated:NO completion:nil];

	[first performSegueWithIdentifier:@"next" sender:nil];
	expect([first prepares] == 2, "performSegueWithIdentifier:sender:", nil);
	[first dismissViewControllerAnimated:NO completion:nil];

	UIViewController *second = [[root storyboard] instantiateViewControllerWithIdentifier:@"Second"];
	expect([second isKindOfClass:[NibSecondController class]] && [[second title] isEqualToString:@"Second"] && [[second view] tag] == 20,
	       "a scene by identifier, with the view archived in it", [second title]);
	BOOL raised = NO;
	@try {
		[[root storyboard] instantiateViewControllerWithIdentifier:@"Nowhere"];
	} @catch (NSException *exception) {
		raised = YES;
	}
	expect(raised, "an unknown identifier raises", nil);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	NSString *files = [[[NSProcessInfo processInfo] environment] objectForKey:@"DARLING_NIB_FILES"];
	if (files != nil)
		exit(loadNibFiles(files));

	expect(_window != nil && [[_window rootViewController] isKindOfClass:[NibFirstController class]],
	       "the main storyboard made the window before launching finished", NSStringFromClass([[_window rootViewController] class]));
	[self nibChecks];
	[self storyboardChecks];
	dispatch_async(dispatch_get_main_queue(), ^{
		expect([self->_window isKeyWindow] || ![self->_window isHidden], "the main storyboard's window is shown", nil);
		printf("%d failures\n", failures);
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
