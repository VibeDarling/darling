/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import "SKInternal.h"

@implementation SKEffectNode {
	id _filter;
	BOOL _shouldCenterFilter, _shouldEnableEffects, _shouldRasterize;
	SKBlendMode _effectBlendMode;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		_shouldCenterFilter = YES;
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil) {
		_shouldCenterFilter = SKDecodeBool(coder, @"_shouldCenterFilter", YES);
		_shouldEnableEffects = SKDecodeBool(coder, @"_shouldEnableEffects", NO);
		_shouldRasterize = SKDecodeBool(coder, @"_shouldRasterize", NO);
	}
	return self;
}

- (id)filter { return _filter; }
- (void)setFilter:(id)filter { _filter = filter; }
- (BOOL)shouldCenterFilter { return _shouldCenterFilter; }
- (void)setShouldCenterFilter:(BOOL)value { _shouldCenterFilter = value; }
- (BOOL)shouldEnableEffects { return _shouldEnableEffects; }
- (void)setShouldEnableEffects:(BOOL)value { _shouldEnableEffects = value; }
- (BOOL)shouldRasterize { return _shouldRasterize; }
- (void)setShouldRasterize:(BOOL)value { _shouldRasterize = value; }
- (SKBlendMode)blendMode { return _effectBlendMode; }
- (void)setBlendMode:(SKBlendMode)mode { _effectBlendMode = mode; }

@end

@implementation SKScene {
	CGSize _size;
	SKSceneScaleMode _scaleMode;
	UIColor *_backgroundColor;
	CGPoint _anchorPoint;
	SKPhysicsWorld *_physicsWorld;
	__weak SKView *_view;
	__weak SKCameraNode *_camera;
	__weak SKNode *_listener;
	__weak id<SKSceneDelegate> _delegate;
	NSTimeInterval _lastUpdate;
}

+ (instancetype)sceneWithSize:(CGSize)size
{
	return [[self alloc] initWithSize:size];
}

static void SKSceneSetDefaults(SKScene *scene)
{
	scene->_backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
	scene->_physicsWorld = [SKPhysicsWorld new];
	scene->_userInteractionEnabled = YES;
	scene->_scaleMode = SKSceneScaleModeFill;
}

- (instancetype)initWithSize:(CGSize)size
{
	self = [super init];
	if (self == nil)
		return nil;
	SKSceneSetDefaults(self);
	_size = size;
	[self sceneDidLoad];
	return self;
}

/* Swift's SKScene() is init: SpriteKit makes it a 1x1 scene. */
- (instancetype)init
{
	return [self initWithSize:CGSizeMake(1, 1)];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self == nil)
		return nil;
	SKSceneSetDefaults(self);
	for (NSString *key in @[ @"Scene_bounds", @"_bounds", @"_visibleRect" ]) {
		id bounds = [coder decodeObjectForKey:key];
		if ([bounds isKindOfClass:[NSValue class]]) {
			_size = [bounds CGRectValue].size;
			break;
		}
	}
	id anchor = [coder decodeObjectForKey:@"_anchorPoint"];
	if ([anchor isKindOfClass:[NSValue class]])
		_anchorPoint = [anchor CGPointValue];
	_scaleMode = (NSInteger)SKDecodeNumber(coder, @"_scaleMode", 0);
	if ([coder containsValueForKey:@"_backgroundColorR"])
		_backgroundColor = [UIColor colorWithRed:SKDecodeNumber(coder, @"_backgroundColorR", 0) green:SKDecodeNumber(coder, @"_backgroundColorG", 0)
			blue:SKDecodeNumber(coder, @"_backgroundColorB", 0) alpha:SKDecodeNumber(coder, @"_backgroundColorA", 1)];
	id world = [coder decodeObjectForKey:@"_physicsWorld"];
	if ([world isKindOfClass:[SKPhysicsWorld class]])
		_physicsWorld = world;
	/* A scene's own position, scale and rotation do nothing. */
	_position = CGPointZero;
	_userInteractionEnabled = YES;
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeObject:[NSValue valueWithCGRect:CGRectMake(0, 0, _size.width, _size.height)] forKey:@"Scene_bounds"];
	[coder encodeObject:[NSValue valueWithCGPoint:_anchorPoint] forKey:@"_anchorPoint"];
	[coder encodeInteger:_scaleMode forKey:@"_scaleMode"];
	SKRGBA c = SKColorComponents(_backgroundColor);
	[coder encodeDouble:c.r forKey:@"_backgroundColorR"];
	[coder encodeDouble:c.g forKey:@"_backgroundColorG"];
	[coder encodeDouble:c.b forKey:@"_backgroundColorB"];
	[coder encodeDouble:c.a forKey:@"_backgroundColorA"];
	[coder encodeObject:_physicsWorld forKey:@"_physicsWorld"];
}

- (void)sceneDidLoad
{
}

- (CGSize)size { return _size; }

- (void)setSize:(CGSize)size
{
	CGSize old = _size;
	_size = size;
	if (!CGSizeEqualToSize(old, size))
		[self didChangeSize:old];
}

- (SKSceneScaleMode)scaleMode { return _scaleMode; }

- (void)setScaleMode:(SKSceneScaleMode)mode
{
	_scaleMode = mode;
	if (mode == SKSceneScaleModeResizeFill && _view != nil)
		[self setSize:[_view bounds].size];
}

- (UIColor *)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(UIColor *)color { _backgroundColor = color; }
- (CGPoint)anchorPoint { return _anchorPoint; }
- (void)setAnchorPoint:(CGPoint)point { _anchorPoint = point; }
- (SKPhysicsWorld *)physicsWorld { return _physicsWorld; }
- (SKView *)view { return _view; }
- (SKCameraNode *)camera { return _camera; }
- (void)setCamera:(SKCameraNode *)camera { _camera = camera; }
- (SKNode *)listener { return _listener; }
- (void)setListener:(SKNode *)listener { _listener = listener; }
- (id<SKSceneDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<SKSceneDelegate>)delegate { _delegate = delegate; }

- (CGRect)frame
{
	return CGRectMake(-_anchorPoint.x * _size.width, -_anchorPoint.y * _size.height, _size.width, _size.height);
}

- (CGRect)sk_contentRect
{
	return [self frame];
}

/* Its view, past the view: a scene passes touches on to the view's controller. */
- (UIResponder *)nextResponder
{
	return (UIResponder *)[_view nextResponder];
}

- (void)sk_setView:(SKView *)view
{
	SKView *old = _view;
	if (old == view)
		return;
	if (old != nil)
		[self willMoveFromView:old];
	_view = view;
	_lastUpdate = 0;
	if (view != nil) {
		if (_scaleMode == SKSceneScaleModeResizeFill)
			[self setSize:[view bounds].size];
		[self didMoveToView:view];
	}
}

- (void)update:(NSTimeInterval)currentTime {}
- (void)didEvaluateActions {}
- (void)didSimulatePhysics {}
- (void)didApplyConstraints {}
- (void)didFinishUpdate {}
- (void)didMoveToView:(SKView *)view {}
- (void)willMoveFromView:(SKView *)view {}
- (void)didChangeSize:(CGSize)oldSize {}

/* One frame of SpriteKit's loop: update, actions, physics, then drawing. */
- (void)sk_frame:(NSTimeInterval)now
{
	/* A long stall shouldn't throw everything forward at once. */
	NSTimeInterval dt = _lastUpdate > 0 ? MIN(MAX(now - _lastUpdate, 0), 0.1) : 0;
	_lastUpdate = now;
	id<SKSceneDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(update:forScene:)])
		[delegate update:now forScene:self];
	else
		[self update:now];
	if (!_paused) {
		[self sk_evaluateActions:dt];
	}
	if ([delegate respondsToSelector:@selector(didEvaluateActionsForScene:)])
		[delegate didEvaluateActionsForScene:self];
	else
		[self didEvaluateActions];
	/* Physics steps at most a 60th of a second at a time, whatever the
	   frame rate: bodies then don't pass through each other. */
	if (!_paused) {
		int steps = MAX(1, (int)ceil(dt * 60 - 1e-6));
		for (int i = 0; i < steps; i++)
			[_physicsWorld sk_simulate:dt / steps scene:self];
	}
	if ([delegate respondsToSelector:@selector(didSimulatePhysicsForScene:)])
		[delegate didSimulatePhysicsForScene:self];
	else
		[self didSimulatePhysics];
	if ([delegate respondsToSelector:@selector(didApplyConstraintsForScene:)])
		[delegate didApplyConstraintsForScene:self];
	else
		[self didApplyConstraints];
	if ([delegate respondsToSelector:@selector(didFinishUpdateForScene:)])
		[delegate didFinishUpdateForScene:self];
	else
		[self didFinishUpdate];
}

/* Scene coordinates (y up, the anchor point at the origin) to the view's
   points (y down), as the scale mode fits the one to the other. */
- (CGAffineTransform)sk_sceneToView
{
	CGSize view = _view != nil ? [_view bounds].size : _size;
	CGSize size = _size;
	if (size.width <= 0 || size.height <= 0)
		size = view;
	CGFloat sx = view.width / size.width, sy = view.height / size.height;
	switch (_scaleMode) {
	case SKSceneScaleModeAspectFill:
		sx = sy = MAX(sx, sy);
		break;
	case SKSceneScaleModeAspectFit:
		sx = sy = MIN(sx, sy);
		break;
	case SKSceneScaleModeResizeFill:
		sx = sy = 1;
		break;
	default:
		break;
	}
	CGFloat ox = (view.width - size.width * sx) / 2, oy = (view.height - size.height * sy) / 2;
	/* x' = ox + (x + ax * w) * sx; y' = oy + (h - (y + ay * h)) * sy */
	return CGAffineTransformMake(sx, 0, 0, -sy, ox + _anchorPoint.x * size.width * sx, oy + (1 - _anchorPoint.y) * size.height * sy);
}

- (CGPoint)convertPointFromView:(CGPoint)point
{
	return CGPointApplyAffineTransform(point, CGAffineTransformInvert([self sk_sceneToView]));
}

- (CGPoint)convertPointToView:(CGPoint)point
{
	return CGPointApplyAffineTransform(point, [self sk_sceneToView]);
}

@end

@implementation SKTransition {
	BOOL _pausesIncomingScene, _pausesOutgoingScene;
}
+ (SKTransition *)crossFadeWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)fadeWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)fadeWithColor:(UIColor *)color duration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)flipHorizontalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)flipVerticalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)doorsOpenHorizontalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)doorsOpenVerticalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)doorsCloseHorizontalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)doorsCloseVerticalWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)doorwayWithDuration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)pushWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)moveInWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec { return [self new]; }
+ (SKTransition *)revealWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec { return [self new]; }
- (BOOL)pausesIncomingScene { return _pausesIncomingScene; }
- (void)setPausesIncomingScene:(BOOL)value { _pausesIncomingScene = value; }
- (BOOL)pausesOutgoingScene { return _pausesOutgoingScene; }
- (void)setPausesOutgoingScene:(BOOL)value { _pausesOutgoingScene = value; }
@end
