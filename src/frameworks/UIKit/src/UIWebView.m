/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * UIWebView over Darling's legacy WebKit.  The page itself is a native
 * window darling-webhost keeps over the document view: this file tells the
 * WebView where that view is in its X11 window and whether it can be seen,
 * and turns WebKit's delegate calls into UIWebViewDelegate ones, as UIKit's
 * UIWebView does.
 */

#import <UIKit/UIWebView.h>
#import <UIKit/UIAlertView.h>
#import <UIKit/UIWindow.h>
#import <WebKitLegacy/WebKitLegacy.h>
#import <AppKit/NSWindow.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

/* A signature taking one object per argument of a setter such as
   setViewportSize:forDocumentTypes:.  The arguments are thrown away, so
   their real types do not matter. */
static NSMethodSignature *UIKitSetterSignature(NSString *name)
{
	NSMutableString *types = [NSMutableString stringWithString:@"v@:"];
	for (NSUInteger i = 0; i < [name length]; i++)
		if ([name characterAtIndex:i] == ':')
			[types appendString:@"@"];
	return [NSMethodSignature signatureWithObjCTypes:[types UTF8String]];
}

/* The many tuning setters apps send these private views do nothing here. */
#define UIKIT_SWALLOW_SETTERS \
	- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector \
	{ \
		NSMethodSignature *signature = [super methodSignatureForSelector:selector]; \
		if (signature != nil) \
			return signature; \
		NSString *name = NSStringFromSelector(selector); \
		if (([name hasPrefix:@"set"] || [name hasPrefix:@"_set"]) && [name hasSuffix:@":"]) \
			return UIKitSetterSignature(name); \
		return nil; \
	} \
	- (void)forwardInvocation:(NSInvocation *)invocation \
	{ \
	}

/* The X11 window behind an AppKit window (Cocotron's X11Window._window). */
static unsigned long long UIKitNativeWindowID(NSWindow *window)
{
	if (window == nil || ![window respondsToSelector:@selector(platformWindow)])
		return 0;
	id platform = ((id (*)(id, SEL))objc_msgSend)(window, @selector(platformWindow));
	if (platform == nil)
		return 0;
	Ivar ivar = class_getInstanceVariable(object_getClass(platform), "_window");
	if (ivar == NULL)
		return 0;
	return *(unsigned long *)((char *)(__bridge void *)platform + ivar_getOffset(ivar));
}

#pragma mark - Scroll view

/* The page scrolls itself; this exists for the API apps reach for. */
@interface UIWebScrollView : UIScrollView
@end

@implementation UIWebScrollView

UIKIT_SWALLOW_SETTERS

@end

#pragma mark - Document view

@interface UIWebDocumentView ()
- (void)uikitUpdateEmbedding;
@end

@implementation UIWebDocumentView {
	WebView *_webView;
	NSTimer *_trackingTimer;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		_webView = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(overlaysChanged:) name:UIKitOverlaysDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_trackingTimer invalidate];
	[_webView dwkEmbedInParent:0 rect:CGRectZero visible:NO];
}

UIKIT_SWALLOW_SETTERS

- (WebView *)webView
{
	return _webView;
}

- (UIScrollView *)_scroller
{
	NSView *superview = [self superview];
	return [superview isKindOfClass:[UIScrollView class]] ? (UIScrollView *)superview : nil;
}

- (void)loadRequest:(NSURLRequest *)request
{
	[[_webView mainFrame] loadRequest:request];
}

- (CGRect)documentBounds
{
	return NSRectToCGRect([self bounds]);
}

- (void)enableReachability { }
- (void)redrawScaledDocument { }

- (void)overlaysChanged:(NSNotification *)notification
{
	[self uikitUpdateEmbedding];
}

/* Where the page goes: this view's rect in its window, from the top left. */
- (void)uikitUpdateEmbedding
{
	NSWindow *window = [self window];
	NSView *content = [window contentView];
	BOOL visible = window != nil && content != nil && [window isVisible] && ![self isHiddenOrHasHiddenAncestor] &&
		UIKitOverlayCount == 0;
	for (NSView *view = self; visible && view != nil; view = [view superview])
		if ([view alphaValue] <= 0.01)
			visible = NO;
	if (!visible) {
		[_webView dwkEmbedInParent:UIKitNativeWindowID(window) rect:CGRectZero visible:NO];
		return;
	}
	NSRect rect = [self convertRect:[self visibleRect] toView:content];
	if (![content isFlipped])
		rect.origin.y = [content bounds].size.height - NSMaxY(rect);
	visible = rect.size.width >= 1 && rect.size.height >= 1;
	[_webView dwkEmbedInParent:UIKitNativeWindowID(window) rect:NSRectToCGRect(rect) visible:visible];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[_trackingTimer invalidate];
	_trackingTimer = nil;
	if ([self window] != nil) {
		/* Ancestors move without telling their subviews: look again now and then. */
		_trackingTimer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(track:) userInfo:nil repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:_trackingTimer forMode:NSRunLoopCommonModes];
	}
	[self uikitUpdateEmbedding];
}

- (void)track:(NSTimer *)timer
{
	[self uikitUpdateEmbedding];
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	[self uikitUpdateEmbedding];
}

- (void)setFrameOrigin:(NSPoint)origin
{
	[super setFrameOrigin:origin];
	[self uikitUpdateEmbedding];
}

- (void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	[self uikitUpdateEmbedding];
}

- (void)drawRect:(NSRect)rect
{
	/* What shows until the page's window is placed (or with no host). */
	[[NSColor whiteColor] setFill];
	NSRectFill(rect);
}

@end

@implementation UIWebBrowserView
@end

#pragma mark - UIWebView

@implementation UIWebView {
	UIWebScrollView *_scrollView;
	UIWebDocumentView *_documentView;
	BOOL _loadingMainFrame;
}

@synthesize delegate = _delegate;
@synthesize scalesPageToFit = _scalesPageToFit;
@synthesize detectsPhoneNumbers = _detectsPhoneNumbers;
@synthesize dataDetectorTypes = _dataDetectorTypes;
@synthesize allowsInlineMediaPlayback = _allowsInlineMediaPlayback;
@synthesize mediaPlaybackRequiresUserAction = _mediaPlaybackRequiresUserAction;
@synthesize mediaPlaybackAllowsAirPlay = _mediaPlaybackAllowsAirPlay;
@synthesize suppressesIncrementalRendering = _suppressesIncrementalRendering;
@synthesize keyboardDisplayRequiresUserAction = _keyboardDisplayRequiresUserAction;

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]) == nil)
		return nil;
	_scrollView = [[UIWebScrollView alloc] initWithFrame:NSRectToCGRect([self bounds])];
	[_scrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[self addSubview:_scrollView];
	_documentView = [[UIWebBrowserView alloc] initWithFrame:NSRectToCGRect([_scrollView bounds])];
	[_documentView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[_scrollView addSubview:_documentView];
	_dataDetectorTypes = UIDataDetectorTypePhoneNumber;
	_mediaPlaybackRequiresUserAction = YES;

	WebView *webView = [_documentView webView];
	[webView setFrameLoadDelegate:self];
	[webView setPolicyDelegate:self];
	[webView setUIDelegate:self];
	[webView setResourceLoadDelegate:self];
	return self;
}

- (void)dealloc
{
	WebView *webView = [_documentView webView];
	[webView setFrameLoadDelegate:nil];
	[webView setPolicyDelegate:nil];
	[webView setUIDelegate:nil];
	[webView setResourceLoadDelegate:nil];
}

UIKIT_SWALLOW_SETTERS

- (WebView *)uikitWebView { return [_documentView webView]; }
- (UIWebDocumentView *)_documentView { return _documentView; }
- (UIWebDocumentView *)_browserView { return _documentView; }
- (UIScrollView *)scrollView { return _scrollView; }
- (UIScrollView *)_scrollView { return _scrollView; }
- (UIScrollView *)_scroller { return _scrollView; }
- (void)_updateViewSettings { }

- (NSURLRequest *)request
{
	WebFrame *frame = [[self uikitWebView] mainFrame];
	return [([frame provisionalDataSource] ?: [frame dataSource]) request];
}

- (BOOL)canGoBack { return [[self uikitWebView] canGoBack]; }
- (BOOL)canGoForward { return [[self uikitWebView] canGoForward]; }
- (BOOL)isLoading { return [[self uikitWebView] isLoading]; }

- (void)loadRequest:(NSURLRequest *)request { [[[self uikitWebView] mainFrame] loadRequest:request]; }
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL { [[[self uikitWebView] mainFrame] loadHTMLString:string baseURL:baseURL]; }

- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)textEncodingName baseURL:(NSURL *)baseURL
{
	[[[self uikitWebView] mainFrame] loadData:data MIMEType:MIMEType textEncodingName:textEncodingName baseURL:baseURL];
}

- (void)reload { [[self uikitWebView] reload:nil]; }
- (void)stopLoading { [[self uikitWebView] stopLoading:nil]; }
- (void)goBack { [[self uikitWebView] goBack]; }
- (void)goForward { [[self uikitWebView] goForward]; }

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script
{
	return [[self uikitWebView] stringByEvaluatingJavaScriptFromString:script];
}

- (void)setBackgroundColor:(UIColor *)color
{
	[super setBackgroundColor:color];
}

#pragma mark WebKit delegate methods

/* UIKit's UIWebView answers these for its WebView; subclasses override and
 * call through, so each must exist. */

- (void)webView:(WebView *)view decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	id<UIWebViewDelegate> delegate = _delegate;
	if ([frame parentFrame] == nil && [delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
		UIWebViewNavigationType type = (UIWebViewNavigationType)[[action objectForKey:WebActionNavigationTypeKey] integerValue];
		if (![delegate webView:self shouldStartLoadWithRequest:request navigationType:type]) {
			[listener ignore];
			return;
		}
	}
	[listener use];
}

- (void)webView:(WebView *)view decidePolicyForNewWindowAction:(NSDictionary *)action request:(NSURLRequest *)request newFrameName:(NSString *)name decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[listener use];
}

- (void)webView:(WebView *)view didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	if ([frame parentFrame] != nil)
		return;
	_loadingMainFrame = YES;
	id<UIWebViewDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(webViewDidStartLoad:)])
		[delegate webViewDidStartLoad:self];
}

- (void)webView:(WebView *)view didCommitLoadForFrame:(WebFrame *)frame
{
}

- (void)webView:(WebView *)view didFinishLoadForFrame:(WebFrame *)frame
{
	if ([frame parentFrame] != nil || !_loadingMainFrame)
		return;
	_loadingMainFrame = NO;
	id<UIWebViewDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(webViewDidFinishLoad:)])
		[delegate webViewDidFinishLoad:self];
}

- (void)reportFailure:(NSError *)error frame:(WebFrame *)frame
{
	if ([frame parentFrame] != nil)
		return;
	_loadingMainFrame = NO;
	id<UIWebViewDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(webView:didFailLoadWithError:)])
		[delegate webView:self didFailLoadWithError:error];
}

- (void)webView:(WebView *)view didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self reportFailure:error frame:frame];
}

- (void)webView:(WebView *)view didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self reportFailure:error frame:frame];
}

- (void)webView:(WebView *)view didClearWindowObject:(WebScriptObject *)window forFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)view didReceiveTitle:(id)title forFrame:(id)frame { }
- (void)webView:(WebView *)view addMessageToConsole:(NSDictionary *)message { }
- (void)webViewClose:(WebView *)view { }

- (NSURLRequest *)webView:(WebView *)view resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)source
{
	return request;
}

- (NSURLRequest *)webThreadWebView:(WebView *)view resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)source
{
	return request;
}

- (void)webView:(WebView *)view resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)source { }
- (void)webView:(WebView *)view resource:(id)identifier didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)source { }

- (void)webView:(WebView *)view runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

/* Nothing can wait for an answer here; confirm and keep the default. */
- (BOOL)webView:(WebView *)view runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	return YES;
}

- (NSString *)webView:(WebView *)view runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)text initiatedByFrame:(WebFrame *)frame
{
	return text;
}

@end
