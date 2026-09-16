#import <AppKit/AppKit.h>

@interface DarlingApplications : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, retain) NSWindow *window;
@property(nonatomic, retain) NSArray *applications;
@property(nonatomic, retain) NSTableView *table;
@end

@implementation DarlingApplications

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.applications = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Applications" error:NULL];
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *entry in self.applications)
		if ([entry.pathExtension isEqualToString:@"app"]) [items addObject:entry];
	self.applications = [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	NSRect frame = NSMakeRect(0, 0, 720, 480);
	self.window = [[[NSWindow alloc] initWithContentRect:frame styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable) backing:NSBackingStoreBuffered defer:NO] autorelease];
	self.window.title = @"Darling Applications";
	NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, 680, 380)] autorelease];
	self.table = [[[NSTableView alloc] initWithFrame:scroll.bounds] autorelease];
	NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"application"] autorelease];
	column.title = @"Applications"; column.width = 660;
	[self.table addTableColumn:column]; self.table.dataSource = self; self.table.delegate = self;
	scroll.documentView = self.table; scroll.hasVerticalScroller = YES;
	[self.window.contentView addSubview:scroll];
	NSButton *brew = [NSButton buttonWithTitle:@"Install Homebrew" target:self action:@selector(installHomebrew:)]; brew.frame = NSMakeRect(20, 15, 180, 32); [self.window.contentView addSubview:brew];
	NSButton *bundle = [NSButton buttonWithTitle:@"Install Brewfile Apps" target:self action:@selector(installBrewfile:)]; bundle.frame = NSMakeRect(215, 15, 180, 32); [self.window.contentView addSubview:bundle];
	[self.window center]; [self.window makeKeyAndOrderFront:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.applications.count; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row { return self.applications[row]; }

- (void)showMessage:(NSString *)message {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease]; alert.messageText = @"Darling Applications"; alert.informativeText = message; [alert runModal];
}

- (void)installHomebrew:(id)sender {
	NSString *bootstrap = @"/usr/local/libexec/darling/homebrew-bootstrap";
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:bootstrap]) { [self showMessage:@"Native Homebrew bootstrap is not installed. Install the verified Darling bootstrap first; host brew is never used."]; return; }
	NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = bootstrap; task.arguments = @[@"/opt/homebrew"]; [task launch]; [self showMessage:@"Native Homebrew bootstrap started in this Darling prefix."];
}

- (void)installBrewfile:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.canChooseFiles = YES; panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO; panel.title = @"Choose Brewfile";
	if ([panel runModal] != NSModalResponseOK) return;
	NSString *source = panel.URL.path; NSString *user = NSUserName(); NSString *dir = [NSString stringWithFormat:@"/Users/%@/Library/Application Support/Darling/Brewfiles", user];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
	NSString *target = [dir stringByAppendingPathComponent:source.lastPathComponent];
	if (![[NSFileManager defaultManager] copyItemAtPath:source toPath:target error:NULL]) { [self showMessage:@"Could not stage the Brewfile inside the Darling prefix."]; return; }
	NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = @"/opt/homebrew/bin/brew"; task.arguments = @[@"bundle", @"--file", [@"/" stringByAppendingString:[target substringFromIndex:1]]]; [task launch];
	[self showMessage:@"Native brew bundle started. MAS entries still require explicit App Store login."];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(int argc, const char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; DarlingApplications *delegate = [[[DarlingApplications alloc] init] autorelease]; NSApplication *app = [NSApplication sharedApplication]; app.delegate = delegate; [app run]; [pool drain]; return 0;
}
