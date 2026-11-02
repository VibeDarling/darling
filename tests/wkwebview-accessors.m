#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        printf("=== Testing WKWebView accessors (Issue #1252) ===\n");

        printf("Bundle for WKWebView: %s\n", [[[NSBundle bundleForClass:[WKWebView class]] bundlePath] UTF8String]);

        unsigned int count = 0;
        Method *methods = class_copyMethodList([WKWebView class], &count);
        printf("WKWebView has %u methods:\n", count);
        for (unsigned int i = 0; i < count; i++) {
            SEL sel = method_getName(methods[i]);
            printf("  - %s\n", sel_getName(sel));
        }
        free(methods);

        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        if (!config) {
            fprintf(stderr, "FAIL: WKWebViewConfiguration alloc/init failed\n");
            return 1;
        }
        printf("PASS: WKWebViewConfiguration created\n");

        WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600) configuration:config];
        if (!webView) {
            fprintf(stderr, "FAIL: WKWebView initWithFrame:configuration: failed\n");
            return 1;
        }
        printf("PASS: WKWebView instantiated\n");

        // 1. configuration
        if (![webView respondsToSelector:@selector(configuration)]) {
            fprintf(stderr, "FAIL: does not respond to -configuration\n");
            return 1;
        }
        WKWebViewConfiguration *storedConfig1 = [webView configuration];
        WKWebViewConfiguration *storedConfig2 = [webView configuration];
        if (storedConfig1 == nil || storedConfig2 == nil) {
            fprintf(stderr, "FAIL: -configuration returned nil\n");
            return 1;
        }
        if (storedConfig1 == config || storedConfig2 == config) {
            fprintf(stderr, "FAIL: -configuration returned original instance without copy\n");
            return 1;
        }
        if (storedConfig1 == storedConfig2) {
            fprintf(stderr, "FAIL: -configuration does not return an independent copy on access\n");
            return 1;
        }
        printf("PASS: -configuration accessor verified (copy semantics confirmed)\n");

        // 2. URL
        if (![webView respondsToSelector:@selector(URL)]) {
            fprintf(stderr, "FAIL: does not respond to -URL\n");
            return 1;
        }
        NSURL *url = [webView URL];
        if (url != nil) {
            fprintf(stderr, "FAIL: initial -URL expected nil, got %s\n", [[url description] UTF8String]);
            return 1;
        }
        printf("PASS: -URL accessor verified (initial nil)\n");

        // 3. isLoading
        if (![webView respondsToSelector:@selector(isLoading)]) {
            fprintf(stderr, "FAIL: does not respond to -isLoading\n");
            return 1;
        }
        if ([webView isLoading] != NO) {
            fprintf(stderr, "FAIL: initial -isLoading expected NO\n");
            return 1;
        }
        printf("PASS: -isLoading accessor verified (initial NO)\n");

        // 4. estimatedProgress
        if (![webView respondsToSelector:@selector(estimatedProgress)]) {
            fprintf(stderr, "FAIL: does not respond to -estimatedProgress\n");
            return 1;
        }
        double progress = [webView estimatedProgress];
        if (progress < 0.0 || progress > 1.0) {
            fprintf(stderr, "FAIL: initial -estimatedProgress out of bounds: %f\n", progress);
            return 1;
        }
        printf("PASS: -estimatedProgress accessor verified (%f)\n", progress);

        // 5. title
        if (![webView respondsToSelector:@selector(title)]) {
            fprintf(stderr, "FAIL: does not respond to -title\n");
            return 1;
        }
        NSString *title = [webView title];
        if (![title isEqualToString:@""]) {
            fprintf(stderr, "FAIL: initial -title expected empty string, got '%s'\n", [title UTF8String]);
            return 1;
        }
        printf("PASS: -title accessor verified (initial empty string)\n");

        // 6. customUserAgent
        if (![webView respondsToSelector:@selector(customUserAgent)] ||
            ![webView respondsToSelector:@selector(setCustomUserAgent:)]) {
            fprintf(stderr, "FAIL: does not respond to customUserAgent accessors\n");
            return 1;
        }
        NSString *ua = @"Mozilla/5.0 (Darling; TestSuite) AppleWebKit/605.1.15";
        [webView setCustomUserAgent:ua];
        if (![[webView customUserAgent] isEqualToString:ua]) {
            fprintf(stderr, "FAIL: -customUserAgent roundtrip failed\n");
            return 1;
        }
        printf("PASS: -customUserAgent / -setCustomUserAgent: verified\n");

        // 7. allowsBackForwardNavigationGestures
        if (![webView respondsToSelector:@selector(allowsBackForwardNavigationGestures)] ||
            ![webView respondsToSelector:@selector(setAllowsBackForwardNavigationGestures:)]) {
            fprintf(stderr, "FAIL: does not respond to allowsBackForwardNavigationGestures accessors\n");
            return 1;
        }
        [webView setAllowsBackForwardNavigationGestures:YES];
        if ([webView allowsBackForwardNavigationGestures] != YES) {
            fprintf(stderr, "FAIL: setAllowsBackForwardNavigationGestures roundtrip failed\n");
            return 1;
        }
        printf("PASS: allowsBackForwardNavigationGestures verified\n");

        // 8. allowsLinkPreview
        if (![webView respondsToSelector:@selector(allowsLinkPreview)] ||
            ![webView respondsToSelector:@selector(setAllowsLinkPreview:)]) {
            fprintf(stderr, "FAIL: does not respond to allowsLinkPreview accessors\n");
            return 1;
        }
        [webView setAllowsLinkPreview:YES];
        if ([webView allowsLinkPreview] != YES) {
            fprintf(stderr, "FAIL: setAllowsLinkPreview roundtrip failed\n");
            return 1;
        }
        printf("PASS: allowsLinkPreview verified\n");

        // 9. canGoBack / canGoForward
        if (![webView respondsToSelector:@selector(canGoBack)] ||
            ![webView respondsToSelector:@selector(canGoForward)]) {
            fprintf(stderr, "FAIL: does not respond to canGoBack / canGoForward\n");
            return 1;
        }
        if ([webView canGoBack] != NO || [webView canGoForward] != NO) {
            fprintf(stderr, "FAIL: initial canGoBack / canGoForward expected NO\n");
            return 1;
        }
        printf("PASS: canGoBack / canGoForward verified (NO)\n");

        // 10. compatibility accessors: scrollView, request, loadingTitle, drawsBackground
        if (![webView respondsToSelector:@selector(scrollView)]) {
            fprintf(stderr, "FAIL: does not respond to -scrollView\n");
            return 1;
        }
        printf("PASS: -scrollView verified\n");

        if (![webView respondsToSelector:@selector(request)]) {
            fprintf(stderr, "FAIL: does not respond to -request\n");
            return 1;
        }
        printf("PASS: -request verified\n");

        if (![webView respondsToSelector:@selector(loadingTitle)]) {
            fprintf(stderr, "FAIL: does not respond to -loadingTitle\n");
            return 1;
        }
        printf("PASS: -loadingTitle verified\n");

        if (![webView respondsToSelector:@selector(drawsBackground)] ||
            ![webView respondsToSelector:@selector(setDrawsBackground:)]) {
            fprintf(stderr, "FAIL: does not respond to drawsBackground accessors\n");
            return 1;
        }
        [webView setDrawsBackground:NO];
        if ([webView drawsBackground] != NO) {
            fprintf(stderr, "FAIL: setDrawsBackground roundtrip failed\n");
            return 1;
        }
        printf("PASS: drawsBackground verified\n");

        // 11. evaluateJavaScript:completionHandler:
        __block BOOL completionCalled = NO;
        __block id evalResult = nil;
        [webView evaluateJavaScript:@"2 + 2" completionHandler:^(id result, NSError *error) {
            completionCalled = YES;
            evalResult = [result retain];
        }];

        // Drain the run loop to allow dispatch_async on main queue to execute
        NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
        while (!completionCalled && [limitDate timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        if (!completionCalled) {
            fprintf(stderr, "FAIL: evaluateJavaScript completionHandler was not called within timeout\n");
            return 1;
        }
        printf("PASS: evaluateJavaScript:completionHandler: invoked cleanly and completion executed\n");
        [evalResult release];

        printf("ALL 11 WKWebView ACCESSOR CHECKS PASSED!\n");
    }

    return 0;
}
