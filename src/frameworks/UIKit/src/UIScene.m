/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UIScene.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIApplicationDelegate.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIStoryboard.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "UIKitPrivate.h"

UISceneSessionRole const UIWindowSceneSessionRoleApplication = @"UIWindowSceneSessionRoleApplication";
UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplayNonInteractive = @"UIWindowSceneSessionRoleExternalDisplayNonInteractive";
UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplay = @"UIWindowSceneSessionRoleExternalDisplayNonInteractive";

NSNotificationName const UISceneWillConnectNotification = @"UISceneWillConnectNotification";
NSNotificationName const UISceneDidDisconnectNotification = @"UISceneDidDisconnectNotification";
NSNotificationName const UISceneDidActivateNotification = @"UISceneDidActivateNotification";
NSNotificationName const UISceneWillDeactivateNotification = @"UISceneWillDeactivateNotification";
NSNotificationName const UISceneWillEnterForegroundNotification = @"UISceneWillEnterForegroundNotification";
NSNotificationName const UISceneDidEnterBackgroundNotification = @"UISceneDidEnterBackgroundNotification";

@implementation UISceneConfiguration {
	NSString *_name;
	UISceneSessionRole _role;
}

@synthesize sceneClass = _sceneClass;
@synthesize delegateClass = _delegateClass;
@synthesize storyboard = _storyboard;

+ (BOOL)supportsSecureCoding { return YES; }

+ (instancetype)configurationWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
	return [[self alloc] initWithName:name sessionRole:sessionRole];
}

- (instancetype)initWithName:(NSString *)name sessionRole:(UISceneSessionRole)sessionRole
{
	if ((self = [super init])) {
		_name = [name copy];
		_role = [sessionRole copy];
	}
	return self;
}

- (NSString *)name { return _name; }
- (UISceneSessionRole)role { return _role; }

- (id)copyWithZone:(NSZone *)zone
{
	UISceneConfiguration *copy = [[UISceneConfiguration alloc] initWithName:_name sessionRole:_role];
	copy->_sceneClass = _sceneClass;
	copy->_delegateClass = _delegateClass;
	copy->_storyboard = _storyboard;
	return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_role forKey:@"role"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [self initWithName:[coder decodeObjectForKey:@"name"] sessionRole:[coder decodeObjectForKey:@"role"]];
}

@end

@implementation UISceneSession {
	__weak UIScene *_scene;
	UISceneSessionRole _role;
	UISceneConfiguration *_configuration;
	NSString *_persistentIdentifier;
}

@synthesize stateRestorationActivity = _stateRestorationActivity;
@synthesize userInfo = _userInfo;

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initUIKitWithRole:(UISceneSessionRole)role
{
	if ((self = [super init])) {
		_role = [role copy];
		_persistentIdentifier = [[NSUUID UUID] UUIDString];
	}
	return self;
}

- (UIScene *)scene { return _scene; }
- (void)uikitSetScene:(UIScene *)scene { _scene = scene; }
- (UISceneSessionRole)role { return _role; }
- (UISceneConfiguration *)configuration { return _configuration; }
- (void)uikitSetConfiguration:(UISceneConfiguration *)configuration { _configuration = [configuration copy]; }
- (NSString *)persistentIdentifier { return _persistentIdentifier; }
- (void)encodeWithCoder:(NSCoder *)coder { }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initUIKitWithRole:UIWindowSceneSessionRoleApplication]; }

@end

@implementation UIOpenURLContext {
	NSURL *_URL;
}
- (NSURL *)URL { return _URL; }
@end

@implementation UISceneConnectionOptions
- (NSSet *)URLContexts { return [NSSet set]; }
- (NSString *)sourceApplication { return nil; }
- (NSString *)handoffUserActivityType { return nil; }
- (NSSet *)userActivities { return [NSSet set]; }
- (id)notificationResponse { return nil; }
- (id)shortcutItem { return nil; }
- (id)cloudKitShareMetadata { return nil; }
@end

@implementation UIScene {
	UISceneSession *_session;
	UISceneActivationState _activationState;
}

@synthesize delegate = _delegate;
@synthesize title = _title;

- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions
{
	if ((self = [super init])) {
		_session = session;
		[session uikitSetScene:self];
		_activationState = UISceneActivationStateUnattached;
	}
	return self;
}

- (UISceneSession *)session { return _session; }
- (UISceneActivationState)activationState { return _activationState; }
- (void)uikitSetActivationState:(UISceneActivationState)state { _activationState = state; }

- (void)openURL:(NSURL *)url options:(id)options completionHandler:(void (^)(BOOL success))completion
{
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:completion];
}

@end

@implementation UIStatusBarManager
- (NSInteger)statusBarStyle { return [(id)[UIApplication sharedApplication] statusBarStyle]; }
- (BOOL)isStatusBarHidden { return [[UIApplication sharedApplication] isStatusBarHidden]; }
- (CGRect)statusBarFrame { return [[UIApplication sharedApplication] statusBarFrame]; }
@end

@implementation UIWindowScene {
	NSHashTable<UIWindow *> *_windows;
	UIStatusBarManager *_statusBarManager;
}

- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions
{
	if ((self = [super initWithSession:session connectionOptions:connectionOptions])) {
		_windows = [NSHashTable weakObjectsHashTable];
		_statusBarManager = [[UIStatusBarManager alloc] init];
	}
	return self;
}

- (UIScreen *)screen { return [UIScreen mainScreen]; }
- (UIInterfaceOrientation)interfaceOrientation { return UIInterfaceOrientationPortrait; }
- (UIStatusBarManager *)statusBarManager { return _statusBarManager; }
- (UITraitCollection *)traitCollection { return [[UIScreen mainScreen] traitCollection]; }
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection { }

- (NSArray<UIWindow *> *)windows
{
	return [_windows allObjects];
}

- (UIWindow *)keyWindow
{
	UIWindow *key = [UIWindow uikitKeyWindow];
	return [_windows containsObject:key] ? key : nil;
}

- (void)uikitAddWindow:(UIWindow *)window { [_windows addObject:window]; }
- (void)uikitRemoveWindow:(UIWindow *)window { [_windows removeObject:window]; }

@end

#pragma mark - The window's scene

static char UIKitWindowSceneKey;

@implementation UIWindow (UIWindowScene)

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene
{
	if ((self = [self initWithFrame:[[windowScene screen] ?: [UIScreen mainScreen] bounds]]))
		[self setWindowScene:windowScene];
	return self;
}

- (UIWindowScene *)windowScene
{
	return objc_getAssociatedObject(self, &UIKitWindowSceneKey);
}

- (void)setWindowScene:(UIWindowScene *)windowScene
{
	UIWindowScene *old = [self windowScene];
	if (old == windowScene)
		return;
	[old uikitRemoveWindow:self];
	objc_setAssociatedObject(self, &UIKitWindowSceneKey, windowScene, OBJC_ASSOCIATION_ASSIGN);
	[windowScene uikitAddWindow:self];
}

@end

#pragma mark - Launch

static UIWindowScene *sMainScene;
static NSMutableSet<UISceneSession *> *sSessions;

UIWindowScene *UIKitMainWindowScene(void)
{
	return sMainScene;
}

static NSDictionary *UIKitSceneManifest(void)
{
	id manifest = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
	return [manifest isKindOfClass:[NSDictionary class]] ? manifest : nil;
}

BOOL UIKitUsesScenes(void)
{
	return UIKitSceneManifest() != nil;
}

/* The Info.plist's configurations for the role: a list of dictionaries. */
static NSArray<NSDictionary *> *UIKitPlistConfigurations(UISceneSessionRole role)
{
	id configurations = [[UIKitSceneManifest() objectForKey:@"UISceneConfigurations"] objectForKey:role];
	return [configurations isKindOfClass:[NSArray class]] ? configurations : @[];
}

static Class UIKitClassNamed(NSString *name)
{
	if (![name isKindOfClass:[NSString class]] || [name length] == 0)
		return Nil;
	Class cls = NSClassFromString(name);
	if (cls == Nil) {
		/* $(PRODUCT_MODULE_NAME).SceneDelegate, when the build did not
		 * expand it, or a Swift class under its module's name. */
		NSRange dot = [name rangeOfString:@"." options:NSBackwardsSearch];
		if (dot.location != NSNotFound)
			cls = NSClassFromString([name substringFromIndex:NSMaxRange(dot)]);
	}
	if (cls == Nil)
		NSLog(@"UIKit: no scene class or delegate named %@", name);
	return cls;
}

/* What a configuration leaves out, from the Info.plist's entry of the same
   name (or the first, when the app made it with none), as iOS fills it. */
static void UIKitCompleteConfiguration(UISceneConfiguration *configuration)
{
	NSArray<NSDictionary *> *entries = UIKitPlistConfigurations([configuration role] ?: UIWindowSceneSessionRoleApplication);
	NSDictionary *entry = nil;
	for (NSDictionary *candidate in entries)
		if ([configuration name] != nil && [[candidate objectForKey:@"UISceneConfigurationName"] isEqual:[configuration name]])
			entry = candidate;
	if (entry == nil && [configuration name] == nil)
		entry = [entries firstObject];
	if (entry == nil)
		return;
	if ([configuration sceneClass] == Nil)
		[configuration setSceneClass:UIKitClassNamed([entry objectForKey:@"UISceneClassName"])];
	if ([configuration delegateClass] == Nil)
		[configuration setDelegateClass:UIKitClassNamed([entry objectForKey:@"UISceneDelegateClassName"])];
	NSString *storyboard = [entry objectForKey:@"UISceneStoryboardFile"];
	if ([configuration storyboard] == nil && [storyboard isKindOfClass:[NSString class]])
		[configuration setStoryboard:[UIStoryboard storyboardWithName:storyboard bundle:[NSBundle mainBundle]]];
}

static void UIKitSceneNotify(UIScene *scene, SEL selector, NSNotificationName name)
{
	id delegate = [scene delegate];
	if ([delegate respondsToSelector:selector])
		((void (*)(id, SEL, UIScene *))objc_msgSend)(delegate, selector, scene);
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:scene];
}

/* One window scene, for the app's whole screen, as an iPhone has. */
void UIKitConnectMainScene(UIApplication *application)
{
	if (sMainScene != nil)
		return;
	UISceneSession *session = [[UISceneSession alloc] initUIKitWithRole:UIWindowSceneSessionRoleApplication];
	UISceneConnectionOptions *options = [[UISceneConnectionOptions alloc] init];
	id<UIApplicationDelegate> appDelegate = [application delegate];

	UISceneConfiguration *configuration = nil;
	if ([appDelegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)])
		configuration = [(id)appDelegate application:application configurationForConnectingSceneSession:session options:options];
	if (configuration == nil) {
		NSDictionary *entry = [UIKitPlistConfigurations(UIWindowSceneSessionRoleApplication) firstObject];
		configuration = [UISceneConfiguration configurationWithName:[entry objectForKey:@"UISceneConfigurationName"]
		                                               sessionRole:UIWindowSceneSessionRoleApplication];
	}
	UIKitCompleteConfiguration(configuration);
	[session uikitSetConfiguration:configuration];
	if (sSessions == nil)
		sSessions = [NSMutableSet set];
	[sSessions addObject:session];

	Class sceneClass = [configuration sceneClass];
	if (sceneClass == Nil || ![sceneClass isSubclassOfClass:[UIWindowScene class]])
		sceneClass = [UIWindowScene class];
	UIWindowScene *scene = [[sceneClass alloc] initWithSession:session connectionOptions:options];
	sMainScene = scene;
	Class delegateClass = [configuration delegateClass];
	id delegate = delegateClass != Nil ? [[delegateClass alloc] init] : nil;
	[scene setDelegate:delegate];

	/* The storyboard's window is made before the delegate hears of the
	   scene, and shown after. */
	UIWindow *window = nil;
	UIStoryboard *storyboard = [configuration storyboard];
	if (storyboard != nil) {
		UIViewController *controller = [storyboard instantiateInitialViewController];
		window = [[UIWindow alloc] initWithWindowScene:scene];
		[window setRootViewController:controller];
		if ([delegate respondsToSelector:@selector(setWindow:)])
			[delegate setWindow:window];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:UISceneWillConnectNotification object:scene];
	if ([delegate respondsToSelector:@selector(scene:willConnectToSession:options:)])
		[delegate scene:scene willConnectToSession:session options:options];
	if (window != nil) {
		UIWindow *shown = [delegate respondsToSelector:@selector(window)] ? [delegate window] : window;
		if (shown != nil && [shown isHidden])
			[shown makeKeyAndVisible];
	}
	[scene uikitSetActivationState:UISceneActivationStateBackground];
}

void UIKitScenesEnterForeground(void)
{
	if (sMainScene == nil || [sMainScene activationState] != UISceneActivationStateBackground)
		return;
	UIKitSceneNotify(sMainScene, @selector(sceneWillEnterForeground:), UISceneWillEnterForegroundNotification);
	[sMainScene uikitSetActivationState:UISceneActivationStateForegroundInactive];
}

void UIKitScenesBecomeActive(void)
{
	UIKitScenesEnterForeground();
	if (sMainScene == nil || [sMainScene activationState] != UISceneActivationStateForegroundInactive)
		return;
	[sMainScene uikitSetActivationState:UISceneActivationStateForegroundActive];
	UIKitSceneNotify(sMainScene, @selector(sceneDidBecomeActive:), UISceneDidActivateNotification);
}

void UIKitScenesResignActive(void)
{
	if (sMainScene == nil || [sMainScene activationState] != UISceneActivationStateForegroundActive)
		return;
	UIKitSceneNotify(sMainScene, @selector(sceneWillResignActive:), UISceneWillDeactivateNotification);
	[sMainScene uikitSetActivationState:UISceneActivationStateForegroundInactive];
}

void UIKitScenesEnterBackground(void)
{
	UIKitScenesResignActive();
	if (sMainScene == nil || [sMainScene activationState] != UISceneActivationStateForegroundInactive)
		return;
	[sMainScene uikitSetActivationState:UISceneActivationStateBackground];
	UIKitSceneNotify(sMainScene, @selector(sceneDidEnterBackground:), UISceneDidEnterBackgroundNotification);
}

void UIKitScenesDisconnect(void)
{
	if (sMainScene == nil)
		return;
	UIKitScenesEnterBackground();
	[sMainScene uikitSetActivationState:UISceneActivationStateUnattached];
	UIKitSceneNotify(sMainScene, @selector(sceneDidDisconnect:), UISceneDidDisconnectNotification);
}

#pragma mark - UIApplication

@implementation UIApplication (UIScene)

- (NSSet<UIScene *> *)connectedScenes
{
	return sMainScene != nil ? [NSSet setWithObject:sMainScene] : [NSSet set];
}

- (NSSet<UISceneSession *> *)openSessions
{
	return [sSessions copy] ?: [NSSet set];
}

- (BOOL)supportsMultipleScenes
{
	return NO;
}

- (void)requestSceneSessionActivation:(UISceneSession *)sceneSession userActivity:(NSUserActivity *)userActivity options:(id)options errorHandler:(void (^)(NSError *error))errorHandler
{
	if (errorHandler != nil)
		errorHandler([NSError errorWithDomain:@"UISceneErrorDomain" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"The application does not support multiple scenes." }]);
}

- (void)requestSceneSessionDestruction:(UISceneSession *)sceneSession options:(id)options errorHandler:(void (^)(NSError *error))errorHandler
{
	if (errorHandler != nil)
		errorHandler([NSError errorWithDomain:@"UISceneErrorDomain" code:0 userInfo:nil]);
}

- (void)requestSceneSessionRefresh:(UISceneSession *)sceneSession { }

@end
