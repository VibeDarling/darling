/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* iOS's SpriteKit, as far as this one goes: the node tree, sprites, labels,
   shapes, textures and atlases, actions, simple physics, and SKView, which
   draws scenes with OpenGL ES. The declarations follow Apple's headers. */

#ifndef _SpriteKit_H_
#define _SpriteKit_H_

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define SKColor UIColor

@class SKScene, SKView, SKAction, SKPhysicsBody, SKPhysicsWorld, SKPhysicsContact, SKTexture, SKTransition, SKCameraNode;

typedef NS_ENUM(NSInteger, SKBlendMode) {
	SKBlendModeAlpha = 0,
	SKBlendModeAdd = 1,
	SKBlendModeSubtract = 2,
	SKBlendModeMultiply = 3,
	SKBlendModeMultiplyX2 = 4,
	SKBlendModeScreen = 5,
	SKBlendModeReplace = 6,
	SKBlendModeMultiplyAlpha = 7,
};

typedef NS_ENUM(NSInteger, SKSceneScaleMode) {
	SKSceneScaleModeFill,
	SKSceneScaleModeAspectFill,
	SKSceneScaleModeAspectFit,
	SKSceneScaleModeResizeFill,
};

typedef NS_ENUM(NSInteger, SKTextureFilteringMode) {
	SKTextureFilteringNearest,
	SKTextureFilteringLinear,
};

typedef NS_ENUM(NSInteger, SKActionTimingMode) {
	SKActionTimingLinear,
	SKActionTimingEaseIn,
	SKActionTimingEaseOut,
	SKActionTimingEaseInEaseOut,
};

typedef float (^SKActionTimingFunction)(float time);

typedef NS_ENUM(NSInteger, SKLabelVerticalAlignmentMode) {
	SKLabelVerticalAlignmentModeBaseline = 0,
	SKLabelVerticalAlignmentModeCenter = 1,
	SKLabelVerticalAlignmentModeTop = 2,
	SKLabelVerticalAlignmentModeBottom = 3,
};

typedef NS_ENUM(NSInteger, SKLabelHorizontalAlignmentMode) {
	SKLabelHorizontalAlignmentModeCenter = 0,
	SKLabelHorizontalAlignmentModeLeft = 1,
	SKLabelHorizontalAlignmentModeRight = 2,
};

typedef NS_ENUM(NSInteger, SKNodeFocusBehavior) {
	SKNodeFocusBehaviorNone = 0,
	SKNodeFocusBehaviorOccluding,
	SKNodeFocusBehaviorFocusable,
};

#pragma mark SKNode

@interface SKNode : UIResponder <NSCopying, NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
+ (instancetype)node;
+ (nullable instancetype)nodeWithFileNamed:(NSString *)filename;
+ (nullable instancetype)nodeWithFileNamed:(NSString *)filename securelyWithClasses:(NSSet<Class> *)classes andError:(NSError **)error;

@property (nonatomic, readonly) CGRect frame;
- (CGRect)calculateAccumulatedFrame;
@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat zPosition;
@property (nonatomic) CGFloat zRotation;
@property (nonatomic) CGFloat xScale;
@property (nonatomic) CGFloat yScale;
@property (nonatomic) CGFloat speed;
@property (nonatomic) CGFloat alpha;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic) SKNodeFocusBehavior focusBehavior;
@property (nonatomic, readonly, nullable) SKNode *parent;
@property (nonatomic, readonly) NSArray<SKNode *> *children;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly, nullable) SKScene *scene;
@property (nonatomic, retain, nullable) SKPhysicsBody *physicsBody;
@property (nonatomic, retain, nullable) NSMutableDictionary *userData;
@property (nonatomic, copy, nullable) NSArray *constraints;

- (void)setScale:(CGFloat)scale;
- (void)addChild:(SKNode *)node;
- (void)insertChild:(SKNode *)node atIndex:(NSInteger)index;
- (void)removeChildrenInArray:(NSArray<SKNode *> *)nodes;
- (void)removeAllChildren;
- (void)removeFromParent;
- (void)moveToParent:(SKNode *)parent;
- (nullable SKNode *)childNodeWithName:(NSString *)name;
- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void (^)(SKNode *node, BOOL *stop))block;
- (NSArray<SKNode *> *)objectForKeyedSubscript:(NSString *)name;
- (BOOL)inParentHierarchy:(SKNode *)parent;

- (void)runAction:(SKAction *)action;
- (void)runAction:(SKAction *)action completion:(void (^)(void))block;
- (void)runAction:(SKAction *)action withKey:(NSString *)key;
- (BOOL)hasActions;
- (nullable SKAction *)actionForKey:(NSString *)key;
- (void)removeActionForKey:(NSString *)key;
- (void)removeAllActions;

- (BOOL)containsPoint:(CGPoint)p;
- (SKNode *)nodeAtPoint:(CGPoint)p;
- (NSArray<SKNode *> *)nodesAtPoint:(CGPoint)p;
- (CGPoint)convertPoint:(CGPoint)point fromNode:(SKNode *)node;
- (CGPoint)convertPoint:(CGPoint)point toNode:(SKNode *)node;
- (BOOL)intersectsNode:(SKNode *)node;
- (BOOL)isEqualToNode:(SKNode *)node;
@end

@interface UITouch (SKNodeTouches)
- (CGPoint)locationInNode:(SKNode *)node;
- (CGPoint)previousLocationInNode:(SKNode *)node;
@end

#pragma mark Textures

@interface SKTexture : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)textureWithImageNamed:(NSString *)name;
+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture;
+ (instancetype)textureWithCGImage:(CGImageRef)image;
+ (instancetype)textureWithImage:(UIImage *)image;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size;
+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size flipped:(BOOL)flipped;
- (CGRect)textureRect;
- (CGSize)size;
@property (nonatomic) SKTextureFilteringMode filteringMode;
@property (nonatomic) BOOL usesMipmaps;
- (CGImageRef)CGImage CF_RETURNS_RETAINED;
+ (void)preloadTextures:(NSArray<SKTexture *> *)textures withCompletionHandler:(void (^)(void))completionHandler;
- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler;
@end

@interface SKTextureAtlas : NSObject <NSSecureCoding>
+ (instancetype)atlasNamed:(NSString *)name;
+ (instancetype)atlasWithDictionary:(NSDictionary<NSString *, id> *)properties;
- (SKTexture *)textureNamed:(NSString *)name;
+ (void)preloadTextureAtlases:(NSArray<SKTextureAtlas *> *)textureAtlases withCompletionHandler:(void (^)(void))completionHandler;
+ (void)preloadTextureAtlasesNamed:(NSArray<NSString *> *)atlasNames withCompletionHandler:(void (^)(NSError *_Nullable error, NSArray<SKTextureAtlas *> *foundAtlases))completionHandler;
- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler;
@property (nonatomic, readonly) NSArray<NSString *> *textureNames;
@end

#pragma mark Drawing nodes

@interface SKSpriteNode : SKNode
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture size:(CGSize)size;
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture;
+ (instancetype)spriteNodeWithTexture:(nullable SKTexture *)texture normalMap:(nullable SKTexture *)normalMap;
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name;
+ (instancetype)spriteNodeWithImageNamed:(NSString *)name normalMapped:(BOOL)generateNormalMap;
+ (instancetype)spriteNodeWithColor:(UIColor *)color size:(CGSize)size;
- (instancetype)initWithTexture:(nullable SKTexture *)texture color:(UIColor *)color size:(CGSize)size NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTexture:(nullable SKTexture *)texture;
- (instancetype)initWithImageNamed:(NSString *)name;
- (instancetype)initWithColor:(UIColor *)color size:(CGSize)size;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, retain, nullable) SKTexture *texture;
@property (nonatomic, retain, nullable) SKTexture *normalTexture;
@property (nonatomic) uint32_t lightingBitMask;
@property (nonatomic) uint32_t shadowCastBitMask;
@property (nonatomic) uint32_t shadowedBitMask;
@property (nonatomic) CGRect centerRect;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic, retain) UIColor *color;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) CGSize size;
- (void)scaleToSize:(CGSize)size;
@end

@interface SKLabelNode : SKNode
+ (instancetype)labelNodeWithText:(nullable NSString *)text;
+ (instancetype)labelNodeWithAttributedText:(nullable NSAttributedString *)attributedText;
+ (instancetype)labelNodeWithFontNamed:(nullable NSString *)fontName;
- (instancetype)initWithFontNamed:(nullable NSString *)fontName;
@property (nonatomic) SKLabelVerticalAlignmentMode verticalAlignmentMode;
@property (nonatomic) SKLabelHorizontalAlignmentMode horizontalAlignmentMode;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;
@property (nonatomic, copy, nullable) NSString *fontName;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic, retain, nullable) UIColor *fontColor;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic, retain, nullable) UIColor *color;
@property (nonatomic) SKBlendMode blendMode;
@end

@interface SKShapeNode : SKNode
+ (instancetype)shapeNodeWithPath:(CGPathRef)path;
+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered;
+ (instancetype)shapeNodeWithRect:(CGRect)rect;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size;
+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)radius;
+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect;
+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size;
+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints;
@property (nonatomic, nullable) CGPathRef path;
@property (nonatomic, retain) UIColor *strokeColor;
@property (nonatomic, retain) UIColor *fillColor;
@property (nonatomic) SKBlendMode blendMode;
@property (nonatomic, getter=isAntialiased) BOOL antialiased;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat glowWidth;
@property (nonatomic) CGLineCap lineCap;
@property (nonatomic) CGLineJoin lineJoin;
@property (nonatomic) CGFloat miterLimit;
@property (nonatomic, readonly) CGFloat lineLength;
@property (nonatomic, retain, nullable) SKTexture *fillTexture;
@property (nonatomic, retain, nullable) SKTexture *strokeTexture;
@end

@interface SKEffectNode : SKNode
@property (nonatomic, retain, nullable) id filter;
@property (nonatomic) BOOL shouldCenterFilter;
@property (nonatomic) BOOL shouldEnableEffects;
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) SKBlendMode blendMode;
@end

@interface SKCropNode : SKNode
@property (nonatomic, retain, nullable) SKNode *maskNode;
@end

@interface SKCameraNode : SKNode
- (BOOL)containsNode:(SKNode *)node;
- (NSSet<SKNode *> *)containedNodeSet;
@end

#pragma mark Scenes

@protocol SKSceneDelegate <NSObject>
@optional
- (void)update:(NSTimeInterval)currentTime forScene:(SKScene *)scene;
- (void)didEvaluateActionsForScene:(SKScene *)scene;
- (void)didSimulatePhysicsForScene:(SKScene *)scene;
- (void)didApplyConstraintsForScene:(SKScene *)scene;
- (void)didFinishUpdateForScene:(SKScene *)scene;
@end

@interface SKScene : SKEffectNode
- (instancetype)initWithSize:(CGSize)size;
+ (instancetype)sceneWithSize:(CGSize)size;
- (void)sceneDidLoad;
@property (nonatomic) CGSize size;
@property (nonatomic) SKSceneScaleMode scaleMode;
@property (nonatomic, weak, nullable) SKCameraNode *camera;
@property (nonatomic, weak, nullable) SKNode *listener;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, weak, nullable) id<SKSceneDelegate> delegate;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic, readonly) SKPhysicsWorld *physicsWorld;
@property (nonatomic, weak, readonly, nullable) SKView *view;
- (CGPoint)convertPointFromView:(CGPoint)point;
- (CGPoint)convertPointToView:(CGPoint)point;
- (void)update:(NSTimeInterval)currentTime;
- (void)didEvaluateActions;
- (void)didSimulatePhysics;
- (void)didApplyConstraints;
- (void)didFinishUpdate;
- (void)didMoveToView:(SKView *)view;
- (void)willMoveFromView:(SKView *)view;
- (void)didChangeSize:(CGSize)oldSize;
@end

@interface SKTransition : NSObject
+ (SKTransition *)crossFadeWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)fadeWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)fadeWithColor:(UIColor *)color duration:(NSTimeInterval)sec;
+ (SKTransition *)flipHorizontalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)flipVerticalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)doorsOpenHorizontalWithDuration:(NSTimeInterval)sec;
+ (SKTransition *)pushWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec;
+ (SKTransition *)moveInWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec;
+ (SKTransition *)revealWithDirection:(NSInteger)direction duration:(NSTimeInterval)sec;
@property (nonatomic) BOOL pausesIncomingScene;
@property (nonatomic) BOOL pausesOutgoingScene;
@end

@protocol SKViewDelegate <NSObject>
@optional
- (BOOL)view:(SKView *)view shouldRenderAtTime:(NSTimeInterval)time;
@end

@interface SKView : UIView
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic) BOOL showsFPS;
@property (nonatomic) BOOL showsDrawCount;
@property (nonatomic) BOOL showsNodeCount;
@property (nonatomic) BOOL showsQuadCount;
@property (nonatomic) BOOL showsPhysics;
@property (nonatomic) BOOL showsFields;
@property (nonatomic, getter=isAsynchronous) BOOL asynchronous;
@property (nonatomic) BOOL allowsTransparency;
@property (nonatomic) BOOL ignoresSiblingOrder;
@property (nonatomic) BOOL shouldCullNonVisibleNodes;
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) BOOL disableDepthStencilBuffer;
@property (nonatomic, weak, nullable) NSObject<SKViewDelegate> *delegate;
@property (nonatomic) NSInteger frameInterval;
@property (nonatomic) float preferredFrameRate;
- (void)presentScene:(nullable SKScene *)scene;
- (void)presentScene:(SKScene *)scene transition:(SKTransition *)transition;
@property (nonatomic, readonly, nullable) SKScene *scene;
- (nullable SKTexture *)textureFromNode:(SKNode *)node;
- (nullable SKTexture *)textureFromNode:(SKNode *)node crop:(CGRect)crop;
- (CGPoint)convertPoint:(CGPoint)point toScene:(SKScene *)scene;
- (CGPoint)convertPoint:(CGPoint)point fromScene:(SKScene *)scene;
@end

#pragma mark Actions

@interface SKAction : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) SKActionTimingMode timingMode;
@property (nonatomic, nullable) SKActionTimingFunction timingFunction;
@property (nonatomic) CGFloat speed;
- (SKAction *)reversedAction;
@end

@interface SKAction (SKActions)
+ (SKAction *)moveBy:(CGVector)delta duration:(NSTimeInterval)duration;
+ (SKAction *)moveByX:(CGFloat)deltaX y:(CGFloat)deltaY duration:(NSTimeInterval)duration;
+ (SKAction *)moveTo:(CGPoint)location duration:(NSTimeInterval)duration;
+ (SKAction *)moveToX:(CGFloat)x duration:(NSTimeInterval)duration;
+ (SKAction *)moveToY:(CGFloat)y duration:(NSTimeInterval)duration;
+ (SKAction *)rotateByAngle:(CGFloat)radians duration:(NSTimeInterval)duration;
+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration;
+ (SKAction *)rotateToAngle:(CGFloat)radians duration:(NSTimeInterval)duration shortestUnitArc:(BOOL)shortestUnitArc;
+ (SKAction *)resizeByWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration;
+ (SKAction *)resizeToWidth:(CGFloat)width height:(CGFloat)height duration:(NSTimeInterval)duration;
+ (SKAction *)resizeToWidth:(CGFloat)width duration:(NSTimeInterval)duration;
+ (SKAction *)resizeToHeight:(CGFloat)height duration:(NSTimeInterval)duration;
+ (SKAction *)scaleBy:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXBy:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXTo:(CGFloat)xScale y:(CGFloat)yScale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleXTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)scaleYTo:(CGFloat)scale duration:(NSTimeInterval)duration;
+ (SKAction *)sequence:(NSArray<SKAction *> *)actions;
+ (SKAction *)group:(NSArray<SKAction *> *)actions;
+ (SKAction *)repeatAction:(SKAction *)action count:(NSUInteger)count;
+ (SKAction *)repeatActionForever:(SKAction *)action;
+ (SKAction *)fadeInWithDuration:(NSTimeInterval)duration;
+ (SKAction *)fadeOutWithDuration:(NSTimeInterval)duration;
+ (SKAction *)fadeAlphaBy:(CGFloat)factor duration:(NSTimeInterval)duration;
+ (SKAction *)fadeAlphaTo:(CGFloat)alpha duration:(NSTimeInterval)duration;
+ (SKAction *)hide;
+ (SKAction *)unhide;
+ (SKAction *)setTexture:(SKTexture *)texture;
+ (SKAction *)setTexture:(SKTexture *)texture resize:(BOOL)resize;
+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec;
+ (SKAction *)animateWithTextures:(NSArray<SKTexture *> *)textures timePerFrame:(NSTimeInterval)sec resize:(BOOL)resize restore:(BOOL)restore;
+ (SKAction *)playSoundFileNamed:(NSString *)soundFile waitForCompletion:(BOOL)wait;
+ (SKAction *)colorizeWithColor:(nullable UIColor *)color colorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)duration;
+ (SKAction *)colorizeWithColorBlendFactor:(CGFloat)colorBlendFactor duration:(NSTimeInterval)sec;
+ (SKAction *)followPath:(CGPathRef)path duration:(NSTimeInterval)duration;
+ (SKAction *)followPath:(CGPathRef)path asOffset:(BOOL)offset orientToPath:(BOOL)orient duration:(NSTimeInterval)duration;
+ (SKAction *)speedBy:(CGFloat)speed duration:(NSTimeInterval)duration;
+ (SKAction *)speedTo:(CGFloat)speed duration:(NSTimeInterval)duration;
+ (SKAction *)waitForDuration:(NSTimeInterval)duration;
+ (SKAction *)waitForDuration:(NSTimeInterval)duration withRange:(NSTimeInterval)durationRange;
+ (SKAction *)removeFromParent;
+ (SKAction *)performSelector:(SEL)selector onTarget:(id)target;
+ (SKAction *)runBlock:(dispatch_block_t)block;
+ (SKAction *)runBlock:(dispatch_block_t)block queue:(dispatch_queue_t)queue;
+ (SKAction *)runAction:(SKAction *)action onChildWithName:(NSString *)name;
+ (SKAction *)customActionWithDuration:(NSTimeInterval)duration actionBlock:(void (^)(SKNode *node, CGFloat elapsedTime))block;
+ (nullable SKAction *)actionNamed:(NSString *)name;
+ (SKAction *)applyImpulse:(CGVector)impulse duration:(NSTimeInterval)duration;
+ (SKAction *)applyForce:(CGVector)force duration:(NSTimeInterval)duration;
@end

#pragma mark Physics

@interface SKPhysicsBody : NSObject <NSCopying, NSSecureCoding>
+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r;
+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r center:(CGPoint)center;
+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)s;
+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)s center:(CGPoint)center;
+ (SKPhysicsBody *)bodyWithPolygonFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2;
+ (SKPhysicsBody *)bodyWithEdgeChainFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeLoopFromPath:(CGPathRef)path;
+ (SKPhysicsBody *)bodyWithEdgeLoopFromRect:(CGRect)rect;
+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture size:(CGSize)size;
+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture alphaThreshold:(float)alphaThreshold size:(CGSize)size;
+ (SKPhysicsBody *)bodyWithBodies:(NSArray<SKPhysicsBody *> *)bodies;
@property (nonatomic, getter=isDynamic) BOOL dynamic;
@property (nonatomic) BOOL usesPreciseCollisionDetection;
@property (nonatomic) BOOL allowsRotation;
@property (nonatomic) BOOL pinned;
@property (nonatomic, getter=isResting) BOOL resting;
@property (nonatomic) CGFloat friction;
@property (nonatomic) CGFloat charge;
@property (nonatomic) CGFloat restitution;
@property (nonatomic, assign) CGFloat linearDamping;
@property (nonatomic, assign) CGFloat angularDamping;
@property (nonatomic) CGFloat density;
@property (nonatomic) CGFloat mass;
@property (nonatomic, readonly) CGFloat area;
@property (nonatomic, assign) BOOL affectedByGravity;
@property (nonatomic, assign) uint32_t fieldBitMask;
@property (nonatomic, assign) uint32_t categoryBitMask;
@property (nonatomic, assign) uint32_t collisionBitMask;
@property (nonatomic, assign) uint32_t contactTestBitMask;
@property (nonatomic, readonly) NSArray *joints;
@property (nonatomic, readonly, weak, nullable) SKNode *node;
@property (nonatomic) CGVector velocity;
@property (nonatomic) CGFloat angularVelocity;
- (void)applyForce:(CGVector)force;
- (void)applyForce:(CGVector)force atPoint:(CGPoint)point;
- (void)applyTorque:(CGFloat)torque;
- (void)applyImpulse:(CGVector)impulse;
- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point;
- (void)applyAngularImpulse:(CGFloat)impulse;
- (NSArray<SKPhysicsBody *> *)allContactedBodies;
@end

@protocol SKPhysicsContactDelegate <NSObject>
@optional
- (void)didBeginContact:(SKPhysicsContact *)contact;
- (void)didEndContact:(SKPhysicsContact *)contact;
@end

@interface SKPhysicsWorld : NSObject <NSSecureCoding>
@property (nonatomic) CGVector gravity;
@property (nonatomic) CGFloat speed;
@property (nonatomic, assign, nullable) id<SKPhysicsContactDelegate> contactDelegate;
- (void)addJoint:(id)joint;
- (void)removeJoint:(id)joint;
- (void)removeAllJoints;
- (nullable SKPhysicsBody *)bodyAtPoint:(CGPoint)point;
- (nullable SKPhysicsBody *)bodyInRect:(CGRect)rect;
- (void)enumerateBodiesAtPoint:(CGPoint)point usingBlock:(void (^)(SKPhysicsBody *body, BOOL *stop))block;
- (void)enumerateBodiesInRect:(CGRect)rect usingBlock:(void (^)(SKPhysicsBody *body, BOOL *stop))block;
@end

@interface SKPhysicsContact : NSObject
@property (nonatomic, readonly) SKPhysicsBody *bodyA;
@property (nonatomic, readonly) SKPhysicsBody *bodyB;
@property (nonatomic, readonly) CGPoint contactPoint;
@property (nonatomic, readonly) CGVector contactNormal;
@property (nonatomic, readonly) CGFloat collisionImpulse;
@end

NS_ASSUME_NONNULL_END

#endif
