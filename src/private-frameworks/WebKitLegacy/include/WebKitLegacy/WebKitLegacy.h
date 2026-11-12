/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * iOS's legacy WebKit (the engine behind UIWebView), as Darling provides
 * it: the Objective-C surface apps reach through UIWebView's private API.
 * Pages render in darling-webhost; see DWKBridge.h.
 */

#ifndef WEBKITLEGACY_H
#define WEBKITLEGACY_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <WebKitLegacy/WebScriptObject.h>
#import <WebKitLegacy/WebThread.h>

@class WebView, WebFrame, WebDataSource, WebPreferences, DOMDocument;

extern NSString *const WebKitErrorDomain;
enum {
	WebKitErrorCannotShowMIMEType = 100,
	WebKitErrorCannotShowURL = 101,
	WebKitErrorFrameLoadInterruptedByPolicyChange = 102,
};

/* Navigation action dictionary keys and types (WebPolicyDelegate.h). */
extern NSString *const WebActionNavigationTypeKey;
extern NSString *const WebActionElementKey;
extern NSString *const WebActionButtonKey;
extern NSString *const WebActionModifierFlagsKey;
extern NSString *const WebActionOriginalURLKey;
typedef NS_ENUM(NSInteger, WebNavigationType) {
	WebNavigationTypeLinkClicked,
	WebNavigationTypeFormSubmitted,
	WebNavigationTypeBackForward,
	WebNavigationTypeReload,
	WebNavigationTypeFormResubmitted,
	WebNavigationTypeOther,
};

extern NSString *const WebElementFrameKey;
extern NSString *const WebKitLocalStorageDatabasePathPreferenceKey;

@protocol WebPolicyDecisionListener <NSObject>
- (void)use;
- (void)download;
- (void)ignore;
@end

/* The delegate methods WebView calls (WebPolicyDelegate.h). */
@interface NSObject (WebPolicyDelegate)
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener;
- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener;
@end

typedef NS_ENUM(NSUInteger, WebCacheModel) {
	WebCacheModelDocumentViewer = 0,
	WebCacheModelDocumentBrowser = 1,
	WebCacheModelPrimaryWebBrowser = 2,
};

@interface WebPreferences : NSObject
+ (WebPreferences *)standardPreferences;
+ (void)_setInitialDefaultTextEncodingToSystemEncoding;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic) BOOL javaScriptEnabled;
@property (nonatomic) BOOL javaScriptCanOpenWindowsAutomatically;
@property (nonatomic) BOOL offlineWebApplicationCacheEnabled;
@property (nonatomic) BOOL plugInsEnabled;
@property (nonatomic) WebCacheModel cacheModel;
@property (nonatomic, copy) NSString *defaultTextEncodingName;
- (void)_setLayoutInterval:(int)interval;
- (void)_setLocalStorageDatabasePath:(NSString *)path;
- (void)setStorageBlockingPolicy:(NSInteger)policy;
@end

@interface WebDataSource : NSObject
@property (nonatomic, readonly) NSURLRequest *initialRequest;
@property (nonatomic, readonly) NSMutableURLRequest *request;
@property (nonatomic, readonly) NSURLResponse *response;
@property (nonatomic, readonly) WebFrame *webFrame;
@property (nonatomic, readonly) NSString *pageTitle;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) NSURL *unreachableURL;
- (NSData *)data;
- (NSString *)textEncodingName;
@end

@interface WebFrame : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) WebView *webView;
@property (nonatomic, readonly) WebDataSource *dataSource;
@property (nonatomic, readonly) WebDataSource *provisionalDataSource;
@property (nonatomic, readonly) WebFrame *parentFrame;
@property (nonatomic, readonly) NSArray *childFrames;
@property (nonatomic, readonly) WebScriptObject *windowObject;
@property (nonatomic, readonly) DOMDocument *DOMDocument;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)URL;
- (void)stopLoading;
- (void)reload;
- (void)reloadFromOrigin;
- (void)setNeedsLayout;
/* There is no JavaScriptCore context in this process: always NULL. */
- (JSGlobalContextRef)globalContext;
@end

/*
 * On iOS a WebView is a WAKView inside UIKit's document view.  Here it holds
 * the page's state and delegates, and darling-webhost draws the page in a
 * native child window that UIKit positions over the hosting view.
 */
@interface WebView : NSObject
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame frameName:(NSString *)frameName groupName:(NSString *)groupName;
@property (nonatomic, readonly) WebFrame *mainFrame;
@property (nonatomic, strong) WebPreferences *preferences;
@property (nonatomic, weak) id frameLoadDelegate;
@property (nonatomic, weak) id policyDelegate;
@property (nonatomic, weak) id UIDelegate;
@property (nonatomic, weak) id resourceLoadDelegate;
@property (nonatomic, weak) id downloadDelegate;
@property (nonatomic, copy) NSString *customUserAgent;
@property (nonatomic, copy) NSString *applicationNameForUserAgent;
@property (nonatomic, copy) NSString *groupName;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly) double estimatedProgress;
@property (nonatomic, readonly) NSString *mainFrameTitle;
@property (nonatomic, readonly) NSString *mainFrameURL;
- (WebScriptObject *)windowScriptObject;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (void)reload:(id)sender;
- (void)reloadFromOrigin:(id)sender;
- (void)stopLoading:(id)sender;
- (BOOL)goBack;
- (BOOL)goForward;
- (void)close;
- (void)_preferencesChanged:(WebPreferences *)preferences;
- (void)_preferencesChangedNotification:(NSNotification *)notification;
- (void)setDrawsBackground:(BOOL)draws;
- (void)setMediaPlaybackRequiresUserGesture:(BOOL)requires;

/* Darling: where the page is shown.  The parent is an X11 window id (an
 * Android view id elsewhere); the rect is in its coordinates, top left. */
- (void)dwkEmbedInParent:(unsigned long long)parent rect:(CGRect)rect visible:(BOOL)visible;
@end

#endif
