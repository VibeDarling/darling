/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVMetadataObject.h>
#import <CoreGraphics/CGGeometry.h>
#import <dispatch/dispatch.h>

@class AVCaptureConnection;
@protocol AVCaptureMetadataOutputObjectsDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptureMetadataOutput : AVCaptureOutput

- (instancetype)init;
+ (instancetype)new;

- (void)setMetadataObjectsDelegate:(nullable id<AVCaptureMetadataOutputObjectsDelegate>)objectsDelegate
                             queue:(nullable dispatch_queue_t)objectsCallbackQueue;
@property (nonatomic, readonly, nullable) id<AVCaptureMetadataOutputObjectsDelegate> metadataObjectsDelegate;
@property (nonatomic, readonly, nullable) dispatch_queue_t metadataObjectsCallbackQueue;

@property (nonatomic, readonly) NSArray<AVMetadataObjectType> *availableMetadataObjectTypes;
@property (nonatomic, copy, null_resettable) NSArray<AVMetadataObjectType> *metadataObjectTypes;
@property (nonatomic) CGRect rectOfInterest;

@end

@protocol AVCaptureMetadataOutputObjectsDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureMetadataOutput *)output
        didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects
        fromConnection:(AVCaptureConnection *)connection;
@end

NS_ASSUME_NONNULL_END
