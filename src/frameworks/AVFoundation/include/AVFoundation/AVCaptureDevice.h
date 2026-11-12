/*
 This file is part of Darling.

 Copyright (C) 2017 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <Foundation/Foundation.h>
#include <AVFoundation/AVMediaFormat.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVAuthorizationStatus) {
	AVAuthorizationStatusNotDetermined = 0,
	AVAuthorizationStatusRestricted = 1,
	AVAuthorizationStatusDenied = 2,
	AVAuthorizationStatusAuthorized = 3,
};

typedef NSString * AVCaptureDeviceType NS_TYPED_ENUM NS_SWIFT_NAME(AVCaptureDevice.DeviceType);

extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInWideAngleCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTelephotoCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInUltraWideCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInDualCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInDualWideCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTripleCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInTrueDepthCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInLiDARDepthCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeBuiltInMicrophone;
extern AVCaptureDeviceType const AVCaptureDeviceTypeMicrophone;
extern AVCaptureDeviceType const AVCaptureDeviceTypeExternalUnknown;
extern AVCaptureDeviceType const AVCaptureDeviceTypeExternal;
extern AVCaptureDeviceType const AVCaptureDeviceTypeContinuityCamera;
extern AVCaptureDeviceType const AVCaptureDeviceTypeDeskViewCamera;

@interface AVCaptureDevice : NSObject

+ (NSArray<AVCaptureDevice *> *)devices;
+ (NSArray<AVCaptureDevice *> *)devicesWithMediaType:(AVMediaType)mediaType;
+ (nullable AVCaptureDevice *)defaultDeviceWithMediaType:(AVMediaType)mediaType;

+ (AVAuthorizationStatus)authorizationStatusForMediaType:(AVMediaType)mediaType;
+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL granted))handler;

@end

NS_ASSUME_NONNULL_END
