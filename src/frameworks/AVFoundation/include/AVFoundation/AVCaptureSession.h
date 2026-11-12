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

#import <Foundation/Foundation.h>

@class AVCaptureInput, AVCaptureOutput;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * AVCaptureSessionPreset NS_TYPED_ENUM NS_SWIFT_NAME(AVCaptureSession.Preset);

extern NSString *const AVCaptureDeviceWasConnectedNotification;
extern NSString *const AVCaptureDeviceWasDisconnectedNotification;
extern NSNotificationName const AVCaptureSessionDidStartRunningNotification;
extern NSNotificationName const AVCaptureSessionDidStopRunningNotification;
extern NSString *const AVCaptureSessionErrorKey;
extern NSNotificationName const AVCaptureSessionRuntimeErrorNotification;

extern const AVCaptureSessionPreset AVCaptureSessionPreset3840x2160;
extern const AVCaptureSessionPreset AVCaptureSessionPreset1920x1080;
extern const AVCaptureSessionPreset AVCaptureSessionPreset1280x720;
extern const AVCaptureSessionPreset AVCaptureSessionPreset960x540;
extern const AVCaptureSessionPreset AVCaptureSessionPreset640x480;
extern const AVCaptureSessionPreset AVCaptureSessionPreset352x288;
extern const AVCaptureSessionPreset AVCaptureSessionPreset320x240;
extern const AVCaptureSessionPreset AVCaptureSessionPresetiFrame1280x720;
extern const AVCaptureSessionPreset AVCaptureSessionPresetiFrame960x540;
extern const AVCaptureSessionPreset AVCaptureSessionPresetHigh;
extern const AVCaptureSessionPreset AVCaptureSessionPresetLow;
extern const AVCaptureSessionPreset AVCaptureSessionPresetMedium;

@interface AVCaptureSession : NSObject

- (BOOL)canSetSessionPreset:(AVCaptureSessionPreset)preset;
@property (nonatomic, copy) AVCaptureSessionPreset sessionPreset;

@property (nonatomic, readonly) NSArray<__kindof AVCaptureInput *> *inputs;
- (BOOL)canAddInput:(AVCaptureInput *)input;
- (void)addInput:(AVCaptureInput *)input;
- (void)removeInput:(AVCaptureInput *)input;

@property (nonatomic, readonly) NSArray<__kindof AVCaptureOutput *> *outputs;
- (BOOL)canAddOutput:(AVCaptureOutput *)output;
- (void)addOutput:(AVCaptureOutput *)output;
- (void)removeOutput:(AVCaptureOutput *)output;

- (void)beginConfiguration;
- (void)commitConfiguration;

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly, getter=isInterrupted) BOOL interrupted;
- (void)startRunning;
- (void)stopRunning;

@end

NS_ASSUME_NONNULL_END
