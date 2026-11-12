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

#import <IconServices/IFImage.h>

@implementation IFImage {
	CGImageRef _image;
	CGFloat _scale;
}

- (instancetype)initWithCGImage:(CGImageRef)image scale:(CGFloat)scale
{
	self = [super init];
	if (self != nil) {
		_image = CGImageRetain(image);
		_scale = scale > 0 ? scale : 1;
	}
	return self;
}

- (void)dealloc
{
	CGImageRelease(_image);
	[super dealloc];
}

- (CGImageRef)CGImage { return _image; }
- (CGFloat)scale { return _scale; }

- (CGSize)size
{
	return CGSizeMake(CGImageGetWidth(_image) / _scale, CGImageGetHeight(_image) / _scale);
}

@end
