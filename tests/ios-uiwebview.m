/* UIWebView over darling-webhost, and the UIKit around it that Cydia-style
   apps use: a navigation controller over a table, a pushed web view whose
   page calls an Objective-C object exposed in -webView:didClearWindowObject:
   forFrame: (as Cydia exposes window.cydia), and Objective-C calling back
   into the page.  One PASS/FAIL line per check; exits nonzero on any
   failure.  Needs darling-webhost running on the same display; see
   ios-uiwebview.md. */

#import <UIKit/UIKit.h>
#import <WebKitLegacy/WebKitLegacy.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

/* What the page sees as window.bridge. */
@interface Bridge : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) int calls;
@property (nonatomic, copy) NSString *lastMessage;
@end

@implementation Bridge

+ (NSString *)webScriptNameForSelector:(SEL)selector
{
	if (selector == @selector(add:to:))
		return @"add";
	if (selector == @selector(log:))
		return @"log";
	if (selector == @selector(items))
		return @"items";
	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
	return [self webScriptNameForSelector:selector] == nil;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return strcmp(name, "name") != 0;
}

- (NSArray *)attributeKeys
{
	return @[ @"name" ];
}

- (int)add:(int)a to:(int)b
{
	_calls++;
	return a + b;
}

- (void)log:(NSString *)message
{
	_lastMessage = [message copy];
}

- (NSArray *)items
{
	return @[ @"one", @2, @YES ];
}

@end

/* Private UIKit API, declared by apps the way Cydia's iPhonePrivate.h does. */
@interface UIWebView (WebKitDelegate)
- (void)webView:(WebView *)view didClearWindowObject:(WebScriptObject *)window forFrame:(WebFrame *)frame;
@end

@interface TestWebView : UIWebView
@property (nonatomic, strong) Bridge *bridge;
@property (nonatomic) int cleared;
@end

@implementation TestWebView

- (void)webView:(WebView *)view didClearWindowObject:(WebScriptObject *)window forFrame:(WebFrame *)frame
{
	[super webView:view didClearWindowObject:window forFrame:frame];
	_cleared++;
	[window setValue:_bridge forKey:@"bridge"];
}

@end

static NSString *const TestPage = @"<!DOCTYPE html><html><head><title>Bridge test</title></head>"
	"<body style='font: 24px sans-serif; background: #e7f0f7'>"
	"<h1 id='h'>Darling UIWebView</h1><p id='out'>waiting</p>"
	"<script>"
	"var sum = bridge.add(2, 3);"
	"var items = bridge.items();"
	"bridge.log('hello from ' + navigator.userAgent.split(' ')[1]);"
	"document.getElementById('out').textContent = 'add(2,3) = ' + sum + ', name = ' + bridge.name + ', items = ' + items.length;"
	"function twice(x) { return x * 2; }"
	"</script></body></html>";

@interface WebController : UIViewController <UIWebViewDelegate>
@property (nonatomic, strong) TestWebView *webView;
@property (nonatomic) BOOL finished;
@end

@implementation WebController

- (void)loadView
{
	_webView = [[TestWebView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	_webView.bridge = [[Bridge alloc] init];
	_webView.bridge.name = @"Objective-C";
	_webView.delegate = self;
	[_webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	self.view = _webView;
	self.title = @"Page";
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	_finished = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	printf("load failed: %s\n", [[error description] UTF8String]);
}

@end

@interface ListController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@end

@implementation ListController

- (void)loadView
{
	_table = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	_table.dataSource = self;
	_table.delegate = self;
	self.view = _table;
	self.title = @"Sources";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 500;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	cell.textLabel.text = [NSString stringWithFormat:@"Package %ld", (long)indexPath.row];
	cell.detailTextLabel.text = @"from a test repository";
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) ListController *list;
@property (nonatomic, strong) WebController *web;
@property (nonatomic) int ticks;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	_window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
	_list = [[ListController alloc] init];
	_navigation = [[UINavigationController alloc] initWithRootViewController:_list];
	UITabBarController *tabs = [[UITabBarController alloc] init];
	_navigation.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Sources" image:nil tag:0];
	UIViewController *other = [[UIViewController alloc] init];
	other.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search" image:nil tag:1];
	tabs.viewControllers = @[ _navigation, other ];
	_window.rootViewController = tabs;
	[_window makeKeyAndVisible];

	expect([_list.table numberOfRowsInSection:0] == 500, "table rows", nil);
	expect([[_list.table visibleCells] count] > 0 && [[_list.table visibleCells] count] < 30, "table tiles only visible cells",
	       [NSString stringWithFormat:@"%lu cells", (unsigned long)[[_list.table visibleCells] count]]);
	[_list.table setContentOffset:CGPointMake(0, 44 * 200)];
	UITableViewCell *cell = [[_list.table visibleCells] firstObject];
	expect([cell.textLabel.text hasPrefix:@"Package 2"], "table reuses cells while scrolling", cell.textLabel.text);
	[_list.table setContentOffset:CGPointZero];

	_web = [[WebController alloc] init];
	[_navigation pushViewController:_web animated:YES];
	expect(_navigation.topViewController == _web && [_navigation.navigationBar.items count] == 2, "push onto the navigation stack", nil);
	[_web.webView loadHTMLString:TestPage baseURL:[NSURL URLWithString:@"https://example.com/"]];

	[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
	return YES;
}

- (void)tick:(NSTimer *)timer
{
	if (!_web.finished && ++_ticks < 60)
		return;
	[timer invalidate];
	TestWebView *webView = _web.webView;
	expect(_web.finished, "page loaded (webViewDidFinishLoad:)", nil);
	expect(webView.cleared > 0, "didClearWindowObject reached the UIWebView subclass", nil);
	expect(webView.bridge.calls == 1, "page called an Objective-C method", [NSString stringWithFormat:@"%d calls", webView.bridge.calls]);
	expect([webView.bridge.lastMessage hasPrefix:@"hello from"], "page passed a string to Objective-C", webView.bridge.lastMessage);
	NSString *out = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('out').textContent"];
	expect([out isEqualToString:@"add(2,3) = 5, name = Objective-C, items = 3"], "values crossed both ways", out);
	NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	expect([title isEqualToString:@"Bridge test"], "stringByEvaluatingJavaScriptFromString", title);
	WebScriptObject *window = [[[webView _documentView] webView] windowScriptObject];
	id doubled = [window callWebScriptMethod:@"twice" withArguments:@[ @21 ]];
	expect([doubled intValue] == 42, "WebScriptObject callWebScriptMethod", [doubled description]);
	expect([[[webView request] URL] isEqual:[NSURL URLWithString:@"https://example.com/"]], "request URL", [[[webView request] URL] absoluteString]);

	/* Leave it up for a screenshot, then report. */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		printf("%d failure(s)\n", failures);
		fflush(stdout);
		exit(failures != 0);
	});
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
