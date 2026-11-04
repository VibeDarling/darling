/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import "SKInternal.h"

#pragma mark Sprites

@implementation SKSpriteNode {
	SKTexture *_texture, *_normalTexture;
	UIColor *_color;
	CGFloat _colorBlendFactor;
	SKBlendMode _blendMode;
	CGPoint _anchorPoint;
	/* Unscaled: -size includes the node's scale, as SpriteKit's does. */
	CGSize _size;
	CGRect _centerRect;
	uint32_t _lightingBitMask, _shadowCastBitMask, _shadowedBitMask;
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture size:(CGSize)size
{
	return [[self alloc] initWithTexture:texture color:[UIColor whiteColor] size:size];
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture
{
	return [[self alloc] initWithTexture:texture];
}

+ (instancetype)spriteNodeWithTexture:(SKTexture *)texture normalMap:(SKTexture *)normalMap
{
	SKSpriteNode *node = [[self alloc] initWithTexture:texture];
	node.normalTexture = normalMap;
	return node;
}

+ (instancetype)spriteNodeWithImageNamed:(NSString *)name
{
	return [[self alloc] initWithImageNamed:name];
}

+ (instancetype)spriteNodeWithImageNamed:(NSString *)name normalMapped:(BOOL)generateNormalMap
{
	return [[self alloc] initWithImageNamed:name];
}

+ (instancetype)spriteNodeWithColor:(UIColor *)color size:(CGSize)size
{
	return [[self alloc] initWithColor:color size:size];
}

static void SKSpriteSetDefaults(SKSpriteNode *node)
{
	node->_anchorPoint = CGPointMake(0.5, 0.5);
	node->_color = [UIColor whiteColor];
	node->_centerRect = CGRectMake(0, 0, 1, 1);
	node->_lightingBitMask = 0;
	node->_shadowCastBitMask = 0;
	node->_shadowedBitMask = 0;
}

- (instancetype)initWithTexture:(SKTexture *)texture color:(UIColor *)color size:(CGSize)size
{
	self = [super init];
	if (self == nil)
		return nil;
	SKSpriteSetDefaults(self);
	_texture = texture;
	_color = color ?: [UIColor whiteColor];
	_size = size;
	/* A texture's colors are shown as they are; a plain sprite is its color. */
	_colorBlendFactor = texture != nil ? 0 : 1;
	return self;
}

- (instancetype)init
{
	return [self initWithTexture:nil color:[UIColor whiteColor] size:CGSizeZero];
}

- (instancetype)initWithTexture:(SKTexture *)texture
{
	return [self initWithTexture:texture color:[UIColor whiteColor] size:texture != nil ? [texture size] : CGSizeZero];
}

- (instancetype)initWithImageNamed:(NSString *)name
{
	SKTexture *texture = [SKTexture textureWithImageNamed:name];
	return [self initWithTexture:texture color:[UIColor whiteColor] size:[texture size]];
}

- (instancetype)initWithColor:(UIColor *)color size:(CGSize)size
{
	return [self initWithTexture:nil color:color size:size];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self == nil)
		return nil;
	SKSpriteSetDefaults(self);
	id texture = [coder decodeObjectForKey:@"_texture"];
	if ([texture isKindOfClass:[SKTexture class]])
		_texture = texture;
	id size = [coder decodeObjectForKey:@"_size"];
	if ([size isKindOfClass:[NSValue class]])
		_size = [size CGSizeValue];
	id anchor = [coder decodeObjectForKey:@"_anchorPoint"];
	if ([anchor isKindOfClass:[NSValue class]])
		_anchorPoint = [anchor CGPointValue];
	if ([coder containsValueForKey:@"_colorBlendFactor"])
		_colorBlendFactor = SKDecodeNumber(coder, @"_colorBlendFactor", 0);
	else if ([coder containsValueForKey:@"_colorMix"])
		_colorBlendFactor = SKDecodeNumber(coder, @"_colorMix", 0);
	else
		_colorBlendFactor = _texture != nil ? 0 : 1;
	if ([coder containsValueForKey:@"_baseColorR"])
		_color = [UIColor colorWithRed:SKDecodeNumber(coder, @"_baseColorR", 0) green:SKDecodeNumber(coder, @"_baseColorG", 0)
			blue:SKDecodeNumber(coder, @"_baseColorB", 0) alpha:SKDecodeNumber(coder, @"_baseColorA", 1)];
	id color = [coder decodeObjectForKey:@"_color"];
	if ([color isKindOfClass:[UIColor class]])
		_color = color;
	_blendMode = (NSInteger)SKDecodeNumber(coder, @"_blendMode", 0);
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	if (_texture != nil)
		[coder encodeObject:_texture forKey:@"_texture"];
	[coder encodeObject:[NSValue valueWithCGSize:_size] forKey:@"_size"];
	[coder encodeObject:[NSValue valueWithCGPoint:_anchorPoint] forKey:@"_anchorPoint"];
	[coder encodeDouble:_colorBlendFactor forKey:@"_colorBlendFactor"];
	if (_color != nil)
		[coder encodeObject:_color forKey:@"_color"];
	[coder encodeInteger:_blendMode forKey:@"_blendMode"];
}

- (SKTexture *)texture { return _texture; }
- (void)setTexture:(SKTexture *)texture { _texture = texture; }
- (SKTexture *)normalTexture { return _normalTexture; }
- (void)setNormalTexture:(SKTexture *)texture { _normalTexture = texture; }
- (uint32_t)lightingBitMask { return _lightingBitMask; }
- (void)setLightingBitMask:(uint32_t)mask { _lightingBitMask = mask; }
- (uint32_t)shadowCastBitMask { return _shadowCastBitMask; }
- (void)setShadowCastBitMask:(uint32_t)mask { _shadowCastBitMask = mask; }
- (uint32_t)shadowedBitMask { return _shadowedBitMask; }
- (void)setShadowedBitMask:(uint32_t)mask { _shadowedBitMask = mask; }
- (CGRect)centerRect { return _centerRect; }
- (void)setCenterRect:(CGRect)rect { _centerRect = rect; }
- (CGFloat)colorBlendFactor { return _colorBlendFactor; }
- (void)setColorBlendFactor:(CGFloat)factor { _colorBlendFactor = factor; }
- (UIColor *)color { return _color; }
- (void)setColor:(UIColor *)color { _color = color; }
- (SKBlendMode)blendMode { return _blendMode; }
- (void)setBlendMode:(SKBlendMode)mode { _blendMode = mode; }
- (CGPoint)anchorPoint { return _anchorPoint; }
- (void)setAnchorPoint:(CGPoint)point { _anchorPoint = point; }

- (CGSize)size
{
	return CGSizeMake(_size.width * _xScale, _size.height * _yScale);
}

- (void)setSize:(CGSize)size
{
	_size = CGSizeMake(_xScale != 0 ? size.width / _xScale : size.width, _yScale != 0 ? size.height / _yScale : size.height);
}

- (void)scaleToSize:(CGSize)size
{
	if (_size.width != 0)
		_xScale = size.width / _size.width;
	if (_size.height != 0)
		_yScale = size.height / _size.height;
}

/* Setting a texture keeps the size; SKAction's setTexture:resize: sets it. */
- (void)sk_setTexture:(SKTexture *)texture resize:(BOOL)resize
{
	_texture = texture;
	if (resize && texture != nil)
		_size = [texture size];
}

- (CGRect)sk_contentRect
{
	return CGRectMake(-_anchorPoint.x * _size.width, -_anchorPoint.y * _size.height, _size.width, _size.height);
}

- (BOOL)sk_quad:(SKQuad *)quad
{
	if (_size.width == 0 || _size.height == 0)
		return NO;
	quad->texture = _texture;
	quad->rect = [self sk_contentRect];
	quad->color = SKColorComponents(_color);
	quad->colorBlendFactor = _texture != nil ? _colorBlendFactor : 1;
	quad->blendMode = _blendMode;
	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SKSpriteNode> name:'%@' texture:[%@] position:{%g, %g} scale:{%.2f, %.2f} size:{%g, %g} anchor:{%g, %g} rotation:%.2f",
		_name, _texture, _position.x, _position.y, _xScale, _yScale, _size.width, _size.height, _anchorPoint.x, _anchorPoint.y, _zRotation];
}

@end

#pragma mark Drawing into a texture

/* Labels and shapes are drawn with UIKit into an image, which is their
   texture until they change. */
static SKTexture *SKDrawTexture(CGSize size, CGFloat scale, void (^draw)(CGContextRef context))
{
	if (size.width <= 0 || size.height <= 0)
		return nil;
	UIGraphicsBeginImageContextWithOptions(size, NO, scale);
	draw(UIGraphicsGetCurrentContext());
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image != nil ? [SKTexture textureWithImage:image] : nil;
}

static CGFloat SKDrawingScale(SKNode *node)
{
	CGFloat scale = [[UIScreen mainScreen] scale];
	SKScene *scene = [node scene];
	if (scene != nil && [scene view] != nil) {
		CGAffineTransform t = [scene sk_sceneToView];
		CGFloat sceneScale = sqrt(fabs(t.a * t.d - t.b * t.c));
		if (sceneScale > 0)
			scale *= sceneScale;
	}
	CGFloat nodeScale = MAX(fabs(node.xScale), fabs(node.yScale));
	if (nodeScale > 0)
		scale *= nodeScale;
	/* Whole pixels per point: a fractional scale rounds the bitmap's size,
	   which then no longer fills the node's rectangle exactly. */
	return MIN(MAX(ceil(scale - 0.01), 1), 8);
}

#pragma mark Labels

@implementation SKLabelNode {
	NSString *_text, *_fontName;
	NSAttributedString *_attributedText;
	CGFloat _fontSize, _colorBlendFactor, _preferredMaxLayoutWidth;
	UIColor *_fontColor, *_color;
	SKBlendMode _blendMode;
	SKLabelVerticalAlignmentMode _verticalAlignmentMode;
	SKLabelHorizontalAlignmentMode _horizontalAlignmentMode;
	NSInteger _numberOfLines;
	NSLineBreakMode _lineBreakMode;
	/* The text drawn, and where its image goes, in the node's coordinates. */
	SKTexture *_rendered;
	CGRect _renderedRect;
	CGFloat _renderedScale;
	BOOL _dirty;
}

+ (instancetype)labelNodeWithText:(NSString *)text
{
	SKLabelNode *node = [[self alloc] init];
	node.text = text;
	return node;
}

+ (instancetype)labelNodeWithAttributedText:(NSAttributedString *)attributedText
{
	SKLabelNode *node = [[self alloc] init];
	node.attributedText = attributedText;
	return node;
}

+ (instancetype)labelNodeWithFontNamed:(NSString *)fontName
{
	return [[self alloc] initWithFontNamed:fontName];
}

static void SKLabelSetDefaults(SKLabelNode *node, NSString *fontName)
{
	node->_fontName = [fontName copy] ?: @"HelveticaNeue-UltraLight";
	node->_fontSize = 32;
	node->_fontColor = [UIColor whiteColor];
	node->_color = [UIColor whiteColor];
	node->_numberOfLines = 1;
	node->_lineBreakMode = NSLineBreakByTruncatingTail;
	node->_dirty = YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		SKLabelSetDefaults(self, nil);
	return self;
}

- (instancetype)initWithFontNamed:(NSString *)fontName
{
	self = [super init];
	if (self != nil)
		SKLabelSetDefaults(self, fontName);
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self == nil)
		return nil;
	SKLabelSetDefaults(self, [coder decodeObjectForKey:@"_fontName"]);
	_text = [[coder decodeObjectForKey:@"_text"] copy];
	if ([coder containsValueForKey:@"_fontSize"])
		_fontSize = SKDecodeNumber(coder, @"_fontSize", 0);
	id color = [coder decodeObjectForKey:@"_fontColor"];
	if ([color isKindOfClass:[UIColor class]])
		_fontColor = color;
	_horizontalAlignmentMode = (NSInteger)SKDecodeNumber(coder, @"_horizontalAlignmentMode", 0);
	_verticalAlignmentMode = (NSInteger)SKDecodeNumber(coder, @"_verticalAlignmentMode", 0);
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	if (_text != nil)
		[coder encodeObject:_text forKey:@"_text"];
	if (_fontName != nil)
		[coder encodeObject:_fontName forKey:@"_fontName"];
	[coder encodeDouble:_fontSize forKey:@"_fontSize"];
	if (_fontColor != nil)
		[coder encodeObject:_fontColor forKey:@"_fontColor"];
	[coder encodeInteger:_horizontalAlignmentMode forKey:@"_horizontalAlignmentMode"];
	[coder encodeInteger:_verticalAlignmentMode forKey:@"_verticalAlignmentMode"];
}

#define SK_LABEL_SETTER(type, name, setter) \
	- (type)name { return _##name; } \
	- (void)setter:(type)value { _##name = value; _dirty = YES; }

SK_LABEL_SETTER(CGFloat, fontSize, setFontSize)
SK_LABEL_SETTER(UIColor *, fontColor, setFontColor)
SK_LABEL_SETTER(SKLabelVerticalAlignmentMode, verticalAlignmentMode, setVerticalAlignmentMode)
SK_LABEL_SETTER(SKLabelHorizontalAlignmentMode, horizontalAlignmentMode, setHorizontalAlignmentMode)
SK_LABEL_SETTER(NSInteger, numberOfLines, setNumberOfLines)
SK_LABEL_SETTER(NSLineBreakMode, lineBreakMode, setLineBreakMode)
SK_LABEL_SETTER(CGFloat, preferredMaxLayoutWidth, setPreferredMaxLayoutWidth)

- (NSString *)fontName { return _fontName; }
- (void)setFontName:(NSString *)name { _fontName = [name copy]; _dirty = YES; }
- (NSString *)text { return _text ?: [_attributedText string]; }
- (void)setText:(NSString *)text
{
	if (_attributedText == nil && (_text == text || [_text isEqualToString:text]))
		return;
	_text = [text copy];
	_attributedText = nil;
	_dirty = YES;
}
- (NSAttributedString *)attributedText { return _attributedText; }
- (void)setAttributedText:(NSAttributedString *)text
{
	_attributedText = [text copy];
	_text = nil;
	_dirty = YES;
}
- (CGFloat)colorBlendFactor { return _colorBlendFactor; }
- (void)setColorBlendFactor:(CGFloat)factor { _colorBlendFactor = factor; }
- (UIColor *)color { return _color; }
- (void)setColor:(UIColor *)color { _color = color; }
- (SKBlendMode)blendMode { return _blendMode; }
- (void)setBlendMode:(SKBlendMode)mode { _blendMode = mode; }

- (UIFont *)sk_font
{
	UIFont *font = _fontName != nil ? [UIFont fontWithName:_fontName size:_fontSize] : nil;
	return font ?: [UIFont systemFontOfSize:_fontSize];
}

- (NSAttributedString *)sk_string
{
	if (_attributedText != nil)
		return _attributedText;
	if (_text.length == 0)
		return nil;
	/* No paragraph alignment: the node aligns the drawn line, and Cocotron
	   would align it about the point it is drawn at. */
	return [[NSAttributedString alloc] initWithString:_text attributes:@{
		NSFontAttributeName : [self sk_font],
		NSForegroundColorAttributeName : _fontColor ?: [UIColor whiteColor],
	}];
}

- (void)sk_render
{
	CGFloat scale = SKDrawingScale(self);
	/* A node shrinking back (a score bouncing) keeps its sharper bitmap. */
	if (!_dirty && _renderedScale >= scale)
		return;
	_dirty = NO;
	_renderedScale = scale;
	_rendered = nil;
	_renderedRect = CGRectNull;
	NSAttributedString *string = [self sk_string];
	if (string.length == 0)
		return;
	UIFont *font = [string attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] ?: [self sk_font];
	CGSize size = [string size];
	/* Strokes and italics overhang the measured box a little. */
	CGFloat pad = ceil(font.pointSize * 0.1) + 1;
	CGSize canvas = CGSizeMake(ceil(size.width) + 2 * pad, ceil(size.height) + 2 * pad);
	_rendered = SKDrawTexture(canvas, scale, ^(CGContextRef context) {
		[string drawAtPoint:CGPointMake(pad, pad)];
	});
	/* The baseline is font.ascender below the top of the first line. */
	CGFloat x = _horizontalAlignmentMode == SKLabelHorizontalAlignmentModeLeft ? 0
		: _horizontalAlignmentMode == SKLabelHorizontalAlignmentModeRight ? -size.width : -size.width / 2;
	CGFloat top;
	switch (_verticalAlignmentMode) {
	case SKLabelVerticalAlignmentModeCenter:
		top = size.height / 2;
		break;
	case SKLabelVerticalAlignmentModeTop:
		top = 0;
		break;
	case SKLabelVerticalAlignmentModeBottom:
		top = size.height;
		break;
	default:
		top = font.ascender;
		break;
	}
	_renderedRect = CGRectMake(x - pad, top - size.height - pad, canvas.width, canvas.height);
}

- (CGRect)sk_contentRect
{
	[self sk_render];
	if (CGRectIsNull(_renderedRect))
		return CGRectNull;
	/* Without the padding. */
	CGFloat pad = ceil([[self sk_font] pointSize] * 0.1) + 1;
	return CGRectInset(_renderedRect, pad, pad);
}

- (BOOL)sk_quad:(SKQuad *)quad
{
	[self sk_render];
	if (_rendered == nil)
		return NO;
	quad->texture = _rendered;
	quad->rect = _renderedRect;
	quad->color = SKColorComponents(_color);
	quad->colorBlendFactor = _colorBlendFactor;
	quad->blendMode = _blendMode;
	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SKLabelNode> name:'%@' text:'%@' fontName:'%@' position:{%g, %g}", _name, [self text], _fontName, _position.x, _position.y];
}

@end

#pragma mark Shapes

@implementation SKShapeNode {
	CGPathRef _path;
	UIColor *_strokeColor, *_fillColor;
	SKBlendMode _blendMode;
	BOOL _antialiased;
	CGFloat _lineWidth, _glowWidth, _miterLimit;
	CGLineCap _lineCap;
	CGLineJoin _lineJoin;
	SKTexture *_fillTexture, *_strokeTexture;
	SKTexture *_rendered;
	CGRect _renderedRect;
	CGFloat _renderedScale;
	BOOL _dirty;
}

static void SKShapeSetDefaults(SKShapeNode *node)
{
	node->_strokeColor = [UIColor whiteColor];
	node->_fillColor = [UIColor clearColor];
	node->_antialiased = YES;
	node->_lineWidth = 1;
	node->_miterLimit = 10;
	node->_dirty = YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		SKShapeSetDefaults(self);
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil)
		SKShapeSetDefaults(self);
	return self;
}

- (void)dealloc
{
	CGPathRelease(_path);
}

+ (instancetype)shapeNodeWithPath:(CGPathRef)path
{
	SKShapeNode *node = [[self alloc] init];
	node.path = path;
	return node;
}

+ (instancetype)shapeNodeWithPath:(CGPathRef)path centered:(BOOL)centered
{
	if (!centered || path == NULL)
		return [self shapeNodeWithPath:path];
	CGRect box = CGPathGetBoundingBox(path);
	CGAffineTransform t = CGAffineTransformMakeTranslation(-CGRectGetMidX(box), -CGRectGetMidY(box));
	CGPathRef moved = CGPathCreateCopyByTransformingPath(path, &t);
	SKShapeNode *node = [self shapeNodeWithPath:moved];
	CGPathRelease(moved);
	return node;
}

static SKShapeNode *SKShapeWithPath(Class class, CGPathRef path)
{
	SKShapeNode *node = [class shapeNodeWithPath:path];
	CGPathRelease(path);
	return node;
}

+ (instancetype)shapeNodeWithRect:(CGRect)rect
{
	return (id)SKShapeWithPath(self, CGPathCreateWithRect(rect, NULL));
}

+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size
{
	return [self shapeNodeWithRect:CGRectMake(-size.width / 2, -size.height / 2, size.width, size.height)];
}

+ (instancetype)shapeNodeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
	CGFloat r = MIN(cornerRadius, MIN(rect.size.width, rect.size.height) / 2);
	if (r <= 0)
		return [self shapeNodeWithRect:rect];
	return (id)SKShapeWithPath(self, CGPathCreateWithRoundedRect(rect, r, r, NULL));
}

+ (instancetype)shapeNodeWithRectOfSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius
{
	return [self shapeNodeWithRect:CGRectMake(-size.width / 2, -size.height / 2, size.width, size.height) cornerRadius:cornerRadius];
}

+ (instancetype)shapeNodeWithCircleOfRadius:(CGFloat)radius
{
	return [self shapeNodeWithEllipseInRect:CGRectMake(-radius, -radius, 2 * radius, 2 * radius)];
}

+ (instancetype)shapeNodeWithEllipseInRect:(CGRect)rect
{
	return (id)SKShapeWithPath(self, CGPathCreateWithEllipseInRect(rect, NULL));
}

+ (instancetype)shapeNodeWithEllipseOfSize:(CGSize)size
{
	return [self shapeNodeWithEllipseInRect:CGRectMake(-size.width / 2, -size.height / 2, size.width, size.height)];
}

+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints
{
	CGMutablePathRef path = CGPathCreateMutable();
	if (numPoints > 0)
		CGPathAddLines(path, NULL, points, numPoints);
	return (id)SKShapeWithPath(self, path);
}

+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints
{
	return [self shapeNodeWithPoints:points count:numPoints];
}

- (CGPathRef)path { return _path; }

- (void)setPath:(CGPathRef)path
{
	CGPathRef copy = path != NULL ? CGPathCreateCopy(path) : NULL;
	CGPathRelease(_path);
	_path = copy;
	_dirty = YES;
}

#define SK_SHAPE_SETTER(type, name, setter) \
	- (type)name { return _##name; } \
	- (void)setter:(type)value { _##name = value; _dirty = YES; }

SK_SHAPE_SETTER(UIColor *, strokeColor, setStrokeColor)
SK_SHAPE_SETTER(UIColor *, fillColor, setFillColor)
SK_SHAPE_SETTER(CGFloat, lineWidth, setLineWidth)
SK_SHAPE_SETTER(CGFloat, glowWidth, setGlowWidth)
SK_SHAPE_SETTER(CGLineCap, lineCap, setLineCap)
SK_SHAPE_SETTER(CGLineJoin, lineJoin, setLineJoin)
SK_SHAPE_SETTER(CGFloat, miterLimit, setMiterLimit)
SK_SHAPE_SETTER(SKTexture *, fillTexture, setFillTexture)
SK_SHAPE_SETTER(SKTexture *, strokeTexture, setStrokeTexture)

- (SKBlendMode)blendMode { return _blendMode; }
- (void)setBlendMode:(SKBlendMode)mode { _blendMode = mode; }
- (BOOL)isAntialiased { return _antialiased; }
- (void)setAntialiased:(BOOL)antialiased { _antialiased = antialiased; _dirty = YES; }

- (CGFloat)lineLength
{
	if (_path == NULL)
		return 0;
	__block CGFloat length = 0;
	__block CGPoint last = CGPointZero, start = CGPointZero;
	SKPathApply(_path, ^(const CGPathElement *element) {
		CGPoint p = element->points != NULL ? element->points[0] : CGPointZero;
		switch (element->type) {
		case kCGPathElementMoveToPoint:
			last = start = p;
			break;
		case kCGPathElementAddLineToPoint:
			length += hypot(p.x - last.x, p.y - last.y);
			last = p;
			break;
		case kCGPathElementAddQuadCurveToPoint:
			p = element->points[1];
			length += hypot(p.x - last.x, p.y - last.y);
			last = p;
			break;
		case kCGPathElementAddCurveToPoint:
			p = element->points[2];
			length += hypot(p.x - last.x, p.y - last.y);
			last = p;
			break;
		case kCGPathElementCloseSubpath:
			length += hypot(start.x - last.x, start.y - last.y);
			last = start;
			break;
		}
	});
	return length;
}

- (void)sk_render
{
	CGFloat scale = SKDrawingScale(self);
	if (!_dirty && _renderedScale >= scale)
		return;
	_dirty = NO;
	_renderedScale = scale;
	_rendered = nil;
	_renderedRect = CGRectNull;
	if (_path == NULL || CGPathIsEmpty(_path))
		return;
	SKRGBA fill = SKColorComponents(_fillColor), stroke = SKColorComponents(_strokeColor);
	BOOL fills = fill.a > 0, strokes = stroke.a > 0 && _lineWidth > 0;
	if (!fills && !strokes)
		return;
	CGRect box = CGRectInset(CGPathGetBoundingBox(_path), -(strokes ? _lineWidth : 0) - 1, -(strokes ? _lineWidth : 0) - 1);
	box = CGRectIntegral(box);
	CGPathRef path = _path;
	UIColor *fillColor = _fillColor, *strokeColor = _strokeColor;
	CGFloat lineWidth = _lineWidth, miterLimit = _miterLimit;
	CGLineCap cap = _lineCap;
	CGLineJoin join = _lineJoin;
	BOOL antialiased = _antialiased;
	_rendered = SKDrawTexture(box.size, scale, ^(CGContextRef context) {
		/* The path is y-up, the image y-down. */
		CGContextTranslateCTM(context, -box.origin.x, box.size.height + box.origin.y);
		CGContextScaleCTM(context, 1, -1);
		CGContextSetShouldAntialias(context, antialiased);
		if (fills) {
			CGContextAddPath(context, path);
			CGContextSetFillColorWithColor(context, [fillColor CGColor]);
			CGContextFillPath(context);
		}
		if (strokes) {
			CGContextAddPath(context, path);
			CGContextSetStrokeColorWithColor(context, [strokeColor CGColor]);
			CGContextSetLineWidth(context, lineWidth);
			CGContextSetLineCap(context, cap);
			CGContextSetLineJoin(context, join);
			CGContextSetMiterLimit(context, miterLimit);
			CGContextStrokePath(context);
		}
	});
	_renderedRect = box;
}

- (CGRect)sk_contentRect
{
	if (_path == NULL)
		return CGRectNull;
	CGFloat outset = _lineWidth / 2;
	return CGRectInset(CGPathGetBoundingBox(_path), -outset, -outset);
}

- (BOOL)sk_quad:(SKQuad *)quad
{
	[self sk_render];
	if (_rendered == nil)
		return NO;
	quad->texture = _rendered;
	quad->rect = _renderedRect;
	quad->color = (SKRGBA){ 1, 1, 1, 1 };
	quad->colorBlendFactor = 0;
	quad->blendMode = _blendMode;
	return YES;
}

@end

#pragma mark Other nodes

@implementation SKCropNode {
	SKNode *_maskNode;
}
- (SKNode *)maskNode { return _maskNode; }
- (void)setMaskNode:(SKNode *)node { _maskNode = node; }
@end

@implementation SKCameraNode
- (BOOL)containsNode:(SKNode *)node
{
	return YES;
}
- (NSSet<SKNode *> *)containedNodeSet
{
	return [NSSet setWithArray:[[self scene] children] ?: @[]];
}
@end
