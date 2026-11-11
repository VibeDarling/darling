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
#import <CoreGraphics/CGGeometry.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * AVMetadataObjectType NS_TYPED_ENUM NS_SWIFT_NAME(AVMetadataObject.ObjectType);

@interface AVMetadataObject : NSObject

@property (readonly) CGRect bounds;
@property (readonly) AVMetadataObjectType type;

@end

extern AVMetadataObjectType const AVMetadataObjectTypeFace;

extern AVMetadataObjectType const AVMetadataObjectTypeUPCECode;
extern AVMetadataObjectType const AVMetadataObjectTypeCode39Code;
extern AVMetadataObjectType const AVMetadataObjectTypeCode39Mod43Code;
extern AVMetadataObjectType const AVMetadataObjectTypeEAN13Code;
extern AVMetadataObjectType const AVMetadataObjectTypeEAN8Code;
extern AVMetadataObjectType const AVMetadataObjectTypeCode93Code;
extern AVMetadataObjectType const AVMetadataObjectTypeCode128Code;
extern AVMetadataObjectType const AVMetadataObjectTypePDF417Code;
extern AVMetadataObjectType const AVMetadataObjectTypeQRCode;
extern AVMetadataObjectType const AVMetadataObjectTypeAztecCode;
extern AVMetadataObjectType const AVMetadataObjectTypeInterleaved2of5Code;
extern AVMetadataObjectType const AVMetadataObjectTypeITF14Code;
extern AVMetadataObjectType const AVMetadataObjectTypeDataMatrixCode;

@interface AVMetadataMachineReadableCodeObject : AVMetadataObject

@property (readonly) NSArray<NSDictionary *> *corners;
@property (readonly, nullable) NSString *stringValue;

@end

NS_ASSUME_NONNULL_END
