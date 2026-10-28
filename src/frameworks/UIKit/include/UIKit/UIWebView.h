/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIWEBVIEW_H
#define UIKIT_UIWEBVIEW_H

#import <UIKit/UIView.h>
#import <UIKit/UIScrollView.h>

@class UIWebView, UIWebDocumentView, WebView;

typedef NS_ENUM(NSInteger, UIWebViewNavigationType) {
	UIWebViewNavigationTypeLinkClicked,
	UIWebViewNavigationTypeFormSubmitted,
	UIWebViewNavigationTypeBackForward,
	UIWebViewNavigationTypeReload,
	UIWebViewNavigationTypeFormResubmitted,
	UIWebViewNavigationTypeOther,
};

typedef NS_OPTIONS(NSUInteger, UIDataDetectorTypes) {
	UIDataDetectorTypePhoneNumber = 1 << 0,
	UIDataDetectorTypeLink = 1 << 1,
	UIDataDetectorTypeAddress = 1 << 2,
	UIDataDetectorTypeCalendarEvent = 1 << 3,
	UIDataDetectorTypeNone = 0,
	UIDataDetectorTypeAll = NSUIntegerMax,
	UIDataDetectorTypeAutomatic = 1 << 31,
};

@protocol UIWebViewDelegate <NSObject>
@optional
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webViewDidFinishLoad:(UIWebView *)webView;
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;
@end

/*
 * The page is drawn by darling-webhost in a native window kept over this
 * view; see WebKitLegacy's DWKBridge.h.  The legacy WebKit objects behind it
 * (-_documentView, -webView) are there for apps that reach for them.
 */
@interface UIWebView : UIView
@property (nonatomic, weak) id<UIWebViewDelegate> delegate;
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic) BOOL scalesPageToFit;
@property (nonatomic) BOOL detectsPhoneNumbers;
@property (nonatomic) UIDataDetectorTypes dataDetectorTypes;
@property (nonatomic) BOOL allowsInlineMediaPlayback;
@property (nonatomic) BOOL mediaPlaybackRequiresUserAction;
@property (nonatomic) BOOL mediaPlaybackAllowsAirPlay;
@property (nonatomic) BOOL suppressesIncrementalRendering;
@property (nonatomic) BOOL keyboardDisplayRequiresUserAction;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)textEncodingName baseURL:(NSURL *)baseURL;
- (void)reload;
- (void)stopLoading;
- (void)goBack;
- (void)goForward;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
/* Private UIKit API. */
- (UIWebDocumentView *)_documentView;
- (UIWebDocumentView *)_browserView;
- (UIScrollView *)_scrollView;
- (UIScrollView *)_scroller;
- (void)_updateViewSettings;
@end

/* Private UIKit: the view that hosts the legacy WebView. */
@interface UIWebDocumentView : UIView
- (WebView *)webView;
- (UIScrollView *)_scroller;
- (void)loadRequest:(NSURLRequest *)request;
- (CGRect)documentBounds;
@end

@interface UIWebBrowserView : UIWebDocumentView
@end

#endif /* UIKIT_UIWEBVIEW_H */
