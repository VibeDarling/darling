/* OpenGL ES in an iOS app, as games use it: a UIView whose +layerClass is
   CAEAGLLayer, an EAGLContext, a renderbuffer sized to the layer, shaders,
   a blit (ES 3), a CADisplayLink, and presenting. It checks what GL reads
   back, then prints "ready" with where its colors are on the host's screen
   (pixels) for ios-opengles.sh to check there, and exits on a tap on the
   view. One PASS/FAIL line per check, nonzero exit on any failure. See
   ios-opengles.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>
#import <QuartzCore/CAEAGLLayer.h>
#import <QuartzCore/CADisplayLink.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#include <stdio.h>
#include <stdlib.h>

/* The GL this test uses, from OpenGLES.framework (this SDK has no GL headers). */
typedef unsigned int GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef unsigned char GLubyte;
typedef char GLchar;
void glGenRenderbuffers(GLsizei, GLuint *);
void glBindRenderbuffer(GLenum, GLuint);
void glRenderbufferStorage(GLenum, GLenum, GLsizei, GLsizei);
void glGetRenderbufferParameteriv(GLenum, GLenum, GLint *);
void glGenFramebuffers(GLsizei, GLuint *);
void glBindFramebuffer(GLenum, GLuint);
void glFramebufferRenderbuffer(GLenum, GLenum, GLenum, GLuint);
GLenum glCheckFramebufferStatus(GLenum);
void glViewport(GLint, GLint, GLsizei, GLsizei);
void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat);
void glClear(GLbitfield);
GLuint glCreateShader(GLenum);
void glShaderSource(GLuint, GLsizei, const GLchar *const *, const GLint *);
void glCompileShader(GLuint);
void glGetShaderiv(GLuint, GLenum, GLint *);
GLuint glCreateProgram(void);
void glAttachShader(GLuint, GLuint);
void glBindAttribLocation(GLuint, GLuint, const GLchar *);
void glLinkProgram(GLuint);
void glGetProgramiv(GLuint, GLenum, GLint *);
void glUseProgram(GLuint);
GLint glGetUniformLocation(GLuint, const GLchar *);
void glUniform4f(GLint, GLfloat, GLfloat, GLfloat, GLfloat);
void glVertexAttribPointer(GLuint, GLint, GLenum, unsigned char, GLsizei, const void *);
void glEnableVertexAttribArray(GLuint);
void glDrawArrays(GLenum, GLint, GLsizei);
void glReadPixels(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);
GLenum glGetError(void);
const GLubyte *glGetString(GLenum);
void glBlitFramebuffer(GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLbitfield, GLenum);
void glFinish(void);

#define GL_RENDERBUFFER 0x8D41
#define GL_FRAMEBUFFER 0x8D40
#define GL_READ_FRAMEBUFFER 0x8CA8
#define GL_DRAW_FRAMEBUFFER 0x8CA9
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_RENDERBUFFER_WIDTH 0x8D42
#define GL_RENDERBUFFER_HEIGHT 0x8D43
#define GL_RGBA8 0x8058
#define GL_COLOR_BUFFER_BIT 0x4000
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_FLOAT 0x1406
#define GL_TRIANGLE_STRIP 0x0005
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_NEAREST 0x2600
#define GL_RENDERER 0x1F01
#define GL_VERSION 0x1F02

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name, detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

@interface GLView : UIView
@property (nonatomic) int frames;
@end

@implementation GLView

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	printf("tapped\n");
	printf("%d failures\n", failures);
	fflush(stdout);
	exit(failures != 0);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) GLView *view;
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CADisplayLink *link;
@end

@implementation AppDelegate {
	GLuint _colorbuffer, _framebuffer, _program;
	GLint _width, _height, _colorUniform;
	NSTimeInterval _linkStarted;
}

/* A point of a view, in the host's pixels from the screen's top left. */
static CGPoint hostPixel(UIView *view, CGPoint point)
{
	NSRect frame = [view convertRect:NSMakeRect(point.x, point.y, 0, 0) toView:nil];
	NSRect onScreen = [[view window] convertRectToScreen:frame];
	CGFloat height = [[[view window] screen] frame].size.height;
	CGFloat scale = [[UIScreen mainScreen] scale];
	return CGPointMake(onScreen.origin.x * scale, (height - onScreen.origin.y) * scale);
}

static GLuint compile(GLenum type, const char *source)
{
	GLuint shader = glCreateShader(type);
	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);
	GLint ok = 0;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
	return ok ? shader : 0;
}

/* RRGGBB of a pixel of the bound framebuffer, from the bottom left as GL has it. */
static NSString *readPixel(GLint x, GLint y)
{
	GLubyte rgba[4] = { 0 };
	glReadPixels(x, y, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
	return [NSString stringWithFormat:@"%02x%02x%02x", rgba[0], rgba[1], rgba[2]];
}

- (void)drawWithColor:(const GLfloat *)clear
{
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glViewport(0, 0, _width, _height);
	glClearColor(clear[0], clear[1], clear[2], 1);
	glClear(GL_COLOR_BUFFER_BIT);
	/* The left half, green, by a shader. */
	static const GLfloat quad[] = { -1, -1, 0, -1, -1, 1, 0, 1 };
	glUseProgram(_program);
	glUniform4f(_colorUniform, 0, 1, 0, 1);
	glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, quad);
	glEnableVertexAttribArray(0);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIViewController *controller = [[UIViewController alloc] init];
	UIView *root = [controller view];
	[root setBackgroundColor:[UIColor whiteColor]];
	[_window setRootViewController:controller];
	_view = [[GLView alloc] initWithFrame:CGRectMake(20, 60, 320, 200)];
	[root addSubview:_view];
	[_window makeKeyAndVisible];

	CAEAGLLayer *layer = (CAEAGLLayer *)[_view layer];
	expect([layer isKindOfClass:[CAEAGLLayer class]] && [layer delegate] == _view,
	       "a view's layer is of its +layerClass, with the view as its delegate", NSStringFromClass([layer class]));
	[layer setDrawableProperties:@{ kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
	                                kEAGLDrawablePropertyRetainedBacking: @NO }];

	_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
	if (_context == nil)
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	expect(_context != nil && [EAGLContext setCurrentContext:_context] && [EAGLContext currentContext] == _context,
	       "an OpenGL ES context, made current",
	       [NSString stringWithFormat:@"API %lu, %s, %s", (unsigned long)[_context API],
	                                  (const char *)glGetString(GL_VERSION), (const char *)glGetString(GL_RENDERER)]);

	CGFloat scale = [[UIScreen mainScreen] scale];
	[_view setContentScaleFactor:scale];
	glGenRenderbuffers(1, &_colorbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	BOOL stored = [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
	expect(stored && _width == 320 * scale && _height == 200 * scale,
	       "the renderbuffer takes the layer's size in pixels", [NSString stringWithFormat:@"%dx%d", _width, _height]);

	glGenFramebuffers(1, &_framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorbuffer);
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	expect(status == GL_FRAMEBUFFER_COMPLETE, "a framebuffer on it is complete", [NSString stringWithFormat:@"0x%x", status]);

	GLuint vertex = compile(GL_VERTEX_SHADER, "attribute vec2 a_position; void main() { gl_Position = vec4(a_position, 0.0, 1.0); }");
	GLuint fragment = compile(GL_FRAGMENT_SHADER, "precision mediump float; uniform vec4 u_color; void main() { gl_FragColor = u_color; }");
	_program = glCreateProgram();
	glAttachShader(_program, vertex);
	glAttachShader(_program, fragment);
	glBindAttribLocation(_program, 0, "a_position");
	glLinkProgram(_program);
	GLint linked = 0;
	glGetProgramiv(_program, GL_LINK_STATUS, &linked);
	_colorUniform = glGetUniformLocation(_program, "u_color");
	expect(vertex && fragment && linked, "shaders compile and link", nil);

	static const GLfloat red[] = { 1, 0, 0 };
	[self drawWithColor:red];
	NSString *left = readPixel(_width / 4, _height / 2), *right = readPixel(_width * 3 / 4, _height / 2);
	expect([left isEqualToString:@"00ff00"] && [right isEqualToString:@"ff0000"], "clearing and drawing",
	       [NSString stringWithFormat:@"left %@, right %@", left, right]);
	expect(glGetError() == 0, "with no GL error", nil);

	/* The first frames, from a display link; then the one the host checks. */
	_linkStarted = [NSDate timeIntervalSinceReferenceDate];
	_link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	[_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	return YES;
}

- (void)tick:(CADisplayLink *)link
{
	GLfloat shade = (_view.frames % 2) ? 0.5f : 0.25f;
	GLfloat clear[] = { shade, 0, shade };
	[self drawWithColor:clear];
	if ([_context presentRenderbuffer:GL_RENDERBUFFER])
		_view.frames++;
	if ([NSDate timeIntervalSinceReferenceDate] - _linkStarted < 3)
		return;
	[_link invalidate];
	_link = nil;
	expect(_view.frames >= 5, "a display link drives presenting",
	       [NSString stringWithFormat:@"%d frames in 3 s", _view.frames]);
	[self lastFrame];
}

- (void)lastFrame
{
	static const GLfloat red[] = { 1, 0, 0 };
	[self drawWithColor:red];

	/* ES 3: a blit from a framebuffer of its own, blue, into the top right
	   corner. glBlitFramebuffer passes two of its arguments on the stack. */
	BOOL blitted = NO;
	if ([_context API] >= kEAGLRenderingAPIOpenGLES3) {
		GLuint source, sourceBuffer;
		glGenRenderbuffers(1, &sourceBuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, sourceBuffer);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, 64, 64);
		glGenFramebuffers(1, &source);
		glBindFramebuffer(GL_FRAMEBUFFER, source);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, sourceBuffer);
		glClearColor(0, 0, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
		glBindFramebuffer(GL_READ_FRAMEBUFFER, source);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _framebuffer);
		glBlitFramebuffer(0, 0, 64, 64, _width - 64, _height - 64, _width, _height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
		glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
		NSString *corner = readPixel(_width - 32, _height - 32);
		blitted = [corner isEqualToString:@"0000ff"];
		expect(blitted && glGetError() == 0, "a blit, whose last arguments are on the stack", corner);
		glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	}

	BOOL presented = [_context presentRenderbuffer:GL_RENDERBUFFER];
	id contents = [[_view layer] contents];
	expect(presented && contents != nil, "presenting makes the frame the layer's contents", nil);

	CGFloat scale = [[UIScreen mainScreen] scale];
	CGPoint green = hostPixel(_view, CGPointMake(80, 100)), red2 = hostPixel(_view, CGPointMake(240, 140));
	CGPoint blue = blitted ? hostPixel(_view, CGPointMake(320 - 16 / scale * 2, 16 / scale * 2)) : CGPointMake(-1, -1);
	CGPoint white = hostPixel(_view, CGPointMake(160, 230));
	printf("ready green %d %d red %d %d blue %d %d white %d %d\n", (int)green.x, (int)green.y, (int)red2.x, (int)red2.y,
	       (int)blue.x, (int)blue.y, (int)white.x, (int)white.y);
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
