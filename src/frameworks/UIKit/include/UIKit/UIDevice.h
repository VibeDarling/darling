/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIDEVICE_H
#define UIKIT_UIDEVICE_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UIUserInterfaceIdiom) {
	UIUserInterfaceIdiomUnspecified = -1,
	UIUserInterfaceIdiomPhone,
	UIUserInterfaceIdiomPad,
};

typedef NS_ENUM(NSInteger, UIDeviceOrientation) {
	UIDeviceOrientationUnknown,
	UIDeviceOrientationPortrait,
	UIDeviceOrientationPortraitUpsideDown,
	UIDeviceOrientationLandscapeLeft,
	UIDeviceOrientationLandscapeRight,
	UIDeviceOrientationFaceUp,
	UIDeviceOrientationFaceDown,
};

typedef NS_ENUM(NSInteger, UIDeviceBatteryState) {
	UIDeviceBatteryStateUnknown,
	UIDeviceBatteryStateUnplugged,
	UIDeviceBatteryStateCharging,
	UIDeviceBatteryStateFull,
};

extern NSString *const UIDeviceOrientationDidChangeNotification;

/* Darling presents itself as an iPhone running the iOS release its UIKit
 * and WebKit correspond to. */
@interface UIDevice : NSObject
+ (UIDevice *)currentDevice;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) NSString *localizedModel;
@property (nonatomic, readonly) NSString *systemName;
@property (nonatomic, readonly) NSString *systemVersion;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIDeviceOrientation orientation;
@property (nonatomic, readonly, getter=isMultitaskingSupported) BOOL multitaskingSupported;
@property (nonatomic, readonly) float batteryLevel;
@property (nonatomic, readonly) UIDeviceBatteryState batteryState;
@property (nonatomic, getter=isBatteryMonitoringEnabled) BOOL batteryMonitoringEnabled;
@property (nonatomic, getter=isProximityMonitoringEnabled) BOOL proximityMonitoringEnabled;
@property (nonatomic, readonly) NSUUID *identifierForVendor;
@property (nonatomic, readonly, getter=isGeneratingDeviceOrientationNotifications) BOOL generatesDeviceOrientationNotifications;
- (void)beginGeneratingDeviceOrientationNotifications;
- (void)endGeneratingDeviceOrientationNotifications;
- (void)playInputClick;
/* Removed from iOS in 7; old apps still call it. */
- (NSString *)uniqueIdentifier;
@end

#define UI_USER_INTERFACE_IDIOM() ([[UIDevice currentDevice] userInterfaceIdiom])

#endif /* UIKIT_UIDEVICE_H */
