/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIActivityViewController.h>
#import <UIKit/UIDocumentInteractionController.h>
#import <UIKit/UIImagePickerController.h>
#import <UIKit/UIMenuController.h>
#import <UIKit/UIPrintInteractionController.h>
#import <UIKit/UIAlertView.h>
#import <UIKit/UIPasteboard.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIFont.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>
#import "UIKitPrivate.h"
#import <objc/message.h>

#pragma mark - UIActivity

@interface UIActivity ()
@property (nonatomic, copy) void (^uikitFinished)(BOOL completed);
@end

@implementation UIActivity

@synthesize uikitFinished = _uikitFinished;

+ (UIActivityCategory)activityCategory { return UIActivityCategoryAction; }
- (UIActivityType)activityType { return NSStringFromClass([self class]); }
- (NSString *)activityTitle { return nil; }
- (UIImage *)activityImage { return nil; }
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems { return NO; }
- (void)prepareWithActivityItems:(NSArray *)activityItems { }
- (UIViewController *)activityViewController { return nil; }
- (void)performActivity { [self activityDidFinish:NO]; }

- (void)activityDidFinish:(BOOL)completed
{
	void (^finished)(BOOL) = _uikitFinished;
	_uikitFinished = nil;
	UIViewController *controller = [self activityViewController];
	if ([controller presentingViewController] != nil)
		[controller dismissViewControllerAnimated:YES completion:nil];
	if (finished != nil)
		finished(completed);
}

@end

/* The built-in Copy activity. */
@interface UIKitCopyActivity : UIActivity {
	NSArray *_items;
}
@end

@implementation UIKitCopyActivity

- (UIActivityType)activityType { return UIActivityTypeCopyToPasteboard; }
- (NSString *)activityTitle { return @"Copy"; }

- (BOOL)canPerformWithActivityItems:(NSArray *)items
{
	for (id item in items)
		if ([item isKindOfClass:[NSString class]] || [item isKindOfClass:[NSURL class]] || [item isKindOfClass:[NSAttributedString class]])
			return YES;
	return NO;
}

- (void)prepareWithActivityItems:(NSArray *)items { _items = [items copy]; }

- (void)performActivity
{
	UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
	for (id item in _items) {
		if ([item isKindOfClass:[NSURL class]]) {
			[pasteboard setURL:item];
			break;
		}
		if ([item isKindOfClass:[NSString class]] || [item isKindOfClass:[NSAttributedString class]]) {
			[pasteboard setString:[item isKindOfClass:[NSString class]] ? item : [item string]];
			break;
		}
	}
	[self activityDidFinish:YES];
}

@end

#pragma mark - UIActivityViewController

/* Shown over what presented it, as an action sheet of the activities. */
@interface UIActivityViewController () <UIActionSheetDelegate>
@end

@implementation UIActivityViewController {
	NSArray *_items;
	NSArray<UIActivity *> *_applicationActivities;
	NSArray<UIActivity *> *_shownActivities;
	BOOL _sheetShown;
}

@synthesize completionHandler = _completionHandler;
@synthesize completionWithItemsHandler = _completionWithItemsHandler;
@synthesize excludedActivityTypes = _excludedActivityTypes;

- (instancetype)initWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray *)applicationActivities
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_items = [activityItems copy] ?: @[];
		_applicationActivities = [applicationActivities copy] ?: @[];
		[self setModalPresentationStyle:UIModalPresentationFormSheet];
	}
	return self;
}

/* Items may be providers that say what to share. */
- (NSArray *)uikitResolvedItems
{
	NSMutableArray *items = [NSMutableArray array];
	for (id item in _items) {
		id value = item;
		if ([item respondsToSelector:@selector(activityViewController:itemForActivityType:)])
			value = ((id (*)(id, SEL, id, id))objc_msgSend)(item, @selector(activityViewController:itemForActivityType:), self, nil);
		else if ([item respondsToSelector:@selector(activityViewControllerPlaceholderItem:)])
			value = ((id (*)(id, SEL, id))objc_msgSend)(item, @selector(activityViewControllerPlaceholderItem:), self);
		if (value != nil)
			[items addObject:value];
	}
	return items;
}

- (void)loadView
{
	UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[view setBackgroundColor:[UIColor clearColor]];
	[self setView:view];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (_sheetShown)
		return;
	_sheetShown = YES;
	NSArray *items = [self uikitResolvedItems];
	NSMutableArray *activities = [NSMutableArray array];
	for (UIActivity *activity in [_applicationActivities arrayByAddingObject:[[UIKitCopyActivity alloc] init]])
		if (![_excludedActivityTypes containsObject:[activity activityType]] && [activity canPerformWithActivityItems:items])
			[activities addObject:activity];
	_shownActivities = activities;
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	for (UIActivity *activity in activities)
		[sheet addButtonWithTitle:[activity activityTitle] ?: [activity activityType]];
	[sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Cancel"]];
	[sheet showInView:[self view]];
}

- (void)uikitFinish:(UIActivityType)type completed:(BOOL)completed
{
	if (_completionWithItemsHandler != nil)
		_completionWithItemsHandler(type, completed, nil, nil);
	else if (_completionHandler != nil)
		_completionHandler(type, completed);
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index
{
	UIViewController *presenter = [self presentingViewController];
	[self dismissViewControllerAnimated:YES completion:nil];
	if (index < 0 || index >= (NSInteger)[_shownActivities count]) {
		[self uikitFinish:nil completed:NO];
		return;
	}
	UIActivity *activity = [_shownActivities objectAtIndex:index];
	__weak UIActivityViewController *weakSelf = self;
	UIActivityType type = [activity activityType];
	[activity setUikitFinished:^(BOOL completed) {
		[weakSelf uikitFinish:type completed:completed];
	}];
	[activity prepareWithActivityItems:[self uikitResolvedItems]];
	UIViewController *controller = [activity activityViewController];
	if (controller != nil)
		[presenter presentViewController:controller animated:YES completion:nil];
	else
		[activity performActivity];
}

@end

#pragma mark - UIDocumentInteractionController

@implementation UIDocumentInteractionController {
	NSURL *_URL;
	NSString *_name;
}

@synthesize delegate = _delegate;
@synthesize UTI = _UTI;
@synthesize annotation = _annotation;

+ (instancetype)interactionControllerWithURL:(NSURL *)url
{
	UIDocumentInteractionController *controller = [[self alloc] init];
	[controller setURL:url];
	return controller;
}

- (NSURL *)URL { return _URL; }
- (void)setURL:(NSURL *)url { _URL = url; }
- (NSString *)name { return _name ?: [_URL lastPathComponent]; }
- (void)setName:(NSString *)name { _name = [name copy]; }
- (NSArray *)icons { return @[]; }
- (NSArray *)gestureRecognizers { return @[]; }

- (BOOL)presentPreviewAnimated:(BOOL)animated
{
	NSLog(@"UIDocumentInteractionController: cannot preview %@", _URL);
	return NO;
}

- (BOOL)presentOptionsMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated { return NO; }
- (BOOL)presentOptionsMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { return NO; }
- (BOOL)presentOpenInMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated { return NO; }
- (BOOL)presentOpenInMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated { return NO; }
- (void)dismissPreviewAnimated:(BOOL)animated { }
- (void)dismissMenuAnimated:(BOOL)animated { }

@end

#pragma mark - UIImagePickerController

@implementation UIImagePickerController

@dynamic delegate;
@synthesize sourceType = _sourceType;
@synthesize mediaTypes = _mediaTypes;
@synthesize allowsEditing = _allowsEditing;
@synthesize videoMaximumDuration = _videoMaximumDuration;
@synthesize videoQuality = _videoQuality;
@synthesize showsCameraControls = _showsCameraControls;
@synthesize cameraOverlayView = _cameraOverlayView;
@synthesize cameraViewTransform = _cameraViewTransform;
@synthesize cameraDevice = _cameraDevice;
@synthesize cameraCaptureMode = _cameraCaptureMode;
@synthesize cameraFlashMode = _cameraFlashMode;

+ (BOOL)isSourceTypeAvailable:(UIImagePickerControllerSourceType)sourceType { return NO; }
+ (NSArray *)availableMediaTypesForSourceType:(UIImagePickerControllerSourceType)sourceType { return nil; }
+ (BOOL)isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)cameraDevice { return NO; }
+ (BOOL)isFlashAvailableForCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice { return NO; }

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
	if ((self = [super initWithNibName:nibName bundle:bundle]) == nil)
		return nil;
	_mediaTypes = @[ @"public.image" ];
	_videoMaximumDuration = 600;
	_cameraViewTransform = CGAffineTransformIdentity;
	_cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
	UIViewController *empty = [[UIViewController alloc] init];
	[empty setTitle:@"Photos"];
	[[empty navigationItem] setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(uikitCancel:)]];
	[self setViewControllers:@[ empty ]];
	return self;
}

- (BOOL)allowsImageEditing { return _allowsEditing; }
- (void)setAllowsImageEditing:(BOOL)allows { _allowsEditing = allows; }

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIView *content = [[[self viewControllers] firstObject] view];
	UILabel *label = [[UILabel alloc] initWithFrame:[content bounds]];
	[label setText:@"No Photos or Videos"];
	[label setTextAlignment:NSCenterTextAlignment];
	[label setTextColor:[UIColor grayColor]];
	[label setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[content addSubview:label];
}

- (void)uikitCancel:(id)sender
{
	id delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(imagePickerControllerDidCancel:)])
		[delegate imagePickerControllerDidCancel:self];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)takePicture { }
- (BOOL)startVideoCapture { return NO; }
- (void)stopVideoCapture { }

@end

/* There is no photo album: saving reports an error. */
static void UIKitReportSaveFailure(id target, SEL selector, id item, void *context)
{
	if (target == nil || selector == NULL)
		return;
	NSError *error = [NSError errorWithDomain:@"ALAssetsLibraryErrorDomain" code:-3310 userInfo:@{ NSLocalizedDescriptionKey: @"There is no photo album." }];
	dispatch_async(dispatch_get_main_queue(), ^{
		((void (*)(id, SEL, id, NSError *, void *))objc_msgSend)(target, selector, item, error, context);
	});
}

void UIImageWriteToSavedPhotosAlbum(UIImage *image, id completionTarget, SEL completionSelector, void *contextInfo)
{
	UIKitReportSaveFailure(completionTarget, completionSelector, image, contextInfo);
}

BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath)
{
	return NO;
}

void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id completionTarget, SEL completionSelector, void *contextInfo)
{
	UIKitReportSaveFailure(completionTarget, completionSelector, videoPath, contextInfo);
}

#pragma mark - UIMenuController

NSString *const UIMenuControllerWillShowMenuNotification = @"UIMenuControllerWillShowMenuNotification";
NSString *const UIMenuControllerDidShowMenuNotification = @"UIMenuControllerDidShowMenuNotification";
NSString *const UIMenuControllerWillHideMenuNotification = @"UIMenuControllerWillHideMenuNotification";
NSString *const UIMenuControllerDidHideMenuNotification = @"UIMenuControllerDidHideMenuNotification";
NSString *const UIMenuControllerMenuFrameDidChangeNotification = @"UIMenuControllerMenuFrameDidChangeNotification";

@implementation UIMenuItem

@synthesize title = _title;
@synthesize action = _action;

- (instancetype)initWithTitle:(NSString *)title action:(SEL)action
{
	if ((self = [super init])) {
		_title = [title copy];
		_action = action;
	}
	return self;
}

@end

@interface UIMenuController () <UIActionSheetDelegate>
@end

@implementation UIMenuController {
	__weak UIView *_targetView;
	CGRect _targetRect;
	UIActionSheet *_sheet;
	NSArray *_sheetActions;
	BOOL _visible;
}

@synthesize arrowDirection = _arrowDirection;
@synthesize menuItems = _menuItems;

+ (UIMenuController *)sharedMenuController
{
	static UIMenuController *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[UIMenuController alloc] init];
	});
	return shared;
}

- (BOOL)isMenuVisible { return _visible; }
- (void)setMenuVisible:(BOOL)visible { [self setMenuVisible:visible animated:NO]; }
- (CGRect)menuFrame { return _targetRect; }
- (void)update { }

- (void)setTargetRect:(CGRect)rect inView:(UIView *)view
{
	_targetRect = rect;
	_targetView = view;
}

static BOOL UIKitCanPerform(id target, SEL action, id sender)
{
	SEL query = @selector(canPerformAction:withSender:);
	if ([target respondsToSelector:query])
		return ((BOOL (*)(id, SEL, SEL, id))objc_msgSend)(target, query, action, sender);
	return [target respondsToSelector:action];
}

/* The first responder from the target view up, which performs the items. */
- (id)uikitTarget
{
	NSResponder *responder = [[_targetView window] firstResponder];
	if (![responder isKindOfClass:[UIResponder class]] && ![responder isKindOfClass:[UIView class]])
		responder = _targetView;
	return responder;
}

- (void)setMenuVisible:(BOOL)visible animated:(BOOL)animated
{
	if (visible == _visible)
		return;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	if (!visible) {
		[center postNotificationName:UIMenuControllerWillHideMenuNotification object:self];
		_visible = NO;
		[_sheet dismissWithClickedButtonIndex:[_sheet cancelButtonIndex] animated:animated];
		_sheet = nil;
		[center postNotificationName:UIMenuControllerDidHideMenuNotification object:self];
		return;
	}
	UIView *view = _targetView;
	if (view == nil)
		return;
	id target = [self uikitTarget];
	NSMutableArray *actions = [NSMutableArray array];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
	NSArray *standard = @[ @[ @"Cut", @"cut:" ], @[ @"Copy", @"copy:" ], @[ @"Paste", @"paste:" ], @[ @"Select", @"select:" ], @[ @"Select All", @"selectAll:" ], @[ @"Delete", @"delete:" ] ];
	for (NSArray *entry in standard) {
		SEL action = NSSelectorFromString([entry objectAtIndex:1]);
		if (UIKitCanPerform(target, action, self)) {
			[sheet addButtonWithTitle:[entry objectAtIndex:0]];
			[actions addObject:[entry objectAtIndex:1]];
		}
	}
	for (UIMenuItem *item in _menuItems) {
		if ([item action] == NULL)
			continue;
		if (UIKitCanPerform(target, [item action], self)) {
			[sheet addButtonWithTitle:[item title]];
			[actions addObject:NSStringFromSelector([item action])];
		}
	}
	if ([actions count] == 0)
		return;
	[sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Cancel"]];
	[center postNotificationName:UIMenuControllerWillShowMenuNotification object:self];
	_visible = YES;
	_sheet = sheet;
	_sheetActions = actions;
	[sheet showInView:view];
	[center postNotificationName:UIMenuControllerDidShowMenuNotification object:self];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index
{
	if (sheet != _sheet)
		return;
	id target = [self uikitTarget];
	NSArray *actions = _sheetActions;
	_sheet = nil;
	_visible = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:UIMenuControllerDidHideMenuNotification object:self];
	if (index < 0 || index >= (NSInteger)[actions count])
		return;
	SEL action = NSSelectorFromString([actions objectAtIndex:index]);
	if ([target respondsToSelector:action])
		((void (*)(id, SEL, id))objc_msgSend)(target, action, self);
}

@end

#pragma mark - Printing

@implementation UIPrintInfo

@synthesize printerID = _printerID;
@synthesize jobName = _jobName;
@synthesize outputType = _outputType;
@synthesize orientation = _orientation;
@synthesize duplex = _duplex;

+ (UIPrintInfo *)printInfo
{
	UIPrintInfo *info = [[self alloc] init];
	[info setJobName:[[NSProcessInfo processInfo] processName]];
	return info;
}

+ (UIPrintInfo *)printInfoWithDictionary:(NSDictionary *)dictionary
{
	UIPrintInfo *info = [self printInfo];
	if ([dictionary objectForKey:@"jobName"] != nil)
		[info setJobName:[dictionary objectForKey:@"jobName"]];
	[info setPrinterID:[dictionary objectForKey:@"printerID"]];
	[info setOutputType:[[dictionary objectForKey:@"outputType"] integerValue]];
	[info setOrientation:[[dictionary objectForKey:@"orientation"] integerValue]];
	[info setDuplex:[[dictionary objectForKey:@"duplex"] integerValue]];
	return info;
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
		@"outputType": @(_outputType), @"orientation": @(_orientation), @"duplex": @(_duplex),
	}];
	if (_jobName != nil)
		[dictionary setObject:_jobName forKey:@"jobName"];
	if (_printerID != nil)
		[dictionary setObject:_printerID forKey:@"printerID"];
	return dictionary;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [UIPrintInfo printInfoWithDictionary:[self dictionaryRepresentation]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:[self dictionaryRepresentation] forKey:@"UIPrintInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [UIPrintInfo printInfoWithDictionary:[coder decodeObjectForKey:@"UIPrintInfo"]];
}

@end

@implementation UIPrintInteractionController

@synthesize printInfo = _printInfo;
@synthesize delegate = _delegate;
@synthesize showsPageRange = _showsPageRange;
@synthesize showsNumberOfCopies = _showsNumberOfCopies;
@synthesize printPageRenderer = _printPageRenderer;
@synthesize printFormatter = _printFormatter;
@synthesize printingItem = _printingItem;
@synthesize printingItems = _printingItems;

+ (BOOL)isPrintingAvailable { return NO; }
+ (NSSet *)printableUTIs { return [NSSet set]; }
+ (BOOL)canPrintURL:(NSURL *)url { return NO; }
+ (BOOL)canPrintData:(NSData *)data { return NO; }

+ (UIPrintInteractionController *)sharedPrintController
{
	static UIPrintInteractionController *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[UIPrintInteractionController alloc] init];
	});
	return shared;
}

- (BOOL)presentAnimated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion
{
	if (completion != nil) {
		NSError *error = [NSError errorWithDomain:@"UIPrintErrorDomain" code:1 userInfo:@{ NSLocalizedDescriptionKey: @"Printing is not available." }];
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(self, NO, error);
		});
	}
	return NO;
}

- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion
{
	return [self presentAnimated:animated completionHandler:completion];
}

- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion
{
	return [self presentAnimated:animated completionHandler:completion];
}

- (void)dismissAnimated:(BOOL)animated { }

@end
