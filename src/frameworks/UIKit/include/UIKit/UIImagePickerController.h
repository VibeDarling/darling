/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIIMAGEPICKERCONTROLLER_H
#define UIKIT_UIIMAGEPICKERCONTROLLER_H

#import <Foundation/Foundation.h>
#import <UIKit/UINavigationController.h>

@class UIImagePickerController, UIImage;

typedef NS_ENUM(NSInteger, UIImagePickerControllerSourceType) {
	UIImagePickerControllerSourceTypePhotoLibrary,
	UIImagePickerControllerSourceTypeCamera,
	UIImagePickerControllerSourceTypeSavedPhotosAlbum,
};

typedef NS_ENUM(NSInteger, UIImagePickerControllerQualityType) {
	UIImagePickerControllerQualityTypeHigh = 0,
	UIImagePickerControllerQualityTypeMedium = 1,
	UIImagePickerControllerQualityTypeLow = 2,
	UIImagePickerControllerQualityType640x480 = 3,
};

typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraDevice) {
	UIImagePickerControllerCameraDeviceRear,
	UIImagePickerControllerCameraDeviceFront,
};

typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraCaptureMode) {
	UIImagePickerControllerCameraCaptureModePhoto,
	UIImagePickerControllerCameraCaptureModeVideo,
};

typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraFlashMode) {
	UIImagePickerControllerCameraFlashModeOff = -1,
	UIImagePickerControllerCameraFlashModeAuto = 0,
	UIImagePickerControllerCameraFlashModeOn = 1,
};

@protocol UIImagePickerControllerDelegate <NSObject>
@optional
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
@end

/* There is no camera and no photo library: no source is available, and a
 * picker presented anyway only offers Cancel. */
@interface UIImagePickerController : UINavigationController
+ (BOOL)isSourceTypeAvailable:(UIImagePickerControllerSourceType)sourceType;
+ (NSArray<NSString *> *)availableMediaTypesForSourceType:(UIImagePickerControllerSourceType)sourceType;
+ (BOOL)isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)cameraDevice;
+ (BOOL)isFlashAvailableForCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice;
@property (nonatomic, weak) id<UINavigationControllerDelegate, UIImagePickerControllerDelegate> delegate;
@property (nonatomic) UIImagePickerControllerSourceType sourceType;
@property (nonatomic, copy) NSArray<NSString *> *mediaTypes;
@property (nonatomic) BOOL allowsEditing;
@property (nonatomic) BOOL allowsImageEditing;
@property (nonatomic) NSTimeInterval videoMaximumDuration;
@property (nonatomic) UIImagePickerControllerQualityType videoQuality;
@property (nonatomic) BOOL showsCameraControls;
@property (nonatomic, strong) UIView *cameraOverlayView;
@property (nonatomic) CGAffineTransform cameraViewTransform;
@property (nonatomic) UIImagePickerControllerCameraDevice cameraDevice;
@property (nonatomic) UIImagePickerControllerCameraCaptureMode cameraCaptureMode;
@property (nonatomic) UIImagePickerControllerCameraFlashMode cameraFlashMode;
- (void)takePicture;
- (BOOL)startVideoCapture;
- (void)stopVideoCapture;
@end

void UIImageWriteToSavedPhotosAlbum(UIImage *image, id completionTarget, SEL completionSelector, void *contextInfo);
BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath);
void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id completionTarget, SEL completionSelector, void *contextInfo);

#endif /* UIKIT_UIIMAGEPICKERCONTROLLER_H */
