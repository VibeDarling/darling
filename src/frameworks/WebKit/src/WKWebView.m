/*
 * Guest-side WKWebView, backed by a host engine.
 *
 * Drop-in replacement for the 32-line stub currently at
 * src/frameworks/WebKit/src/WKWebView.m, whose catch-all
 * methodSignatureForSelector: returns "v@:" for every selector and whose
 * forwardInvocation: only logs. That is not merely unimplemented: the wrong
 * signature means initWithFrame:configuration: returns void-garbage, and the
 * caller traps on it. YouLearn v0.3.1 died exactly there
 * (SIGTRAP, exit 133) before any WebKit behaviour was even reached.
 *
 * The real engine runs on the Linux host, in darling-webkit-host, which speaks
 * the protocol in dwb_client.h. This file owns no engine logic; it owns AppKit
 * state and maps the public WKWebView surface onto the transport.
 *
 * CAVEAT, stated plainly: this file has not been compiled, because building it
 * needs a macOS toolchain and the Darling build tree, neither of which was
 * available to the session that wrote it. Everything it delegates to - framing,
 * the shared-memory path, sequence tracking, error events, resize, failed
 * navigation - is implemented and tested off-target in dwb_client.c against a
 * live host, 18/18 on both backends. What is unverified here is only the ObjC
 * glue: selectors this implementation does not cover still fall through to the
 * stub behaviour inherited from WebKit.m, which is the pre-existing behaviour
 * and no worse.
 */

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#import "dwb_client.h"
#import "protocol.h"

/* Where the host service is listening.
 *
 * Hardcoding one path is wrong on both ends of the story: the host takes its
 * path from --serve, so the two could simply disagree and the guest would report
 * "not reachable" while the host was serving perfectly. /tmp is also the least
 * durable place to put a socket, and on this machine it is full.
 *
 * DWB_SOCKET_PATH stays the build-time default for a packaged build. At runtime
 * DWB_WEBKIT_SOCKET wins, and the conventional sidecar file is used next, so a
 * host started on a custom path can be found without recompiling the guest. */
#ifndef DWB_SOCKET_PATH
#define DWB_SOCKET_PATH "/tmp/darling-webkit-host.sock"
#endif
#define DWB_SOCKET_PATH_FILE "/var/run/darling-webkit-host.sock"
#define DWB_SOCKET_ENV "DWB_WEBKIT_SOCKET"

/* The path the host is expected to be listening on, or NULL to use the default.
 * Checked in order, first hit wins. */
static const char *dwb_socket_path(void)
{
	const char *fromEnv = getenv(DWB_SOCKET_ENV);
	if (fromEnv != NULL && fromEnv[0] != '\0')
		return fromEnv;
	/* The sidecar is only trusted if it exists: a stale file from a previous
	 * run would otherwise send the guest to a socket nobody is serving. */
	if (access(DWB_SOCKET_PATH_FILE, F_OK) == 0)
		return DWB_SOCKET_PATH_FILE;
	return DWB_SOCKET_PATH;
}

/* Size of the shared frame region requested from the host. A 1080p RGBA frame is
 * ~8.3MB, so this leaves room without being wasteful. */
#define DWB_FRAME_REGION (16u * 1024 * 1024)

/* Applied from a configuration: user scripts, then message handlers. Order
 * matters - scripts must be installed before the page loads, and handlers before
 * the page can post into them. */
/* Defined in WebKitSiblings.m alongside the rest of the configuration surface. */
/* Defined in WebKitSiblings.m, which is compiled into the same framework; only
 * the header half of its interface is duplicated here for the type. */
@interface DWBWebNavigationAction : NSObject
- (id) initWithRequest: (id)request navigationType: (NSInteger)type;
@end

/* The part of WKNavigationDelegate this proxy can honour. Declared here because
 * the app's own headers are not visible here, and a bare performSelector cannot
 * pass the decision-handler block. */
@protocol DWBWebKitNavigationDelegate <NSObject>
- (void) webView: (id)webView
    decidePolicyForNavigationAction: (DWBWebNavigationAction *)action
                    decisionHandler: (void (^)(NSInteger policy))decisionHandler;
@end

@interface DWBWebScriptMessage : NSObject
- (id) initWithName: (NSString *)name body: (id)body;
- (NSString *) name;
- (id) body;
@end

@interface WKWebViewHostState : NSObject {
@public
	dwb_client client;
	/* Frame region shared with the host. NULL until attached. */
	void *shmBase;
	size_t shmSize;
	/* Last frame presented, so a pull can skip work when nothing changed. */
	dwb_frame_header lastFrame;
	BOOL haveFrame;
	/* Non-nil when the host reported a failure the guest has not seen yet. */
	NSString *pendingError;
	/* Whether the engine implements message handlers. Asked once at connect time
	 * rather than discovered by crashing on the first post. */
	BOOL supportsHandlers;
}
/* Keeps the message alive until reportPendingError runs on a later turn. */
- (void) setPendingError: (NSString *) message;
@end

@implementation WKWebViewHostState

- (id) init
{
	self = [super init];
	client.fd = -1;
	shmBase = NULL;
	shmSize = 0;
	haveFrame = NO;
	return self;
}

- (void) setPendingError: (NSString *) message
{
	if (message == pendingError)
		return;
	[message retain];
	[pendingError release];
	pendingError = message;
}

- (void) dealloc
{
	[pendingError release];
	if (shmBase)
		munmap(shmBase, shmSize);
	if (client.fd >= 0)
		dwb_client_close(&client);
	[super dealloc];
}

@end

@implementation WKWebView

- (id) initWithFrame: (NSRect)frame configuration: (id)configuration
{
	/* The selector that used to trap. Returning a real object here is the whole
	 * point: every caller receives an object, and nothing force-unwraps nil. */
	self = [super initWithFrame: frame];
	if (self == nil)
		return nil;

	_host = [[WKWebViewHostState alloc] init];
	_lastURL = @"";
	_configuration = (configuration != nil) ? [configuration retain] : nil;

	/* One pull, at load, showed a single frame and then nothing: no repaints, no
	 * video, and the message queue drained exactly once. The transport holds only
	 * the newest frame, so pulling from drawRect: would re-present the same one
	 * and never notice a new one arriving. A repeating timer on the app's own run
	 * loop is what actually tracks the host. */
	_frameTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05
	                                               target: self
	                                             selector: @selector(frameTick:)
	                                             userInfo: nil
	                                              repeats: YES];

	const char *socketPath = dwb_socket_path();
	if (dwb_client_connect(&_host->client, socketPath) != 0) {
		/* No host service is a degraded webview, not a crash. The view still
		 * exists, still has a frame, and simply shows nothing. Apps that embed
		 * a webview must not die because an optional host is missing. */
		[_host setPendingError: [NSString stringWithFormat:
			@"darling-webkit-host is not reachable at %s", socketPath ? socketPath : "?"]];
	} else {
		char *backend = NULL;
		int w = 0, h = 0;
		if (dwb_client_hello(&_host->client, &backend, &w, &h) == 0) {
			NSLog(@"YouLearn WKWebView: host engine %s at %s",
			      backend ? backend : "?", socketPath ? socketPath : "?");
			free(backend);
			_host->supportsHandlers = YES; /* not assumed: drainScriptMessages clears it if the host refuses */
			[self attachSharedFrameRegion];
			[self applyConfiguration: configuration];
		}
	}

	return self;
}

/* Forwards everything a configuration carries that the engine can act on. The
 * host can only inject scripts and register handlers; anything else in a
 * configuration is host-side default and stays local. */
- (void) applyConfiguration: (id)configuration
{
	if (configuration == nil)
		return;
	/* Through performSelector, not a typed call. Darling's WKWebViewConfiguration.h
	 * declares the class and nothing else, so a direct call to userContentController
	 * is an unknown-method warning - and the very next accessor below already had to
	 * go through performSelector for the same reason. Being consistent also means
	 * this keeps working if the class comes from somewhere else entirely. */
	id uc = [configuration respondsToSelector: @selector(userContentController)]
		? [configuration performSelector: @selector(userContentController)] : nil;
	if (uc == nil)
		return;
	/* Selector check rather than a cast: these classes are the ones defined
	 * alongside this file, and a configuration from elsewhere would not answer. */
	NSArray *scripts = [uc respondsToSelector: @selector(userScripts)]
		? [uc performSelector: @selector(userScripts)] : nil;
	NSUInteger count = [scripts count];
	for (NSUInteger i = 0; i < count; i++) {
		id script = [scripts objectAtIndex: i];
		NSString *source = [script respondsToSelector: @selector(source)]
			? [script performSelector: @selector(source)] : nil;
		if (source == nil)
			continue;
		BOOL atStart = YES;
		if ([script respondsToSelector: @selector(injectionTime)]) {
			NSInteger t = (NSInteger)[script performSelector: @selector(injectionTime)];
			atStart = (t == 0);
		}
		BOOL mainOnly = YES;
		if ([script respondsToSelector: @selector(forMainFrameOnly)])
			mainOnly = [script performSelector: @selector(forMainFrameOnly)] ? YES : NO;
		if (dwb_client_add_script(&_host->client, [source UTF8String], atStart, mainOnly) != 0)
			[_host setPendingError: [NSString stringWithUTF8String: _host->client.error]];
	}
	NSArray *names = [uc respondsToSelector: @selector(scriptMessageHandlerNames)]
		? [uc performSelector: @selector(scriptMessageHandlerNames)] : nil;
	NSUInteger ncount = [names count];
	for (NSUInteger i = 0; i < ncount; i++) {
		NSString *name = [names objectAtIndex: i];
		if (dwb_client_add_handler(&_host->client, [name UTF8String]) == 0)
			_host->supportsHandlers = YES;
	}
}

/* Drains the host's handler queue and hands each message to the object the app
 * registered for that channel.
 *
 * This was missing entirely. The host registered handlers, queued messages and
 * was tested end to end, and the guest never called dwb_client_poll_message at
 * all, so a page calling postMessage reached a queue nobody drained. Called from
 * the frame loop, which is the only place the guest runs work: the proxy has no
 * run loop of its own to hang a timer on.
 *
 * The transport polls one channel per call, so this walks the registered names.
 * The guard is per channel so one chatty channel cannot starve the rest. */
- (void) drainScriptMessages
{
	if (!_host->supportsHandlers)
		return;
	NSArray *names = [self registeredHandlerNames];
	NSUInteger n = [names count];
	for (NSUInteger i = 0; i < n; i++) {
		NSString *channel = [names objectAtIndex: i];
		const char *cname = [channel UTF8String];
		if (cname == NULL)
			continue;
		id target = [self handlerObjectForChannel: channel];
		if (target == nil)
			continue;
		for (int guard = 0; guard < 32; guard++) {
			char *body = NULL;
			int got = dwb_client_poll_message(&_host->client, cname, &body);
			if (got < 0) {
				/* A refusal is a fact about the backend, not a transient
				 * error: stop asking rather than spinning on every frame. */
				_host->supportsHandlers = NO;
				[_host setPendingError: @"the host backend does not support message handlers"];
				return;
			}
			if (got == 0) {
				if (body != NULL)
					free(body);
				break;
			}
			NSString *text = body != NULL
				? [[[NSString alloc] initWithUTF8String: body] autorelease]
				: nil;
			free(body);
			if (text == nil)
				continue;
			/* A message object, not the payload: the app's binary reads .body and
			 * .name off what arrives, and handing it an NSString fails at the
			 * first property access. */
			DWBWebScriptMessage *message =
				[[[DWBWebScriptMessage alloc] initWithName: channel body: text] autorelease];
			[target performSelector: @selector(userContentController:didReceiveScriptMessage:)
			           withObject: message
			           withObject: self];
		}
	}
}

- (NSArray *) registeredHandlerNames
{
	WKWebViewConfiguration *configuration = _configuration;
	if (configuration == nil)
		return nil;
	id uc = [configuration performSelector: @selector(userContentController)];
	if (uc == nil || ![uc respondsToSelector: @selector(scriptMessageHandlerNames)])
		return nil;
	return [uc performSelector: @selector(scriptMessageHandlerNames)];
}

- (id) handlerObjectForChannel: (NSString *)channel
{
	WKWebViewConfiguration *configuration = _configuration;
	if (configuration == nil)
		return nil;
	id uc = [configuration performSelector: @selector(userContentController)];
	if (uc == nil || ![uc respondsToSelector: @selector(scriptMessageHandlerForName:)])
		return nil;
	return [uc performSelector: @selector(scriptMessageHandlerForName:) withObject: channel];
}

- (void) attachSharedFrameRegion
{
	/* Frames are ~3MB as raw RGB; sending them over the socket is ~90MB/s at
	 * 30fps, which is unusable for video. The host copies into this region
	 * instead and sends only the header. */
	char path[128];
	snprintf(path, sizeof(path), "/tmp/dwb-frames-%d", (int)getpid());
	int fd = open(path, O_CREAT | O_RDWR | O_TRUNC, 0600);
	if (fd < 0)
		return;
	if (ftruncate(fd, (off_t)DWB_FRAME_REGION) != 0) {
		close(fd);
		unlink(path);
		return;
	}
	_host->shmBase = mmap(NULL, DWB_FRAME_REGION, PROT_READ | PROT_WRITE,
	                      MAP_SHARED, fd, 0);
	close(fd);
	if (_host->shmBase == MAP_FAILED) {
		_host->shmBase = NULL;
		unlink(path);
		return;
	}
	_host->shmSize = DWB_FRAME_REGION;
	if (dwb_client_attach_shm(&_host->client, path, DWB_FRAME_REGION) != 0) {
		munmap(_host->shmBase, _host->shmSize);
		_host->shmBase = NULL;
		_host->shmSize = 0;
		unlink(path);
	}
}

- (void) dealloc
{
	/* Stop the timer before anything it touches goes away. NSTimer retains its
	 * target, so an invalidated-but-still-armed timer fires against a freed _host
	 * and writes through it - which showed up as pendingError holding an unrelated
	 * object, such as a font glyph cache entry. */
	[_frameTimer invalidate];
	[_frameTimer release];

	[_frameImage release];
	[_host release];
	[_lastURL release];
	[_configuration release];
	[_navigationDelegate release];
	[_title release];
	[super dealloc];
}

#pragma mark - Navigation

- (id) loadRequest: (id)request
{
	NSString *url = [request URL] ? [[request URL] absoluteString] : nil;
	if (url == nil)
		return nil;
	if (_host->client.fd < 0)
		return nil;
	/* webView:decidePolicyForNavigationAction:decisionHandler:, asked before the
	 * navigation goes to the host.
	 *
	 * The app implements it, and an app embedding YouTube alongside its own UI
	 * often refuses an embed - so not asking means the guest navigates on its own
	 * authority and that code never runs. The reason it was left unimplemented for
	 * several commits was that answering it needs a WKNavigationAction, which the
	 * SDK does not provide. DWBWebNavigationAction provides one.
	 *
	 * Called through a protocol rather than performSelector, because the decision
	 * handler is a *block* argument: performSelector:withObject: cannot pass one,
	 * and an earlier attempt here faked a way to get at it that did not exist. The
	 * declared signature is what makes the call type-check.
	 *
	 * Cancel is 1, allow is 0. Defaulting to allow matches WKWebView with no
	 * delegate set; guessing "cancel" for a page the user asked for would be
	 * worse. A delegate that does not implement the selector is not asked. */
	{
		id delegate = _navigationDelegate;
		SEL policySel = @selector(webView:decidePolicyForNavigationAction:decisionHandler:);
		if (delegate != nil && [delegate respondsToSelector: policySel]) {
			DWBWebNavigationAction *action =
				[[[DWBWebNavigationAction alloc] initWithRequest: request
				                                       navigationType: 0] autorelease];
			/* __block, because the handler is a block: without it the assignment
			 * happens to a copy the caller never sees, and every navigation would
			 * be treated as allowed. A captured int is a classic silent failure -
			 * the code reads correctly and does nothing. */
			__block int allow = 1;
			/* Held in a typed local rather than casting in the receiver position:
			 * the cast-plus-message-send form did not parse, and the error it
			 * produced pointed at the end of the block rather than at the cast. */
			id<DWBWebKitNavigationDelegate> policyDelegate =
				(id<DWBWebKitNavigationDelegate>)delegate;
			[policyDelegate webView: self
				decidePolicyForNavigationAction: action
				decisionHandler: ^(NSInteger policy) { allow = (policy == 0); }];
			if (!allow) {
				/* Refused by the app. The host is never told, so nothing loads
				 * and the app's own policy stands. */
				[_host setPendingError: [NSString stringWithFormat:
					@"the app refused to navigate to %s",
				[url UTF8String] ? [url UTF8String] : "?"]];
				return nil;
			}
		}
	}

	/* webView:didStartProvisionalNavigation:, before the host is told to load.
	 * The app's binary carries it, and a loadingOverlay with six references that
	 * has to appear when a load starts. Sending only the end event left an
	 * overlay that never showed, which looks like a slow page rather than a
	 * missing callback. */
	[self announceNavigationStarted];

	if (dwb_client_navigate(&_host->client, [url UTF8String]) != 0) {
		_loading = NO;
		/* A failed navigation must not look like success. The host tells us
		 * why - an unreachable origin, a refused connection - and the guest
		 * needs that, because the previous behaviour was to report success and
		 * leave the app showing a blank page forever. */
		[_host setPendingError: [NSString stringWithUTF8String:_host->client.error]];
		return nil;
	}
	[_host setPendingError: nil];
	[_lastURL release];
	_lastURL = [url retain];
	/* The host blocks in navigate until the page's load event fires, and only
	 * then sends load-finished - so returning from here means the page really
	 * has loaded, and this is the point to say so.
	 *
	 * An earlier version deferred this to the first frame after a load, on the
	 * belief that navigate returns as soon as the navigation is accepted. That is
	 * wrong, and it was a regression: a page that loads and then produces no
	 * frame - a blank document, a redirect to something the engine cannot draw -
	 * would never announce a finish, and the app's loading overlay would stay up
	 * for good. The premise was asserted rather than read off the host code. */
	_loading = NO;
	[self announceNavigationFinished];
	return nil;
}

- (id) loadHTMLString: (id)html baseURL: (id)baseURL
{
	/* Not proxied. Data URLs are the one navigation form that needs no host
	 * engine at all, so handling it here keeps a caller working even with no
	 * service, rather than pretending a load happened. */
	NSString *markup = html;
	NSData *utf8 = [markup dataUsingEncoding: NSUTF8StringEncoding];
	if (utf8 == nil)
		return nil;
	NSString *encoded = [utf8 base64EncodedStringWithOptions: 0];
	NSString *url = [NSString stringWithFormat: @"data:text/html;base64,%@", encoded];
	return [self loadRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: url]]];
}

- (id) reload
{
	return [self loadRequest: [NSURLRequest requestWithURL:
	                           [NSURL URLWithString: _lastURL]]];
}

- (void) evaluateJavaScript: (id)script completionHandler: (id)completion
{
	char *value = NULL;
	NSString *result = nil;
	NSError *failure = nil;
	if (_host->client.fd < 0) {
		failure = [NSError errorWithDomain: @"DarlingWebKitHost"
		                              code: 2
		                          userInfo: [NSDictionary dictionaryWithObject:
		                            @"darling-webkit-host is not reachable"
		                                               forKey: NSLocalizedDescriptionKey]];
	} else if (dwb_client_eval(&_host->client, [script UTF8String], &value) == 0) {
		result = value ? [NSString stringWithUTF8String: value] : nil;
		free(value);
	} else {
		failure = [NSError errorWithDomain: @"DarlingWebKitHost"
		                              code: 3
		                          userInfo: [NSDictionary dictionaryWithObject:
		                            [NSString stringWithUTF8String: _host->client.error]
		                                               ?: @"script evaluation failed"
		                                               forKey: NSLocalizedDescriptionKey]];
	}
	if (completion != nil) {
		/* Call the handler on the main thread.
		 *
		 * Not performSelectorOnMainThread:withObject:@selector(callWithObject:) -
		 * that is an NSInvocation method on NSObject, and a block does not
		 * answer it, so the completion would silently never fire. A block is
		 * invoked by calling it. The dispatch is needed because the host's
		 * evaluate is synchronous and may have run the engine's loop, so
		 * re-entering the completion here could re-enter the guest from inside
		 * a transport call. */
		typedef void (^DWBCompletion)(id result, NSError *error);
		DWBCompletion handler = (DWBCompletion)[completion copy];
		dispatch_async(dispatch_get_main_queue(), ^{
			handler(result, failure);
		});
		[handler release];
	}
}

#pragma mark - Frame presentation

- (void) frameTick: (id)sender
{
	(void)sender;
	[self presentLatestFrame];
	[self reportPendingError];
}

/* webView:didStartProvisionalNavigation: - the load has been requested. */
- (void) announceNavigationStarted
{
	id delegate = _navigationDelegate;
	if (delegate == nil ||
	    ![delegate respondsToSelector: @selector(webView:didStartProvisionalNavigation:)])
		return;
	[delegate performSelector: @selector(webView:didStartProvisionalNavigation:)
	           withObject: self];
}

/* Tells the app the navigation completed.
 *
 * The app's binary contains webView:didFinishNavigation and
 * decidePolicyForNavigation, so it is a navigation delegate waiting to be
 * told. Nothing ever told it: the host reports load completion as an EVENT, and
 * the guest dropped that message on the floor. A delegate that is never called
 * back looks exactly like a page that never loaded. */
- (void) announceNavigationFinished
{
	/* Cleared first, so a delegate that triggers another load does not re-enter
	 * this and announce twice for one page. */
	_loading = NO;
	id delegate = _navigationDelegate;
	if (delegate == nil ||
	    ![delegate respondsToSelector: @selector(webView:didFinishNavigation:)])
		return;
	[delegate performSelector: @selector(webView:didFinishNavigation:)
	           withObject: self];
}

/* Surfaces a failure that has been sitting in pendingError, exactly once, and
 * routes it to the app's navigation delegate.
 *
 * The errors were being written down and never read. Six sites set pendingError
 * - host unreachable, navigation refused, script injection refused, handler
 * refusal, compressed frame, resize refused - and an app got no notification of
 * any of them, so a webview that could not work failed silently while looking
 * like a blank view. The delegate is the selector WKWebView actually has for
 * this; failing to load the only view the user can see is the honest signal.
 *
 * Clear-once matters: a refused resize would otherwise re-notify on every frame
 * tick forever, and navigation delegates do not expect that. */
- (void) reportPendingError
{
	NSString *message = [[_host->pendingError retain] autorelease];
	if (message == nil)
		return;
	[_host setPendingError: nil];
	NSLog(@"YouLearn WKWebView: %@", message);
	id delegate = nil;
	if ([self respondsToSelector: @selector(navigationDelegate)])
		delegate = [self performSelector: @selector(navigationDelegate)];
	if (delegate == nil ||
	    ![delegate respondsToSelector: @selector(webView:didFailProvisionalNavigation:withError:)]) {
		/* No delegate to tell, so the log above is the whole of it. */
		return;
	}
	NSError *error = [NSError errorWithDomain: @"DarlingWebKitHost"
	                                     code: 1
	                                 userInfo: [NSDictionary dictionaryWithObject: message
	                                                                   forKey: NSLocalizedDescriptionKey]];
	[delegate performSelector: @selector(webView:didFailProvisionalNavigation:withError:)
	           withObject: self
	           withObject: error];
}

- (void) presentLatestFrame
{
	/* The only place the guest runs work, so the page-to-guest queue is drained
	 * here. Frames arrive continuously while the page is live, which is exactly
	 * when messages are being posted. */
	[self drainScriptMessages];
	if (_host->client.fd < 0)
		return;
	dwb_frame_header fh;
	const void *pixels = NULL;
	size_t bytes = 0;
	void *map = NULL;
	size_t mapsz = 0;
	int in_shm = 0;

	if (dwb_client_frame(&_host->client, &fh, &pixels, &bytes, &map, &mapsz, &in_shm) != 0)
		return;

	/* Drop stale frames: if the host has already produced a newer one while we
	 * were painting, this one is superseded and must not be shown. */
	if (_host->haveFrame && _host->client.have_seq && fh.seq <= _host->lastFrame.seq) {
		if (!in_shm)
			dwb_client_free_frame(&_host->client, (void *)pixels);
		return;
	}
	_host->lastFrame = fh;
	_host->haveFrame = YES;
	_host->client.last_seq = fh.seq;
	_host->client.have_seq = 1;

	/* The view draws the latest frame in drawRect:, so it keeps its own copy: the
	 * socket buffer is freed below and the shared region is overwritten by the
	 * next frame. */
	const unsigned char *src = NULL;
	size_t available = 0;
	if (in_shm && _host->shmBase != NULL) {
		src = (const unsigned char *)_host->shmBase + sizeof(dwb_frame_header);
		available = _host->shmSize;
	} else if (pixels != NULL) {
		src = (const unsigned char *)pixels;
		available = sizeof(dwb_frame_header) + bytes;
	}

	dwb_frame_layout layout;
	if (src != NULL && dwb_frame_describe(&fh, available, &layout) != 0) {
		[_host setPendingError: [NSString stringWithFormat:
			@"host sent a malformed %ux%u frame", fh.width, fh.height]];
	} else if (src != NULL) {
		NSBitmapImageRep *rep;
		if (layout.is_raw) {
			rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
				pixelsWide: fh.width
				pixelsHigh: fh.height
				bitsPerSample: 8
				samplesPerPixel: (NSInteger)layout.components
				hasAlpha: layout.has_alpha ? YES : NO
				isPlanar: NO
				colorSpaceName: NSDeviceRGBColorSpace
				bytesPerRow: 0
				bitsPerPixel: (NSInteger)(8 * layout.components)];
			unsigned char *dst = [rep bitmapData];
			size_t rowBytes = (size_t)[rep bytesPerRow];
			size_t copyBytes = (size_t)fh.width * (size_t)layout.components;
			if (dst == NULL || rowBytes < copyBytes) {
				[rep release];
				rep = nil;
			} else {
				for (uint32_t y = 0; y < fh.height; y++)
					memcpy(dst + y * rowBytes, src + (size_t)y * fh.stride, copyBytes);
			}
		} else {
			/* JPEG from the Chromium backend; AppKit decodes it. */
			rep = [[NSBitmapImageRep alloc] initWithData:
				[NSData dataWithBytes: src length: fh.size]];
		}
		if (rep == nil || [rep pixelsWide] <= 0) {
			[_host setPendingError: [NSString stringWithFormat:
				@"could not decode a %u byte frame", fh.size]];
			[rep release];
		} else {
			[_frameImage release];
			_frameImage = rep;
			[self setNeedsDisplay: YES];
		}
	}

	/* Only a socket buffer is ours to release. The shared region outlives the
	 * call and must not be freed here. */
	if (!in_shm && pixels != NULL)
		dwb_client_free_frame(&_host->client, (void *)pixels);
}

- (void) drawRect: (NSRect)dirtyRect
{
	[_frameImage drawInRect: [self bounds]];
}

- (BOOL) allowsBackForwardNavigationGestures
{
	return _allowsBackForwardNavigationGestures;
}

- (void) setAllowsBackForwardNavigationGestures: (BOOL)allowed
{
	_allowsBackForwardNavigationGestures = allowed ? YES : NO;
}

/* The properties above are the ones the app touches that the proxy has no real
 * equivalent for. It has no navigation history, so these report the truth - an
 * empty back/forward list - rather than raising on a gesture that cannot work. */

- (BOOL) isLoading
{
	return _loading ? YES : NO;
}

- (void) setTitle: (NSString *)title
{
	[_title release];
	_title = [title retain];
}

- (NSString *) title
{
	return _title ? _title : @"";
}

- (BOOL) canGoBack
{
	return NO;
}

- (BOOL) canGoForward
{
	return NO;
}

- (void) goBack
{
}

- (void) goForward
{
}

- (void) stopLoading
{
	_loading = NO;
}

- (id) navigationDelegate
{
	return _navigationDelegate;
}

/* macOS 10.14+. Clients set it during setup; a missing selector is an uncaught
 * NSException at launch. Link previews are the host browser's business, so the value is
 * recorded and sent with the rest of the configuration rather than acted on here. */
- (BOOL) allowsLinkPreview
{
	return _allowsLinkPreview;
}

- (void) setAllowsLinkPreview: (BOOL)allows
{
	_allowsLinkPreview = allows;
}

/* Clients set a number of NSView appearance properties through key-value coding, and a
 * key with no accessor is an uncaught NSException, not a no-op. YouLearn v0.3.1 sets
 * drawsBackground among them and died on it. NSView here does not implement these, and
 * the backing view is drawn by the host engine regardless, so the values are accepted
 * and ignored. Same reasoning as the guarded [super setFrame:] below. */
- (void) setDrawsBackground: (BOOL)flag
{
}

- (BOOL) drawsBackground
{
	return YES;
}

- (void) setNavigationDelegate: (id)delegate
{
	[_navigationDelegate release];
	_navigationDelegate = [delegate retain];
}

- (void) setFrame: (NSRect)frame
{
	[super setFrame: frame];
	if (_host->client.fd >= 0 && frame.size.width > 0 && frame.size.height > 0) {
		/* Discarded before now, so a host that refused the new size - a
		 * non-resizable window, a backend that rejects the geometry - left the
		 * guest rendering at the old size with nothing to explain why. */
		if (dwb_client_resize(&_host->client, (int)frame.size.width,
		                      (int)frame.size.height) != 0)
			[_host setPendingError: [NSString stringWithFormat:
				@"host refused resize to %.0fx%.0f: %s",
				frame.size.width, frame.size.height,
				_host->client.error[0] ? _host->client.error : "?"]];
	}
}

@end
