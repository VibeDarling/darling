#import <AppKit/AppKit.h>
#import <Foundation/NSLayoutAnchor.h>
#import <WebKit/WebKit.h>
#include <math.h>
#include <stdio.h>
@interface WKWebView (FrameRegression)
- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)configuration;
@end
int main(void) {
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    WKWebView *view=[[[WKWebView alloc] initWithFrame:NSZeroRect configuration:[[[WKWebViewConfiguration alloc] init] autorelease]] autorelease];
    NSRect requested=NSMakeRect(7,11,320,180);
    [view setFrame:requested];
    int failures=!NSEqualRects([view frame],requested);
    fprintf(stderr,"%s direct frame update\n",failures?"FAIL":"PASS");
    NSView *parent=[[[NSView alloc] initWithFrame:NSMakeRect(0,0,400,300)] autorelease];
    [view setTranslatesAutoresizingMaskIntoConstraints:NO]; [parent addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [[view leadingAnchor] constraintEqualToAnchor:[parent leadingAnchor]],
        [[view trailingAnchor] constraintEqualToAnchor:[parent trailingAnchor]],
        [[view topAnchor] constraintEqualToAnchor:[parent topAnchor]],
        [[view bottomAnchor] constraintEqualToAnchor:[parent bottomAnchor]]]];
    [parent layoutSubtreeIfNeeded];
    BOOL fits=NSEqualRects([view frame],NSMakeRect(0,0,400,300));
    fprintf(stderr,"%s frame applied by constraint layout\n",fits?"PASS":"FAIL");
    if(!fits) failures++;
    [pool drain]; return failures?1:0;
}
