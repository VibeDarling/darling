#import <Foundation/Foundation.h>
#import "LSApplicationProxyPrivate.h"

/* What iOS's MobileCoreServices tells apps about an installed app or a
 * document type, from the app's bundle. File managers (Filza) and app
 * switchers list apps through these. Unknown messages are logged and
 * answer nil. */

static id LSStubForward(id self, NSInvocation *invocation)
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([invocation selector]), [self class]);
	id nothing = nil;
	if ([[invocation methodSignature] methodReturnLength] == sizeof(id))
		[invocation setReturnValue:&nothing];
	return nil;
}

@implementation LSApplicationProxy

+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier
{
	for (LSApplicationProxy *proxy in LSInstalledApplicationProxies()) {
		if ([[proxy applicationIdentifier] isEqualToString:identifier])
			return proxy;
	}
	return nil;
}

+ (instancetype)applicationProxyForBundleURL:(NSURL *)url
{
	NSBundle *bundle = [NSBundle bundleWithURL:url];
	return bundle != nil ? [[[self alloc] initWithBundle:bundle] autorelease] : nil;
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
	if ((self = [super init]) != nil)
		_bundle = [bundle retain];
	return self;
}

- (void)dealloc
{
	[_bundle release];
	[super dealloc];
}

- (NSString *)applicationIdentifier { return [_bundle bundleIdentifier]; }
- (NSString *)bundleIdentifier { return [_bundle bundleIdentifier]; }
- (NSString *)itemID { return [_bundle bundleIdentifier]; }

- (NSString *)localizedName
{
	return [_bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]
		?: [_bundle objectForInfoDictionaryKey:@"CFBundleName"]
		?: [[[_bundle bundlePath] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)localizedShortName { return [self localizedName]; }
- (NSString *)itemName { return [self localizedName]; }
- (NSURL *)bundleURL { return [_bundle bundleURL]; }
- (NSURL *)resourcesDirectoryURL { return [_bundle resourceURL]; }
- (NSURL *)bundleContainerURL { return [[_bundle bundleURL] URLByDeletingLastPathComponent]; }
- (NSString *)bundleExecutable { return [_bundle objectForInfoDictionaryKey:@"CFBundleExecutable"]; }
- (NSURL *)executableURL { return [_bundle executableURL]; }
- (NSString *)bundleVersion { return [_bundle objectForInfoDictionaryKey:@"CFBundleVersion"]; }
- (NSString *)shortVersionString { return [_bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]; }
- (NSString *)minimumSystemVersion { return [_bundle objectForInfoDictionaryKey:@"MinimumOSVersion"]; }
- (NSDictionary *)infoDictionary { return [_bundle infoDictionary]; }

/* Darling apps keep their data in the user's home, not in containers. */
- (NSURL *)dataContainerURL { return nil; }
- (NSURL *)containerURL { return nil; }
- (NSDictionary *)groupContainerURLs { return @{}; }
- (NSDictionary *)entitlements { return @{}; }

/* Apps in /Applications came with the system or from Cydia; iOS calls
 * both "System". The rest were installed as IPAs. */
- (NSString *)applicationType
{
	return [[_bundle bundlePath] hasPrefix:@"/Applications/"] ? @"System" : @"User";
}

- (NSArray *)appTags
{
	return [_bundle objectForInfoDictionaryKey:@"SBAppTags"] ?: @[];
}

- (BOOL)isInstalled { return YES; }
- (BOOL)isRestricted { return NO; }
- (BOOL)isPlaceholder { return NO; }
- (NSNumber *)staticDiskUsage { return @0; }
- (NSNumber *)dynamicDiskUsage { return @0; }

- (NSData *)iconDataForVariant:(int)variant { return nil; }
- (NSData *)primaryIconDataForVariant:(int)variant { return nil; }

- (BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[LSApplicationProxy class]]
		&& [[self bundleURL] isEqual:[other bundleURL]];
}

- (NSUInteger)hash { return [[self bundleURL] hash]; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@>", [self class], [self applicationIdentifier], [_bundle bundlePath]];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [super methodSignatureForSelector:selector] ?: [NSMethodSignature signatureWithObjCTypes:"@@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	LSStubForward(self, invocation);
}

@end

@implementation LSDocumentProxy

+ (instancetype)documentProxyForName:(NSString *)name type:(NSString *)type MIMEType:(NSString *)MIMEType
{
	LSDocumentProxy *proxy = [[[self alloc] init] autorelease];
	proxy->_name = [name copy];
	proxy->_typeIdentifier = [type copy];
	proxy->_MIMEType = [MIMEType copy];
	return proxy;
}

+ (instancetype)documentProxyForURL:(NSURL *)url
{
	return [self documentProxyForName:[url lastPathComponent] type:nil MIMEType:nil];
}

- (void)dealloc
{
	[_name release];
	[_typeIdentifier release];
	[_MIMEType release];
	[super dealloc];
}

- (NSString *)name { return _name; }
- (NSString *)typeIdentifier { return _typeIdentifier; }
- (NSString *)MIMEType { return _MIMEType; }

/* No app declares document types to Darling yet. */
- (NSArray *)applicationsAvailableForOpeningWithError:(NSError **)error { return @[]; }
- (NSArray *)applicationsAvailableForOpeningFromAirDrop:(BOOL)airDrop { return @[]; }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [super methodSignatureForSelector:selector] ?: [NSMethodSignature signatureWithObjCTypes:"@@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	LSStubForward(self, invocation);
}

@end
