#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <stdio.h>
#include <stdlib.h>

@interface WKWebView (PendingErrorRegression)
- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)configuration;
@end

@interface PendingErrorDelegate : NSObject {
@public
    NSString *description;
}
@end

@implementation PendingErrorDelegate
- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(id)navigation withError:(NSError *)error {
    [description release];
    description = [[error localizedDescription] copy];
}
@end

/* A webview with no reachable host records an error at construction. The error
 * is reported from a frame timer on a later run loop turn, after the creating
 * autorelease pool has drained, so the stored message must still be alive. */
int main(void) {
    setenv("DWB_WEBKIT_SOCKET", "/nonexistent/darling-webkit-host.sock", 1);
    PendingErrorDelegate *delegate = [[PendingErrorDelegate alloc] init];
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    WKWebView *view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                         configuration:[[[WKWebViewConfiguration alloc] init] autorelease]];
    [view setNavigationDelegate:(id)delegate];
    [pool drain];

    /* Reuse the freed autoreleased storage so a dangling message is not benign. */
    pool = [NSAutoreleasePool new];
    for (int i = 0; i < 4096; i++)
        (void)[NSString stringWithFormat:@"filler %d %s", i, "darling-webkit-host is not reachable at xx"];
    [pool drain];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    BOOL delivered = delegate->description != nil &&
        [delegate->description rangeOfString:@"darling-webkit-host is not reachable"].location != NSNotFound;
    fprintf(stderr, "%s pending error delivered intact\n", delivered ? "PASS" : "FAIL");
    [view release];
    return delivered ? 0 : 1;
}
