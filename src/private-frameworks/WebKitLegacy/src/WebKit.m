/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * iOS's legacy WebKit, backed by darling-webhost.  The host owns one native
 * web view per WebView and reports loads, navigation decisions and requests
 * for app-handled URL schemes over a control connection; script access goes
 * through DWKBridge.  Without a host every WebView stays blank but works.
 */

#import <WebKitLegacy/WebKitLegacy.h>
#import <WebKitLegacy/DWKBridge.h>
#include <dispatch/dispatch.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

NSString *const WebKitErrorDomain = @"WebKitErrorDomain";
NSString *const WebActionNavigationTypeKey = @"WebActionNavigationTypeKey";
NSString *const WebActionElementKey = @"WebActionElementKey";
NSString *const WebActionButtonKey = @"WebActionButtonKey";
NSString *const WebActionModifierFlagsKey = @"WebActionModifierFlagsKey";
NSString *const WebActionOriginalURLKey = @"WebActionOriginalURLKey";
NSString *const WebElementFrameKey = @"WebElementFrame";
NSString *const WebKitLocalStorageDatabasePathPreferenceKey = @"WebKitLocalStorageDatabasePathPreferenceKey";

/* The user agent of Safari on iOS 13, which pages expect from UIWebView. */
static NSString *const DWKDefaultUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";

@class DWKHost;

@interface WebView ()
@property (nonatomic, readonly) long long dwkIdentifier;
@property (nonatomic) unsigned long long dwkPage;
- (void)dwkHandleEvent:(NSDictionary *)event;
- (void)dwkWindowObjectCleared:(WebScriptObject *)window main:(BOOL)main;
- (void)dwkLoad:(NSDictionary *)message;
@end

@interface WebFrame ()
- (instancetype)initWithWebView:(WebView *)webView parent:(WebFrame *)parent name:(NSString *)name;
- (void)dwkStartProvisionalLoad:(NSURLRequest *)request;
- (void)dwkCommit;
- (void)dwkFinish;
- (void)dwkSetTitle:(NSString *)title;
- (void)dwkSetResponse:(NSURLResponse *)response;
@end

@interface WebDataSource ()
- (instancetype)initWithRequest:(NSURLRequest *)request frame:(WebFrame *)frame;
@property (nonatomic, readwrite, copy) NSString *pageTitle;
@property (nonatomic, readwrite, strong) NSURLResponse *response;
@property (nonatomic, readwrite, getter=isLoading) BOOL loading;
@end

#pragma mark - Host connection

/* The control connection to darling-webhost, at DARLING_WEBHOST
 * (host:port; 127.0.0.1:7690 by default). */
@interface DWKHost : NSObject
+ (DWKHost *)sharedHost;
- (BOOL)send:(NSDictionary *)message;
- (void)registerView:(WebView *)view;
- (void)unregisterView:(WebView *)view;
- (WebView *)viewForPage:(unsigned long long)page;
@end

@interface DWKPolicyListener : NSObject <WebPolicyDecisionListener>
- (instancetype)initWithRequestID:(id)requestID;
@end

@implementation DWKPolicyListener {
	id _requestID;
	BOOL _decided;
}

- (instancetype)initWithRequestID:(id)requestID
{
	if ((self = [super init]))
		_requestID = requestID;
	return self;
}

- (void)decide:(BOOL)use
{
	if (_decided)
		return;
	_decided = YES;
	[[DWKHost sharedHost] send:@{ @"op": @"policy", @"req": _requestID, @"use": @(use) }];
}

- (void)use { [self decide:YES]; }
- (void)ignore { [self decide:NO]; }
/* Downloads are not supported: the page stays where it is. */
- (void)download { [self decide:NO]; }

- (void)dealloc
{
	/* WebKit leaves an undecided navigation pending forever; let it go. */
	if (!_decided)
		[[DWKHost sharedHost] send:@{ @"op": @"policy", @"req": _requestID, @"use": @NO }];
}

@end

/* Loads a URL the app handles (a registered NSURLProtocol) for the host. */
@interface DWKSchemeLoader : NSObject <NSURLConnectionDataDelegate>
+ (void)loadRequestID:(id)requestID URL:(NSURL *)url;
@end

@implementation DWKSchemeLoader {
	id _requestID;
	NSURLConnection *_connection;
	NSURLResponse *_response;
	NSMutableData *_data;
	DWKSchemeLoader *_selfReference;
}

+ (void)loadRequestID:(id)requestID URL:(NSURL *)url
{
	DWKSchemeLoader *loader = [[DWKSchemeLoader alloc] init];
	loader->_requestID = requestID;
	loader->_data = [NSMutableData data];
	loader->_selfReference = loader;
	loader->_connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:loader startImmediately:NO];
	[loader->_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[loader->_connection start];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	_response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSInteger status = [_response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)_response statusCode] : 200;
	[[DWKHost sharedHost] send:@{
		@"op": @"scheme",
		@"req": _requestID,
		@"status": @(status),
		@"mime": [_response MIMEType] ?: @"application/octet-stream",
		@"data": [_data base64EncodedStringWithOptions:0],
	}];
	_selfReference = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[[DWKHost sharedHost] send:@{ @"op": @"scheme", @"req": _requestID, @"error": [error localizedDescription] ?: @"failed" }];
	_selfReference = nil;
}

@end

@implementation DWKHost {
	int _fd;
	BOOL _failed;
	NSMutableData *_buffer;
	dispatch_source_t _source;
	NSMapTable<NSNumber *, WebView *> *_views;
}

+ (DWKHost *)sharedHost
{
	static DWKHost *host;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		host = [[DWKHost alloc] init];
	});
	return host;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_fd = -1;
		_buffer = [NSMutableData data];
		_views = [NSMapTable strongToWeakObjectsMapTable];
	}
	return self;
}

- (BOOL)connect
{
	if (_fd >= 0)
		return YES;
	if (_failed)
		return NO;
	_failed = YES;

	const char *spec = getenv("DARLING_WEBHOST");
	NSString *address = spec != NULL ? [NSString stringWithUTF8String:spec] : @"127.0.0.1:7690";
	NSRange colon = [address rangeOfString:@":" options:NSBackwardsSearch];
	NSString *hostName = colon.location != NSNotFound ? [address substringToIndex:colon.location] : address;
	NSString *portName = colon.location != NSNotFound ? [address substringFromIndex:colon.location + 1] : @"7690";

	struct addrinfo hints, *result = NULL;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	if (getaddrinfo([hostName UTF8String], [portName UTF8String], &hints, &result) != 0 || result == NULL)
		return NO;
	int fd = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
	if (fd < 0 || connect(fd, result->ai_addr, result->ai_addrlen) < 0) {
		NSLog(@"WebKit: no darling-webhost at %@ (%s); web views stay blank", address, strerror(errno));
		if (fd >= 0)
			close(fd);
		freeaddrinfo(result);
		return NO;
	}
	freeaddrinfo(result);
	int one = 1;
	setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
	_fd = fd;
	_failed = NO;

	__weak DWKHost *weakSelf = self;
	_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(_source, ^{
		[weakSelf readAvailable];
	});
	dispatch_resume(_source);

	DWKBridge *bridge = [DWKBridge sharedBridge];
	[bridge setClearHandler:^id(DWKBridgeConnection *connection, NSDictionary *request) {
		WebView *view = [[DWKHost sharedHost] viewForPage:[[request objectForKey:@"page"] unsignedLongLongValue]];
		WebScriptObject *window = [connection decode:[request objectForKey:@"window"]];
		[view dwkWindowObjectCleared:window main:[[request objectForKey:@"main"] boolValue]];
		return nil;
	}];
	[self send:@{ @"op": @"hello", @"bridge": @([bridge port]), @"pid": @(getpid()) }];
	return YES;
}

- (BOOL)send:(NSDictionary *)message
{
	if (![self connect])
		return NO;
	NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:NULL];
	if (json == nil)
		return NO;
	NSMutableData *line = [json mutableCopy];
	[line appendBytes:"\n" length:1];
	const char *bytes = [line bytes];
	size_t left = [line length];
	while (left > 0) {
		ssize_t n = write(_fd, bytes, left);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0) {
			[self disconnect];
			return NO;
		}
		bytes += n;
		left -= n;
	}
	return YES;
}

- (void)disconnect
{
	if (_fd < 0)
		return;
	NSLog(@"WebKit: lost darling-webhost");
	dispatch_source_cancel(_source);
	close(_fd);
	_fd = -1;
	_failed = YES;
}

- (void)readAvailable
{
	char chunk[65536];
	ssize_t n = recv(_fd, chunk, sizeof(chunk), MSG_DONTWAIT);
	if (n == 0 || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) {
		[self disconnect];
		return;
	}
	if (n > 0)
		[_buffer appendBytes:chunk length:n];
	for (;;) {
		const char *bytes = [_buffer bytes];
		const char *newline = memchr(bytes, '\n', [_buffer length]);
		if (newline == NULL)
			break;
		NSUInteger length = newline - bytes;
		NSData *data = [_buffer subdataWithRange:NSMakeRange(0, length)];
		[_buffer replaceBytesInRange:NSMakeRange(0, length + 1) withBytes:NULL length:0];
		NSDictionary *event = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
		if ([event isKindOfClass:[NSDictionary class]])
			[self handleEvent:event];
	}
}

- (void)handleEvent:(NSDictionary *)event
{
	NSString *name = [event objectForKey:@"ev"];
	if ([name isEqualToString:@"scheme"]) {
		NSURL *url = [NSURL URLWithString:[event objectForKey:@"url"]];
		[DWKSchemeLoader loadRequestID:[event objectForKey:@"req"] URL:url];
		return;
	}
	WebView *view = [_views objectForKey:[event objectForKey:@"view"]];
	if (view == nil) {
		/* A navigation for a view that is gone must still be answered. */
		if ([name isEqualToString:@"policy"])
			[self send:@{ @"op": @"policy", @"req": [event objectForKey:@"req"] ?: @0, @"use": @NO }];
		return;
	}
	@autoreleasepool {
		[view dwkHandleEvent:event];
	}
}

- (void)registerView:(WebView *)view
{
	[_views setObject:view forKey:@([view dwkIdentifier])];
}

- (void)unregisterView:(WebView *)view
{
	[_views removeObjectForKey:@([view dwkIdentifier])];
}

- (WebView *)viewForPage:(unsigned long long)page
{
	for (WebView *view in [_views objectEnumerator])
		if ([view dwkPage] == page)
			return view;
	return nil;
}

@end

#pragma mark - WebPreferences

@implementation WebPreferences {
	NSString *_identifier;
}

+ (WebPreferences *)standardPreferences
{
	static WebPreferences *preferences;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		preferences = [[WebPreferences alloc] initWithIdentifier:nil];
	});
	return preferences;
}

+ (void)_setInitialDefaultTextEncodingToSystemEncoding
{
}

- (instancetype)init
{
	return [self initWithIdentifier:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
	if ((self = [super init])) {
		_identifier = [identifier copy];
		_javaScriptEnabled = YES;
		_cacheModel = WebCacheModelDocumentBrowser;
		_defaultTextEncodingName = @"ISO-8859-1";
	}
	return self;
}

- (NSString *)identifier
{
	return _identifier;
}

- (void)_setLayoutInterval:(int)interval
{
}

- (void)_setLocalStorageDatabasePath:(NSString *)path
{
}

- (void)setStorageBlockingPolicy:(NSInteger)policy
{
}

/* The many other preference setters apps poke at have no effect here. */
- (void)forwardInvocation:(NSInvocation *)invocation
{
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	NSMethodSignature *signature = [super methodSignatureForSelector:selector];
	if (signature != nil)
		return signature;
	NSString *name = NSStringFromSelector(selector);
	if ([name hasPrefix:@"set"] || [name hasPrefix:@"_set"])
		return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
	return nil;
}

@end

#pragma mark - WebDataSource

@implementation WebDataSource {
	NSURLRequest *_initialRequest;
	NSMutableURLRequest *_request;
	__weak WebFrame *_frame;
}

- (instancetype)initWithRequest:(NSURLRequest *)request frame:(WebFrame *)frame
{
	if ((self = [super init])) {
		_initialRequest = [request copy];
		_request = [request mutableCopy];
		_frame = frame;
		_loading = YES;
	}
	return self;
}

- (NSURLRequest *)initialRequest { return _initialRequest; }
- (NSMutableURLRequest *)request { return _request; }
- (WebFrame *)webFrame { return _frame; }
- (NSURL *)unreachableURL { return nil; }
- (NSData *)data { return nil; }
- (NSString *)textEncodingName { return [_response textEncodingName]; }

@end

#pragma mark - WebFrame

@implementation WebFrame {
	__weak WebView *_webView;
	__weak WebFrame *_parent;
	NSString *_name;
	WebDataSource *_dataSource;
	WebDataSource *_provisionalDataSource;
}

- (instancetype)initWithWebView:(WebView *)webView parent:(WebFrame *)parent name:(NSString *)name
{
	if ((self = [super init])) {
		_webView = webView;
		_parent = parent;
		_name = [name copy] ?: @"";
	}
	return self;
}

- (NSString *)name { return _name; }
- (WebView *)webView { return _webView; }
- (WebDataSource *)dataSource { return _dataSource; }
- (WebDataSource *)provisionalDataSource { return _provisionalDataSource; }
- (WebFrame *)parentFrame { return _parent; }
- (NSArray *)childFrames { return @[]; }
- (DOMDocument *)DOMDocument { return nil; }
- (JSGlobalContextRef)globalContext { return NULL; }

- (WebScriptObject *)windowObject
{
	return [_webView windowScriptObject];
}

- (void)dwkStartProvisionalLoad:(NSURLRequest *)request
{
	_provisionalDataSource = [[WebDataSource alloc] initWithRequest:request frame:self];
}

- (void)dwkCommit
{
	if (_provisionalDataSource != nil)
		_dataSource = _provisionalDataSource;
	_provisionalDataSource = nil;
}

- (void)dwkFinish
{
	[_dataSource setLoading:NO];
}

- (void)dwkSetTitle:(NSString *)title
{
	[_dataSource setPageTitle:title];
}

- (void)dwkSetResponse:(NSURLResponse *)response
{
	[(_provisionalDataSource ?: _dataSource) setResponse:response];
}

- (void)loadRequest:(NSURLRequest *)request
{
	if ([request URL] == nil)
		return;
	[self dwkStartProvisionalLoad:request];
	[_webView dwkLoad:@{ @"op": @"load", @"url": [[request URL] absoluteString] }];
}

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL
{
	NSURL *url = URL ?: [NSURL URLWithString:@"about:blank"];
	[self dwkStartProvisionalLoad:[NSURLRequest requestWithURL:url]];
	[_webView dwkLoad:@{ @"op": @"loadHTML", @"html": string ?: @"", @"base": [url absoluteString] }];
}

- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)URL
{
	NSURL *url = URL ?: [NSURL URLWithString:@"about:blank"];
	[self dwkStartProvisionalLoad:[NSURLRequest requestWithURL:url]];
	[_webView dwkLoad:@{
		@"op": @"loadData",
		@"data": [data base64EncodedStringWithOptions:0] ?: @"",
		@"mime": MIMEType ?: @"text/html",
		@"encoding": encodingName ?: @"utf-8",
		@"base": [url absoluteString],
	}];
}

- (void)stopLoading
{
	[_webView stopLoading:nil];
}

- (void)reload
{
	[_webView reload:nil];
}

- (void)reloadFromOrigin
{
	[_webView reloadFromOrigin:nil];
}

- (void)setNeedsLayout
{
}

@end

#pragma mark - WebView

@implementation WebView {
	long long _identifier;
	BOOL _created;
	WebFrame *_mainFrame;
	WebPreferences *_preferences;
	NSString *_groupName;
	BOOL _canGoBack;
	BOOL _canGoForward;
	BOOL _loading;
	double _progress;
	NSString *_title;
	NSString *_url;
	unsigned long long _embeddedParent;
	CGRect _embeddedRect;
	BOOL _embeddedVisible;
	BOOL _embedded;
}

- (instancetype)init
{
	return [self initWithFrame:CGRectZero frameName:nil groupName:nil];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame frameName:nil groupName:nil];
}

- (instancetype)initWithFrame:(CGRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName
{
	if ((self = [super init]) == nil)
		return nil;
	static long long nextIdentifier;
	_identifier = ++nextIdentifier;
	_mainFrame = [[WebFrame alloc] initWithWebView:self parent:nil name:frameName];
	_preferences = [WebPreferences standardPreferences];
	_groupName = [groupName copy];
	[[DWKHost sharedHost] registerView:self];
	return self;
}

- (void)dealloc
{
	[[DWKHost sharedHost] unregisterView:self];
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"destroy", @"view": @(_identifier) }];
}

- (long long)dwkIdentifier { return _identifier; }
- (WebFrame *)mainFrame { return _mainFrame; }
- (WebPreferences *)preferences { return _preferences; }
- (void)setPreferences:(WebPreferences *)preferences { _preferences = preferences ?: [WebPreferences standardPreferences]; }
- (NSString *)groupName { return _groupName; }
- (void)setGroupName:(NSString *)groupName { _groupName = [groupName copy]; }
- (BOOL)canGoBack { return _canGoBack; }
- (BOOL)canGoForward { return _canGoForward; }
- (BOOL)isLoading { return _loading; }
- (double)estimatedProgress { return _progress; }
- (NSString *)mainFrameTitle { return _title ?: @""; }
- (NSString *)mainFrameURL { return _url; }

- (NSString *)userAgent
{
	if ([_customUserAgent length] > 0)
		return _customUserAgent;
	if ([_applicationNameForUserAgent length] > 0)
		return [NSString stringWithFormat:@"%@ %@", DWKDefaultUserAgent, _applicationNameForUserAgent];
	return DWKDefaultUserAgent;
}

/* The host's view is made on first use, so views that never load cost nothing. */
- (BOOL)ensureCreated
{
	if (_created)
		return YES;
	if (![[DWKHost sharedHost] send:@{ @"op": @"create", @"view": @(_identifier), @"ua": [self userAgent] }])
		return NO;
	_created = YES;
	if (_embedded)
		[self sendEmbed];
	return YES;
}

- (void)setCustomUserAgent:(NSString *)customUserAgent
{
	_customUserAgent = [customUserAgent copy];
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"settings", @"view": @(_identifier), @"ua": [self userAgent] }];
}

- (void)setApplicationNameForUserAgent:(NSString *)name
{
	_applicationNameForUserAgent = [name copy];
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"settings", @"view": @(_identifier), @"ua": [self userAgent] }];
}

- (void)dwkLoad:(NSDictionary *)message
{
	if (![self ensureCreated])
		return;
	NSMutableDictionary *load = [message mutableCopy];
	[load setObject:@(_identifier) forKey:@"view"];
	[[DWKHost sharedHost] send:load];
}

- (void)sendEmbed
{
	[[DWKHost sharedHost] send:@{
		@"op": @"embed",
		@"view": @(_identifier),
		@"parent": @(_embeddedParent),
		@"x": @((long)_embeddedRect.origin.x),
		@"y": @((long)_embeddedRect.origin.y),
		@"w": @((long)_embeddedRect.size.width),
		@"h": @((long)_embeddedRect.size.height),
		@"visible": @(_embeddedVisible),
	}];
}

- (void)dwkEmbedInParent:(unsigned long long)parent rect:(CGRect)rect visible:(BOOL)visible
{
	rect = CGRectIntegral(rect);
	if (_embedded && parent == _embeddedParent && CGRectEqualToRect(rect, _embeddedRect) && visible == _embeddedVisible)
		return;
	_embedded = YES;
	_embeddedParent = parent;
	_embeddedRect = rect;
	_embeddedVisible = visible;
	if (_created)
		[self sendEmbed];
}

- (void)reload:(id)sender
{
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"reload", @"view": @(_identifier) }];
}

- (void)reloadFromOrigin:(id)sender
{
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"reload", @"view": @(_identifier), @"origin": @YES }];
}

- (void)stopLoading:(id)sender
{
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"stop", @"view": @(_identifier) }];
}

- (BOOL)goBack
{
	if (!_created || !_canGoBack)
		return NO;
	return [[DWKHost sharedHost] send:@{ @"op": @"back", @"view": @(_identifier) }];
}

- (BOOL)goForward
{
	if (!_created || !_canGoForward)
		return NO;
	return [[DWKHost sharedHost] send:@{ @"op": @"forward", @"view": @(_identifier) }];
}

- (void)close
{
	if (_created)
		[[DWKHost sharedHost] send:@{ @"op": @"destroy", @"view": @(_identifier) }];
	_created = NO;
}

- (void)_preferencesChanged:(WebPreferences *)preferences
{
}

- (void)_preferencesChangedNotification:(NSNotification *)notification
{
}

- (void)setDrawsBackground:(BOOL)draws
{
}

- (void)setMediaPlaybackRequiresUserGesture:(BOOL)requires
{
}

- (DWKBridgeConnection *)bridgeConnection
{
	return _dwkPage != 0 ? [[DWKBridge sharedBridge] connectionForPage:_dwkPage] : nil;
}

- (WebScriptObject *)windowScriptObject
{
	return [[self bridgeConnection] windowObjectForPage:_dwkPage];
}

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script
{
	DWKBridgeConnection *connection = [self bridgeConnection];
	if (connection == nil)
		return @"";
	id result = [connection sendRequest:@{ @"op": @"eval", @"page": @(_dwkPage), @"script": script ?: @"" }];
	if ([result isKindOfClass:[NSString class]])
		return result;
	if ((__bridge CFBooleanRef)result == kCFBooleanTrue)
		return @"true";
	if ((__bridge CFBooleanRef)result == kCFBooleanFalse)
		return @"false";
	if ([result isKindOfClass:[NSNumber class]])
		return [result stringValue];
	return @"";
}

#pragma mark Events from the host

- (void)tell:(id)delegate selector:(SEL)selector with:(id)a with:(id)b
{
	if (![delegate respondsToSelector:selector])
		return;
	NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setTarget:delegate];
	[invocation setSelector:selector];
	__unsafe_unretained WebView *view = self;
	[invocation setArgument:&view atIndex:2];
	if ([signature numberOfArguments] > 3) {
		__unsafe_unretained id first = a;
		[invocation setArgument:&first atIndex:3];
	}
	if ([signature numberOfArguments] > 4) {
		__unsafe_unretained id second = b;
		[invocation setArgument:&second atIndex:4];
	}
	[invocation invoke];
}

- (WebFrame *)frameForEvent:(NSDictionary *)event
{
	if ([[event objectForKey:@"main"] isEqual:@NO])
		return [[WebFrame alloc] initWithWebView:self parent:_mainFrame name:[event objectForKey:@"frame"]];
	return _mainFrame;
}

- (void)dwkHandleEvent:(NSDictionary *)event
{
	NSString *name = [event objectForKey:@"ev"];
	id history = [event objectForKey:@"back"];
	if (history != nil) {
		_canGoBack = [history boolValue];
		_canGoForward = [[event objectForKey:@"forward"] boolValue];
	}

	if ([name isEqualToString:@"created"]) {
		_dwkPage = [[event objectForKey:@"page"] unsignedLongLongValue];
	} else if ([name isEqualToString:@"policy"]) {
		[self decidePolicy:event];
	} else if ([name isEqualToString:@"started"]) {
		_loading = YES;
		_progress = 0.1;
		NSURL *url = [NSURL URLWithString:[event objectForKey:@"url"] ?: @""];
		NSURL *current = [[[_mainFrame provisionalDataSource] request] URL];
		if (url != nil && ![url isEqual:current])
			[_mainFrame dwkStartProvisionalLoad:[NSURLRequest requestWithURL:url]];
		[self tell:_frameLoadDelegate selector:@selector(webView:didStartProvisionalLoadForFrame:) with:_mainFrame with:nil];
	} else if ([name isEqualToString:@"committed"]) {
		_progress = 0.5;
		_url = [event objectForKey:@"url"];
		NSURL *url = [NSURL URLWithString:_url ?: @""];
		if ([_mainFrame provisionalDataSource] == nil && url != nil)
			[_mainFrame dwkStartProvisionalLoad:[NSURLRequest requestWithURL:url]];
		NSString *mime = [event objectForKey:@"mime"];
		if (url != nil)
			[_mainFrame dwkSetResponse:[[NSURLResponse alloc] initWithURL:url MIMEType:mime ?: @"text/html" expectedContentLength:-1 textEncodingName:nil]];
		[_mainFrame dwkCommit];
		[self tell:_frameLoadDelegate selector:@selector(webView:didCommitLoadForFrame:) with:_mainFrame with:nil];
	} else if ([name isEqualToString:@"title"]) {
		_title = [event objectForKey:@"title"];
		[_mainFrame dwkSetTitle:_title];
		[self tell:_frameLoadDelegate selector:@selector(webView:didReceiveTitle:forFrame:) with:_title with:_mainFrame];
	} else if ([name isEqualToString:@"finished"]) {
		_loading = NO;
		_progress = 1;
		[_mainFrame dwkFinish];
		[self tell:_frameLoadDelegate selector:@selector(webView:didFinishLoadForFrame:) with:_mainFrame with:nil];
	} else if ([name isEqualToString:@"failed"]) {
		_loading = NO;
		NSDictionary *info = @{
			NSLocalizedDescriptionKey: [event objectForKey:@"error"] ?: @"The page could not be loaded.",
			@"NSErrorFailingURLStringKey": [event objectForKey:@"url"] ?: @"",
		};
		NSError *error = [NSError errorWithDomain:[event objectForKey:@"domain"] ?: NSURLErrorDomain
		                                     code:[[event objectForKey:@"code"] integerValue]
		                                 userInfo:info];
		BOOL provisional = [[event objectForKey:@"provisional"] boolValue];
		if (provisional)
			[_mainFrame dwkCommit];
		[_mainFrame dwkFinish];
		SEL selector = provisional ? @selector(webView:didFailProvisionalLoadWithError:forFrame:) : @selector(webView:didFailLoadWithError:forFrame:);
		[self tell:_frameLoadDelegate selector:selector with:error with:_mainFrame];
	} else if ([name isEqualToString:@"console"]) {
		NSDictionary *message = @{
			@"message": [event objectForKey:@"message"] ?: @"",
			@"lineNumber": [event objectForKey:@"line"] ?: @0,
			@"sourceURL": [event objectForKey:@"source"] ?: @"",
		};
		[self tell:_UIDelegate selector:@selector(webView:addMessageToConsole:) with:message with:nil];
	} else if ([name isEqualToString:@"alert"]) {
		[self tell:_UIDelegate selector:@selector(webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:)
		      with:[event objectForKey:@"message"] with:_mainFrame];
	} else if ([name isEqualToString:@"close"]) {
		[self tell:_UIDelegate selector:@selector(webViewClose:) with:nil with:nil];
	}
}

- (void)decidePolicy:(NSDictionary *)event
{
	id requestID = [event objectForKey:@"req"];
	NSURL *url = [NSURL URLWithString:[event objectForKey:@"url"] ?: @""];
	if (url == nil) {
		[[DWKHost sharedHost] send:@{ @"op": @"policy", @"req": requestID, @"use": @NO }];
		return;
	}
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	NSString *method = [event objectForKey:@"method"];
	if (method != nil)
		[request setHTTPMethod:method];

	NSString *type = [event objectForKey:@"type"];
	WebNavigationType navigationType = WebNavigationTypeOther;
	if ([type isEqualToString:@"link"])
		navigationType = WebNavigationTypeLinkClicked;
	else if ([type isEqualToString:@"form"])
		navigationType = WebNavigationTypeFormSubmitted;
	else if ([type isEqualToString:@"back"])
		navigationType = WebNavigationTypeBackForward;
	else if ([type isEqualToString:@"reload"])
		navigationType = WebNavigationTypeReload;
	else if ([type isEqualToString:@"resubmit"])
		navigationType = WebNavigationTypeFormResubmitted;
	NSDictionary *action = @{
		WebActionNavigationTypeKey: @(navigationType),
		WebActionOriginalURLKey: url,
		WebActionModifierFlagsKey: @0,
	};

	DWKPolicyListener *listener = [[DWKPolicyListener alloc] initWithRequestID:requestID];
	NSString *target = [event objectForKey:@"target"];
	if (target != nil) {
		SEL selector = @selector(webView:decidePolicyForNewWindowAction:request:newFrameName:decisionListener:);
		if ([_policyDelegate respondsToSelector:selector])
			[_policyDelegate webView:self decidePolicyForNewWindowAction:action request:request newFrameName:target decisionListener:listener];
		else
			[listener use];
		return;
	}
	SEL selector = @selector(webView:decidePolicyForNavigationAction:request:frame:decisionListener:);
	if ([_policyDelegate respondsToSelector:selector])
		[_policyDelegate webView:self decidePolicyForNavigationAction:action request:request frame:[self frameForEvent:event] decisionListener:listener];
	else
		[listener use];
}

- (void)dwkWindowObjectCleared:(WebScriptObject *)window main:(BOOL)main
{
	WebFrame *frame = main ? _mainFrame : [[WebFrame alloc] initWithWebView:self parent:_mainFrame name:nil];
	[self tell:_frameLoadDelegate selector:@selector(webView:didClearWindowObject:forFrame:) with:window with:frame];
}

@end
