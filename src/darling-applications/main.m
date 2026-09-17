#import <AppKit/AppKit.h>
#include <copyfile.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>

@class DarlingApplications;

typedef struct {
	DarlingApplications *controller;
	unsigned long long completedBytes;
	CFAbsoluteTime lastReportTime;
} ImportCopyContext;

@interface DarlingApplications : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, retain) NSWindow *window;
@property(nonatomic, retain) NSArray *applications;
@property(nonatomic, retain) NSTableView *table;
@property(nonatomic, retain) NSButton *importButton;
@property(nonatomic, retain) NSButton *cancelButton;
@property(nonatomic, retain) NSTextField *progressLabel;
@property(nonatomic, retain) NSProgressIndicator *progress;
@property(nonatomic, copy) NSString *statusPrefix;
@property(nonatomic, assign) unsigned long long importTotalBytes;
@property(nonatomic, assign) BOOL importCancelled;
@property(nonatomic, assign) BOOL importRunning;
@end

static NSString *ImportByteCount(unsigned long long bytes) {
	if (bytes >= 1024ULL * 1024ULL * 1024ULL) return [NSString stringWithFormat:@"%.1f GB", (double)bytes / (1024.0 * 1024.0 * 1024.0)];
	if (bytes >= 1024ULL * 1024ULL) return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)];
	if (bytes >= 1024ULL) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
	return [NSString stringWithFormat:@"%llu bytes", bytes];
}

static int ImportCopyStatus(int what, int stage, copyfile_state_t state, const char *source, const char *destination, void *opaque) {
	ImportCopyContext *context = opaque;
	if (context->controller.importCancelled) return COPYFILE_QUIT;
	if (what == COPYFILE_COPY_DATA && stage == COPYFILE_PROGRESS) {
		off_t current = 0;
		CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
		if (now - context->lastReportTime >= 0.1 && copyfile_state_get(state, COPYFILE_STATE_COPIED, &current) == 0) {
			context->lastReportTime = now;
			NSNumber *value = [NSNumber numberWithUnsignedLongLong:context->completedBytes + (unsigned long long)current];
			[context->controller performSelectorOnMainThread:@selector(updateCopiedBytes:) withObject:value waitUntilDone:NO];
		}
	} else if (what == COPYFILE_RECURSE_FILE && stage == COPYFILE_FINISH) {
		struct stat info;
		if (lstat(source, &info) == 0 && S_ISREG(info.st_mode)) context->completedBytes += (unsigned long long)info.st_size;
		[context->controller performSelectorOnMainThread:@selector(updateCopiedBytes:) withObject:[NSNumber numberWithUnsignedLongLong:context->completedBytes] waitUntilDone:NO];
	}
	return COPYFILE_CONTINUE;
}

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
	NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 115, 680, 325)] autorelease];
	self.table = [[[NSTableView alloc] initWithFrame:scroll.bounds] autorelease];
	NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"application"] autorelease];
	NSCell *header = column.headerCell; header.stringValue = @"Applications"; column.width = 660;
	[self.table addTableColumn:column]; self.table.dataSource = self; self.table.delegate = self;
	self.table.doubleAction = @selector(openSelectedApplication:);
	scroll.documentView = self.table; scroll.hasVerticalScroller = YES;
	[self.window.contentView addSubview:scroll];
	NSButton *brew = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 15, 180, 32)] autorelease]; brew.title = @"Install Homebrew"; brew.target = self; brew.action = @selector(installHomebrew:); [self.window.contentView addSubview:brew];
	NSButton *bundle = [[[NSButton alloc] initWithFrame:NSMakeRect(215, 15, 180, 32)] autorelease]; bundle.title = @"Install Brewfile Apps"; bundle.target = self; bundle.action = @selector(installBrewfile:); [self.window.contentView addSubview:bundle];
	self.progressLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 82, 680, 22)] autorelease]; self.progressLabel.editable = NO; self.progressLabel.bordered = NO; self.progressLabel.drawsBackground = NO; self.progressLabel.stringValue = @"Ready to import verified macOS apps."; [self.window.contentView addSubview:self.progressLabel];
	self.progress = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 60, 570, 16)] autorelease]; self.progress.minValue = 0; self.progress.maxValue = 1; self.progress.doubleValue = 0; self.progress.indeterminate = NO; [self.window.contentView addSubview:self.progress];
	self.cancelButton = [[[NSButton alloc] initWithFrame:NSMakeRect(600, 54, 100, 28)] autorelease]; self.cancelButton.title = @"Cancel"; self.cancelButton.target = self; self.cancelButton.action = @selector(cancelImport:); self.cancelButton.enabled = NO; [self.window.contentView addSubview:self.cancelButton];
	self.importButton = [[[NSButton alloc] initWithFrame:NSMakeRect(410, 15, 180, 32)] autorelease]; self.importButton.title = @"Import macOS Apps"; self.importButton.target = self; self.importButton.action = @selector(importApplications:); [self.window.contentView addSubview:self.importButton];
	[self.window center]; [self.window makeKeyAndOrderFront:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.applications.count; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row { return self.applications[row]; }

- (void)openSelectedApplication:(id)sender {
	NSInteger row = self.table.clickedRow >= 0 ? self.table.clickedRow : self.table.selectedRow;
	if (row < 0 || row >= (NSInteger)self.applications.count) return;
	NSString *bundle = [@"/Applications" stringByAppendingPathComponent:self.applications[row]];
	NSURL *url = [NSURL fileURLWithPath:bundle isDirectory:YES];
	if (![[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:0 configuration:nil error:NULL])
		[self showMessage:[NSString stringWithFormat:@"Could not open %@.", self.applications[row]]];
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
	if (self.importRunning) return;
	self.importCancelled = NO;
	self.importRunning = YES;
	self.importButton.enabled = NO; self.cancelButton.enabled = YES;
	self.progress.indeterminate = YES; [self.progress startAnimation:nil];
	self.progressLabel.stringValue = @"Scanning verified macOS applications…";
	[NSThread detachNewThreadSelector:@selector(importApplicationsInBackground:) toTarget:self withObject:nil];
}

- (void)cancelImport:(id)sender {
	self.importCancelled = YES;
	self.cancelButton.enabled = NO;
	self.progressLabel.stringValue = @"Cancelling safely…";
}

- (unsigned long long)sizeOfTree:(NSString *)path fileManager:(NSFileManager *)fm {
	unsigned long long total = 0;
	NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
	if ([[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular]) total += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
	for (NSString *relative in enumerator) {
		if (self.importCancelled) break;
		attributes = [fm attributesOfItemAtPath:[path stringByAppendingPathComponent:relative] error:NULL];
		if ([[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular]) total += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
	}
	return total;
}

- (void)updateCopiedBytes:(NSNumber *)value {
	self.progress.doubleValue = value.doubleValue;
	self.progressLabel.stringValue = [NSString stringWithFormat:@"%@, %@ of %@", self.statusPrefix, ImportByteCount(value.unsignedLongLongValue), ImportByteCount(self.importTotalBytes)];
}

- (void)updateImportStatus:(NSDictionary *)status {
	NSString *phase = [status objectForKey:@"phase"];
	if ([phase isEqualToString:@"copy"]) {
		unsigned long long completed = [[status objectForKey:@"completedBytes"] unsignedLongLongValue];
		unsigned long long total = [[status objectForKey:@"totalBytes"] unsignedLongLongValue];
		self.importTotalBytes = total;
		self.statusPrefix = [NSString stringWithFormat:@"Copying %@ — app %@ of %@", [status objectForKey:@"name"], [status objectForKey:@"app"], [status objectForKey:@"count"]];
		self.progress.indeterminate = NO; [self.progress stopAnimation:nil]; self.progress.maxValue = MAX(1.0, (double)total); self.progress.doubleValue = completed;
		self.progressLabel.stringValue = [NSString stringWithFormat:@"%@, %@ of %@", self.statusPrefix, ImportByteCount(completed), ImportByteCount(total)];
	} else {
		[self.progress stopAnimation:nil]; self.progress.indeterminate = NO;
		self.importRunning = NO;
		self.importButton.enabled = YES; self.cancelButton.enabled = NO;
		self.progressLabel.stringValue = [status objectForKey:@"label"];
		[self refreshApplications];
		NSString *message = [status objectForKey:@"message"];
		if (message) [self showMessage:message];
	}
}

- (void)importApplicationsInBackground:(id)unused {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	/* The host app library is exposed only through this explicit read-only
	 * SystemRoot share; it is not assumed to exist in guest /Users. */
	NSString *source = [NSString stringWithFormat:@"/Volumes/SystemRoot/home/%@/.local/share/darling/macos-apps/Applications", NSUserName()];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *roots = [fm contentsOfDirectoryAtPath:source error:NULL];
	if (!roots) { [self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import source is unavailable.", @"message": @"Verified local macOS application copies are not mounted in this prefix."} waitUntilDone:NO]; [pool drain]; return; }
	NSMutableArray *candidates = [NSMutableArray array];
	for (NSString *name in roots) {
		if ([name.pathExtension isEqualToString:@"app"]) [candidates addObject:name];
		else if ([name isEqualToString:@"Utilities"]) {
			NSString *utilities = [source stringByAppendingPathComponent:name];
			for (NSString *child in [fm contentsOfDirectoryAtPath:utilities error:NULL])
				if ([child.pathExtension isEqualToString:@"app"]) [candidates addObject:[name stringByAppendingPathComponent:child]];
		}
	}
	unsigned long long totalBytes = 0;
	for (NSString *relative in candidates) {
		NSString *destination = [@"/Applications" stringByAppendingPathComponent:relative];
		if (![fm fileExistsAtPath:destination]) totalBytes += [self sizeOfTree:[source stringByAppendingPathComponent:relative] fileManager:fm];
	}
	if (self.importCancelled) { [self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import cancelled before copying.", @"message": @"Import cancelled; no partial app was installed."} waitUntilDone:NO]; [pool drain]; return; }
	NSUInteger imported = 0, skipped = 0;
	unsigned long long completedBytes = 0;
	for (NSUInteger index = 0; index < candidates.count; index++) {
		NSString *relative = [candidates objectAtIndex:index];
		NSString *src = [source stringByAppendingPathComponent:relative];
		NSString *dst = [@"/Applications" stringByAppendingPathComponent:relative];
		[fm createDirectoryAtPath:[dst stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
		NSString *name = relative.lastPathComponent;
		if ([fm fileExistsAtPath:dst]) { skipped++; continue; }
		NSString *temporaryDirectory = [dst stringByDeletingLastPathComponent];
		NSUInteger temporarySuffix = 0;
		NSString *temp = nil;
		do {
			temp = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.importing-%d-%lu", name, [[NSProcessInfo processInfo] processIdentifier], (unsigned long)temporarySuffix++]];
		} while ([fm fileExistsAtPath:temp]);
		NSDictionary *status = @{@"phase": @"copy", @"name": name, @"app": @(index + 1), @"count": @(candidates.count), @"completedBytes": @(completedBytes), @"totalBytes": @(totalBytes)};
		[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:status waitUntilDone:NO];
		ImportCopyContext context = { self, completedBytes, 0 };
		copyfile_state_t state = copyfile_state_alloc();
		copyfile_callback_t callback = ImportCopyStatus;
		if (!state || copyfile_state_set(state, COPYFILE_STATE_STATUS_CB, callback) != 0 || copyfile_state_set(state, COPYFILE_STATE_STATUS_CTX, &context) != 0) {
			if (state) copyfile_state_free(state);
			[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import could not start.", @"message": @"Could not initialize metadata-preserving copy progress; no app was changed."} waitUntilDone:NO];
			[pool drain]; return;
		}
		errno = 0;
		int result = copyfile(src.fileSystemRepresentation, temp.fileSystemRepresentation, state, COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_EXCL | COPYFILE_NOFOLLOW);
		int copyError = errno;
		copyfile_state_free(state);
		if (result != 0 || self.importCancelled) {
			[fm removeItemAtPath:temp error:NULL];
			NSString *message = self.importCancelled ? @"Import cancelled; only the unfinished temporary copy was removed." : [NSString stringWithFormat:@"Import failed for %@; no partial app was installed: %@", name, [NSString stringWithUTF8String:strerror(copyError)]];
			[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": self.importCancelled ? @"Import cancelled." : @"Import failed.", @"message": message} waitUntilDone:NO];
			[pool drain]; return;
		}
		NSError *error = nil;
		if (![fm moveItemAtPath:temp toPath:dst error:&error] || ![fm fileExistsAtPath:dst isDirectory:NULL]) {
			[fm removeItemAtPath:temp error:NULL];
			[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import failed during publication.", @"message": [NSString stringWithFormat:@"Import failed for %@; no partial app was installed: %@", name, error.localizedDescription ?: @"destination verification failed"]} waitUntilDone:NO];
			[pool drain]; return;
		}
		completedBytes = context.completedBytes;
		imported++;
	}
	NSString *summary = [NSString stringWithFormat:@"Imported %lu verified apps; skipped %lu existing apps. No app was launched.", (unsigned long)imported, (unsigned long)skipped];
	[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": [NSString stringWithFormat:@"Import complete — %@ copied.", ImportByteCount(completedBytes)], @"message": summary} waitUntilDone:NO];
	[pool drain];
}

- (void)installHomebrew:(id)sender {
	NSString *bootstrap = @"/usr/local/libexec/darling/homebrew-bootstrap";
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:bootstrap]) { [self showMessage:@"Native Homebrew bootstrap is not installed. Install the verified Darling bootstrap first; host brew is never used."]; return; }
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
	NSString *helper = @"/usr/local/libexec/darling/brewfile-install";
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:helper]) { [self showMessage:@"Brewfile helper is not installed in this prefix; no packages were started."]; return; }
	NSPipe *pipe = [NSPipe pipe]; NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = helper; task.arguments = @[[@"/" stringByAppendingString:[target substringFromIndex:1]]]; task.standardOutput = pipe; task.standardError = pipe; [task launch]; [task waitUntilExit];
	NSString *output = [[[NSString alloc] initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding] autorelease];
	[self refreshApplications]; [self showMessage:[NSString stringWithFormat:@"Brewfile exited %d:\n%@", task.terminationStatus, output ?: @""]];
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
