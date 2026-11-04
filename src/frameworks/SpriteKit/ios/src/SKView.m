/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* SKView runs a scene's loop from a display link and draws it with OpenGL
   ES 2: each sprite, label and shape is a textured quad. The views share one
   context, so textures are uploaded once. */

#import "SKInternal.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAEAGLLayer.h>
#import <objc/message.h>
#include <dlfcn.h>

#pragma mark GL, as this file uses it

typedef unsigned int GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef unsigned char GLboolean;
typedef char GLchar;

#define GL_TEXTURE_2D 0x0DE1
#define GL_TEXTURE_BINDING_2D 0x8069
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_NEAREST 0x2600
#define GL_LINEAR 0x2601
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_FLOAT 0x1406
#define GL_UNPACK_ALIGNMENT 0x0CF5
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_TRIANGLES 0x0004
#ifndef GL_COLOR_BUFFER_BIT
#define GL_COLOR_BUFFER_BIT 0x4000
#endif
#define GL_BLEND 0x0BE2
#define GL_DEPTH_TEST 0x0B71
#define GL_SCISSOR_TEST 0x0C11
#define GL_ONE 1
#define GL_ZERO 0
#define GL_SRC_COLOR 0x0300
#define GL_ONE_MINUS_SRC_COLOR 0x0301
#define GL_ONE_MINUS_SRC_ALPHA 0x0303
#define GL_DST_COLOR 0x0306
#define GL_FUNC_ADD 0x8006
#define GL_FUNC_REVERSE_SUBTRACT 0x800B
#define GL_FRAMEBUFFER 0x8D40
#define GL_RENDERBUFFER 0x8D41
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_TEXTURE0 0x84C0
#define GL_ARRAY_BUFFER 0x8892

extern void glGenTextures(GLsizei, GLuint *);
extern void glDeleteTextures(GLsizei, const GLuint *);
extern void glBindTexture(GLenum, GLuint);
extern void glGetIntegerv(GLenum, GLint *);
extern void glTexParameteri(GLenum, GLenum, GLint);
extern void glTexImage2D(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *);
extern void glPixelStorei(GLenum, GLint);
extern void glActiveTexture(GLenum);
extern GLuint glCreateShader(GLenum);
extern void glShaderSource(GLuint, GLsizei, const GLchar *const *, const GLint *);
extern void glCompileShader(GLuint);
extern void glGetShaderiv(GLuint, GLenum, GLint *);
extern void glGetShaderInfoLog(GLuint, GLsizei, GLsizei *, GLchar *);
extern GLuint glCreateProgram(void);
extern void glAttachShader(GLuint, GLuint);
extern void glBindAttribLocation(GLuint, GLuint, const GLchar *);
extern void glLinkProgram(GLuint);
extern void glGetProgramiv(GLuint, GLenum, GLint *);
extern void glUseProgram(GLuint);
extern GLint glGetUniformLocation(GLuint, const GLchar *);
extern void glUniform1i(GLint, GLint);
extern void glEnableVertexAttribArray(GLuint);
extern void glVertexAttribPointer(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *);
extern void glDrawArrays(GLenum, GLint, GLsizei);
extern void glViewport(GLint, GLint, GLsizei, GLsizei);
extern void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat);
extern void glClear(GLbitfield);
extern void glEnable(GLenum);
extern void glDisable(GLenum);
extern void glBlendFunc(GLenum, GLenum);
extern void glBlendEquation(GLenum);
extern void glGenFramebuffers(GLsizei, GLuint *);
extern void glDeleteFramebuffers(GLsizei, const GLuint *);
extern void glBindFramebuffer(GLenum, GLuint);
extern void glFramebufferRenderbuffer(GLenum, GLenum, GLenum, GLuint);
extern void glGenRenderbuffers(GLsizei, GLuint *);
extern void glDeleteRenderbuffers(GLsizei, const GLuint *);
extern void glBindRenderbuffer(GLenum, GLuint);
extern GLenum glCheckFramebufferStatus(GLenum);
extern void glBindBuffer(GLenum, GLuint);
extern void glRenderbufferStorage(GLenum, GLenum, GLsizei, GLsizei);
extern void glReadPixels(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);
extern const unsigned char *glGetString(GLenum);
extern GLenum glGetError(void);
#define GL_RGBA8 0x8058
#define GL_BGRA_EXT 0x80E1
#define GL_PACK_ALIGNMENT 0x0D05
#define GL_EXTENSIONS 0x1F03

#pragma mark The shared context

static EAGLContext *sContext;

static BOOL SKGLMakeCurrent(void)
{
	if (sContext == nil) {
		sContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (sContext == nil) {
			static BOOL logged;
			if (!logged)
				NSLog(@"SpriteKit: no OpenGL ES 2 context; nothing is drawn");
			logged = YES;
			return NO;
		}
	}
	if ([EAGLContext currentContext] != sContext)
		[EAGLContext setCurrentContext:sContext];
	return YES;
}

unsigned SKGLUploadImage(CGImageRef image)
{
	if (!SKGLMakeCurrent())
		return 0;
	size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
	if (width == 0 || height == 0)
		return 0;
	uint8_t *pixels = calloc(width * height, 4);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(space);
	if (context == NULL) {
		free(pixels);
		return 0;
	}
	CGContextSetBlendMode(context, kCGBlendModeCopy);
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
	CGContextRelease(context);
	/* Uploads happen while a frame is drawn: the texture bound for the
	   batch being gathered must stay bound. */
	GLint bound = 0;
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
	GLuint name = 0;
	glGenTextures(1, &name);
	glBindTexture(GL_TEXTURE_2D, name);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
	/* Bitmap contexts' rows are top first: t = 0 is the image's top. */
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glBindTexture(GL_TEXTURE_2D, (GLuint)bound);
	free(pixels);
	return name;
}

void SKGLDeleteTexture(unsigned name)
{
	if (sContext == nil)
		return;
	void (^delete)(void) = ^{
		if (SKGLMakeCurrent())
			glDeleteTextures(1, &name);
	};
	if ([NSThread isMainThread])
		delete();
	else
		dispatch_async(dispatch_get_main_queue(), delete);
}

#pragma mark The renderer

enum { SK_ATTR_POSITION, SK_ATTR_UV, SK_ATTR_TINT, SK_ATTR_ALPHA };

/* x, y, u, v, tint (r, g, b, blend factor), alpha */
#define SK_VERTEX_FLOATS 9

static const char *const sVertexShader =
	"attribute vec2 position;\n"
	"attribute vec2 uv;\n"
	"attribute vec4 tint;\n"
	"attribute float alpha;\n"
	"varying vec2 v_uv;\n"
	"varying vec4 v_tint;\n"
	"varying float v_alpha;\n"
	"void main() {\n"
	"  v_uv = uv; v_tint = tint; v_alpha = alpha;\n"
	"  gl_Position = vec4(position, 0.0, 1.0);\n"
	"}\n";

/* As SpriteKit blends: the color replaces the texture's by the blend
   factor, keeping its alpha. Textures are premultiplied. */
static const char *const sFragmentShader =
	"precision mediump float;\n"
	"uniform sampler2D texture;\n"
	"varying vec2 v_uv;\n"
	"varying vec4 v_tint;\n"
	"varying float v_alpha;\n"
	"void main() {\n"
	"  vec4 t = texture2D(texture, v_uv);\n"
	"  vec3 rgb = mix(t.rgb, v_tint.rgb * t.a, v_tint.a);\n"
	"  gl_FragColor = vec4(rgb, t.a) * v_alpha;\n"
	"}\n";

static GLuint SKGLCompile(GLenum type, const char *source)
{
	GLuint shader = glCreateShader(type);
	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);
	GLint ok = 0;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
	if (!ok) {
		char log[512] = "";
		glGetShaderInfoLog(shader, sizeof(log), NULL, log);
		NSLog(@"SpriteKit: shader: %s", log);
	}
	return shader;
}

static GLuint sProgram, sWhite;

static BOOL SKGLPrepare(void)
{
	if (sProgram != 0)
		return YES;
	GLuint program = glCreateProgram();
	glAttachShader(program, SKGLCompile(GL_VERTEX_SHADER, sVertexShader));
	glAttachShader(program, SKGLCompile(GL_FRAGMENT_SHADER, sFragmentShader));
	glBindAttribLocation(program, SK_ATTR_POSITION, "position");
	glBindAttribLocation(program, SK_ATTR_UV, "uv");
	glBindAttribLocation(program, SK_ATTR_TINT, "tint");
	glBindAttribLocation(program, SK_ATTR_ALPHA, "alpha");
	glLinkProgram(program);
	GLint ok = 0;
	glGetProgramiv(program, GL_LINK_STATUS, &ok);
	if (!ok) {
		NSLog(@"SpriteKit: cannot link the sprite program");
		return NO;
	}
	glUseProgram(program);
	glUniform1i(glGetUniformLocation(program, "texture"), 0);
	static const uint8_t white[4] = { 255, 255, 255, 255 };
	glGenTextures(1, &sWhite);
	glBindTexture(GL_TEXTURE_2D, sWhite);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, white);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	sProgram = program;
	return YES;
}

typedef struct {
	SKNode *__unsafe_unretained node;
	SKQuad quad;
	CGAffineTransform transform; /* node to the view's points */
	CGFloat alpha, z;
	NSUInteger order;
} SKDrawItem;

static int SKCompareItems(const void *a, const void *b)
{
	const SKDrawItem *x = a, *y = b;
	if (x->z != y->z)
		return x->z < y->z ? -1 : 1;
	return x->order < y->order ? -1 : x->order > y->order;
}

typedef struct {
	SKDrawItem *items;
	size_t count, capacity;
	NSUInteger nodes;
} SKDrawList;

static void SKCollect(SKNode *node, CGAffineTransform parent, CGFloat alpha, CGFloat z, SKDrawList *list, BOOL root)
{
	if (node->_hidden)
		return;
	CGAffineTransform t = root ? parent : CGAffineTransformConcat([node sk_localTransform], parent);
	alpha *= root ? 1 : node->_alpha;
	if (alpha <= 0)
		return;
	if (!root)
		z += node->_zPosition;
	list->nodes++;
	SKQuad quad;
	memset(&quad, 0, sizeof(quad));
	if (!root && [node sk_quad:&quad]) {
		if (list->count == list->capacity) {
			list->capacity = list->capacity ? list->capacity * 2 : 64;
			list->items = realloc(list->items, list->capacity * sizeof(SKDrawItem));
		}
		list->items[list->count] = (SKDrawItem){ node, quad, t, alpha, z, list->count };
		list->count++;
	}
	for (SKNode *child in node->_children)
		SKCollect(child, t, alpha, z, list, NO);
}

static void SKSetBlend(SKBlendMode mode)
{
	glBlendEquation(mode == SKBlendModeSubtract ? GL_FUNC_REVERSE_SUBTRACT : GL_FUNC_ADD);
	switch (mode) {
	case SKBlendModeAdd:
	case SKBlendModeSubtract:
		glBlendFunc(GL_ONE, GL_ONE);
		break;
	case SKBlendModeMultiply:
	case SKBlendModeMultiplyAlpha:
		glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
		break;
	case SKBlendModeMultiplyX2:
		glBlendFunc(GL_DST_COLOR, GL_SRC_COLOR);
		break;
	case SKBlendModeScreen:
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);
		break;
	case SKBlendModeReplace:
		glBlendFunc(GL_ONE, GL_ZERO);
		break;
	default:
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		break;
	}
}

#pragma mark Presenting into the window

/*
 * EAGL's way to show a frame (read it back, make it the layer's contents,
 * have AppKit draw the view, flush the window) copies the whole frame three
 * times on the CPU. When nothing of UIKit's covers the view, SKView instead
 * reads the frame straight into the window's own pixels and flushes. And on
 * a dense screen it draws at half the screen's scale, doubling the pixels as
 * it copies them in: reading a frame back from the GPU costs by its size.
 */
typedef struct {
	uint8_t *pixels; /* the window's, BGRA, premultiplied */
	size_t stride;
	int x, y, width, height; /* the view, in them */
	id window, platform;
} SKWindowPixels;

/* Onyx2D, the window's drawing, is CoreGraphics here: its own calls. */
static struct {
	void *(*pixelBytes)(id);
	size_t (*width)(id), (*height)(id), (*bytesPerRow)(id), (*bitsPerPixel)(id);
	uint32_t (*bitmapInfo)(id);
	BOOL ready;
} sOnyx;

static BOOL SKOnyxLoad(void)
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sOnyx.pixelBytes = dlsym(RTLD_DEFAULT, "O2SurfaceGetPixelBytes");
		sOnyx.width = dlsym(RTLD_DEFAULT, "O2ImageGetWidth");
		sOnyx.height = dlsym(RTLD_DEFAULT, "O2ImageGetHeight");
		sOnyx.bytesPerRow = dlsym(RTLD_DEFAULT, "O2ImageGetBytesPerRow");
		sOnyx.bitsPerPixel = dlsym(RTLD_DEFAULT, "O2ImageGetBitsPerPixel");
		sOnyx.bitmapInfo = dlsym(RTLD_DEFAULT, "O2ImageGetBitmapInfo");
		sOnyx.ready = sOnyx.pixelBytes && sOnyx.width && sOnyx.height && sOnyx.bytesPerRow && sOnyx.bitsPerPixel && sOnyx.bitmapInfo;
	});
	return sOnyx.ready;
}

static id SKSend(id target, const char *selector)
{
	SEL sel = sel_registerName(selector);
	return target != nil && [target respondsToSelector:sel] ? ((id (*)(id, SEL))objc_msgSend)(target, sel) : nil;
}

/* Whether a view of UIKit's shows over the view: then it is drawn as usual. */
static BOOL SKViewIsCovered(UIView *view)
{
	for (NSView *subview in [(NSView *)view subviews])
		if (![subview isHidden])
			return YES;
	NSView *child = (NSView *)view;
	NSRect rect = [child bounds];
	for (NSView *parent = [child superview]; parent != nil; child = parent, parent = [parent superview]) {
		NSArray *siblings = [parent subviews];
		NSUInteger index = [siblings indexOfObjectIdenticalTo:child];
		NSRect inParent = [child convertRect:rect toView:parent];
		for (NSUInteger i = index + 1; index != NSNotFound && i < siblings.count; i++) {
			NSView *sibling = siblings[i];
			if (![sibling isHidden] && NSIntersectsRect([sibling frame], inParent))
				return YES;
		}
		rect = inParent;
	}
	return NO;
}

static BOOL SKWindowPixelsFor(UIView *view, SKWindowPixels *out)
{
	if (!SKOnyxLoad() || SKViewIsCovered(view))
		return NO;
	id window = SKSend(view, "window");
	id platform = SKSend(window, "platformWindow");
	/* Waits, too, for the last frame to be copied out of the surface. */
	id context = SKSend(platform, "cgContext");
	id surface = SKSend(context, "surface");
	if (surface == nil)
		return NO;
	uint32_t info = sOnyx.bitmapInfo(surface), alpha = info & 0x1F;
	/* 32-bit little-endian, alpha first (premultiplied or skipped): BGRA. */
	if (sOnyx.bitsPerPixel(surface) != 32 || (info & 0x7000) != 0x2000 || (alpha != 2 && alpha != 6))
		return NO;
	NSView *content = SKSend(window, "contentView");
	if (content == nil)
		return NO;
	size_t width = sOnyx.width(surface), height = sOnyx.height(surface);
	NSRect windowBounds = [content bounds];
	if (windowBounds.size.width <= 0 || windowBounds.size.height <= 0)
		return NO;
	CGFloat sx = width / windowBounds.size.width, sy = height / windowBounds.size.height;
	/* In window coordinates, from the bottom; the surface's rows go from the top. */
	NSRect r = [(NSView *)view convertRect:[(NSView *)view bounds] toView:nil];
	int x = (int)lround(r.origin.x * sx), y = (int)lround((windowBounds.size.height - NSMaxY(r)) * sy);
	int w = (int)lround(r.size.width * sx), h = (int)lround(r.size.height * sy);
	if (x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > (int)width || y + h > (int)height)
		return NO;
	uint8_t *pixels = sOnyx.pixelBytes(surface);
	if (pixels == NULL)
		return NO;
	*out = (SKWindowPixels){ pixels, sOnyx.bytesPerRow(surface), x, y, w, h, window, platform };
	return YES;
}

#pragma mark SKView

@implementation SKView {
	/* For drawing into the window (SKWindowPixelsFor). */
	GLuint _directFramebuffer, _directRenderbuffer;
	CGSize _directSize;
	uint32_t *_readback;
	size_t _readbackSize;
	SKScene *_scene;
	CADisplayLink *_link;
	GLuint _framebuffer, _renderbuffer;
	CGSize _pixelSize;
	BOOL _paused, _showsFPS, _showsDrawCount, _showsNodeCount, _showsQuadCount, _showsPhysics, _showsFields;
	BOOL _asynchronous, _allowsTransparency, _ignoresSiblingOrder, _shouldCullNonVisibleNodes, _disableDepthStencilBuffer;
	NSInteger _preferredFramesPerSecond;
	__weak NSObject<SKViewDelegate> *_delegate;
	/* Touches to the nodes they began on. */
	NSMapTable *_touchNodes;
	GLfloat *_vertices;
	size_t _vertexCapacity;
	/* For showsFPS. */
	NSTimeInterval _fpsSince;
	NSUInteger _fpsFrames;
}

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (void)sk_setUp
{
	_preferredFramesPerSecond = 60;
	_asynchronous = YES;
	_shouldCullNonVisibleNodes = YES;
	_touchNodes = [NSMapTable strongToStrongObjectsMapTable];
	[self setMultipleTouchEnabled:YES];
	/* An opaque view's frame is all that is drawn when it presents one. */
	[self setOpaque:YES];
	CALayer *layer = [self layer];
	[layer setOpaque:YES];
	if ([layer respondsToSelector:@selector(setDrawableProperties:)])
		[(CAEAGLLayer *)layer setDrawableProperties:@{ kEAGLDrawablePropertyRetainedBacking : @NO, kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8 }];
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
		[self sk_setUp];
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil)
		[self sk_setUp];
	return self;
}

- (void)dealloc
{
	[_link invalidate];
	free(_vertices);
	free(_readback);
	if (_directFramebuffer != 0 && SKGLMakeCurrent()) {
		glDeleteFramebuffers(1, &_directFramebuffer);
		glDeleteRenderbuffers(1, &_directRenderbuffer);
	}
	if ((_framebuffer != 0 || _renderbuffer != 0) && SKGLMakeCurrent()) {
		glDeleteFramebuffers(1, &_framebuffer);
		glDeleteRenderbuffers(1, &_renderbuffer);
	}
}

#pragma mark Properties

- (BOOL)isPaused { return _paused; }
- (void)setPaused:(BOOL)paused { _paused = paused; }
- (BOOL)showsFPS { return _showsFPS; }
- (void)setShowsFPS:(BOOL)value { _showsFPS = value; }
- (BOOL)showsDrawCount { return _showsDrawCount; }
- (void)setShowsDrawCount:(BOOL)value { _showsDrawCount = value; }
- (BOOL)showsNodeCount { return _showsNodeCount; }
- (void)setShowsNodeCount:(BOOL)value { _showsNodeCount = value; }
- (BOOL)showsQuadCount { return _showsQuadCount; }
- (void)setShowsQuadCount:(BOOL)value { _showsQuadCount = value; }
- (BOOL)showsPhysics { return _showsPhysics; }
- (void)setShowsPhysics:(BOOL)value { _showsPhysics = value; }
- (BOOL)showsFields { return _showsFields; }
- (void)setShowsFields:(BOOL)value { _showsFields = value; }
- (BOOL)isAsynchronous { return _asynchronous; }
- (void)setAsynchronous:(BOOL)value { _asynchronous = value; }
- (BOOL)ignoresSiblingOrder { return _ignoresSiblingOrder; }
- (void)setIgnoresSiblingOrder:(BOOL)value { _ignoresSiblingOrder = value; }
- (BOOL)shouldCullNonVisibleNodes { return _shouldCullNonVisibleNodes; }
- (void)setShouldCullNonVisibleNodes:(BOOL)value { _shouldCullNonVisibleNodes = value; }
- (BOOL)disableDepthStencilBuffer { return _disableDepthStencilBuffer; }
- (void)setDisableDepthStencilBuffer:(BOOL)value { _disableDepthStencilBuffer = value; }
- (NSObject<SKViewDelegate> *)delegate { return _delegate; }
- (void)setDelegate:(NSObject<SKViewDelegate> *)delegate { _delegate = delegate; }
- (SKScene *)scene { return _scene; }

- (BOOL)allowsTransparency { return _allowsTransparency; }

- (void)setAllowsTransparency:(BOOL)value
{
	_allowsTransparency = value;
	[self setOpaque:!value];
	[[self layer] setOpaque:!value];
}

- (NSInteger)preferredFramesPerSecond { return _preferredFramesPerSecond; }

- (void)setPreferredFramesPerSecond:(NSInteger)fps
{
	_preferredFramesPerSecond = fps > 0 ? fps : 60;
	[_link setPreferredFramesPerSecond:_preferredFramesPerSecond];
}

- (NSInteger)frameInterval { return MAX(1, 60 / MAX(_preferredFramesPerSecond, 1)); }
- (void)setFrameInterval:(NSInteger)interval { [self setPreferredFramesPerSecond:60 / MAX(interval, 1)]; }
- (float)preferredFrameRate { return _preferredFramesPerSecond; }
- (void)setPreferredFrameRate:(float)rate { [self setPreferredFramesPerSecond:(NSInteger)rate]; }

#pragma mark Scenes

- (void)presentScene:(SKScene *)scene
{
	if (scene == _scene)
		return;
	SKScene *old = _scene;
	_scene = scene;
	[old sk_setView:nil];
	[_touchNodes removeAllObjects];
	if (scene != nil) {
		[scene sk_setView:self];
		[self sk_startLink];
	}
	[self sk_drawFrame];
}

- (void)presentScene:(SKScene *)scene transition:(SKTransition *)transition
{
	[self presentScene:scene];
}

- (CGPoint)convertPoint:(CGPoint)point toScene:(SKScene *)scene
{
	return [scene convertPointFromView:point];
}

- (CGPoint)convertPoint:(CGPoint)point fromScene:(SKScene *)scene
{
	return [scene convertPointToView:point];
}

- (SKTexture *)textureFromNode:(SKNode *)node
{
	return [self textureFromNode:node crop:[node calculateAccumulatedFrame]];
}

- (SKTexture *)textureFromNode:(SKNode *)node crop:(CGRect)crop
{
	return nil;
}

#pragma mark The loop

- (void)didMoveToWindow
{
	[super didMoveToWindow];
	if ([self window] != nil)
		[self sk_startLink];
	else {
		[_link invalidate];
		_link = nil;
	}
}

- (void)sk_startLink
{
	if (_link != nil || [self window] == nil || _scene == nil)
		return;
	_link = [CADisplayLink displayLinkWithTarget:self selector:@selector(sk_tick:)];
	[_link setPreferredFramesPerSecond:_preferredFramesPerSecond];
	[_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	if (_scene != nil && [_scene scaleMode] == SKSceneScaleModeResizeFill)
		[_scene setSize:[self bounds].size];
}

- (void)sk_tick:(CADisplayLink *)link
{
	if ([self window] == nil || [self isHidden])
		return;
	NSTimeInterval now = CACurrentMediaTime();
	NSObject<SKViewDelegate> *delegate = _delegate;
	if ([delegate respondsToSelector:@selector(view:shouldRenderAtTime:)] && ![delegate view:self shouldRenderAtTime:now])
		return;
	if (_paused)
		return;
	SKScene *scene = _scene;
	[scene sk_frame:now];
	[self sk_drawFrame];
	if (_showsFPS) {
		_fpsFrames++;
		if (_fpsSince == 0)
			_fpsSince = now;
		if (now - _fpsSince >= 5) {
			NSLog(@"SpriteKit: %.1f fps", _fpsFrames / (now - _fpsSince));
			_fpsFrames = 0;
			_fpsSince = now;
		}
	}
}

- (BOOL)sk_prepareFramebuffer
{
	CGFloat scale = [self contentScaleFactor];
	CGSize size = [self bounds].size;
	CGSize pixels = CGSizeMake(floor(size.width * scale), floor(size.height * scale));
	if (pixels.width < 1 || pixels.height < 1)
		return NO;
	if (_framebuffer == 0) {
		glGenFramebuffers(1, &_framebuffer);
		glGenRenderbuffers(1, &_renderbuffer);
	}
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
	if (!CGSizeEqualToSize(pixels, _pixelSize)) {
		if (![sContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)[self layer]])
			return NO;
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
			NSLog(@"SpriteKit: incomplete framebuffer for %gx%g", pixels.width, pixels.height);
			return NO;
		}
		_pixelSize = pixels;
	}
	return YES;
}

/* A framebuffer of its own, of the size the frame is drawn at. */
- (BOOL)sk_prepareDirectFramebuffer:(CGSize)size
{
	if (_directFramebuffer == 0) {
		glGenFramebuffers(1, &_directFramebuffer);
		glGenRenderbuffers(1, &_directRenderbuffer);
	}
	glBindFramebuffer(GL_FRAMEBUFFER, _directFramebuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _directRenderbuffer);
	if (!CGSizeEqualToSize(size, _directSize)) {
		glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, (GLsizei)size.width, (GLsizei)size.height);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _directRenderbuffer);
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
			_directSize = CGSizeZero;
			return NO;
		}
		_directSize = size;
	}
	return YES;
}

/* Reads the frame (drawn upside down, so its rows come back top first) into
   the window, each pixel factor times over. */
- (void)sk_present:(const SKWindowPixels *)target factor:(int)factor
{
	static int bgra = -1;
	if (bgra < 0) {
		const char *extensions = (const char *)glGetString(GL_EXTENSIONS);
		bgra = extensions != NULL && strstr(extensions, "GL_EXT_read_format_bgra") != NULL;
	}
	int w = (int)_directSize.width, h = (int)_directSize.height;
	size_t size = (size_t)w * h * 4;
	if (size > _readbackSize) {
		free(_readback);
		_readback = malloc(size);
		_readbackSize = size;
	}
	glPixelStorei(GL_PACK_ALIGNMENT, 4);
	BOOL swap = !bgra;
	if (bgra) {
		while (glGetError() != 0)
			;
		glReadPixels(0, 0, w, h, GL_BGRA_EXT, GL_UNSIGNED_BYTE, _readback);
		if (glGetError() != 0) {
			bgra = 0;
			swap = YES;
		}
	}
	if (swap)
		glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, _readback);

	for (int row = 0; row < target->height; row++) {
		uint32_t *to = (uint32_t *)(target->pixels + (size_t)(target->y + row) * target->stride) + target->x;
		/* A row that repeats the one above: copy it. */
		if (row % factor != 0) {
			memcpy(to, (uint8_t *)to - target->stride, (size_t)target->width * 4);
			continue;
		}
		const uint32_t *from = _readback + (size_t)MIN(row / factor, h - 1) * w;
		int count = MIN(target->width, w * factor);
		if (factor == 1 && !swap)
			memcpy(to, from, (size_t)count * 4);
		else if (factor == 2 && !swap) {
			int i = 0;
			for (; i + 1 < count; i += 2) {
				uint32_t p = from[i >> 1];
				to[i] = p;
				to[i + 1] = p;
			}
			if (i < count)
				to[i] = from[i >> 1];
		} else if (!swap)
			for (int i = 0; i < count; i++)
				to[i] = from[i / factor];
		else
			for (int i = 0; i < count; i++) {
				uint32_t p = from[i / factor];
				to[i] = (p & 0xFF00FF00) | ((p & 0xFF) << 16) | ((p >> 16) & 0xFF);
			}
	}
	/* The Pocket backend's copies the frame out while the next is made. */
	SEL async = sel_registerName("flushBufferAsync");
	if ([target->platform respondsToSelector:async])
		((void (*)(id, SEL))objc_msgSend)(target->platform, async);
	else
		((void (*)(id, SEL))objc_msgSend)(target->window, @selector(flushWindow));
}

- (void)sk_drawFrame
{
	SKScene *scene = _scene;
	if (scene == nil || [self window] == nil || !SKGLMakeCurrent() || !SKGLPrepare())
		return;
	SKWindowPixels target;
	BOOL direct = !_allowsTransparency && SKWindowPixelsFor(self, &target);
	/* Half the scale of a 3x screen: a quarter of the pixels to read back. */
	int factor = direct && [self contentScaleFactor] >= 2.5 ? 2 : 1;
	if (direct && ![self sk_prepareDirectFramebuffer:CGSizeMake((target.width + factor - 1) / factor, (target.height + factor - 1) / factor)])
		direct = NO;
	if (!direct && ![self sk_prepareFramebuffer])
		return;
	CGSize drawn = direct ? _directSize : _pixelSize;
	glViewport(0, 0, (GLsizei)drawn.width, (GLsizei)drawn.height);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);
	SKRGBA background = SKColorComponents([scene backgroundColor]);
	if (_allowsTransparency)
		glClearColor(background.r * background.a, background.g * background.a, background.b * background.a, background.a);
	else
		glClearColor(background.r, background.g, background.b, 1);
	glClear(GL_COLOR_BUFFER_BIT);

	SKDrawList list = { 0 };
	CGAffineTransform sceneToView = [scene sk_sceneToView];
	SKCameraNode *camera = [scene camera];
	if (camera != nil && [camera scene] == scene) {
		/* The camera's position is the view's center; its scale and rotation apply to the scene. */
		CGAffineTransform cameraTransform = [camera sk_sceneTransform];
		CGAffineTransform view = CGAffineTransformInvert(cameraTransform);
		CGPoint center = CGPointMake(-[scene anchorPoint].x * [scene size].width + [scene size].width / 2,
			-[scene anchorPoint].y * [scene size].height + [scene size].height / 2);
		view = CGAffineTransformConcat(view, CGAffineTransformMakeTranslation(center.x, center.y));
		sceneToView = CGAffineTransformConcat(view, sceneToView);
	}
	SKCollect(scene, sceneToView, 1, 0, &list, YES);
	if (list.count > 1)
		mergesort(list.items, list.count, sizeof(SKDrawItem), SKCompareItems);

	glUseProgram(sProgram);
	glActiveTexture(GL_TEXTURE0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glEnable(GL_BLEND);
	size_t needed = list.count * 6 * SK_VERTEX_FLOATS;
	if (needed > _vertexCapacity) {
		_vertexCapacity = needed;
		_vertices = realloc(_vertices, _vertexCapacity * sizeof(GLfloat));
	}
	GLfloat *v = _vertices;
	glEnableVertexAttribArray(SK_ATTR_POSITION);
	glEnableVertexAttribArray(SK_ATTR_UV);
	glEnableVertexAttribArray(SK_ATTR_TINT);
	glEnableVertexAttribArray(SK_ATTR_ALPHA);
	glVertexAttribPointer(SK_ATTR_POSITION, 2, GL_FLOAT, 0, SK_VERTEX_FLOATS * sizeof(GLfloat), v);
	glVertexAttribPointer(SK_ATTR_UV, 2, GL_FLOAT, 0, SK_VERTEX_FLOATS * sizeof(GLfloat), v + 2);
	glVertexAttribPointer(SK_ATTR_TINT, 4, GL_FLOAT, 0, SK_VERTEX_FLOATS * sizeof(GLfloat), v + 4);
	glVertexAttribPointer(SK_ATTR_ALPHA, 1, GL_FLOAT, 0, SK_VERTEX_FLOATS * sizeof(GLfloat), v + 8);

	CGSize bounds = [self bounds].size;
	/* View points to GL's -1...1; drawn into the window, upside down. */
	GLfloat sx = 2 / bounds.width, sy = (direct ? 2 : -2) / bounds.height, oy = direct ? -1 : 1;
	/* Quads are batched while the texture, its filtering and the blend stay. */
	GLuint batchTexture = 0;
	SKTextureFilteringMode batchFilter = -1;
	SKBlendMode batchBlend = -1;
	size_t batchStart = 0, n = 0;
	for (size_t i = 0; i < list.count; i++) {
		SKDrawItem *item = &list.items[i];
		SKQuad *q = &item->quad;
		GLuint texture = q->texture != nil ? [q->texture sk_glTexture] : 0;
		if (q->texture != nil && texture == 0)
			continue;
		if (texture == 0)
			texture = sWhite;
		SKTextureFilteringMode filter = q->texture != nil ? [q->texture filteringMode] : SKTextureFilteringNearest;
		if (texture != batchTexture || filter != batchFilter || q->blendMode != batchBlend) {
			if (n > batchStart)
				glDrawArrays(GL_TRIANGLES, (GLint)batchStart, (GLsizei)(n - batchStart));
			batchStart = n;
			glBindTexture(GL_TEXTURE_2D, texture);
			GLint f = filter == SKTextureFilteringNearest ? GL_NEAREST : GL_LINEAR;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, f);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, f);
			if (q->blendMode != batchBlend)
				SKSetBlend(q->blendMode);
			batchTexture = texture;
			batchFilter = filter;
			batchBlend = q->blendMode;
		}
		CGRect r = q->rect;
		CGRect uv = q->texture != nil ? [q->texture sk_rect] : CGRectMake(0, 0, 1, 1);
		CGPoint corners[4] = {
			{ CGRectGetMinX(r), CGRectGetMinY(r) }, { CGRectGetMaxX(r), CGRectGetMinY(r) },
			{ CGRectGetMinX(r), CGRectGetMaxY(r) }, { CGRectGetMaxX(r), CGRectGetMaxY(r) },
		};
		/* Texture rectangles are bottom-up; the texture's rows top-down. */
		GLfloat u0 = uv.origin.x, u1 = uv.origin.x + uv.size.width;
		GLfloat vBottom = 1 - uv.origin.y, vTop = 1 - (uv.origin.y + uv.size.height);
		GLfloat uvs[4][2] = { { u0, vBottom }, { u1, vBottom }, { u0, vTop }, { u1, vTop } };
		GLfloat alpha = item->alpha * (q->texture == nil ? q->color.a : 1);
		static const int order[6] = { 0, 1, 2, 2, 1, 3 };
		for (int k = 0; k < 6; k++) {
			CGPoint p = CGPointApplyAffineTransform(corners[order[k]], item->transform);
			GLfloat *out = v + n * SK_VERTEX_FLOATS;
			out[0] = p.x * sx - 1;
			out[1] = p.y * sy + oy;
			out[2] = uvs[order[k]][0];
			out[3] = uvs[order[k]][1];
			out[4] = q->color.r;
			out[5] = q->color.g;
			out[6] = q->color.b;
			out[7] = q->colorBlendFactor;
			out[8] = alpha;
			n++;
		}
	}
	if (n > batchStart)
		glDrawArrays(GL_TRIANGLES, (GLint)batchStart, (GLsizei)(n - batchStart));
	free(list.items);
	if (direct) {
		[self sk_present:&target factor:factor];
		return;
	}
	glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
	[sContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark Touches

/* The front-most node under the touch that takes touches, or the scene. */
- (SKNode *)sk_nodeForTouch:(UITouch *)touch
{
	SKScene *scene = _scene;
	CGPoint p = [scene convertPointFromView:[touch locationInView:self]];
	for (SKNode *hit in [scene nodesAtPoint:p])
		for (SKNode *node = hit; node != nil && node != scene; node = node->_parent)
			if (node->_userInteractionEnabled && !node->_hidden)
				return node;
	return scene;
}

typedef void (*SKTouchMethod)(id, SEL, NSSet *, UIEvent *);

- (void)sk_deliver:(NSSet<UITouch *> *)touches event:(UIEvent *)event selector:(SEL)selector began:(BOOL)began ended:(BOOL)ended
{
	if (_scene == nil)
		return;
	NSMapTable *groups = [NSMapTable strongToStrongObjectsMapTable];
	for (UITouch *touch in touches) {
		SKNode *node = began ? [self sk_nodeForTouch:touch] : [_touchNodes objectForKey:touch];
		if (node == nil)
			node = _scene;
		if (began)
			[_touchNodes setObject:node forKey:touch];
		if (ended)
			[_touchNodes removeObjectForKey:touch];
		NSMutableSet *set = [groups objectForKey:node];
		if (set == nil) {
			set = [NSMutableSet set];
			[groups setObject:set forKey:node];
		}
		[set addObject:touch];
	}
	for (SKNode *node in [[groups keyEnumerator] allObjects])
		((SKTouchMethod)[node methodForSelector:selector])(node, selector, [groups objectForKey:node], event);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[self sk_deliver:touches event:event selector:@selector(touchesBegan:withEvent:) began:YES ended:NO];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[self sk_deliver:touches event:event selector:@selector(touchesMoved:withEvent:) began:NO ended:NO];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[self sk_deliver:touches event:event selector:@selector(touchesEnded:withEvent:) began:NO ended:YES];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	[self sk_deliver:touches event:event selector:@selector(touchesCancelled:withEvent:) began:NO ended:YES];
}

@end
