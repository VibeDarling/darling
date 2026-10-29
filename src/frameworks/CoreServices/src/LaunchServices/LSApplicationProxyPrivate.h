#import <Foundation/Foundation.h>

@interface LSApplicationProxy : NSObject {
	NSBundle *_bundle;
}
- (instancetype)initWithBundle:(NSBundle *)bundle;
- (NSString *)applicationIdentifier;
- (NSURL *)bundleURL;
@end

@interface LSDocumentProxy : NSObject {
	NSString *_name;
	NSString *_typeIdentifier;
	NSString *_MIMEType;
}
@end

/* Every app installed where iOS apps are, as LSApplicationProxy objects. */
NSArray<LSApplicationProxy *> *LSInstalledApplicationProxies(void);
