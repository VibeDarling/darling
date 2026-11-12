/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import "SKInternal.h"

SKRGBA SKColorComponents(UIColor *color)
{
	SKRGBA c = { 0, 0, 0, 0 };
	if (color == nil)
		return c;
	if (![color getRed:&c.r green:&c.g blue:&c.b alpha:&c.a]) {
		CGFloat white = 0;
		if ([color getWhite:&white alpha:&c.a])
			c.r = c.g = c.b = white;
	}
	return c;
}

static void SKPathApplier(void *info, const CGPathElement *element)
{
	((__bridge void (^)(const CGPathElement *))info)(element);
}

void SKPathApply(CGPathRef path, void (^block)(const CGPathElement *element))
{
	if (path != NULL && block != nil)
		CGPathApply(path, (__bridge void *)block, SKPathApplier);
}

@interface SKRunningAction : NSObject {
@public
	SKAction *_action;
	NSString *_key;
	void (^_completion)(void);
}
@end

@implementation SKRunningAction
@end

/* Whether NAME matches PATTERN, in which * stands for any run of characters. */
static BOOL SKNameMatches(NSString *name, NSString *pattern)
{
	if (name == nil)
		return NO;
	if ([pattern rangeOfString:@"*"].location == NSNotFound)
		return [name isEqualToString:pattern];
	NSArray<NSString *> *parts = [pattern componentsSeparatedByString:@"*"];
	NSUInteger at = 0;
	for (NSUInteger i = 0; i < parts.count; i++) {
		NSString *part = parts[i];
		if (part.length == 0)
			continue;
		if (i == 0) {
			if (![name hasPrefix:part])
				return NO;
			at = part.length;
			continue;
		}
		if (i == parts.count - 1)
			return name.length >= at + part.length && [[name substringFromIndex:name.length - part.length] isEqualToString:part];
		NSRange found = [name rangeOfString:part options:0 range:NSMakeRange(at, name.length - at)];
		if (found.location == NSNotFound)
			return NO;
		at = NSMaxRange(found);
	}
	return YES;
}

@implementation SKNode

+ (BOOL)supportsSecureCoding
{
	return YES;
}

+ (instancetype)node
{
	return [[self alloc] init];
}

static void SKNodeSetDefaults(SKNode *node)
{
	node->_xScale = node->_yScale = 1;
	node->_speed = 1;
	node->_alpha = 1;
	node->_children = [NSMutableArray new];
	node->_runningActions = [NSMutableArray new];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		SKNodeSetDefaults(self);
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	if (self == nil)
		return nil;
	SKNodeSetDefaults(self);
	[self sk_decodeSceneKit:coder];
	return self;
}

double SKDecodeNumber(NSCoder *coder, NSString *key, double fallback)
{
	if (![coder containsValueForKey:key])
		return fallback;
	@try {
		id value = [coder decodeObjectForKey:key];
		if ([value isKindOfClass:[NSNumber class]])
			return [value doubleValue];
	} @catch (NSException *exception) {
	}
	@try {
		return [coder decodeDoubleForKey:key];
	} @catch (NSException *exception) {
		return fallback;
	}
}

BOOL SKDecodeBool(NSCoder *coder, NSString *key, BOOL fallback)
{
	return SKDecodeNumber(coder, key, fallback) != 0;
}

/* Xcode's scene files (.sks) are keyed archives of the nodes' own ivars. */
- (void)sk_decodeSceneKit:(NSCoder *)coder
{
	_name = [[coder decodeObjectForKey:@"_name"] copy];
	id position = [coder decodeObjectForKey:@"_position"];
	if ([position isKindOfClass:[NSValue class]])
		_position = [position CGPointValue];
	_zPosition = SKDecodeNumber(coder, @"_zPosition", 0);
	_zRotation = SKDecodeNumber(coder, @"_zRotation", 0);
	_xScale = SKDecodeNumber(coder, @"_xScale", 1);
	_yScale = SKDecodeNumber(coder, @"_yScale", 1);
	_speed = SKDecodeNumber(coder, @"_speed", 1);
	_alpha = SKDecodeNumber(coder, @"_opacity", 1);
	_paused = SKDecodeBool(coder, @"_paused", NO);
	_hidden = SKDecodeBool(coder, @"_hidden", NO);
	_userInteractionEnabled = SKDecodeBool(coder, @"_userInteractionEnabled", NO);
	id userData = [coder decodeObjectForKey:@"_userData"];
	if ([userData isKindOfClass:[NSDictionary class]])
		_userData = [userData mutableCopy];
	id body = [coder decodeObjectForKey:@"_physicsBody"];
	if ([body isKindOfClass:[SKPhysicsBody class]])
		[self setPhysicsBody:body];
	NSArray *children = [coder decodeObjectForKey:@"_children"];
	if ([children isKindOfClass:[NSArray class]])
		for (id child in children)
			if ([child isKindOfClass:[SKNode class]])
				[self addChild:child];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if (_name != nil)
		[coder encodeObject:_name forKey:@"_name"];
	[coder encodeObject:[NSValue valueWithCGPoint:_position] forKey:@"_position"];
	[coder encodeDouble:_zPosition forKey:@"_zPosition"];
	[coder encodeDouble:_zRotation forKey:@"_zRotation"];
	[coder encodeDouble:_xScale forKey:@"_xScale"];
	[coder encodeDouble:_yScale forKey:@"_yScale"];
	[coder encodeDouble:_speed forKey:@"_speed"];
	[coder encodeDouble:_alpha forKey:@"_opacity"];
	[coder encodeBool:_paused forKey:@"_paused"];
	[coder encodeBool:_hidden forKey:@"_hidden"];
	[coder encodeBool:_userInteractionEnabled forKey:@"_userInteractionEnabled"];
	if (_userData != nil)
		[coder encodeObject:_userData forKey:@"_userData"];
	if (_physicsBody != nil)
		[coder encodeObject:_physicsBody forKey:@"_physicsBody"];
	[coder encodeObject:[_children copy] forKey:@"_children"];
}

/* As SpriteKit does: a copy is the node archived and read back. */
- (id)copyWithZone:(NSZone *)zone
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
	return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

+ (instancetype)nodeWithFileNamed:(NSString *)filename
{
	NSString *path = filename;
	if (![filename isAbsolutePath]) {
		NSString *base = [filename stringByDeletingPathExtension];
		NSString *extension = [filename pathExtension].length > 0 ? [filename pathExtension] : @"sks";
		path = [[NSBundle mainBundle] pathForResource:base ofType:extension];
	}
	NSData *data = path != nil ? [NSData dataWithContentsOfFile:path] : nil;
	if (data == nil)
		return nil;
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
	/* The archive's root is of the class the file was made with: an app's
	   subclass reads it instead. */
	for (Class class = self; class != Nil && class != [SKNode superclass]; class = [class superclass])
		[unarchiver setClass:self forClassName:NSStringFromClass(class)];
	[unarchiver setClass:[SKPhysicsWorld class] forClassName:@"PKPhysicsWorld"];
	[unarchiver setClass:[SKPhysicsBody class] forClassName:@"PKPhysicsBody"];
	id root = nil;
	@try {
		root = [unarchiver decodeObjectForKey:@"root"];
	} @catch (NSException *exception) {
		NSLog(@"SpriteKit: cannot read %@: %@", path, exception);
		root = nil;
	}
	[unarchiver finishDecoding];
	if (![root isKindOfClass:self])
		return nil;
	if ([root isKindOfClass:[SKScene class]])
		[(SKScene *)root sceneDidLoad];
	return root;
}

+ (instancetype)nodeWithFileNamed:(NSString *)filename securelyWithClasses:(NSSet<Class> *)classes andError:(NSError **)error
{
	SKNode *node = [self nodeWithFileNamed:filename];
	if (node == nil && error != NULL)
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:nil];
	return node;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@> name:'%@' position:{%g, %g} scale:{%.2f, %.2f} alpha:%.2f", [self class], _name, _position.x, _position.y, _xScale, _yScale, _alpha];
}

#pragma mark Properties

- (CGPoint)position { return _position; }
- (void)setPosition:(CGPoint)position { _position = position; }
- (CGFloat)zPosition { return _zPosition; }
- (void)setZPosition:(CGFloat)z { _zPosition = z; }
- (CGFloat)zRotation { return _zRotation; }
- (void)setZRotation:(CGFloat)rotation { _zRotation = rotation; }
- (CGFloat)xScale { return _xScale; }
- (void)setXScale:(CGFloat)scale { _xScale = scale; }
- (CGFloat)yScale { return _yScale; }
- (void)setYScale:(CGFloat)scale { _yScale = scale; }
- (void)setScale:(CGFloat)scale { _xScale = _yScale = scale; }
- (CGFloat)speed { return _speed; }
- (void)setSpeed:(CGFloat)speed { _speed = speed; }
- (CGFloat)alpha { return _alpha; }
- (void)setAlpha:(CGFloat)alpha { _alpha = alpha; }
- (BOOL)isPaused { return _paused; }
- (void)setPaused:(BOOL)paused { _paused = paused; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)hidden { _hidden = hidden; }
- (BOOL)isUserInteractionEnabled { return _userInteractionEnabled; }
- (void)setUserInteractionEnabled:(BOOL)enabled { _userInteractionEnabled = enabled; }
- (SKNodeFocusBehavior)focusBehavior { return _focusBehavior; }
- (void)setFocusBehavior:(SKNodeFocusBehavior)behavior { _focusBehavior = behavior; }
- (SKNode *)parent { return _parent; }
- (NSArray<SKNode *> *)children { return [_children copy]; }
- (NSString *)name { return _name; }
- (void)setName:(NSString *)name { _name = [name copy]; }
- (NSMutableDictionary *)userData { return _userData; }
- (void)setUserData:(NSMutableDictionary *)userData { _userData = userData; }
- (NSArray *)constraints { return _constraints; }
- (void)setConstraints:(NSArray *)constraints { _constraints = [constraints copy]; }
- (SKPhysicsBody *)physicsBody { return _physicsBody; }

- (void)setPhysicsBody:(SKPhysicsBody *)body
{
	if (_physicsBody == body)
		return;
	[_physicsBody sk_setNode:nil];
	_physicsBody = body;
	[body sk_setNode:self];
}

- (SKScene *)scene
{
	SKNode *node = self;
	while (node->_parent != nil)
		node = node->_parent;
	return [node isKindOfClass:[SKScene class]] ? (SKScene *)node : nil;
}

/* The parent, then the scene's view: touches a node doesn't take go there. */
- (UIResponder *)nextResponder
{
	return _parent;
}

/* This UIKit's UIResponder has no touch methods: a node passes touches on
   up the responder chain, as UIResponder's do on iOS. */
static void SKPassTouches(SKNode *node, SEL selector, NSSet *touches, UIEvent *event)
{
	id next = [node nextResponder];
	if (next != nil && [next respondsToSelector:selector])
		((void (*)(id, SEL, NSSet *, UIEvent *))[next methodForSelector:selector])(next, selector, touches, event);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	SKPassTouches(self, _cmd, touches, event);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	SKPassTouches(self, _cmd, touches, event);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	SKPassTouches(self, _cmd, touches, event);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	SKPassTouches(self, _cmd, touches, event);
}

#pragma mark The tree

- (void)addChild:(SKNode *)node
{
	[self insertChild:node atIndex:_children.count];
}

- (void)insertChild:(SKNode *)node atIndex:(NSInteger)index
{
	if (node == nil)
		[NSException raise:NSInvalidArgumentException format:@"Attempted to add nil node to parent: %@", self];
	if (node->_parent != nil)
		[NSException raise:NSInvalidArgumentException format:@"Attempted to add a SKNode which already has a parent: %@", node];
	if (index < 0 || (NSUInteger)index > _children.count)
		index = _children.count;
	[_children insertObject:node atIndex:index];
	node->_parent = self;
	if ([self scene] != nil)
		[node sk_didMoveToScene];
}

- (void)sk_didMoveToScene
{
	for (SKNode *child in [_children copy])
		[child sk_didMoveToScene];
}

- (void)removeFromParent
{
	SKNode *parent = _parent;
	if (parent == nil)
		return;
	/* The parent's array may hold the last reference. */
	SKNode *keep = self;
	[parent->_children removeObjectIdenticalTo:keep];
	_parent = nil;
	(void)keep;
}

- (void)removeChildrenInArray:(NSArray<SKNode *> *)nodes
{
	for (SKNode *node in [nodes copy])
		if (node->_parent == self)
			[node removeFromParent];
}

- (void)removeAllChildren
{
	NSArray *children = [_children copy];
	[_children removeAllObjects];
	for (SKNode *child in children)
		child->_parent = nil;
}

- (void)moveToParent:(SKNode *)parent
{
	SKNode *keep = self;
	[self removeFromParent];
	[parent addChild:keep];
}

- (BOOL)inParentHierarchy:(SKNode *)parent
{
	for (SKNode *node = self; node != nil; node = node->_parent)
		if (node == parent)
			return YES;
	return NO;
}

- (BOOL)isEqualToNode:(SKNode *)node
{
	return node == self;
}

/* Calls block with each node PATH (a search string's segments) leads to from
   self. */
static BOOL SKSearch(SKNode *node, NSArray<NSString *> *path, NSUInteger at, BOOL recursive, void (^block)(SKNode *, BOOL *))
{
	if (at == path.count) {
		BOOL stop = NO;
		block(node, &stop);
		return stop;
	}
	NSString *segment = path[at];
	if ([segment isEqualToString:@".."])
		return node->_parent != nil && SKSearch(node->_parent, path, at + 1, NO, block);
	if ([segment isEqualToString:@"."])
		return SKSearch(node, path, at + 1, NO, block);
	for (SKNode *child in [node->_children copy]) {
		if (SKNameMatches(child->_name, segment) && SKSearch(child, path, at + 1, NO, block))
			return YES;
		if (recursive && SKSearch(child, path, at, YES, block))
			return YES;
	}
	return NO;
}

- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void (^)(SKNode *node, BOOL *stop))block
{
	if (name.length == 0 || block == nil)
		return;
	SKNode *start = self;
	BOOL recursive = NO;
	NSString *rest = name;
	if ([rest hasPrefix:@"//"]) {
		recursive = YES;
		rest = [rest substringFromIndex:2];
		while (start->_parent != nil)
			start = start->_parent;
	} else if ([rest hasPrefix:@"/"]) {
		rest = [rest substringFromIndex:1];
		while (start->_parent != nil)
			start = start->_parent;
	}
	NSMutableArray *path = [[rest componentsSeparatedByString:@"/"] mutableCopy];
	[path removeObject:@""];
	if (path.count == 0)
		return;
	/* "//" in the middle searches the rest recursively too. */
	SKSearch(start, path, 0, recursive, block);
}

- (SKNode *)childNodeWithName:(NSString *)name
{
	__block SKNode *found = nil;
	[self enumerateChildNodesWithName:name usingBlock:^(SKNode *node, BOOL *stop) {
		found = node;
		*stop = YES;
	}];
	return found;
}

- (NSArray<SKNode *> *)objectForKeyedSubscript:(NSString *)name
{
	NSMutableArray *found = [NSMutableArray array];
	[self enumerateChildNodesWithName:name usingBlock:^(SKNode *node, BOOL *stop) {
		[found addObject:node];
	}];
	return found;
}

#pragma mark Geometry

- (CGAffineTransform)sk_localTransform
{
	CGAffineTransform t = CGAffineTransformMakeTranslation(_position.x, _position.y);
	if (_zRotation != 0)
		t = CGAffineTransformRotate(t, _zRotation);
	if (_xScale != 1 || _yScale != 1)
		t = CGAffineTransformScale(t, _xScale, _yScale);
	return t;
}

- (CGAffineTransform)sk_sceneTransform
{
	CGAffineTransform t = CGAffineTransformIdentity;
	for (SKNode *node = self; node->_parent != nil; node = node->_parent)
		t = CGAffineTransformConcat(t, [node sk_localTransform]);
	return t;
}

- (CGRect)sk_contentRect
{
	return CGRectNull;
}

- (BOOL)sk_quad:(SKQuad *)quad
{
	return NO;
}

- (CGRect)frame
{
	CGRect content = [self sk_contentRect];
	if (CGRectIsNull(content))
		return CGRectMake(_position.x, _position.y, 0, 0);
	return CGRectApplyAffineTransform(content, [self sk_localTransform]);
}

- (CGRect)calculateAccumulatedFrame
{
	CGRect frame = [self sk_contentRect];
	for (SKNode *child in _children) {
		CGRect childFrame = [child calculateAccumulatedFrame];
		frame = CGRectIsNull(frame) ? childFrame : CGRectUnion(frame, childFrame);
	}
	if (CGRectIsNull(frame))
		return CGRectMake(_position.x, _position.y, 0, 0);
	return CGRectApplyAffineTransform(frame, [self sk_localTransform]);
}

- (BOOL)containsPoint:(CGPoint)p
{
	return CGRectContainsPoint([self calculateAccumulatedFrame], p);
}

/* Whether the node itself (not its children) covers P, in its parent's coordinates. */
static BOOL SKNodeCovers(SKNode *node, CGPoint p)
{
	CGRect content = [node sk_contentRect];
	if (CGRectIsNull(content) || CGRectIsEmpty(content))
		return NO;
	CGPoint local = CGPointApplyAffineTransform(p, CGAffineTransformInvert([node sk_localTransform]));
	return CGRectContainsPoint(content, local);
}

/* A node scaled to nothing covers nothing, and nor do its children (CG's
   inverse of such a transform is the transform itself). */
static BOOL SKNodeIsFlat(SKNode *node)
{
	return node->_xScale == 0 || node->_yScale == 0;
}

/* Descendants of node under p (in node's coordinates), the front-most last. */
static void SKNodesAt(SKNode *node, CGPoint p, CGFloat z, NSMutableArray *found, NSMutableArray *depths)
{
	for (SKNode *child in node->_children) {
		if (child->_hidden || SKNodeIsFlat(child))
			continue;
		CGFloat childZ = z + child->_zPosition;
		if (SKNodeCovers(child, p)) {
			NSUInteger i = depths.count;
			while (i > 0 && [depths[i - 1] doubleValue] > childZ)
				i--;
			[found insertObject:child atIndex:i];
			[depths insertObject:@(childZ) atIndex:i];
		}
		CGPoint local = CGPointApplyAffineTransform(p, CGAffineTransformInvert([child sk_localTransform]));
		SKNodesAt(child, local, childZ, found, depths);
	}
}

- (NSArray<SKNode *> *)nodesAtPoint:(CGPoint)p
{
	NSMutableArray *found = [NSMutableArray array], *depths = [NSMutableArray array];
	SKNodesAt(self, p, 0, found, depths);
	return [[found reverseObjectEnumerator] allObjects];
}

- (SKNode *)nodeAtPoint:(CGPoint)p
{
	NSArray *nodes = [self nodesAtPoint:p];
	return nodes.count > 0 ? nodes[0] : self;
}

- (CGPoint)convertPoint:(CGPoint)point fromNode:(SKNode *)node
{
	CGPoint inScene = CGPointApplyAffineTransform(point, [node sk_sceneTransform]);
	return CGPointApplyAffineTransform(inScene, CGAffineTransformInvert([self sk_sceneTransform]));
}

- (CGPoint)convertPoint:(CGPoint)point toNode:(SKNode *)node
{
	return [node convertPoint:point fromNode:self];
}

- (BOOL)intersectsNode:(SKNode *)node
{
	SKNode *root = [self scene] ?: self;
	CGRect mine = CGRectApplyAffineTransform([self calculateAccumulatedFrame], _parent != nil ? [_parent sk_sceneTransform] : CGAffineTransformIdentity);
	CGRect theirs = CGRectApplyAffineTransform([node calculateAccumulatedFrame], node->_parent != nil ? [node->_parent sk_sceneTransform] : CGAffineTransformIdentity);
	(void)root;
	return CGRectIntersectsRect(mine, theirs);
}

#pragma mark Actions

- (void)runAction:(SKAction *)action
{
	[self runAction:action withKey:nil completion:nil];
}

- (void)runAction:(SKAction *)action completion:(void (^)(void))block
{
	[self runAction:action withKey:nil completion:block];
}

- (void)runAction:(SKAction *)action withKey:(NSString *)key
{
	[self runAction:action withKey:key completion:nil];
}

- (void)runAction:(SKAction *)action withKey:(NSString *)key completion:(void (^)(void))block
{
	if (action == nil)
		return;
	if (key != nil)
		[self removeActionForKey:key];
	SKRunningAction *running = [SKRunningAction new];
	running->_action = [action copy];
	running->_key = [key copy];
	running->_completion = [block copy];
	[_runningActions addObject:running];
}

- (BOOL)hasActions
{
	return _runningActions.count > 0;
}

- (SKAction *)actionForKey:(NSString *)key
{
	for (SKRunningAction *running in _runningActions)
		if (running->_key != nil && [running->_key isEqualToString:key])
			return running->_action;
	return nil;
}

- (void)removeActionForKey:(NSString *)key
{
	if (key == nil)
		return;
	for (NSUInteger i = _runningActions.count; i > 0; i--) {
		SKRunningAction *running = _runningActions[i - 1];
		if (running->_key != nil && [running->_key isEqualToString:key])
			[_runningActions removeObjectAtIndex:i - 1];
	}
}

- (void)removeAllActions
{
	[_runningActions removeAllObjects];
}

- (void)sk_evaluateActions:(NSTimeInterval)dt
{
	if (_paused)
		return;
	dt *= _speed;
	if (_runningActions.count > 0) {
		SKNode *keep = self;
		for (SKRunningAction *running in [_runningActions copy]) {
			/* An earlier action may have removed it. */
			if ([_runningActions indexOfObjectIdenticalTo:running] == NSNotFound)
				continue;
			NSTimeInterval left = 0;
			if (![running->_action sk_step:dt node:self left:&left])
				continue;
			NSUInteger index = [_runningActions indexOfObjectIdenticalTo:running];
			if (index != NSNotFound)
				[_runningActions removeObjectAtIndex:index];
			if (running->_completion != nil)
				running->_completion();
		}
		(void)keep;
	}
	for (SKNode *child in [_children copy])
		if (child->_parent == self)
			[child sk_evaluateActions:dt];
}

@end

#pragma mark Touches

@implementation UITouch (SKNodeTouches)

static CGPoint SKTouchPoint(UITouch *touch, SKNode *node, BOOL previous)
{
	SKScene *scene = [node scene];
	SKView *view = [scene view];
	if (view == nil)
		return CGPointZero;
	CGPoint inView = previous ? [touch previousLocationInView:view] : [touch locationInView:view];
	CGPoint inScene = [scene convertPointFromView:inView];
	return node == scene ? inScene : [node convertPoint:inScene fromNode:scene];
}

- (CGPoint)locationInNode:(SKNode *)node
{
	return SKTouchPoint(self, node, NO);
}

- (CGPoint)previousLocationInNode:(SKNode *)node
{
	return SKTouchPoint(self, node, YES);
}

@end
