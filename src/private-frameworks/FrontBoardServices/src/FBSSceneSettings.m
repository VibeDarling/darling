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

#import <FrontBoardServices/FrontBoardServices.h>

/* CGRectEqualToRect would pull in CoreGraphics for one comparison. */
static BOOL FBSRectsEqual(CGRect a, CGRect b)
{
	return a.origin.x == b.origin.x && a.origin.y == b.origin.y
		&& a.size.width == b.size.width && a.size.height == b.size.height;
}

@implementation FBSSceneSettings {
@protected
	CGRect _frame;
	NSInteger _interfaceOrientation;
	CGFloat _level;
	BOOL _foreground;
	BOOL _backgrounded;
	BOOL _occluded;
}

@synthesize frame = _frame, interfaceOrientation = _interfaceOrientation, level = _level;
@synthesize foreground = _foreground, backgrounded = _backgrounded, occluded = _occluded;

- (instancetype)init
{
	if ((self = [super init])) {
		_interfaceOrientation = 1; /* UIInterfaceOrientationPortrait */
		_level = FBSSceneLevelNormal;
	}
	return self;
}

- (void)fbs_copySettingsTo:(FBSSceneSettings *)other
{
	other->_frame = _frame;
	other->_interfaceOrientation = _interfaceOrientation;
	other->_level = _level;
	other->_foreground = _foreground;
	other->_backgrounded = _backgrounded;
	other->_occluded = _occluded;
}

- (id)copyWithZone:(NSZone *)zone
{
	FBSSceneSettings *copy = [[FBSSceneSettings alloc] init];
	[self fbs_copySettingsTo:copy];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	FBSMutableSceneSettings *copy = [[FBSMutableSceneSettings alloc] init];
	[self fbs_copySettingsTo:copy];
	return copy;
}

- (BOOL)isEqual:(id)other
{
	if (![other isKindOfClass:[FBSSceneSettings class]])
		return NO;
	FBSSceneSettings *settings = other;
	return FBSRectsEqual(_frame, settings->_frame) && _interfaceOrientation == settings->_interfaceOrientation
		&& _level == settings->_level && _foreground == settings->_foreground
		&& _backgrounded == settings->_backgrounded && _occluded == settings->_occluded;
}

- (NSUInteger)hash
{
	return (NSUInteger)_interfaceOrientation ^ ((NSUInteger)_foreground << 8) ^ ((NSUInteger)_backgrounded << 9) ^ ((NSUInteger)_occluded << 10);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ frame={{%g, %g}, {%g, %g}} orientation=%ld level=%g foreground=%d backgrounded=%d occluded=%d>",
		[self class], _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height,
		(long)_interfaceOrientation, _level, _foreground, _backgrounded, _occluded];
}

@end

@implementation FBSMutableSceneSettings

@dynamic frame, interfaceOrientation, level, foreground, backgrounded, occluded;

- (void)setFrame:(CGRect)frame { _frame = frame; }
- (void)setInterfaceOrientation:(NSInteger)orientation { _interfaceOrientation = orientation; }
- (void)setLevel:(CGFloat)level { _level = level; }
- (void)setForeground:(BOOL)foreground { _foreground = foreground; }
- (void)setBackgrounded:(BOOL)backgrounded { _backgrounded = backgrounded; }
- (void)setOccluded:(BOOL)occluded { _occluded = occluded; }

@end
