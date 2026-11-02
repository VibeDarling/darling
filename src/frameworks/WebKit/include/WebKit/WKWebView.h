/*
 This file is part of Darling.

 Copyright (C) 2017 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

/* AppKit, not just Foundation: the superclass is an NSView, which Foundation
 * does not declare. WebView.h in this same directory already imports Cocoa for
 * the same reason. */
#include <AppKit/AppKit.h>
#include <Foundation/Foundation.h>

@class WKWebViewHostState;
@class WKWebViewConfiguration;
@protocol WKNavigationDelegate;

/* WKWebView is a view on macOS, and an application that allocates one expects
 * to be able to put it in a window and have AppKit lay it out. Declared here as
 * an NSObject, which it is not: [super setFrame:] is an unrecognized selector,
 * the view can never be added to a window, and the app dies on its first layout
 * pass even when every other part of the proxy works.
 *
 * The class body stays empty. The implementation is supplied by the guest
 * (src/WKWebView.m and src/dwb-siblings.m), which proxies rendering to
 * darling-webkit-host over a Unix socket. */
@interface WKWebView : NSView {
@public
	WKWebViewHostState *_host;
	NSBitmapImageRep *_frameImage;
	NSString *_lastURL;
	WKWebViewConfiguration *_configuration;
	NSTimer *_frameTimer;
	id _navigationDelegate;
	BOOL _allowsBackForwardNavigationGestures;
	BOOL _allowsLinkPreview;
	BOOL _loading;
	NSString *_title;
	id _currentRequest;
	NSString *_customUserAgent;
	double _estimatedProgress;
	BOOL _drawsBackground;
}

@property (nonatomic, readonly, copy) WKWebViewConfiguration *configuration;
@property (nonatomic, assign) id <WKNavigationDelegate> navigationDelegate;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) double estimatedProgress;
@property (nonatomic) BOOL allowsBackForwardNavigationGestures;
@property (nonatomic, copy) NSString *customUserAgent;
@property (nonatomic) BOOL allowsLinkPreview;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic) BOOL drawsBackground;

- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)configuration;
- (id)loadRequest:(NSURLRequest *)request;
- (id)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (id)reload;
- (void)stopLoading;
- (id)goBack;
- (id)goForward;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id result, NSError *error))completionHandler;

@end

@interface WKWebView (Compatibility)

- (id)scrollView;
- (NSURLRequest *)request;
- (NSString *)loadingTitle;

@end
