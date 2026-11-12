/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* Actions are templates: a node runs a copy, which keeps the state. Each
   kind is a private subclass; timed ones get the elapsed fraction of their
   duration, eased by the timing mode. */

#import "SKInternal.h"

@interface SKSpriteNode ()
- (void)sk_setTexture:(SKTexture *)texture resize:(BOOL)resize;
@end

@implementation SKAction {
@package
	NSTimeInterval _duration;
	SKActionTimingMode _timingMode;
	SKActionTimingFunction _timingFunction;
	CGFloat _speed;
	/* Running state. */
	BOOL _started;
	NSTimeInterval _elapsed;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		_speed = 1;
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self != nil && [coder containsValueForKey:@"_duration"])
		_duration = SKDecodeNumber(coder, @"_duration", 0);
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeDouble:_duration forKey:@"_duration"];
}

/* A fresh copy: the configuration, none of the running state. Subclasses
   add their own configuration. */
- (id)copyWithZone:(NSZone *)zone
{
	SKAction *copy = [[[self class] alloc] init];
	copy->_duration = _duration;
	copy->_timingMode = _timingMode;
	copy->_timingFunction = _timingFunction;
	copy->_speed = _speed;
	return copy;
}

- (NSTimeInterval)duration { return _duration; }
- (void)setDuration:(NSTimeInterval)duration { _duration = duration; }
- (SKActionTimingMode)timingMode { return _timingMode; }
- (void)setTimingMode:(SKActionTimingMode)mode { _timingMode = mode; }
- (SKActionTimingFunction)timingFunction { return _timingFunction; }
- (void)setTimingFunction:(SKActionTimingFunction)function { _timingFunction = [function copy]; }
- (CGFloat)speed { return _speed; }
- (void)setSpeed:(CGFloat)speed { _speed = speed; }

- (SKAction *)reversedAction
{
	return [self copy];
}

- (CGFloat)sk_ease:(CGFloat)t
{
	if (_timingFunction != nil)
		return _timingFunction((float)t);
	switch (_timingMode) {
	case SKActionTimingEaseIn:
		return t * t;
	case SKActionTimingEaseOut:
		return 1 - (1 - t) * (1 - t);
	case SKActionTimingEaseInEaseOut:
		return t * t * (3 - 2 * t);
	default:
		return t;
	}
}

- (void)sk_begin:(SKNode *)node {}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio {}

- (BOOL)sk_step:(NSTimeInterval)dt node:(SKNode *)node left:(NSTimeInterval *)left
{
	CGFloat speed = _speed;
	dt *= speed;
	if (!_started) {
		_started = YES;
		[self sk_begin:node];
	}
	if (_duration <= 0) {
		[self sk_update:node ratio:1];
		*left = speed > 0 ? dt / speed : 0;
		return YES;
	}
	_elapsed += dt;
	CGFloat t = MIN(_elapsed / _duration, 1);
	[self sk_update:node ratio:[self sk_ease:t]];
	if (_elapsed < _duration)
		return NO;
	*left = speed > 0 ? (_elapsed - _duration) / speed : 0;
	return YES;
}

@end

#pragma mark Timed actions

/* Ratio-relative actions add what the fraction gained since the last frame,
   so that several can run on a node at once. */
@interface SKRelativeAction : SKAction {
@public
	CGFloat _last;
}
@end

@implementation SKRelativeAction
- (CGFloat)sk_advance:(CGFloat)ratio
{
	CGFloat d = ratio - _last;
	_last = ratio;
	return d;
}
@end

@interface SKMoveByAction : SKRelativeAction {
@public
	CGVector _delta;
}
@end

@implementation SKMoveByAction
- (id)copyWithZone:(NSZone *)zone
{
	SKMoveByAction *copy = [super copyWithZone:zone];
	copy->_delta = _delta;
	return copy;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	CGFloat d = [self sk_advance:ratio];
	CGPoint p = node->_position;
	node.position = CGPointMake(p.x + _delta.dx * d, p.y + _delta.dy * d);
}
- (SKAction *)reversedAction
{
	SKMoveByAction *r = [self copy];
	r->_delta = CGVectorMake(-_delta.dx, -_delta.dy);
	return r;
}
@end

@interface SKMoveToAction : SKAction {
@public
	CGPoint _target, _start;
	BOOL _x, _y;
}
@end

@implementation SKMoveToAction
- (id)copyWithZone:(NSZone *)zone
{
	SKMoveToAction *copy = [super copyWithZone:zone];
	copy->_target = _target;
	copy->_x = _x;
	copy->_y = _y;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_start = node->_position;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	CGPoint p = node->_position;
	if (_x)
		p.x = _start.x + (_target.x - _start.x) * ratio;
	if (_y)
		p.y = _start.y + (_target.y - _start.y) * ratio;
	node.position = p;
}
@end

@interface SKRotateByAction : SKRelativeAction {
@public
	CGFloat _angle;
}
@end

@implementation SKRotateByAction
- (id)copyWithZone:(NSZone *)zone
{
	SKRotateByAction *copy = [super copyWithZone:zone];
	copy->_angle = _angle;
	return copy;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	node.zRotation = node->_zRotation + _angle * [self sk_advance:ratio];
}
- (SKAction *)reversedAction
{
	SKRotateByAction *r = [self copy];
	r->_angle = -_angle;
	return r;
}
@end

@interface SKRotateToAction : SKAction {
@public
	CGFloat _target, _start;
	BOOL _shortest;
}
@end

@implementation SKRotateToAction
- (id)copyWithZone:(NSZone *)zone
{
	SKRotateToAction *copy = [super copyWithZone:zone];
	copy->_target = _target;
	copy->_shortest = _shortest;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_start = node->_zRotation;
	if (_shortest) {
		CGFloat d = remainder(_target - _start, 2 * M_PI);
		_target = _start + d;
	}
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	node.zRotation = _start + (_target - _start) * ratio;
}
@end

enum { SK_SCALE_BY, SK_SCALE_TO };

@interface SKScaleAction : SKAction {
@public
	int _mode;
	CGFloat _sx, _sy;
	BOOL _x, _y;
	CGFloat _startX, _startY, _targetX, _targetY;
}
@end

@implementation SKScaleAction
- (id)copyWithZone:(NSZone *)zone
{
	SKScaleAction *copy = [super copyWithZone:zone];
	copy->_mode = _mode;
	copy->_sx = _sx;
	copy->_sy = _sy;
	copy->_x = _x;
	copy->_y = _y;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_startX = node->_xScale;
	_startY = node->_yScale;
	_targetX = _mode == SK_SCALE_BY ? _startX * _sx : _sx;
	_targetY = _mode == SK_SCALE_BY ? _startY * _sy : _sy;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (_x)
		node.xScale = _startX + (_targetX - _startX) * ratio;
	if (_y)
		node.yScale = _startY + (_targetY - _startY) * ratio;
}
- (SKAction *)reversedAction
{
	SKScaleAction *r = [self copy];
	if (_mode == SK_SCALE_BY) {
		r->_sx = _sx != 0 ? 1 / _sx : 0;
		r->_sy = _sy != 0 ? 1 / _sy : 0;
	}
	return r;
}
@end

@interface SKResizeAction : SKAction {
@public
	CGSize _size;
	BOOL _by, _width, _height;
	CGSize _start;
}
@end

@implementation SKResizeAction
- (id)copyWithZone:(NSZone *)zone
{
	SKResizeAction *copy = [super copyWithZone:zone];
	copy->_size = _size;
	copy->_by = _by;
	copy->_width = _width;
	copy->_height = _height;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	if ([node isKindOfClass:[SKSpriteNode class]])
		_start = [(SKSpriteNode *)node size];
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (![node isKindOfClass:[SKSpriteNode class]])
		return;
	CGSize target = _by ? CGSizeMake(_start.width + _size.width, _start.height + _size.height) : _size;
	CGSize size = [(SKSpriteNode *)node size];
	if (_width)
		size.width = _start.width + (target.width - _start.width) * ratio;
	if (_height)
		size.height = _start.height + (target.height - _start.height) * ratio;
	[(SKSpriteNode *)node setSize:size];
}
@end

@interface SKFadeAction : SKAction {
@public
	CGFloat _value;
	BOOL _by;
	CGFloat _start, _last;
}
@end

@implementation SKFadeAction
- (id)copyWithZone:(NSZone *)zone
{
	SKFadeAction *copy = [super copyWithZone:zone];
	copy->_value = _value;
	copy->_by = _by;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_start = node->_alpha;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (_by) {
		node.alpha = node->_alpha + _value * (ratio - _last);
		_last = ratio;
	} else
		node.alpha = _start + (_value - _start) * ratio;
}
- (SKAction *)reversedAction
{
	SKFadeAction *r = [self copy];
	if (_by)
		r->_value = -_value;
	return r;
}
@end

@interface SKColorizeAction : SKAction {
@public
	UIColor *_color;
	CGFloat _factor;
	SKRGBA _from, _to;
	CGFloat _startFactor;
}
@end

@implementation SKColorizeAction
- (id)copyWithZone:(NSZone *)zone
{
	SKColorizeAction *copy = [super copyWithZone:zone];
	copy->_color = _color;
	copy->_factor = _factor;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	if (![node respondsToSelector:@selector(colorBlendFactor)])
		return;
	_startFactor = [(id)node colorBlendFactor];
	_from = SKColorComponents([(id)node color]);
	_to = _color != nil ? SKColorComponents(_color) : _from;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (![node respondsToSelector:@selector(setColorBlendFactor:)])
		return;
	[(id)node setColorBlendFactor:_startFactor + (_factor - _startFactor) * ratio];
	if (_color != nil)
		[(id)node setColor:[UIColor colorWithRed:_from.r + (_to.r - _from.r) * ratio green:_from.g + (_to.g - _from.g) * ratio
			blue:_from.b + (_to.b - _from.b) * ratio alpha:_from.a + (_to.a - _from.a) * ratio]];
}
@end

@interface SKSpeedAction : SKAction {
@public
	CGFloat _value;
	BOOL _by;
	CGFloat _start;
}
@end

@implementation SKSpeedAction
- (id)copyWithZone:(NSZone *)zone
{
	SKSpeedAction *copy = [super copyWithZone:zone];
	copy->_value = _value;
	copy->_by = _by;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_start = node->_speed;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	CGFloat target = _by ? _start + _value : _value;
	node.speed = _start + (target - _start) * ratio;
}
@end

@interface SKWaitAction : SKAction {
@public
	NSTimeInterval _range;
}
@end

@implementation SKWaitAction
- (id)copyWithZone:(NSZone *)zone
{
	SKWaitAction *copy = [super copyWithZone:zone];
	copy->_range = _range;
	/* Each run waits its own random time. */
	if (_range > 0)
		copy->_duration = MAX(0, _duration + _range * ((double)arc4random() / UINT32_MAX - 0.5));
	return copy;
}
@end

@interface SKCustomAction : SKAction {
@public
	void (^_block)(SKNode *, CGFloat);
}
@end

@implementation SKCustomAction
- (id)copyWithZone:(NSZone *)zone
{
	SKCustomAction *copy = [super copyWithZone:zone];
	copy->_block = _block;
	return copy;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (_block != nil)
		_block(node, (CGFloat)MIN(_elapsed, _duration));
}
@end

@interface SKAnimateAction : SKAction {
@public
	NSArray<SKTexture *> *_textures;
	BOOL _resize, _restore;
	SKTexture *_original;
	CGSize _originalSize;
}
@end

@implementation SKAnimateAction
- (id)copyWithZone:(NSZone *)zone
{
	SKAnimateAction *copy = [super copyWithZone:zone];
	copy->_textures = _textures;
	copy->_resize = _resize;
	copy->_restore = _restore;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	if ([node isKindOfClass:[SKSpriteNode class]]) {
		_original = [(SKSpriteNode *)node texture];
		_originalSize = [(SKSpriteNode *)node size];
	}
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (![node isKindOfClass:[SKSpriteNode class]] || _textures.count == 0)
		return;
	SKSpriteNode *sprite = (SKSpriteNode *)node;
	if (ratio >= 1 && _restore) {
		[sprite setTexture:_original];
		if (_resize)
			[sprite setSize:_originalSize];
		return;
	}
	/* Every frame, not only when the index changes: of several animations
	   on one sprite, the last one run shows, as in SpriteKit. */
	NSInteger index = MIN((NSInteger)(ratio * _textures.count), (NSInteger)_textures.count - 1);
	[sprite sk_setTexture:_textures[index] resize:_resize];
}
@end

@interface SKFollowPathAction : SKAction {
@public
	CGPathRef _path;
	BOOL _offset, _orient;
	NSMutableArray<NSValue *> *_points;
	NSMutableArray<NSNumber *> *_lengths;
	CGPoint _start;
}
@end

@implementation SKFollowPathAction
- (void)dealloc
{
	CGPathRelease(_path);
}
- (id)copyWithZone:(NSZone *)zone
{
	SKFollowPathAction *copy = [super copyWithZone:zone];
	copy->_path = CGPathRetain(_path);
	copy->_offset = _offset;
	copy->_orient = _orient;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	_start = node->_position;
	_points = [NSMutableArray array];
	_lengths = [NSMutableArray array];
	NSMutableArray *points = _points;
	SKPathApply(_path, ^(const CGPathElement *e) {
		CGPoint last = points.count > 0 ? [[points lastObject] CGPointValue] : CGPointZero;
		switch (e->type) {
		case kCGPathElementMoveToPoint:
		case kCGPathElementAddLineToPoint:
			[points addObject:[NSValue valueWithCGPoint:e->points[0]]];
			break;
		case kCGPathElementAddQuadCurveToPoint:
			for (int i = 1; i <= 8; i++) {
				CGFloat t = i / 8.0, u = 1 - t;
				[points addObject:[NSValue valueWithCGPoint:CGPointMake(u * u * last.x + 2 * u * t * e->points[0].x + t * t * e->points[1].x,
					u * u * last.y + 2 * u * t * e->points[0].y + t * t * e->points[1].y)]];
			}
			break;
		case kCGPathElementAddCurveToPoint:
			for (int i = 1; i <= 12; i++) {
				CGFloat t = i / 12.0, u = 1 - t;
				[points addObject:[NSValue valueWithCGPoint:CGPointMake(
					u * u * u * last.x + 3 * u * u * t * e->points[0].x + 3 * u * t * t * e->points[1].x + t * t * t * e->points[2].x,
					u * u * u * last.y + 3 * u * u * t * e->points[0].y + 3 * u * t * t * e->points[1].y + t * t * t * e->points[2].y)]];
			}
			break;
		case kCGPathElementCloseSubpath:
			if (points.count > 0)
				[points addObject:points[0]];
			break;
		}
	});
	CGFloat total = 0;
	for (NSUInteger i = 0; i < _points.count; i++) {
		if (i > 0) {
			CGPoint a = [_points[i - 1] CGPointValue], b = [_points[i] CGPointValue];
			total += hypot(b.x - a.x, b.y - a.y);
		}
		[_lengths addObject:@(total)];
	}
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	if (_points.count == 0)
		return;
	CGFloat total = [[_lengths lastObject] doubleValue], at = total * ratio;
	NSUInteger i = 1;
	while (i < _points.count && [_lengths[i] doubleValue] < at)
		i++;
	CGPoint p = [_points[MIN(i, _points.count - 1)] CGPointValue];
	if (i < _points.count) {
		CGPoint a = [_points[i - 1] CGPointValue], b = [_points[i] CGPointValue];
		CGFloat l0 = [_lengths[i - 1] doubleValue], l1 = [_lengths[i] doubleValue];
		CGFloat t = l1 > l0 ? (at - l0) / (l1 - l0) : 0;
		p = CGPointMake(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
		if (_orient)
			node.zRotation = atan2(b.y - a.y, b.x - a.x) - M_PI_2;
	}
	if (_offset)
		p = CGPointMake(_start.x + p.x, _start.y + p.y);
	node.position = p;
}
@end

@interface SKPhysicsAction : SKRelativeAction {
@public
	CGVector _vector;
	BOOL _impulse;
}
@end

@implementation SKPhysicsAction
- (id)copyWithZone:(NSZone *)zone
{
	SKPhysicsAction *copy = [super copyWithZone:zone];
	copy->_vector = _vector;
	copy->_impulse = _impulse;
	return copy;
}
- (void)sk_update:(SKNode *)node ratio:(CGFloat)ratio
{
	CGFloat d = [self sk_advance:ratio];
	SKPhysicsBody *body = node->_physicsBody;
	if (_impulse)
		[body applyImpulse:CGVectorMake(_vector.dx * d, _vector.dy * d)];
	else
		[body applyForce:_vector];
}
@end

#pragma mark Instant actions

@interface SKBlockAction : SKAction {
@public
	void (^_block)(SKNode *);
}
@end

@implementation SKBlockAction
- (id)copyWithZone:(NSZone *)zone
{
	SKBlockAction *copy = [super copyWithZone:zone];
	copy->_block = _block;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	if (_block != nil)
		_block(node);
}
@end

@interface SKSoundAction : SKAction {
@public
	NSString *_file;
	BOOL _wait;
}
@end

@implementation SKSoundAction
- (id)copyWithZone:(NSZone *)zone
{
	SKSoundAction *copy = [super copyWithZone:zone];
	copy->_file = _file;
	copy->_wait = _wait;
	return copy;
}
- (void)sk_begin:(SKNode *)node
{
	NSTimeInterval length = SKPlaySound(_file);
	_duration = _wait ? length : 0;
}
@end

#pragma mark Groups

@interface SKSequenceAction : SKAction {
@public
	NSArray<SKAction *> *_actions;
	NSUInteger _index;
}
@end

@implementation SKSequenceAction
- (id)copyWithZone:(NSZone *)zone
{
	SKSequenceAction *copy = [super copyWithZone:zone];
	NSMutableArray *actions = [NSMutableArray arrayWithCapacity:_actions.count];
	for (SKAction *action in _actions)
		[actions addObject:[action copy]];
	copy->_actions = actions;
	return copy;
}
- (BOOL)sk_step:(NSTimeInterval)dt node:(SKNode *)node left:(NSTimeInterval *)left
{
	CGFloat speed = _speed;
	dt *= speed;
	while (_index < _actions.count) {
		NSTimeInterval rest = 0;
		if (![_actions[_index] sk_step:dt node:node left:&rest])
			return NO;
		dt = rest;
		_index++;
	}
	*left = speed > 0 ? dt / speed : 0;
	return YES;
}
- (SKAction *)reversedAction
{
	NSMutableArray *reversed = [NSMutableArray array];
	for (SKAction *action in [_actions reverseObjectEnumerator])
		[reversed addObject:[action reversedAction]];
	return [SKAction sequence:reversed];
}
@end

@interface SKGroupAction : SKAction {
@public
	NSArray<SKAction *> *_actions;
	NSMutableIndexSet *_done;
}
@end

@implementation SKGroupAction
- (id)copyWithZone:(NSZone *)zone
{
	SKGroupAction *copy = [super copyWithZone:zone];
	NSMutableArray *actions = [NSMutableArray arrayWithCapacity:_actions.count];
	for (SKAction *action in _actions)
		[actions addObject:[action copy]];
	copy->_actions = actions;
	return copy;
}
- (BOOL)sk_step:(NSTimeInterval)dt node:(SKNode *)node left:(NSTimeInterval *)left
{
	CGFloat speed = _speed;
	dt *= speed;
	if (_done == nil)
		_done = [NSMutableIndexSet indexSet];
	NSTimeInterval least = dt;
	for (NSUInteger i = 0; i < _actions.count; i++) {
		if ([_done containsIndex:i])
			continue;
		NSTimeInterval rest = 0;
		if ([_actions[i] sk_step:dt node:node left:&rest]) {
			[_done addIndex:i];
			least = MIN(least, rest);
		}
	}
	if (_done.count < _actions.count)
		return NO;
	*left = speed > 0 ? least / speed : 0;
	return YES;
}
- (SKAction *)reversedAction
{
	NSMutableArray *reversed = [NSMutableArray array];
	for (SKAction *action in _actions)
		[reversed addObject:[action reversedAction]];
	return [SKAction group:reversed];
}
@end

@interface SKRepeatAction : SKAction {
@public
	SKAction *_action, *_current;
	NSUInteger _count, _times;
}
@end

@implementation SKRepeatAction
- (id)copyWithZone:(NSZone *)zone
{
	SKRepeatAction *copy = [super copyWithZone:zone];
	copy->_action = _action;
	copy->_count = _count;
	return copy;
}
- (BOOL)sk_step:(NSTimeInterval)dt node:(SKNode *)node left:(NSTimeInterval *)left
{
	CGFloat speed = _speed;
	dt *= speed;
	for (;;) {
		if (_current == nil)
			_current = [_action copy];
		NSTimeInterval rest = 0;
		if (![_current sk_step:dt node:node left:&rest])
			return NO;
		_current = nil;
		_times++;
		if (_count != 0 && _times >= _count) {
			*left = speed > 0 ? rest / speed : 0;
			return YES;
		}
		/* An action that takes no time runs once a frame, not forever now. */
		if (rest >= dt)
			return NO;
		dt = rest;
	}
}
- (SKAction *)reversedAction
{
	SKRepeatAction *r = [self copy];
	r->_action = [_action reversedAction];
	return r;
}
@end

#pragma mark Making actions

@implementation SKAction (SKActions)

static id SKMake(Class class, NSTimeInterval duration)
{
	SKAction *action = [[class alloc] init];
	action->_duration = MAX(duration, 0);
	return action;
}

+ (SKAction *)moveBy:(CGVector)delta duration:(NSTimeInterval)duration
{
	SKMoveByAction *action = SKMake([SKMoveByAction class], duration);
	action->_delta = delta;
	return action;
}

+ (SKAction *)moveByX:(CGFloat)deltaX y:(CGFloat)deltaY duration:(NSTimeInterval)duration
{
	return [self moveBy:CGVectorMake(deltaX, deltaY) duration:duration];
}

static SKAction *SKMoveTo(CGPoint target, BOOL x, BOOL y, NSTimeInterval duration)
{
	SKMoveToAction *action = SKMake([SKMoveToAction class], duration);
	action->_target = target;
	action->_x = x;
	action->_y = y;
	return action;
}

+ (SKAction *)moveTo:(CGPoint)location duration:(NSTimeInterval)duration { return SKMoveTo(location, YES, YES, duration); }
+ (SKAction *)moveToX:(CGFloat)x duration:(NSTimeInterval)duration { return SKMoveTo(CGPointMake(x, 0), YES, NO, duration); }
+ (SKAction *)moveToY:(CGFloat)y duration:(NSTimeInterval)duration { return SKMoveTo(CGPointMake(0, y), NO, YES, duration); }

+ (SKAction *)rotateByAngle:(CGFloat)radians duration:(NSTimeInterval)duration
{
	SKRotateByAction *action = SKMake([SKRotateByAction class], duration);
	action->_angle = radians;
	return action;
}

+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration
{
	return [self rotateToAngle:radians duration:duration shortestUnitArc:NO];
}

+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration shortestUnitArc:(BOOL)shortestUnitArc
{
	SKRotateToAction *action = SKMake([SKRotateToAction class], duration);
	action->_target = radians;
	action->_shortest = shortestUnitArc;
	return action;
}

static SKAction *SKResize(CGSize size, BOOL by, BOOL width, BOOL height, NSTimeInterval duration)
{
	SKResizeAction *action = SKMake([SKResizeAction class], duration);
	action->_size = size;
	action->_by = by;
	action->_width = width;
	action->_height = height;
	return action;
}

+ (SKAction *)resizeByWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration { return SKResize(CGSizeMake(width, height), YES, YES, YES, duration); }
+ (SKAction *)resizeToWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration { return SKResize(CGSizeMake(width, height), NO, YES, YES, duration); }
+ (SKAction *)resizeToWidth:(CGFloat)width duration:(NSTimeInterval)duration { return SKResize(CGSizeMake(width, 0), NO, YES, NO, duration); }
+ (SKAction *)resizeToHeight:(CGFloat)height duration:(NSTimeInterval)duration { return SKResize(CGSizeMake(0, height), NO, NO, YES, duration); }

static SKAction *SKScale(int mode, CGFloat sx, CGFloat sy, BOOL x, BOOL y, NSTimeInterval duration)
{
	SKScaleAction *action = SKMake([SKScaleAction class], duration);
	action->_mode = mode;
	action->_sx = sx;
	action->_sy = sy;
	action->_x = x;
	action->_y = y;
	return action;
}

+ (SKAction *)scaleBy:(CGFloat)scale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_BY, scale, scale, YES, YES, duration); }
+ (SKAction *)scaleXBy:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_BY, xScale, yScale, YES, YES, duration); }
+ (SKAction *)scaleTo:(CGFloat)scale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_TO, scale, scale, YES, YES, duration); }
+ (SKAction *)scaleXTo:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_TO, xScale, yScale, YES, YES, duration); }
+ (SKAction *)scaleXTo:(CGFloat)scale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_TO, scale, 1, YES, NO, duration); }
+ (SKAction *)scaleYTo:(CGFloat)scale duration:(NSTimeInterval)duration { return SKScale(SK_SCALE_TO, 1, scale, NO, YES, duration); }

+ (SKAction *)sequence:(NSArray<SKAction *> *)actions
{
	SKSequenceAction *action = SKMake([SKSequenceAction class], 0);
	action->_actions = [actions copy] ?: @[];
	NSTimeInterval total = 0;
	for (SKAction *a in action->_actions)
		total += a.duration;
	action->_duration = total;
	return action;
}

+ (SKAction *)group:(NSArray<SKAction *> *)actions
{
	SKGroupAction *action = SKMake([SKGroupAction class], 0);
	action->_actions = [actions copy] ?: @[];
	NSTimeInterval longest = 0;
	for (SKAction *a in action->_actions)
		longest = MAX(longest, a.duration);
	action->_duration = longest;
	return action;
}

+ (SKAction *)repeatAction:(SKAction *)repeated count:(NSUInteger)count
{
	SKRepeatAction *action = SKMake([SKRepeatAction class], repeated.duration * count);
	action->_action = repeated;
	action->_count = MAX(count, (NSUInteger)1);
	return action;
}

+ (SKAction *)repeatActionForever:(SKAction *)repeated
{
	SKRepeatAction *action = SKMake([SKRepeatAction class], INFINITY);
	action->_action = repeated;
	action->_count = 0;
	return action;
}

static SKAction *SKFade(CGFloat value, BOOL by, NSTimeInterval duration)
{
	SKFadeAction *action = SKMake([SKFadeAction class], duration);
	action->_value = value;
	action->_by = by;
	return action;
}

+ (SKAction *)fadeInWithDuration:(NSTimeInterval)duration { return SKFade(1, NO, duration); }
+ (SKAction *)fadeOutWithDuration:(NSTimeInterval)duration { return SKFade(0, NO, duration); }
+ (SKAction *)fadeAlphaBy:(CGFloat)factor duration:(NSTimeInterval)duration { return SKFade(factor, YES, duration); }
+ (SKAction *)fadeAlphaTo:(CGFloat)alpha duration:(NSTimeInterval)duration { return SKFade(alpha, NO, duration); }

static SKAction *SKBlock(void (^block)(SKNode *))
{
	SKBlockAction *action = SKMake([SKBlockAction class], 0);
	action->_block = [block copy];
	return action;
}

+ (SKAction *)hide { return SKBlock(^(SKNode *node) { node.hidden = YES; }); }
+ (SKAction *)unhide { return SKBlock(^(SKNode *node) { node.hidden = NO; }); }

+ (SKAction *)setTexture:(SKTexture *)texture
{
	return [self setTexture:texture resize:NO];
}

+ (SKAction *)setTexture:(SKTexture *)texture resize:(BOOL)resize
{
	return SKBlock(^(SKNode *node) {
		if ([node isKindOfClass:[SKSpriteNode class]])
			[(SKSpriteNode *)node sk_setTexture:texture resize:resize];
	});
}

+ (SKAction *)setNormalTexture:(SKTexture *)texture
{
	return SKBlock(^(SKNode *node) {
		if ([node isKindOfClass:[SKSpriteNode class]])
			[(SKSpriteNode *)node setNormalTexture:texture];
	});
}

+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec
{
	return [self animateWithTextures:textures timePerFrame:sec resize:NO restore:NO];
}

+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec resize:(BOOL)resize restore:(BOOL)restore
{
	SKAnimateAction *action = SKMake([SKAnimateAction class], sec * textures.count);
	action->_textures = [textures copy];
	action->_resize = resize;
	action->_restore = restore;
	return action;
}

+ (SKAction *)playSoundFileNamed:(NSString *)soundFile waitForCompletion:(BOOL)wait
{
	SKSoundAction *action = SKMake([SKSoundAction class], 0);
	action->_file = [soundFile copy];
	action->_wait = wait;
	return action;
}

+ (SKAction *)colorizeWithColor:(UIColor *)color colorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)duration
{
	SKColorizeAction *action = SKMake([SKColorizeAction class], duration);
	action->_color = color;
	action->_factor = colorBlendFactor;
	return action;
}

+ (SKAction *)colorizeWithColorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)sec
{
	return [self colorizeWithColor:nil colorBlendFactor:colorBlendFactor duration:sec];
}

+ (SKAction *)followPath:(CGPathRef)path duration:(NSTimeInterval)duration
{
	return [self followPath:path asOffset:YES orientToPath:YES duration:duration];
}

+ (SKAction *)followPath:(CGPathRef)path asOffset:(BOOL)offset orientToPath:(BOOL)orient duration:(NSTimeInterval)duration
{
	SKFollowPathAction *action = SKMake([SKFollowPathAction class], duration);
	action->_path = CGPathCreateCopy(path);
	action->_offset = offset;
	action->_orient = orient;
	return action;
}

+ (SKAction *)followPath:(CGPathRef)path speed:(CGFloat)speed
{
	return [self followPath:path asOffset:YES orientToPath:YES speed:speed];
}

+ (SKAction *)followPath:(CGPathRef)path asOffset:(BOOL)offset orientToPath:(BOOL)orient speed:(CGFloat)speed
{
	SKFollowPathAction *action = SKMake([SKFollowPathAction class], 0);
	action->_path = CGPathCreateCopy(path);
	action->_offset = offset;
	action->_orient = orient;
	SKFollowPathAction *probe = [action copy];
	[probe sk_begin:[SKNode node]];
	CGFloat length = [[probe->_lengths lastObject] doubleValue];
	action->_duration = speed > 0 ? length / speed : 0;
	return action;
}

static SKAction *SKSpeed(CGFloat value, BOOL by, NSTimeInterval duration)
{
	SKSpeedAction *action = SKMake([SKSpeedAction class], duration);
	action->_value = value;
	action->_by = by;
	return action;
}

+ (SKAction *)speedBy:(CGFloat)speed duration:(NSTimeInterval)duration { return SKSpeed(speed, YES, duration); }
+ (SKAction *)speedTo:(CGFloat)speed duration:(NSTimeInterval)duration { return SKSpeed(speed, NO, duration); }

+ (SKAction *)waitForDuration:(NSTimeInterval)duration
{
	return SKMake([SKWaitAction class], duration);
}

+ (SKAction *)waitForDuration:(NSTimeInterval)duration withRange:(NSTimeInterval)durationRange
{
	SKWaitAction *action = SKMake([SKWaitAction class], duration);
	action->_range = durationRange;
	return action;
}

+ (SKAction *)removeFromParent
{
	return SKBlock(^(SKNode *node) {
		[node removeFromParent];
	});
}

+ (SKAction *)performSelector:(SEL)selector onTarget:(id)target
{
	__weak id weakTarget = target;
	return SKBlock(^(SKNode *node) {
		id strong = weakTarget;
		if (strong != nil)
			((void (*)(id, SEL))[strong methodForSelector:selector])(strong, selector);
	});
}

+ (SKAction *)runBlock:(dispatch_block_t)block
{
	dispatch_block_t copied = [block copy];
	return SKBlock(^(SKNode *node) {
		if (copied != nil)
			copied();
	});
}

+ (SKAction *)runBlock:(dispatch_block_t)block queue:(dispatch_queue_t)queue
{
	dispatch_block_t copied = [block copy];
	return SKBlock(^(SKNode *node) {
		if (copied != nil)
			dispatch_async(queue ?: dispatch_get_main_queue(), copied);
	});
}

+ (SKAction *)runAction:(SKAction *)action onChildWithName:(NSString *)name
{
	return SKBlock(^(SKNode *node) {
		[[node childNodeWithName:name] runAction:action];
	});
}

+ (SKAction *)customActionWithDuration:(NSTimeInterval)duration actionBlock:(void (^)(SKNode *node, CGFloat elapsedTime))block
{
	SKCustomAction *action = SKMake([SKCustomAction class], duration);
	action->_block = [block copy];
	return action;
}

/* Actions.sks is a keyed archive of SpriteKit's private action classes;
   those aren't read here. */
+ (SKAction *)actionNamed:(NSString *)name
{
	NSLog(@"SpriteKit: actionNamed:%@ is not supported", name);
	return nil;
}

+ (SKAction *)actionNamed:(NSString *)name duration:(NSTimeInterval)duration
{
	return [self actionNamed:name];
}

+ (SKAction *)applyImpulse:(CGVector)impulse duration:(NSTimeInterval)duration
{
	SKPhysicsAction *action = SKMake([SKPhysicsAction class], duration);
	action->_vector = impulse;
	action->_impulse = YES;
	return action;
}

+ (SKAction *)applyForce:(CGVector)force duration:(NSTimeInterval)duration
{
	SKPhysicsAction *action = SKMake([SKPhysicsAction class], duration);
	action->_vector = force;
	return action;
}

@end
