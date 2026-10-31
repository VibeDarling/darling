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

/* Terminal: a shell on a pseudo-terminal, in a UIKit app. It is the
   terminal Darling's iOS runtime ships in /Applications, so on a phone
   (Darling Pocket) it is what people get to type commands into.

   The pieces: TerminalSession runs the shell on a pty and reads its output
   on a thread of its own; TerminalScreen (TerminalScreen.m) interprets that
   output into a grid of cells; TerminalView (TerminalView.m) draws the grid
   and turns typing into bytes for the pty. Output is handed to the main
   thread in batches, so a fast program costs one redraw per batch rather
   than one per byte. See README.md for what is supported and how to test. */

#import <UIKit/UIKit.h>
#import "TerminalView.h"
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <util.h>

/* Output read ahead of the main thread is capped; past it the reader waits,
   which in turn makes the program writing wait. */
static const NSUInteger TerminalMaximumPending = 1 << 20;
/* The extra-keys bar under the terminal. */
static const CGFloat TerminalKeyBarHeight = 40;

static void TerminalLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	fprintf(stderr, "Terminal: %s\n", [line UTF8String]);
}

#pragma mark - The session

/* A shell on a pty: $SHELL, else bash, else sh, as a login shell in $HOME. */
@interface TerminalSession : NSObject
/* Called on the main thread with the shell's output, and once when it ends. */
@property (nonatomic, copy) void (^output)(NSData *data);
@property (nonatomic, copy) void (^exited)(int status);
- (BOOL)startWithColumns:(int)columns rows:(int)rows;
- (void)writeData:(NSData *)data;
- (void)resizeToColumns:(int)columns rows:(int)rows;
@end

@implementation TerminalSession {
	int _master;
	pid_t _child;
	pthread_t _reader;
	pthread_mutex_t _lock;
	pthread_cond_t _drained;
	NSMutableData *_pending;
	BOOL _drainScheduled;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_master = -1;
		pthread_mutex_init(&_lock, NULL);
		pthread_cond_init(&_drained, NULL);
		_pending = [NSMutableData data];
	}
	return self;
}

+ (NSString *)shellPath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *shell = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHELL"];
	if ([shell length] > 0 && [fm isExecutableFileAtPath:shell])
		return shell;
	if ([fm isExecutableFileAtPath:@"/bin/bash"])
		return @"/bin/bash";
	return @"/bin/sh";
}

/* A NULL-terminated array of C strings, for after fork(), where nothing
   may be allocated. Leaked in the child, freed in the parent. */
static char **TerminalCStrings(NSArray<NSString *> *strings)
{
	char **array = calloc([strings count] + 1, sizeof(char *));
	for (NSUInteger i = 0; i < [strings count]; i++)
		array[i] = strdup([strings[i] UTF8String]);
	return array;
}

static void TerminalFreeCStrings(char **array)
{
	for (char **p = array; *p != NULL; p++)
		free(*p);
	free(array);
}

- (NSArray<NSString *> *)environmentForShell:(NSString *)shell
{
	NSMutableDictionary<NSString *, NSString *> *environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
	environment[@"TERM"] = @"xterm-256color";
	environment[@"COLORTERM"] = @"truecolor";
	environment[@"TERM_PROGRAM"] = @"Darling_Terminal";
	environment[@"SHELL"] = shell;
	environment[@"HOME"] = NSHomeDirectory();
	if ([environment[@"PATH"] length] == 0)
		environment[@"PATH"] = @"/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
	if ([environment[@"LANG"] length] == 0 && [environment[@"LC_ALL"] length] == 0)
		environment[@"LANG"] = @"en_US.UTF-8";
	/* The grid's size is the pty's; stale values would override it. */
	[environment removeObjectForKey:@"COLUMNS"];
	[environment removeObjectForKey:@"LINES"];
	NSMutableArray<NSString *> *list = [NSMutableArray array];
	for (NSString *key in environment)
		[list addObject:[NSString stringWithFormat:@"%@=%@", key, environment[key]]];
	return list;
}

- (BOOL)startWithColumns:(int)columns rows:(int)rows
{
	NSString *shell = [[self class] shellPath];
	/* A leading dash makes it a login shell. */
	NSString *argv0 = [@"-" stringByAppendingString:[shell lastPathComponent]];
	char **argv = TerminalCStrings(@[ argv0 ]);
	char **envp = TerminalCStrings([self environmentForShell:shell]);
	char *path = strdup([shell fileSystemRepresentation]);
	char *home = strdup([NSHomeDirectory() fileSystemRepresentation]);

	struct winsize size = { (unsigned short)rows, (unsigned short)columns, 0, 0 };
	int master = -1;
	pid_t child = forkpty(&master, NULL, NULL, &size);
	if (child == 0) {
		/* The child: only async-signal-safe calls from here to exec. */
		struct sigaction action;
		memset(&action, 0, sizeof(action));
		action.sa_handler = SIG_DFL;
		static const int reset[] = { SIGPIPE, SIGINT, SIGQUIT, SIGTERM, SIGHUP, SIGCHLD, SIGTSTP, SIGTTIN, SIGTTOU, SIGWINCH };
		for (size_t i = 0; i < sizeof(reset) / sizeof(*reset); i++)
			sigaction(reset[i], &action, NULL);
		sigset_t none;
		sigemptyset(&none);
		sigprocmask(SIG_SETMASK, &none, NULL);
		if (chdir(home) != 0)
			chdir("/");
		execve(path, argv, envp);
		char *fallback[] = { "-sh", NULL };
		execve("/bin/sh", fallback, envp);
		_exit(127);
	}
	TerminalFreeCStrings(argv);
	TerminalFreeCStrings(envp);
	free(path);
	free(home);
	if (child < 0) {
		TerminalLog(@"forkpty: %s", strerror(errno));
		return NO;
	}
	fcntl(master, F_SETFD, FD_CLOEXEC);
	_master = master;
	_child = child;
	TerminalLog(@"started %@ (pid %d) on %dx%d", shell, (int)child, columns, rows);

	/* Reading blocks, so it gets a thread of its own (not a GCD worker). */
	pthread_create(&_reader, NULL, TerminalReaderMain, (void *)CFBridgingRetain(self));
	pthread_detach(_reader);
	return YES;
}

static void *TerminalReaderMain(void *argument)
{
	TerminalSession *session = CFBridgingRelease(argument);
	pthread_setname_np("Terminal pty reader");
	[session readUntilEnd];
	return NULL;
}

- (void)readUntilEnd
{
	uint8_t buffer[16384];
	for (;;) {
		ssize_t count = read(_master, buffer, sizeof(buffer));
		if (count < 0 && errno == EINTR)
			continue;
		if (count <= 0)
			break; /* EIO once the shell and everything it started is gone */
		pthread_mutex_lock(&_lock);
		while ([_pending length] > TerminalMaximumPending)
			pthread_cond_wait(&_drained, &_lock);
		[_pending appendBytes:buffer length:(NSUInteger)count];
		BOOL schedule = !_drainScheduled;
		_drainScheduled = YES;
		pthread_mutex_unlock(&_lock);
		if (schedule)
			dispatch_async(dispatch_get_main_queue(), ^{
				[self drain];
			});
	}

	int status = 0;
	while (waitpid(_child, &status, 0) < 0 && errno == EINTR)
		;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self drain];
		close(self->_master);
		self->_master = -1;
		if (self.exited != nil)
			self.exited(status);
	});
}

/* On the main thread: everything read so far, in one go. */
- (void)drain
{
	pthread_mutex_lock(&_lock);
	NSData *data = _pending;
	_pending = [NSMutableData data];
	_drainScheduled = NO;
	pthread_cond_broadcast(&_drained);
	pthread_mutex_unlock(&_lock);
	if ([data length] > 0 && self.output != nil)
		self.output(data);
}

- (void)writeData:(NSData *)data
{
	const uint8_t *bytes = [data bytes];
	size_t left = [data length];
	while (left > 0 && _master >= 0) {
		ssize_t written = write(_master, bytes, left);
		if (written < 0) {
			if (errno == EINTR || errno == EAGAIN)
				continue;
			break;
		}
		bytes += written;
		left -= (size_t)written;
	}
}

- (void)resizeToColumns:(int)columns rows:(int)rows
{
	if (_master < 0)
		return;
	struct winsize size = { (unsigned short)rows, (unsigned short)columns, 0, 0 };
	ioctl(_master, TIOCSWINSZ, &size);
}

@end

#pragma mark - The root view

/* The terminal and the extra-keys bar, inside the safe area (the host's
   status and navigation bars) and above the keyboard when UIKit says where
   it is. */
@interface TerminalRootView : UIView
@property (nonatomic, strong, readonly) TerminalView *terminalView;
@property (nonatomic, strong, readonly) TerminalKeyBar *keyBar;
@end

@implementation TerminalRootView {
	CGFloat _keyboardHeight;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setBackgroundColor:[UIColor colorWithRed:0.07 green:0.08 blue:0.09 alpha:1]];
		_terminalView = [[TerminalView alloc] initWithFrame:CGRectZero];
		[self addSubview:_terminalView];
		_keyBar = [[TerminalKeyBar alloc] initWithFrame:CGRectZero];
		_keyBar.terminalView = _terminalView;
		[self addSubview:_keyBar];
		[self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
		[center addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillShowNotification object:nil];
		[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillChange:(NSNotification *)notification
{
	NSValue *value = [notification userInfo][UIKeyboardFrameEndUserInfoKey];
	if (value == nil)
		return;
	CGRect keyboard;
	[value getValue:&keyboard];
	CGFloat height = MAX(0, CGRectGetMaxY([self bounds]) - CGRectGetMinY(keyboard));
	if (height != _keyboardHeight) {
		_keyboardHeight = height;
		[self setNeedsLayout];
	}
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	if (_keyboardHeight != 0) {
		_keyboardHeight = 0;
		[self setNeedsLayout];
	}
}

- (void)safeAreaInsetsDidChange
{
	[self setNeedsLayout];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect bounds = [self bounds];
	UIEdgeInsets insets = [self safeAreaInsets];
	CGFloat bottom = MAX(insets.bottom, _keyboardHeight);
	CGFloat width = bounds.size.width - insets.left - insets.right;
	CGFloat barY = bounds.size.height - bottom - TerminalKeyBarHeight;
	[_keyBar setFrame:CGRectMake(insets.left, barY, width, TerminalKeyBarHeight)];
	[_terminalView setFrame:CGRectMake(insets.left, insets.top, width, MAX(0, barY - insets.top))];
	[_terminalView layoutSubviews];
}

@end

#pragma mark - Application

@interface TerminalViewController : UIViewController <TerminalViewDelegate>
@end

@implementation TerminalViewController {
	TerminalRootView *_root;
	TerminalSession *_session;
}

- (void)loadView
{
	_root = [[TerminalRootView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	_root.terminalView.delegate = self;
	[self setView:_root];
}

- (void)startShell
{
	TerminalView *view = _root.terminalView;
	TerminalScreen *screen = view.screen;
	TerminalSession *session = [[TerminalSession alloc] init];
	__weak TerminalViewController *weakSelf = self;
	__weak TerminalSession *weakSession = session;
	session.output = ^(NSData *data) {
		[screen feed:[data bytes] length:[data length]];
		[view screenDidChange];
	};
	session.exited = ^(int status) {
		TerminalViewController *controller = weakSelf;
		if (controller == nil || controller->_session != weakSession)
			return;
		TerminalLog(@"shell exited (status %d)", status);
		static const char completed[] = "\033[0m\r\n[Process completed]";
		[screen feed:(const uint8_t *)completed length:strlen(completed)];
		view.ended = YES;
		[view screenDidChange];
	};
	/* The screen's answers to queries go back to the program. */
	screen.responder = ^(NSData *answer) {
		[weakSelf terminalView:view sendData:answer];
	};
	_session = session;
	view.ended = NO;
	if (![session startWithColumns:[screen columns] rows:[screen rows]]) {
		static const char failed[] = "\033[31mCannot start a shell.\033[0m\r\n";
		[screen feed:(const uint8_t *)failed length:strlen(failed)];
		view.ended = YES;
		[view screenDidChange];
	}
}

- (void)viewDidAppearOnce
{
	[_root layoutSubviews];
	[self startShell];
	[_root.terminalView becomeFirstResponder];
}

#pragma mark TerminalViewDelegate

- (void)terminalView:(TerminalView *)view sendData:(NSData *)data
{
	[_session writeData:data];
}

- (void)terminalView:(TerminalView *)view didResizeToColumns:(int)columns rows:(int)rows
{
	[_session resizeToColumns:columns rows:rows];
}

- (void)terminalViewWantsRestart:(TerminalView *)view
{
	[view.screen reset];
	[view setNeedsDisplay:YES];
	[self startShell];
	[view becomeFirstResponder];
}

@end

@interface TerminalAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TerminalAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	TerminalViewController *controller = [[TerminalViewController alloc] init];
	self.window.rootViewController = controller;
	[self.window makeKeyAndVisible];
	/* The grid has its size once the window is laid out; the shell starts
	   with it, so its first prompt already fits. */
	dispatch_async(dispatch_get_main_queue(), ^{
		[controller viewDidAppearOnce];
	});
	return YES;
}

@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		/* Writing to a pty whose shell is gone must not kill the app. */
		signal(SIGPIPE, SIG_IGN);
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([TerminalAppDelegate class]));
	}
}
