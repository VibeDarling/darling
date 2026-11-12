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

#import <IconServices/ISImageDescriptor.h>

@implementation ISImageDescriptor

@synthesize size = _size;
@synthesize scale = _scale;
@synthesize shape = _shape;
@synthesize appearance = _appearance;
@synthesize appearanceVariant = _appearanceVariant;
@synthesize specialIconOptions = _specialIconOptions;
@synthesize variantOptions = _variantOptions;
@synthesize drawBorder = _drawBorder;
@synthesize ignoreCache = _ignoreCache;
@synthesize tintColor = _tintColor;

/* The named descriptors iOS apps ask for, by their size in points. */
+ (instancetype)imageDescriptorNamed:(NSString *)name
{
	static NSDictionary *sizes;
	if (sizes == nil)
		sizes = [@{
			@"com.apple.IconServices.ImageDescriptor.HomeScreen": @60,
			@"com.apple.IconServices.ImageDescriptor.HomeScreenLarge": @76,
			@"com.apple.IconServices.ImageDescriptor.Spotlight": @40,
			@"com.apple.IconServices.ImageDescriptor.TableUIIcon": @29,
			@"com.apple.IconServices.ImageDescriptor.Notification": @20,
			@"com.apple.IconServices.ImageDescriptor.MessagesUIIcon": @60,
		} retain];
	CGFloat points = [[sizes objectForKey:name] doubleValue];
	if (points <= 0)
		points = 60;
	return [[[self alloc] initWithSize:CGSizeMake(points, points) scale:1] autorelease];
}

- (instancetype)initWithSize:(CGSize)size scale:(CGFloat)scale
{
	self = [super init];
	if (self != nil) {
		_size = size;
		_scale = scale;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithSize:CGSizeMake(60, 60) scale:1];
}

- (void)dealloc
{
	[_tintColor release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	ISImageDescriptor *copy = [[[self class] alloc] initWithSize:_size scale:_scale];
	copy.shape = _shape;
	copy.appearance = _appearance;
	copy.appearanceVariant = _appearanceVariant;
	copy.specialIconOptions = _specialIconOptions;
	copy.variantOptions = _variantOptions;
	copy.drawBorder = _drawBorder;
	copy.ignoreCache = _ignoreCache;
	copy.tintColor = _tintColor;
	return copy;
}

@end
