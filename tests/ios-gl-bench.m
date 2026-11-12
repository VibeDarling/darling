/* How fast an iOS game's OpenGL ES frames reach the screen: a full-screen
   CAEAGLLayer view, as games have, with a UILabel over it (a score), drawn
   and presented from a CADisplayLink. After a second of warming up, it
   counts frames for BENCH_SECONDS (5) and prints the frame rate and the time
   -presentRenderbuffer: took. Then it prints "ready" with where on the
   host's screen (pixels) the GL frame and the label are, for a script to
   check the host shows both, and exits on a tap. See ios-gl-bench.md. */

#import <UIKit/UIKit.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSScreen.h>
#import <QuartzCore/CAEAGLLayer.h>
#import <QuartzCore/CADisplayLink.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef unsigned int GLenum, GLuint, GLbitfield;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef unsigned char GLubyte;
typedef char GLchar;
void glGenRenderbuffers(GLsizei, GLuint *);
void glBindRenderbuffer(GLenum, GLuint);
void glGetRenderbufferParameteriv(GLenum, GLenum, GLint *);
void glGenFramebuffers(GLsizei, GLuint *);
void glBindFramebuffer(GLenum, GLuint);
void glFramebufferRenderbuffer(GLenum, GLenum, GLenum, GLuint);
void glViewport(GLint, GLint, GLsizei, GLsizei);
void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat);
void glClear(GLbitfield);
GLuint glCreateShader(GLenum);
void glShaderSource(GLuint, GLsizei, const GLchar *const *, const GLint *);
void glCompileShader(GLuint);
GLuint glCreateProgram(void);
void glAttachShader(GLuint, GLuint);
void glBindAttribLocation(GLuint, GLuint, const GLchar *);
void glLinkProgram(GLuint);
void glUseProgram(GLuint);
GLint glGetUniformLocation(GLuint, const GLchar *);
void glUniform4f(GLint, GLfloat, GLfloat, GLfloat, GLfloat);
void glVertexAttribPointer(GLuint, GLint, GLenum, unsigned char, GLsizei, const void *);
void glEnableVertexAttribArray(GLuint);
void glDrawArrays(GLenum, GLint, GLsizei);
const GLubyte *glGetString(GLenum);

#define GL_RENDERBUFFER 0x8D41
#define GL_FRAMEBUFFER 0x8D40
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_RENDERBUFFER_WIDTH 0x8D42
#define GL_RENDERBUFFER_HEIGHT 0x8D43
#define GL_COLOR_BUFFER_BIT 0x4000
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_FLOAT 0x1406
#define GL_TRIANGLE_STRIP 0x0005
#define GL_RENDERER 0x1F01

static double now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

@interface GLView : UIView
@end

@implementation GLView
+ (Class)layerClass { return [CAEAGLLayer class]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	printf("tapped\n");
	exit(0);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate {
	GLView *_view;
	UILabel *_label;
	EAGLContext *_context;
	CADisplayLink *_link;
	GLuint _colorbuffer, _framebuffer, _program;
	GLint _width, _height, _colorUniform;
	double _started, _seconds, _presenting, _slowest;
	int _frames, _counted;
}

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
	return shader;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	const char *seconds = getenv("BENCH_SECONDS");
	_seconds = seconds != NULL ? atof(seconds) : 5;
	CGRect bounds = [[UIScreen mainScreen] bounds];
	_window = [[UIWindow alloc] initWithFrame:bounds];
	UIViewController *controller = [[UIViewController alloc] init];
	[_window setRootViewController:controller];
	_view = [[GLView alloc] initWithFrame:bounds];
	[_view setOpaque:YES];
	[[controller view] addSubview:_view];
	_label = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, 200, 40)];
	[_label setBackgroundColor:[UIColor whiteColor]];
	[_label setTextColor:[UIColor blackColor]];
	[_label setText:@"Score 0"];
	[[controller view] addSubview:_label];
	[_window makeKeyAndVisible];

	CAEAGLLayer *layer = (CAEAGLLayer *)[_view layer];
	[layer setOpaque:YES];
	[layer setDrawableProperties:@{ kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
	                                kEAGLDrawablePropertyRetainedBacking: @NO }];
	_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	[EAGLContext setCurrentContext:_context];
	[_view setContentScaleFactor:[[UIScreen mainScreen] scale]];
	glGenRenderbuffers(1, &_colorbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _colorbuffer);
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
	glGenFramebuffers(1, &_framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorbuffer);

	_program = glCreateProgram();
	glAttachShader(_program, compile(GL_VERTEX_SHADER, "attribute vec2 a_position; void main() { gl_Position = vec4(a_position, 0.0, 1.0); }"));
	glAttachShader(_program, compile(GL_FRAGMENT_SHADER, "precision mediump float; uniform vec4 u_color; void main() { gl_FragColor = u_color; }"));
	glBindAttribLocation(_program, 0, "a_position");
	glLinkProgram(_program);
	_colorUniform = glGetUniformLocation(_program, "u_color");
	printf("%dx%d pixels, %s\n", _width, _height, (const char *)glGetString(GL_RENDERER));

	_started = now();
	_link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	[_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	return YES;
}

/* A frame: a background, and a green square that moves. The last frame
   leaves the square at the left, on red. */
- (void)drawFrame:(int)frame last:(BOOL)last
{
	glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
	glViewport(0, 0, _width, _height);
	if (last)
		glClearColor(1, 0, 0, 1);
	else
		glClearColor(0, 0, (frame % 60) / 60.0f, 1);
	glClear(GL_COLOR_BUFFER_BIT);
	GLfloat x = last ? -0.9f : -0.9f + (frame % 120) / 120.0f * 1.4f;
	GLfloat quad[] = { x, -0.25f, x + 0.4f, -0.25f, x, 0.25f, x + 0.4f, 0.25f };
	glUseProgram(_program);
	glUniform4f(_colorUniform, 0, 1, 0, 1);
	glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, quad);
	glEnableVertexAttribArray(0);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)tick:(CADisplayLink *)link
{
	double elapsed = now() - _started;
	BOOL counting = elapsed >= 1;
	BOOL last = elapsed >= 1 + _seconds;
	[self drawFrame:_frames++ last:last];
	double before = now();
	[_context presentRenderbuffer:GL_RENDERBUFFER];
	double took = now() - before;
	if (counting && !last) {
		_counted++;
		_presenting += took;
		if (took > _slowest)
			_slowest = took;
		if (_counted % 30 == 0)
			[_label setText:[NSString stringWithFormat:@"Score %d", _counted]];
	}
	if (!last)
		return;
	[_link invalidate];
	_link = nil;
	printf("%d frames in %.1f s: %.1f fps; presenting took %.1f ms on average, %.1f ms at most\n", _counted, _seconds,
	       _counted / _seconds, _counted ? _presenting / _counted * 1000 : 0, _slowest * 1000);
	[_label setText:@"Score"];
	CGPoint square = hostPixel(_view, CGPointMake(_view.bounds.size.width * 0.15, _view.bounds.size.height / 2));
	CGPoint red = hostPixel(_view, CGPointMake(_view.bounds.size.width * 0.8, _view.bounds.size.height * 0.8));
	CGPoint label = hostPixel(_label, CGPointMake(190, 20));
	printf("ready green %d %d red %d %d white %d %d\n", (int)square.x, (int)square.y, (int)red.x, (int)red.y,
	       (int)label.x, (int)label.y);
}

@end

int main(int argc, char *argv[])
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
