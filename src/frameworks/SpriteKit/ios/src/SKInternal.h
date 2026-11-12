/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <SpriteKit/SpriteKit.h>

/* Box2D's scale, which SpriteKit's physics keeps: 150 points to a meter. */
#define SK_POINTS_PER_METER 150.0

typedef struct {
	CGFloat r, g, b, a;
} SKRGBA;

SKRGBA SKColorComponents(UIColor *color);

/* Scene files keep numbers as objects; archives made here, as scalars. */
double SKDecodeNumber(NSCoder *coder, NSString *key, double fallback);
BOOL SKDecodeBool(NSCoder *coder, NSString *key, BOOL fallback);

/* CGPathApplyWithBlock, which this CoreGraphics lacks. */
void SKPathApply(CGPathRef path, void (^block)(const CGPathElement *element));

/* What a node draws: a texture (or none, for a plain color) over a rectangle
   in the node's own coordinates. */
typedef struct {
	SKTexture *__unsafe_unretained texture;
	CGRect rect;
	SKRGBA color;
	CGFloat colorBlendFactor;
	SKBlendMode blendMode;
} SKQuad;

@class SKRenderer;

@interface SKNode () {
@package
	CGPoint _position;
	CGFloat _zPosition, _zRotation, _xScale, _yScale, _speed, _alpha;
	BOOL _paused, _hidden, _userInteractionEnabled;
	__weak SKNode *_parent;
	NSMutableArray<SKNode *> *_children;
	NSString *_name;
	SKPhysicsBody *_physicsBody;
	NSMutableDictionary *_userData;
	NSArray *_constraints;
	SKNodeFocusBehavior _focusBehavior;
	/* SKRunningAction, oldest first. */
	NSMutableArray *_runningActions;
}
/* From the node's coordinates to its parent's. */
- (CGAffineTransform)sk_localTransform;
/* From the node's coordinates to its scene's. */
- (CGAffineTransform)sk_sceneTransform;
/* What the node itself covers, in its own coordinates; empty if nothing. */
- (CGRect)sk_contentRect;
/* Fills QUAD with what the node draws; NO if it draws nothing. */
- (BOOL)sk_quad:(SKQuad *)quad;
- (void)sk_evaluateActions:(NSTimeInterval)dt;
- (void)sk_decodeSceneKit:(NSCoder *)coder;
- (void)sk_didMoveToScene;
@end

@interface SKTexture ()
/* The texture's pixels, whole: subtextures share their parent's. */
- (CGImageRef)sk_image;
/* The texture's rectangle of sk_image, as fractions, bottom-up. */
- (CGRect)sk_rect;
/* Its OpenGL ES texture in the renderer's context; 0 if it has none. */
- (unsigned)sk_glTexture;
+ (instancetype)sk_textureWithImage:(CGImageRef)image scale:(CGFloat)scale;
@end

@interface SKScene ()
- (void)sk_setView:(SKView *)view;
- (void)sk_frame:(NSTimeInterval)now;
/* From scene coordinates to the view's points. */
- (CGAffineTransform)sk_sceneToView;
@end

@interface SKAction ()
/* Runs the action (a copy: running actions keep state) for dt seconds.
   Returns YES when it is done; *left is the part of dt it didn't use. */
- (BOOL)sk_step:(NSTimeInterval)dt node:(SKNode *)node left:(NSTimeInterval *)left;
@end

@interface SKPhysicsBody () {
@package
	__weak SKNode *_node;
}
- (void)sk_setNode:(SKNode *)node;
@end

@interface SKPhysicsWorld ()
- (void)sk_simulate:(NSTimeInterval)dt scene:(SKScene *)scene;
- (NSArray<SKPhysicsBody *> *)sk_contactedBodies:(SKPhysicsBody *)body;
@end

/* Starts playing the bundle's sound NAME; returns how long it lasts, 0 if
   it can't be played. */
NSTimeInterval SKPlaySound(NSString *name);
