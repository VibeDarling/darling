#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "LSApplicationProxyPrivate.h"

/* iOS's view of the installed apps (MobileCoreServices). Apps live where
 * FrontBoardServices looks for them; opening one goes through
 * FBSSystemService, found at run time since it sits above this framework. */

@interface LSApplicationWorkspace : NSObject
@end

NSArray<LSApplicationProxy *> *LSInstalledApplicationProxies(void)
{
	NSArray<NSString *> *roots = @[
		@"/Applications",
		@"/var/containers/Bundle/Application",
		[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],
	];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *proxies = [NSMutableArray array];
	for (NSString *root in roots) {
		NSArray<NSString *> *entries = [[fm contentsOfDirectoryAtPath:root error:NULL] sortedArrayUsingSelector:@selector(compare:)];
		for (NSString *entry in entries) {
			NSString *path = [root stringByAppendingPathComponent:entry];
			NSMutableArray *candidates = [NSMutableArray array];
			if ([[entry pathExtension] isEqualToString:@"app"]) {
				[candidates addObject:path];
			} else {
				// Installed apps sit one directory deeper, in a container.
				for (NSString *inner in [fm contentsOfDirectoryAtPath:path error:NULL])
					if ([[inner pathExtension] isEqualToString:@"app"])
						[candidates addObject:[path stringByAppendingPathComponent:inner]];
			}
			for (NSString *candidate in candidates) {
				NSBundle *bundle = [NSBundle bundleWithPath:candidate];
				if ([bundle bundleIdentifier] != nil)
					[proxies addObject:[[[LSApplicationProxy alloc] initWithBundle:bundle] autorelease]];
			}
		}
	}
	return proxies;
}

@implementation LSApplicationWorkspace

+ (instancetype)defaultWorkspace
{
	static LSApplicationWorkspace *workspace;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		workspace = [[LSApplicationWorkspace alloc] init];
	});
	return workspace;
}

- (NSArray *)allApplications { return LSInstalledApplicationProxies(); }
- (NSArray *)allInstalledApplications { return LSInstalledApplicationProxies(); }

/* 0: user apps, 1: system apps (LSApplicationProxy's applicationType). */
- (NSArray *)applicationsOfType:(NSUInteger)type
{
	NSString *wanted = type == 1 ? @"System" : @"User";
	NSMutableArray *result = [NSMutableArray array];
	for (LSApplicationProxy *proxy in LSInstalledApplicationProxies()) {
		if ([[proxy performSelector:@selector(applicationType)] isEqualToString:wanted])
			[result addObject:proxy];
	}
	return result;
}

- (BOOL)applicationIsInstalled:(NSString *)identifier
{
	return [LSApplicationProxy performSelector:@selector(applicationProxyForIdentifier:) withObject:identifier] != nil;
}

- (BOOL)openApplicationWithBundleID:(NSString *)identifier
{
	Class service = NSClassFromString(@"FBSSystemService");
	if (service == Nil || ![self applicationIsInstalled:identifier])
		return NO;
	id shared = ((id (*)(id, SEL))objc_msgSend)(service, @selector(sharedService));
	((void (*)(id, SEL, id, id, id))objc_msgSend)(shared,
		@selector(openApplication:options:withResult:), identifier, nil, nil);
	return YES;
}

- (BOOL)openURL:(NSURL *)url { return [self openURL:url withOptions:nil]; }

- (BOOL)openURL:(NSURL *)url withOptions:(NSDictionary *)options
{
	NSLog(@"LSApplicationWorkspace: no app is registered to open %@", url);
	return NO;
}

- (NSArray *)installedPlugins { return @[]; }
- (NSArray *)applicationsAvailableForHandlingURLScheme:(NSString *)scheme { return @[]; }
- (NSArray *)applicationsAvailableForOpeningDocument:(id)document { return @[]; }
- (NSArray *)publicURLSchemes { return @[]; }
- (NSArray *)privateURLSchemes { return @[]; }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [super methodSignatureForSelector:selector] ?: [NSMethodSignature signatureWithObjCTypes:"@@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([invocation selector]), [self class]);
	id nothing = nil;
	if ([[invocation methodSignature] methodReturnLength] == sizeof(id))
		[invocation setReturnValue:&nothing];
}

@end
