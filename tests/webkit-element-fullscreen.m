#import <Foundation/Foundation.h>
#import <WebKit/WKWebViewConfiguration.h>
#include <stdio.h>

@interface NSObject (FullscreenPreferenceProbe)
- (id)preferences;
- (BOOL)isElementFullscreenEnabled;
- (void)setElementFullscreenEnabled:(BOOL)enabled;
- (BOOL)fullScreenEnabled;
- (void)setFullScreenEnabled:(BOOL)enabled;
@end

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int failures = 0;
    @try {
        WKWebViewConfiguration *first = [[WKWebViewConfiguration alloc] init];
        WKWebViewConfiguration *second = [[WKWebViewConfiguration alloc] init];
        id preferences = [first preferences];
        if ([preferences isElementFullscreenEnabled]) failures++;
        [preferences setElementFullscreenEnabled:YES];
        if (![preferences isElementFullscreenEnabled] || ![preferences fullScreenEnabled]) failures++;
        if ([[second preferences] isElementFullscreenEnabled]) failures++;
        [preferences setFullScreenEnabled:NO];
        if ([preferences isElementFullscreenEnabled]) failures++;
        [preferences setValue:@YES forKey:@"elementFullscreenEnabled"];
        if (![[preferences valueForKey:@"elementFullscreenEnabled"] boolValue]) failures++;
        [preferences setElementFullscreenEnabled:NO];
        if ([preferences fullScreenEnabled]) failures++;
        [first release];
        [second release];
    } @catch (NSException *exception) {
        fprintf(stderr, "FAIL: %s\n", [[exception reason] UTF8String]);
        failures++;
    }
    fprintf(stderr, "RESULT failures=%d\n", failures);
    [pool release];
    return failures ? 1 : 0;
}
