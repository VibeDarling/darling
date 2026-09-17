#import <AppKit/AppKit.h>

static NSString *FindHelper(NSString *name) {
	NSArray *searchPaths = @[
		[NSString stringWithFormat:@"/usr/libexec/darling/%@", name],
		[NSString stringWithFormat:@"/usr/local/libexec/darling/%@", name],
		[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name],
		[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:name],
	];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *path in searchPaths) {
		if ([fm isExecutableFileAtPath:path])
			return path;
	}
	return nil;
}

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
	NSCell *header = column.headerCell; header.stringValue = @"Applications"; column.width = 660;
	[self.table addTableColumn:column]; self.table.dataSource = self; self.table.delegate = self;
	self.table.doubleAction = @selector(openSelectedApplication:);
	scroll.documentView = self.table; scroll.hasVerticalScroller = YES;
	[self.window.contentView addSubview:scroll];
	NSButton *brew = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 15, 180, 32)] autorelease]; brew.title = @"Install Homebrew"; brew.target = self; brew.action = @selector(installHomebrew:); [self.window.contentView addSubview:brew];
	NSButton *bundle = [[[NSButton alloc] initWithFrame:NSMakeRect(215, 15, 180, 32)] autorelease]; bundle.title = @"Install Brewfile Apps"; bundle.target = self; bundle.action = @selector(installBrewfile:); [self.window.contentView addSubview:bundle];
	NSButton *import = [[[NSButton alloc] initWithFrame:NSMakeRect(410, 15, 180, 32)] autorelease]; import.title = @"Import macOS Apps"; import.target = self; import.action = @selector(importApplications:); [self.window.contentView addSubview:import];
	[self.window center]; [self.window makeKeyAndOrderFront:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.applications.count; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row { return self.applications[row]; }

- (void)openSelectedApplication:(id)sender {
	NSInteger row = self.table.clickedRow >= 0 ? self.table.clickedRow : self.table.selectedRow;
	if (row < 0 || row >= (NSInteger)self.applications.count) return;
	NSString *bundle = [@"/Applications" stringByAppendingPathComponent:self.applications[row]];
	NSURL *url = [NSURL fileURLWithPath:bundle isDirectory:YES];
	NSError *error = nil;
	NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:0 configuration:nil error:&error];
	BOOL launched = (app != nil);
	if (!launched) {
		NSString *detail = error.localizedDescription ?: @"no error detail from NSWorkspace";
		NSLog(@"viewer launch failed: bundle=%@ path=%@ error=%@", self.applications[row], bundle, detail);
		[self showMessage:[NSString stringWithFormat:@"Could not open %@:\n%@", self.applications[row], detail]];
	} else {
		NSLog(@"viewer launch requested: bundle=%@ path=%@ backend=%s wayland=%s", self.applications[row], bundle, getenv("DARLING_APPKIT_BACKEND") ?: "unset", getenv("WAYLAND_DISPLAY") ?: "unset");
	}
}

- (void)showMessage:(NSString *)message {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease]; alert.messageText = @"Darling Applications"; alert.informativeText = message; [alert runModal];
}

- (void)refreshApplications {
	NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Applications" error:NULL];
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *entry in entries) if ([entry.pathExtension isEqualToString:@"app"]) [items addObject:entry];
	self.applications = [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	[self.table reloadData];
}

- (void)importApplications:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseFiles = YES;
	panel.canChooseDirectories = YES;
	panel.allowsMultipleSelection = YES;
	panel.title = @"Choose Application (.app) or Directory to Import";

	NSString *defaultPath = [NSString stringWithFormat:@"/Volumes/SystemRoot/home/%@", NSUserName()];
	if ([[NSFileManager defaultManager] fileExistsAtPath:defaultPath]) {
		panel.directoryURL = [NSURL fileURLWithPath:defaultPath];
	}

	if ([panel runModal] != NSOKButton) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *candidates = [NSMutableArray array];

	for (NSURL *url in panel.URLs) {
		NSString *path = url.path;
		if ([path.pathExtension isEqualToString:@"app"]) {
			[candidates addObject:path];
		} else {
			NSArray *entries = [fm contentsOfDirectoryAtPath:path error:NULL];
			for (NSString *entry in entries) {
				if ([entry.pathExtension isEqualToString:@"app"]) {
					[candidates addObject:[path stringByAppendingPathComponent:entry]];
				} else if ([entry isEqualToString:@"Utilities"]) {
					NSString *utilities = [path stringByAppendingPathComponent:entry];
					for (NSString *child in [fm contentsOfDirectoryAtPath:utilities error:NULL]) {
						if ([child.pathExtension isEqualToString:@"app"]) {
							[candidates addObject:[utilities stringByAppendingPathComponent:child]];
						}
					}
				}
			}
		}
	}

	if (candidates.count == 0) {
		[self showMessage:@"No .app application bundles found in the selected location."];
		return;
	}

	NSUInteger imported = 0, skipped = 0;
	for (NSString *src in candidates) {
		NSString *name = src.lastPathComponent;
		NSString *dst = [@"/Applications" stringByAppendingPathComponent:name];
		[fm createDirectoryAtPath:[dst stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];

		if ([fm fileExistsAtPath:dst]) {
			skipped++;
			continue;
		}

		NSString *temp = [@"/Applications" stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.importing", name]];
		NSError *error = nil;
		if (![fm copyItemAtPath:src toPath:temp error:&error] || ![fm moveItemAtPath:temp toPath:dst error:&error]) {
			[fm removeItemAtPath:temp error:NULL];
			[self showMessage:[NSString stringWithFormat:@"Import failed for %@; no partial app was installed: %@", name, error.localizedDescription]];
			return;
		}
		imported++;
	}
	[self refreshApplications];
	[self showMessage:[NSString stringWithFormat:@"Imported %lu apps; skipped %lu existing apps. No app was launched.", (unsigned long)imported, (unsigned long)skipped]];
}

- (void)installHomebrew:(id)sender {
	NSString *bootstrap = FindHelper(@"homebrew-bootstrap");
	if (!bootstrap) {
		[self showMessage:@"Native Homebrew bootstrap helper is not installed. Install the verified Darling bootstrap first; host brew is never used."];
		return;
	}
	NSPipe *pipe = [NSPipe pipe]; NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = bootstrap; task.arguments = @[@"/opt/homebrew"]; task.standardOutput = pipe; task.standardError = pipe; [task launch]; [task waitUntilExit];
	NSString *output = [[[NSString alloc] initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding] autorelease];
	[self showMessage:[NSString stringWithFormat:@"Homebrew bootstrap exited %d:\n%@", task.terminationStatus, output ?: @""]];
}

- (void)installBrewfile:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.canChooseFiles = YES; panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO; panel.title = @"Choose Brewfile";
	if ([panel runModal] != NSOKButton) return;
	NSString *source = panel.URL.path; NSString *user = NSUserName(); NSString *dir = [NSString stringWithFormat:@"/Users/%@/Library/Application Support/Darling/Brewfiles", user];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
	NSString *target = [dir stringByAppendingPathComponent:source.lastPathComponent];
	if (![[NSFileManager defaultManager] copyItemAtPath:source toPath:target error:NULL]) { [self showMessage:@"Could not stage the Brewfile inside the Darling prefix."]; return; }
	NSString *helper = FindHelper(@"brewfile-install");
	if (!helper) { [self showMessage:@"Brewfile helper is not installed in this prefix; no packages were started."]; return; }
	NSString *brewText = [NSString stringWithContentsOfFile:source encoding:NSUTF8StringEncoding error:NULL] ?: @"";
	NSRegularExpression *masPattern = [NSRegularExpression regularExpressionWithPattern:@"mas\\s*\\(?\\s*[\\\"']([^\\\"']+)[\\\"'][\\s\\S]*?\\bid\\s*:\\s*[\\\"']?([0-9]+)" options:0 error:NULL];
	NSMutableArray *masIDs = [NSMutableArray array]; NSMutableArray *masNames = [NSMutableArray array];
	for (NSTextCheckingResult *m in [masPattern matchesInString:brewText options:0 range:NSMakeRange(0, brewText.length)]) { [masNames addObject:[brewText substringWithRange:[m rangeAtIndex:1]]]; [masIDs addObject:[brewText substringWithRange:[m rangeAtIndex:2]]]; }
	NSString *skipIDs = [masIDs componentsJoinedByString:@" "];
	NSPipe *pipe = [NSPipe pipe]; NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = helper; task.arguments = @[[@"/" stringByAppendingString:[target substringFromIndex:1]], skipIDs]; task.standardOutput = pipe; task.standardError = pipe; [task launch]; [task waitUntilExit];
	NSString *output = [[[NSString alloc] initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding] autorelease];
	[self refreshApplications]; [self showMessage:[NSString stringWithFormat:@"Brewfile exited %d. Skipped %lu MAS apps (App Store unavailable): %@\n%@", task.terminationStatus, (unsigned long)masNames.count, [masNames componentsJoinedByString:@", "], output ?: @""]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(int argc, const char **argv) {
	/* Native Wayland is the default on Omarchy; X11 remains explicit. */
	if (getenv("WAYLAND_DISPLAY") && !getenv("DARLING_APPKIT_BACKEND")) {
		setenv("DARLING_APPKIT_BACKEND", "wayland", 1);
		unsetenv("DISPLAY");
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; DarlingApplications *delegate = [[[DarlingApplications alloc] init] autorelease]; NSApplication *app = [NSApplication sharedApplication]; app.delegate = delegate; [app run]; [pool drain]; return 0;
}
