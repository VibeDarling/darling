#import <AppKit/AppKit.h>
#include <copyfile.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <math.h>

static NSCache *gIconCache = nil;

static NSString *FindHelper(NSString *name) {
	NSArray *searchPaths = @[
		[NSString stringWithFormat:@"/usr/libexec/darling/%@", name],
		[NSString stringWithFormat:@"/usr/local/libexec/darling/%@", name],
		[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name],
		[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:name],
	];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *path in searchPaths) if ([fm isExecutableFileAtPath:path]) return path;
	return nil;
}

@class DarlingApplications;

@protocol DarlingApplicationsGridDelegate;

@interface DarlingApplicationsGrid : NSView
@property(nonatomic, assign) id< DarlingApplicationsGridDelegate > gridDelegate;
@property(nonatomic, retain) NSArray *items;
@property(nonatomic, retain) NSMutableDictionary *icons;
@property(nonatomic, assign) NSInteger selectedIndex;
@property(nonatomic, assign) NSUInteger generation;
- (void)setIcon:(NSImage *)icon forIndex:(NSUInteger)index generation:(NSUInteger)generation;
@end

@protocol DarlingApplicationsGridDelegate <NSObject>
- (void)grid:(DarlingApplicationsGrid *)grid selectedIndex:(NSInteger)index doubleClicked:(BOOL)doubleClicked;
@end

@implementation DarlingApplicationsGrid

- (id)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.icons = [NSMutableDictionary dictionary];
		self.selectedIndex = -1;
		[self setAutoresizingMask:NSViewWidthSizable];
	}
	return self;
}

- (BOOL)isFlipped { return YES; }

- (CGFloat)columnCountForWidth:(CGFloat)width {
	return MAX(1.0, floor((width + 12.0) / (130.0 + 12.0)));
}

- (void)resizeToViewportWidth:(CGFloat)width {
	NSUInteger columns = (NSUInteger)[self columnCountForWidth:width];
	NSUInteger rows = (self.items.count + columns - 1) / columns;
	[self setFrameSize:NSMakeSize(MAX(width, 1.0), MAX(1.0, rows * 120.0 + 20.0))];
}

- (void)drawRect:(NSRect)dirtyRect {
	NSUInteger columns = (NSUInteger)[self columnCountForWidth:self.bounds.size.width];
	CGFloat cellWidth = (self.bounds.size.width - 24.0 - (columns - 1) * 12.0) / columns;
	NSUInteger firstRow = dirtyRect.origin.y > 10.0 ? (NSUInteger)floor((dirtyRect.origin.y - 10.0) / 120.0) : 0;
	NSUInteger lastRow = MIN((self.items.count + columns - 1) / columns, (NSUInteger)ceil((NSMaxY(dirtyRect) - 10.0) / 120.0));
	for (NSUInteger index = firstRow * columns; index < MIN(self.items.count, lastRow * columns); index++) {
		NSUInteger row = index / columns, column = index % columns;
		NSRect cell = NSMakeRect(12.0 + column * (cellWidth + 12.0), 10.0 + row * 120.0, cellWidth, 108.0);
		if ((NSInteger)index == self.selectedIndex) {
			[[NSColor selectedControlColor] set];
			NSBezierPath *selection = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cell, 1.0, 1.0) xRadius:6.0 yRadius:6.0];
			[selection fill];
		}
		NSImage *icon = [self.icons objectForKey:[NSNumber numberWithUnsignedInteger:index]];
		if ((id)icon == [NSNull null]) icon = nil;
		if (icon) {
			NSRect iconRect = NSMakeRect(NSMidX(cell) - 36.0, cell.origin.y + 4.0, 72.0, 72.0);
			CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
			CGContextSaveGState(context);
			CGContextClipToRect(context, cell);
			if ([self isFlipped]) {
				CGAffineTransform flip = {1, 0, 0, -1, 0, 2.0 * iconRect.origin.y + iconRect.size.height};
				CGContextConcatCTM(context, flip);
			}
			[icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			CGContextRestoreGState(context);
		}
		NSString *name = [self.items objectAtIndex:index];
		NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:12.0], NSForegroundColorAttributeName: [NSColor textColor]};
		[name drawInRect:NSMakeRect(cell.origin.x + 4.0, cell.origin.y + 79.0, cell.size.width - 8.0, 26.0) withAttributes:attributes];
	}
}

- (void)setIcon:(NSImage *)icon forIndex:(NSUInteger)index generation:(NSUInteger)generation {
	if (generation != self.generation || index >= self.items.count) return;
	[self.icons setObject:icon ?: (id)[NSNull null] forKey:[NSNumber numberWithUnsignedInteger:index]];
	NSUInteger columns = (NSUInteger)[self columnCountForWidth:self.bounds.size.width];
	CGFloat cellWidth = (self.bounds.size.width - 24.0 - (columns - 1) * 12.0) / columns;
	NSUInteger row = index / columns, column = index % columns;
	[self setNeedsDisplayInRect:NSMakeRect(12.0 + column * (cellWidth + 12.0), 10.0 + row * 120.0, cellWidth, 108.0)];
}

- (void)mouseDown:(NSEvent *)event {
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	NSUInteger columns = (NSUInteger)[self columnCountForWidth:self.bounds.size.width];
	CGFloat cellWidth = (self.bounds.size.width - 24.0 - (columns - 1) * 12.0) / columns;
	NSInteger column = (NSInteger)floor((point.x - 12.0) / (cellWidth + 12.0));
	NSInteger row = (NSInteger)floor((point.y - 10.0) / 120.0);
	NSInteger index = row >= 0 && column >= 0 ? row * (NSInteger)columns + column : -1;
	if (index < 0 || index >= (NSInteger)self.items.count) return;
	self.selectedIndex = index;
	[self setNeedsDisplay:YES];
	[self.gridDelegate grid:self selectedIndex:index doubleClicked:event.clickCount > 1];
}

@end

typedef struct {
	DarlingApplications *controller;
	unsigned long long completedBytes;
	CFAbsoluteTime lastReportTime;
} ImportCopyContext;

@interface DarlingApplications : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, DarlingApplicationsGridDelegate>
@property(nonatomic, retain) NSWindow *window;
@property(nonatomic, retain) NSArray *applications;
@property(nonatomic, retain) NSTableView *table;
@property(nonatomic, retain) NSScrollView *scrollView;
@property(nonatomic, retain) DarlingApplicationsGrid *grid;
@property(nonatomic, retain) NSButton *importButton;
@property(nonatomic, retain) NSButton *cancelButton;
@property(nonatomic, retain) NSButton *brewButton;
@property(nonatomic, retain) NSButton *bundleButton;
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

static NSImage *BundleIconForApplication(NSString *path) {
	if (gIconCache) {
		NSImage *cached = [gIconCache objectForKey:path];
		if (cached) return cached;
	}
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	NSMutableArray *names = [NSMutableArray array];
	id value = [info objectForKey:@"CFBundleIconName"];
	if ([value isKindOfClass:[NSString class]]) [names addObject:value];
	value = [info objectForKey:@"CFBundleIconFile"];
	if ([value isKindOfClass:[NSString class]] && ![names containsObject:value]) [names addObject:value];
	id files = [info objectForKey:@"CFBundleIconFiles"];
	if ([files isKindOfClass:[NSArray class]]) for (id item in files) if ([item isKindOfClass:[NSString class]]) [names addObject:item];
	for (NSString *name in names) {
		NSString *candidate = [name pathExtension].length ? name : [name stringByAppendingPathExtension:@"icns"];
		NSString *file = [[path stringByAppendingPathComponent:@"Contents/Resources"] stringByAppendingPathComponent:candidate];
		NSImage *icon = nil;
		@try { icon = [[[NSImage alloc] initWithContentsOfFile:file] autorelease]; } @catch (id exception) { icon = nil; }
		if (icon && (icon.size.width <= 0.0 || icon.size.height <= 0.0)) icon = nil;
		if (!icon) {
			NSData *data = [NSData dataWithContentsOfFile:file];
			const unsigned char *bytes = data.bytes; NSUInteger length = data.length; NSImage *best = nil; CGFloat bestArea = 0;
			uint32_t declaredLength = length >= 8 ? ((uint32_t)bytes[4] << 24) | ((uint32_t)bytes[5] << 16) | ((uint32_t)bytes[6] << 8) | bytes[7] : 0;
			if (bytes && length >= 8 && !memcmp(bytes, "icns", 4) && declaredLength >= 8 && declaredLength <= length) {
				NSUInteger offset = 8;
				while (offset + 8 <= declaredLength) {
					uint32_t chunkLength = ((uint32_t)bytes[offset + 4] << 24) | ((uint32_t)bytes[offset + 5] << 16) | ((uint32_t)bytes[offset + 6] << 8) | bytes[offset + 7];
					if (chunkLength < 8 || chunkLength > declaredLength - offset) break;
					BOOL pngChunk = (!memcmp(bytes + offset, "ic13", 4) || !memcmp(bytes + offset, "ic12", 4) || !memcmp(bytes + offset, "ic11", 4) || !memcmp(bytes + offset, "ic10", 4) || !memcmp(bytes + offset, "ic09", 4) || !memcmp(bytes + offset, "ic08", 4) || !memcmp(bytes + offset, "ic07", 4));
					if (pngChunk && chunkLength > 8) {
						NSData *payload = [data subdataWithRange:NSMakeRange(offset + 8, chunkLength - 8)];
						const unsigned char *png = payload.bytes;
						NSImage *candidateImage = nil;
						if (payload.length >= 8 && png && !memcmp(png, "\x89PNG\r\n\x1a\n", 8)) @try { candidateImage = [[[NSImage alloc] initWithData:payload] autorelease]; } @catch (id exception) { candidateImage = nil; }
						CGFloat area = candidateImage ? candidateImage.size.width * candidateImage.size.height : 0;
						if (candidateImage && area > bestArea) { best = candidateImage; bestArea = area; }
					}
					offset += chunkLength;
				}
				icon = best;
			}
		}
		if (icon) return icon;
	}
	return nil;
}

static NSImage *GenericApplicationIcon(void) {
	NSImage *icon = [[[NSImage alloc] initWithSize:NSMakeSize(72.0, 72.0)] autorelease];
	[icon lockFocus];
	[[NSColor colorWithCalibratedRed:0.30 green:0.48 blue:0.78 alpha:1.0] set];
	[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3.0, 3.0, 66.0, 66.0) xRadius:12.0 yRadius:12.0] fill];
	NSDictionary *attributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:18.0], NSForegroundColorAttributeName: [NSColor whiteColor]};
	[@"APP" drawAtPoint:NSMakePoint(15.0, 26.0) withAttributes:attributes];
	[icon unlockFocus];
	return icon;
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

- (void)layoutViewerContent {
	NSView *content = self.window.contentView;
	CGFloat width = content.bounds.size.width;
	CGFloat height = content.bounds.size.height;
	CGFloat margin = 20.0;
	CGFloat bottomControls = 135.0;
	NSRect listFrame = NSMakeRect(margin, bottomControls, MAX(1.0, width - margin * 2.0), MAX(1.0, height - bottomControls - 20.0));
	/* Actions stay together above a dedicated status strip.  Keeping the
	 * operation label and progress control below the buttons makes import
	 * activity visible without stealing space from the scrollable grid. */
	NSRect statusFrame = NSMakeRect(margin, 42.0, MAX(1.0, width - margin * 2.0), 22.0);
	CGFloat cancelWidth = 100.0;
	NSRect progressFrame = NSMakeRect(margin, 18.0, MAX(1.0, width - margin * 2.0 - cancelWidth - 30.0), 16.0);
	NSRect cancelFrame = NSMakeRect(width - margin - cancelWidth, 14.0, cancelWidth, 28.0);
	CGFloat buttonGap = 8.0;
	CGFloat buttonWidth = MAX(1.0, (width - margin * 2.0 - buttonGap * 2.0) / 3.0);
	[self.scrollView setFrame:listFrame];
	[self.grid setFrameOrigin:NSMakePoint(0.0, 0.0)];
	[self.grid resizeToViewportWidth:self.scrollView.bounds.size.width];
	[self.progressLabel setFrame:statusFrame];
	[self.progress setFrame:progressFrame];
	[self.cancelButton setFrame:cancelFrame];
	[self.brewButton setFrame:NSMakeRect(margin, 75.0, buttonWidth, 32.0)];
	[self.bundleButton setFrame:NSMakeRect(margin + buttonWidth + buttonGap, 75.0, buttonWidth, 32.0)];
	[self.importButton setFrame:NSMakeRect(margin + (buttonWidth + buttonGap) * 2.0, 75.0, buttonWidth, 32.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
	[self layoutViewerContent];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.applications = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Applications" error:NULL];
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *entry in self.applications)
		if ([entry.pathExtension isEqualToString:@"app"]) [items addObject:entry];
	self.applications = [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	NSScreen *screen = [NSScreen mainScreen];
	NSRect visible = screen ? [screen visibleFrame] : NSMakeRect(0, 0, 1024, 768);
	CGFloat width = MIN(720.0, MAX(1.0, visible.size.width - 40.0));
	CGFloat height = MIN(480.0, MAX(1.0, visible.size.height - 40.0));
	NSRect frame = NSMakeRect(visible.origin.x + (visible.size.width - width) / 2.0, visible.origin.y + (visible.size.height - height) / 2.0, width, height);
	self.window = [[[NSWindow alloc] initWithContentRect:frame styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable) backing:NSBackingStoreBuffered defer:NO] autorelease];
	self.window.title = @"Darling Applications";
	[self.window setMinSize:NSMakeSize(MIN(520.0, width), MIN(320.0, height))];
	NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 135, 680, 305)] autorelease];
	self.scrollView = scroll;
	self.table = [[[NSTableView alloc] initWithFrame:scroll.bounds] autorelease];
	NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"application"] autorelease];
	NSCell *header = column.headerCell; header.stringValue = @"Applications"; column.width = 660;
	[self.table addTableColumn:column]; self.table.dataSource = self; self.table.delegate = self;
	self.table.doubleAction = @selector(openSelectedApplication:);
	self.grid = [[[DarlingApplicationsGrid alloc] initWithFrame:scroll.bounds] autorelease];
	self.grid.gridDelegate = self;
	scroll.documentView = self.grid; scroll.hasVerticalScroller = YES;
	[self.window.contentView addSubview:scroll];
	self.brewButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 75, 180, 32)] autorelease]; self.brewButton.title = @"Install Homebrew"; self.brewButton.toolTip = @"Bootstrap the native Homebrew environment in this prefix."; self.brewButton.target = self; self.brewButton.action = @selector(installHomebrew:); [self.window.contentView addSubview:self.brewButton];
	self.bundleButton = [[[NSButton alloc] initWithFrame:NSMakeRect(215, 75, 180, 32)] autorelease]; self.bundleButton.title = @"Install Brewfile Apps"; self.bundleButton.toolTip = @"Choose a Brewfile and install its supported native packages."; self.bundleButton.target = self; self.bundleButton.action = @selector(installBrewfile:); [self.window.contentView addSubview:self.bundleButton];
	self.progressLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 42, 680, 22)] autorelease]; self.progressLabel.editable = NO; self.progressLabel.bordered = NO; self.progressLabel.drawsBackground = NO; self.progressLabel.toolTip = @"Current import operation and byte progress."; self.progressLabel.stringValue = @"Ready to import verified macOS apps."; [self.window.contentView addSubview:self.progressLabel];
	self.progress = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 18, 570, 16)] autorelease]; self.progress.minValue = 0; self.progress.maxValue = 1; self.progress.doubleValue = 0; self.progress.indeterminate = NO; self.progress.toolTip = @"Import progress"; [self.window.contentView addSubview:self.progress];
	self.cancelButton = [[[NSButton alloc] initWithFrame:NSMakeRect(600, 14, 100, 28)] autorelease]; self.cancelButton.title = @"Cancel"; self.cancelButton.toolTip = @"Cancel the current import and remove only its temporary copy."; self.cancelButton.target = self; self.cancelButton.action = @selector(cancelImport:); self.cancelButton.enabled = NO; [self.window.contentView addSubview:self.cancelButton];
	self.importButton = [[[NSButton alloc] initWithFrame:NSMakeRect(410, 75, 180, 32)] autorelease]; self.importButton.title = @"Import macOS Apps"; self.importButton.toolTip = @"Copy verified applications into this prefix with progress."; self.importButton.target = self; self.importButton.action = @selector(importApplications:); [self.window.contentView addSubview:self.importButton];
	[self.window setFrame:frame display:NO];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:self.window];
	[self layoutViewerContent];
	[self refreshApplications];
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
	if (!app) {
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

- (NSArray *)applicationEntries {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *entries = [fm contentsOfDirectoryAtPath:@"/Applications" error:NULL];
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *entry in entries) {
		if ([entry.pathExtension isEqualToString:@"app"]) [items addObject:entry];
		else if ([entry isEqualToString:@"Utilities"]) {
			NSString *utilities = [@"/Applications" stringByAppendingPathComponent:entry];
			for (NSString *child in [fm contentsOfDirectoryAtPath:utilities error:NULL])
				if ([child.pathExtension isEqualToString:@"app"]) [items addObject:[entry stringByAppendingPathComponent:child]];
		}
	}
	return [items sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (void)grid:(DarlingApplicationsGrid *)grid selectedIndex:(NSInteger)index doubleClicked:(BOOL)doubleClicked {
	if (index < 0 || index >= (NSInteger)self.applications.count) return;
	[self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	if (doubleClicked) [self openSelectedApplication:grid];
}

- (void)loadIconUpdate:(NSDictionary *)update {
	id icon = [update objectForKey:@"icon"];
	if (icon == (id)[NSNull null] || !icon) icon = GenericApplicationIcon();
	[self.grid setIcon:icon forIndex:[[update objectForKey:@"index"] unsignedIntegerValue] generation:[[update objectForKey:@"generation"] unsignedIntegerValue]];
}

- (void)loadIconsInBackground:(NSDictionary *)request {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *items = [request objectForKey:@"items"];
	NSUInteger generation = [[request objectForKey:@"generation"] unsignedIntegerValue];
	for (NSUInteger index = 0; index < items.count; index++) {
		NSString *path = [@"/Applications" stringByAppendingPathComponent:[items objectAtIndex:index]];
		NSImage *icon = BundleIconForApplication(path);
		NSDictionary *update = @{@"icon": icon ?: (id)[NSNull null], @"index": @(index), @"generation": @(generation)};
		[self performSelectorOnMainThread:@selector(loadIconUpdate:) withObject:update waitUntilDone:NO];
	}
	[pool drain];
}

- (void)startIconLoading {
	self.grid.generation++;
	self.grid.icons = [NSMutableDictionary dictionary];
	if (!gIconCache) gIconCache = [[NSCache alloc] init];
	[self.grid setNeedsDisplay:YES];
	NSDictionary *request = @{@"items": self.applications, @"generation": @(self.grid.generation)};
	[NSThread detachNewThreadSelector:@selector(loadIconsInBackground:) toTarget:self withObject:request];
}

- (void)refreshApplications {
	self.applications = [self applicationEntries];
	self.grid.items = self.applications;
	self.grid.selectedIndex = -1;
	[self.grid resizeToViewportWidth:self.scrollView.bounds.size.width];
	[self.table reloadData];
	[self startIconLoading];
}

- (void)importApplications:(id)sender {
	if (self.importRunning) return;

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

	NSArray *chosenURLs = [panel.URLs retain];
	if (chosenURLs.count == 0) return;

	self.importCancelled = NO;
	self.importRunning = YES;
	self.importButton.enabled = NO; self.cancelButton.enabled = YES;
	self.progress.indeterminate = YES; [self.progress startAnimation:nil];
	self.progressLabel.stringValue = @"Scanning applications to import…";
	[NSThread detachNewThreadSelector:@selector(importApplicationsInBackground:) toTarget:self withObject:chosenURLs];
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

- (void)importApplicationsInBackground:(NSArray *)chosenURLs {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *candidates = [NSMutableArray array];

	for (NSURL *url in chosenURLs) {
		NSString *path = url.path;
		if ([path.pathExtension isEqualToString:@"app"]) {
			[candidates addObject:@{@"src": path, @"name": path.lastPathComponent}];
		} else {
			NSArray *entries = [fm contentsOfDirectoryAtPath:path error:NULL];
			for (NSString *entry in entries) {
				NSString *sub = [path stringByAppendingPathComponent:entry];
				if ([entry.pathExtension isEqualToString:@"app"]) {
					[candidates addObject:@{@"src": sub, @"name": entry}];
				} else if ([entry isEqualToString:@"Utilities"]) {
					for (NSString *child in [fm contentsOfDirectoryAtPath:sub error:NULL]) {
						if ([child.pathExtension isEqualToString:@"app"]) {
							[candidates addObject:@{@"src": [sub stringByAppendingPathComponent:child],
							                        @"name": [NSString stringWithFormat:@"Utilities/%@", child]}];
						}
					}
				}
			}
		}
	}
	[chosenURLs release];

	if (candidates.count == 0) {
		[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"No applications found.", @"message": @"No .app application bundles found in the selected location."} waitUntilDone:NO];
		[pool drain];
		return;
	}

	unsigned long long totalBytes = 0;
	for (NSDictionary *cand in candidates) {
		NSString *dst = [@"/Applications" stringByAppendingPathComponent:cand[@"name"]];
		if (![fm fileExistsAtPath:dst]) totalBytes += [self sizeOfTree:cand[@"src"] fileManager:fm];
	}

	if (self.importCancelled) {
		[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import cancelled before copying.", @"message": @"Import cancelled; no partial app was installed."} waitUntilDone:NO];
		[pool drain];
		return;
	}

	NSUInteger imported = 0, skipped = 0;
	unsigned long long completedBytes = 0;
	for (NSUInteger index = 0; index < candidates.count; index++) {
		NSDictionary *cand = [candidates objectAtIndex:index];
		NSString *src = cand[@"src"];
		NSString *name = cand[@"name"];
		NSString *dst = [@"/Applications" stringByAppendingPathComponent:name];
		[fm createDirectoryAtPath:[dst stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
		if ([fm fileExistsAtPath:dst]) { skipped++; continue; }
		NSString *temporaryDirectory = [dst stringByDeletingLastPathComponent];
		NSUInteger temporarySuffix = 0;
		NSString *temp = nil;
		do {
			temp = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.importing-%d-%lu", [name lastPathComponent], [[NSProcessInfo processInfo] processIdentifier], (unsigned long)temporarySuffix++]];
		} while ([fm fileExistsAtPath:temp]);

		NSDictionary *status = @{@"phase": @"copy", @"name": [name lastPathComponent], @"app": @(index + 1), @"count": @(candidates.count), @"completedBytes": @(completedBytes), @"totalBytes": @(totalBytes)};
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
			NSString *message = self.importCancelled ? @"Import cancelled; only the unfinished temporary copy was removed." : [NSString stringWithFormat:@"Import failed for %@; no partial app was installed: %@", [name lastPathComponent], [NSString stringWithUTF8String:strerror(copyError)]];
			[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": self.importCancelled ? @"Import cancelled." : @"Import failed.", @"message": message} waitUntilDone:NO];
			[pool drain]; return;
		}
		NSError *error = nil;
		if (![fm moveItemAtPath:temp toPath:dst error:&error] || ![fm fileExistsAtPath:dst isDirectory:NULL]) {
			[fm removeItemAtPath:temp error:NULL];
			[self performSelectorOnMainThread:@selector(updateImportStatus:) withObject:@{@"phase": @"done", @"label": @"Import failed during publication.", @"message": [NSString stringWithFormat:@"Import failed for %@; no partial app was installed: %@", [name lastPathComponent], error.localizedDescription ?: @"destination verification failed"]} waitUntilDone:NO];
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
	NSString *bootstrap = FindHelper(@"homebrew-bootstrap");
	if (!bootstrap) { [self showMessage:@"Native Homebrew bootstrap helper is not installed. Install the verified Darling bootstrap first; host brew is never used."]; return; }
	NSPipe *pipe = [NSPipe pipe]; NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = bootstrap; task.arguments = @[@"/opt/homebrew"]; task.standardOutput = pipe; task.standardError = pipe; [task launch];
	NSData *data = [pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit];
	NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
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
	NSString *skipIDs = [masIDs componentsJoinedByString:@","];
	NSPipe *pipe = [NSPipe pipe]; NSTask *task = [[[NSTask alloc] init] autorelease]; task.launchPath = helper; task.arguments = @[[@"/" stringByAppendingString:[target substringFromIndex:1]], skipIDs]; task.standardOutput = pipe; task.standardError = pipe; [task launch];
	NSData *data = [pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit];
	NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
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
