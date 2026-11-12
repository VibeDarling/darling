/*
 This file is part of Darling.

 Copyright (C) 2023 Darling Team

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
#include <CoreGraphics/CoreGraphics.h>

@class ISImageDescriptor, IFImage;

/* An app bundle's icon, from the image files its Info.plist names. */
@interface ISBundleIcon : NSObject
@property (readonly) NSURL *url;
@property (readonly) NSString *type;
@property (readonly) NSString *tag;
@property (readonly) NSString *tagClass;
- (instancetype)initWithBundleURL:(NSURL *)url;
- (instancetype)initWithBundleURL:(NSURL *)url type:(NSString *)type;
- (instancetype)initWithBundleURL:(NSURL *)url fileExtension:(NSString *)extension;
- (instancetype)initWithBundleURL:(NSURL *)url type:(NSString *)type tag:(NSString *)tag tagClass:(NSString *)tagClass;
/* The image drawn for descriptor, or nil when the bundle has no icon file IconServices can read. */
- (IFImage *)imageForImageDescriptor:(ISImageDescriptor *)descriptor;
- (CGImageRef)CGImageForImageDescriptor:(ISImageDescriptor *)descriptor;
@end
