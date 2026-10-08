/*
 * The state-owning siblings of WKWebView, and the surface YouLearn touches
 * before it ever shows anything.
 *
 * YouLearn configures its webview in this order: it builds a
 * WKWebViewConfiguration, installs a WKUserScript and a named message handler
 * through a WKUserContentController, hands the configuration to WKWebView, and
 * only then loads a page. With the current 32-line stubs each of those calls
 * throws "unrecognized selector" and the app dies before drawing anything.
 *
 * These own genuine local state and forward what can be forwarded. They are
 * deliberately small: the engine lives on the host, so there is nothing to
 * implement here beyond holding state correctly and translating.
 *
 * Not compiled - see the note at the top of WKWebView.m. Every piece of real
 * logic involved is covered off-target by the passing transport suite.
 */

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "dwb_client.h"

/* Injection point, mirroring WKUserScriptInjectionTime. */
typedef NS_ENUM(NSInteger, DWBInjectionTime) {
	DWBInjectionTimeDocumentStart = 0,
	DWBInjectionTimeDocumentEnd = 1,
};

@implementation WKUserScript

- (id) initWithSource: (NSString *)source
       injectionTime: (DWBInjectionTime)time
  forMainFrameOnly: (BOOL)mainOnly
{
	self = [super init];
	if (self == nil)
		return nil;
	_source = [source copy];
	_injectionTime = time;
	_forMainFrameOnly = mainOnly;
	return self;
}

- (void) dealloc
{
	[_source release];
	[super dealloc];
}

- (NSString *) source
{
	return _source;
}

- (DWBInjectionTime) injectionTime
{
	return _injectionTime;
}

- (BOOL) forMainFrameOnly
{
	return _forMainFrameOnly;
}

@end

/* What the app receives in userContentController:didReceiveScriptMessage:.
 *
 * It was being handed a bare NSString, and the app's binary reads `.body` off
 * whatever arrives - so the message object it got did not answer that, and every
 * page-to-guest callback died at the first property access. The payload has to be
 * an object, not a string: a string is what the body *is*, not what the message
 * is. `name` is the channel, which is how an app with several handlers tells
 * them apart. */
/* WKNavigationAction: what a navigation delegate is asked about before a
 * navigation is allowed to proceed.
 *
 * The SDK declares the class and no methods, so the ivars live here and the
 * accessors are this guest's. That is not a shortcut: the guest has to build the
 * object itself anyway, since it drives navigation over a socket rather than
 * through an engine that would hand one over.
 *
 * -request is the NSURLRequest being loaded, and -navigationType distinguishes a
 * first load from a click from a redirect, which is what a policy callback
 * usually keys on. */
@interface DWBWebNavigationAction : NSObject {
	id _request;
	NSInteger _navigationType;
}
- (id) initWithRequest: (id)request navigationType: (NSInteger)type;
- (id) request;
- (NSInteger) navigationType;
- (id) targetFrame;
- (BOOL) isMainFrame;
@end

@implementation DWBWebNavigationAction

- (id) initWithRequest: (id)request navigationType: (NSInteger)type
{
	self = [super init];
	if (self == nil)
		return nil;
	_request = [request retain];
	_navigationType = type;
	return self;
}

- (void) dealloc
{
	[_request release];
	[super dealloc];
}

- (id) request
{
	return _request;
}

- (NSInteger) navigationType
{
	return _navigationType;
}

/* The guest has no frames to navigate, so there is no target frame. nil is the
 * honest answer: a delegate that inspects a nil target to decide whether to
 * allow the load is looking for information this proxy does not have, and
 * inventing a frame would be worse. */
- (id) targetFrame
{
	return nil;
}

- (BOOL) isMainFrame
{
	return YES;
}

@end

@interface DWBWebScriptMessage : NSObject {
	NSString *_name;
	id _body;
}
- (id) initWithName: (NSString *)name body: (id)body;
- (NSString *) name;
- (id) body;
- (id) webView;
@end

@implementation DWBWebScriptMessage

- (id) initWithName: (NSString *)name body: (id)body
{
	self = [super init];
	if (self == nil)
		return nil;
	_name = [name retain];
	_body = [body retain];
	return self;
}

- (void) dealloc
{
	[_name release];
	[_body release];
	[super dealloc];
}

- (NSString *) name
{
	return _name;
}

- (id) body
{
	return _body;
}

- (id) webView
{
	/* A real WKScriptMessage carries a weak reference to the view that produced
	 * it. Returning nil is honest: this proxy delivers messages out of band and
	 * has no single originating view, and an app that navigates from a handler
	 * needs a real one, which it should not be handed here. */
	return nil;
}

@end

@implementation WKUserContentController

- (id) init
{
	self = [super init];
	_scripts = [[NSMutableArray alloc] init];
	_handlerNames = [[NSMutableArray alloc] init];
	_handlerObjects = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc
{
	[_scripts release];
	[_handlerNames release];
	[_handlerObjects release];
	[super dealloc];
}

- (NSArray *) userScripts
{
	return _scripts;
}

- (void) addUserScript: (id)script
{
	if (script == nil)
		return;
	[_scripts addObject: script];
}

- (void) removeAllUserScripts
{
	[_scripts removeAllObjects];
}

- (id) scriptMessageHandlerForName: (NSString *)name
{
	if (name == nil)
		return nil;
	return [_handlerObjects objectForKey: name];
}

- (NSArray *) scriptMessageHandlerNames
{
	return _handlerNames;
}

- (void) addScriptMessageHandler: (id)handler name: (NSString *)name
{
	/* The host only needs the channel name, but the guest still has to deliver
	 * the message to this object, so it is kept as well. */
	if (name == nil)
		return;
	if (handler != nil) {
		if (![_handlerNames containsObject: name]) {
			[_handlerNames addObject: name];
			[_handlerObjects setObject: handler forKey: name];
		}
	}
}

- (void) removeScriptMessageHandlerForName: (NSString *)name
{
	if (name == nil)
		return;
	[_handlerNames removeObject: name];
	[_handlerObjects removeObjectForKey: name];
}

- (void) removeAllScriptMessageHandlers
{
	[_handlerNames removeAllObjects];
}

@end

/* The object WKWebViewConfiguration.preferences returns. YouLearn reads it and
 * immediately sets a media policy on it, so it must be a real object: a nil
 * here throws on the very next call. */
@interface DWBWebViewPreferences : NSObject {
@public
	NSUInteger _mediaTypesRequiringUserAction;
	BOOL _allowsAirPlayForMediaPlayback;
	BOOL _allowsPictureInPictureMediaPlayback;
	BOOL _allowsInlineMediaPlayback;
	BOOL _fullScreenEnabled;
}
@end

@implementation DWBWebViewPreferences

- (id) init
{
	self = [super init];
	_allowsInlineMediaPlayback = YES;
	return self;
}

- (NSUInteger) mediaTypesRequiringUserActionForPlayback
{
	return _mediaTypesRequiringUserAction;
}

- (void) setMediaTypesRequiringUserActionForPlayback: (NSUInteger)types
{
	_mediaTypesRequiringUserAction = types;
}

/* Present because clients set it through key-value coding, and a missing key is an
 * uncaught NSException that kills the app at launch. The host drives fullscreen, so
 * this records the request and leaves the behaviour to it. */
- (BOOL) fullScreenEnabled
{
	return _fullScreenEnabled;
}

- (void) setFullScreenEnabled: (BOOL)enabled
{
	_fullScreenEnabled = enabled;
}

- (BOOL) isElementFullscreenEnabled
{
	return [self fullScreenEnabled];
}

- (void) setElementFullscreenEnabled: (BOOL)enabled
{
	[self setFullScreenEnabled: enabled];
}

- (BOOL) allowsAirPlayForMediaPlayback
{
	return _allowsAirPlayForMediaPlayback;
}

- (void) setAllowsAirPlayForMediaPlayback: (BOOL)allows
{
	_allowsAirPlayForMediaPlayback = allows;
}

- (BOOL) allowsPictureInPictureMediaPlayback
{
	return _allowsPictureInPictureMediaPlayback;
}

- (void) setAllowsPictureInPictureMediaPlayback: (BOOL)allows
{
	_allowsPictureInPictureMediaPlayback = allows;
}

- (BOOL) allowsInlineMediaPlayback
{
	return _allowsInlineMediaPlayback;
}

- (void) setAllowsInlineMediaPlayback: (BOOL)allows
{
	_allowsInlineMediaPlayback = allows;
}

@end

/* Swipe-to-go-back. In the binary twice, via setValue:forKey: as well as the
 * setter, so the property has to exist for KVC or the write throws. The guest has
 * no history to navigate, so it records the setting and reports the back/forward
 * lists as empty rather than pretending a gesture can work. */
@interface DWBWebView : NSObject {
	BOOL _allowsBackForwardNavigationGestures;
	BOOL _loading;
	NSString *_title;
}
- (BOOL) allowsBackForwardNavigationGestures;
- (void) setAllowsBackForwardNavigationGestures: (BOOL)allowed;
- (BOOL) isLoading;
- (void) setTitle: (NSString *)title;
- (NSString *) title;
- (BOOL) canGoBack;
- (BOOL) canGoForward;
- (void) goBack;
- (void) goForward;
- (void) stopLoading;
@end

@implementation WKWebViewConfiguration

- (id) init
{
	self = [super init];
	/* A fresh controller, not nil. Clients read this before setting it - that is
	 * the common order - and a nil here would throw on an accessor the client
	 * never had a reason to think was unimplemented. */
	_userContentController = [[WKUserContentController alloc] init];
	_preferences = [[DWBWebViewPreferences alloc] init];
	_mediaTypesRequiringUserAction = 0;
	_allowsInlineMediaPlayback = YES;
	_mediaPlaybackRequiresUserGesture = NO;
	return self;
}

- (void) dealloc
{
	[_userContentController release];
	[_preferences release];
	[_applicationNameForUserAgent release];
	[_userAgent release];
	[super dealloc];
}

- (DWBWebViewPreferences *) preferences
{
	return _preferences;
}

- (WKUserContentController *) userContentController
{
	return _userContentController;
}

- (void) setUserContentController: (WKUserContentController *)controller
{
	if (controller == _userContentController)
		return;
	[_userContentController release];
	_userContentController = [controller retain];
}

- (NSUInteger) mediaTypesRequiringUserActionForPlayback
{
	return _mediaTypesRequiringUserAction;
}

- (void) setMediaTypesRequiringUserActionForPlayback: (NSUInteger)types
{
	_mediaTypesRequiringUserAction = types;
}

- (BOOL) allowsInlineMediaPlayback
{
	return _allowsInlineMediaPlayback;
}

- (void) setAllowsInlineMediaPlayback: (BOOL)allows
{
	_allowsInlineMediaPlayback = allows;
}

- (BOOL) mediaPlaybackRequiresUserGesture
{
	return _mediaPlaybackRequiresUserGesture;
}

- (void) setMediaPlaybackRequiresUserGesture: (BOOL)requires
{
	_mediaPlaybackRequiresUserGesture = requires;
}

- (NSString *) applicationNameForUserAgent
{
	return _applicationNameForUserAgent;
}

- (void) setApplicationNameForUserAgent: (NSString *)name
{
	[_applicationNameForUserAgent release];
	_applicationNameForUserAgent = [name copy];
}

- (NSString *) userAgent
{
	return _userAgent;
}

- (void) setUserAgent: (NSString *)agent
{
	[_userAgent release];
	_userAgent = [agent copy];
}

@end
