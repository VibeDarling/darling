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

#import <IconServices/ISGenerationRequest.h>
#import <IconServices/ISImageDescriptor.h>
#import <IconServices/IFImage.h>

@implementation ISGenerationRequest

@synthesize icon = _icon;
@synthesize imageDescriptor = _imageDescriptor;
@synthesize lsDatabaseSequenceNumber = _lsDatabaseSequenceNumber;
@synthesize lsDatabaseUUID = _lsDatabaseUUID;

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self != nil) {
		_icon = [[coder decodeObjectForKey:@"icon"] retain];
		_imageDescriptor = [[coder decodeObjectForKey:@"imageDescriptor"] retain];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_icon forKey:@"icon"];
	[coder encodeObject:_imageDescriptor forKey:@"imageDescriptor"];
}

- (void)dealloc
{
	[_icon release];
	[_imageDescriptor release];
	[_lsDatabaseUUID release];
	[super dealloc];
}

/* Drawn here, in the app: there is no icon service to ask. */
- (IFImage *)generateImageReturningRecordIdentifiers:(id *)identifiers
{
	if (identifiers != NULL)
		*identifiers = nil;
	ISImageDescriptor *descriptor = _imageDescriptor ?: [ISImageDescriptor imageDescriptorNamed:@"com.apple.IconServices.ImageDescriptor.HomeScreen"];
	if (![_icon respondsToSelector:@selector(imageForImageDescriptor:)])
		return nil;
	return [_icon imageForImageDescriptor:descriptor];
}

- (IFImage *)generateImage
{
	return [self generateImageReturningRecordIdentifiers:NULL];
}

@end
