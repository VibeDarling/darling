/* JavaScriptCore.framework: the C API, the Objective-C API (JSContext,
   JSValue, blocks, JSExport) and enough of the language that apps embed it
   for (JSON, RegExp, Date, Promise jobs, exceptions). One PASS/FAIL line per
   check; exits nonzero on any failure. See ios-javascriptcore.md. */

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#include <stdio.h>
#include <time.h>

static int failures;

static void expect(BOOL ok, const char *name, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", name,
	       detail ? ": " : "", detail ? [detail UTF8String] : "");
	if (!ok)
		failures++;
}

static double now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

@protocol PointExports <JSExport>
@property (nonatomic) double x;
@property (nonatomic) double y;
- (double)length;
JSExportAs(scaledBy, - (id)scaledBy:(double)factor);
@end

@interface Point2D : NSObject <PointExports>
@end

@implementation Point2D
@synthesize x = _x, y = _y;
- (double)length
{
	return sqrt(_x * _x + _y * _y);
}
- (id)scaledBy:(double)factor
{
	Point2D *p = [Point2D new];
	p.x = _x * factor;
	p.y = _y * factor;
	return p;
}
@end

static void testCAPI(void)
{
	JSGlobalContextRef ctx = JSGlobalContextCreate(NULL);
	JSStringRef script = JSStringCreateWithUTF8CString("[1, 2, 3].map(function (n) { return n * n; }).join('+')");
	JSValueRef exception = NULL;
	JSValueRef result = JSEvaluateScript(ctx, script, NULL, NULL, 1, &exception);
	JSStringRelease(script);
	NSString *text = nil;
	if (result != NULL && exception == NULL) {
		JSStringRef s = JSValueToStringCopy(ctx, result, NULL);
		text = CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, s));
		JSStringRelease(s);
	}
	expect([text isEqualToString:@"1+4+9"], "C API: JSEvaluateScript", text);

	JSStringRef bad = JSStringCreateWithUTF8CString("function (");
	BOOL syntaxOK = JSCheckScriptSyntax(ctx, bad, NULL, 1, NULL);
	JSStringRelease(bad);
	expect(!syntaxOK, "C API: JSCheckScriptSyntax rejects bad syntax", nil);
	JSGlobalContextRelease(ctx);
}

static void testObjCAPI(void)
{
	JSContext *context = [JSContext new];
	__block NSString *lastException = nil;
	context.exceptionHandler = ^(JSContext *c, JSValue *exception) {
		lastException = [exception toString];
	};

	JSValue *sum = [context evaluateScript:@"var total = 0; for (var i = 1; i <= 100; i++) total += i; total"];
	expect([sum toInt32] == 5050, "JSContext evaluateScript", [sum toString]);

	context[@"greeting"] = @"hello";
	JSValue *upper = [context evaluateScript:@"greeting.toUpperCase() + ' ' + typeof greeting"];
	expect([[upper toString] isEqualToString:@"HELLO string"], "NSString into JS", [upper toString]);

	context[@"add"] = ^(int a, int b) { return a + b; };
	JSValue *added = [context evaluateScript:@"add(40, 2)"];
	expect([added toInt32] == 42, "block called from JS", [added toString]);

	context[@"echoArgs"] = ^{
		NSMutableArray *names = [NSMutableArray array];
		for (JSValue *v in [JSContext currentArguments])
			[names addObject:[v toString]];
		return [names componentsJoinedByString:@","];
	};
	JSValue *echoed = [context evaluateScript:@"echoArgs('a', 1, true)"];
	expect([[echoed toString] isEqualToString:@"a,1,true"], "currentArguments", [echoed toString]);

	JSValue *array = [context evaluateScript:@"[3, 'x', {k: [1, 2]}]"];
	NSArray *native = [array toArray];
	expect([native count] == 3 && [native[0] intValue] == 3 && [native[1] isEqual:@"x"] &&
	      [native[2][@"k"] isEqual:(@[ @1, @2 ])],
	      "JS array and object to Foundation", [native description]);

	JSValue *fn = [context evaluateScript:@"(function (a, b) { return a * b; })"];
	JSValue *product = [fn callWithArguments:@[ @6, @7 ]];
	expect([product toInt32] == 42, "call a JS function from Objective-C", [product toString]);

	Point2D *p = [Point2D new];
	p.x = 3;
	p.y = 4;
	context[@"p"] = p;
	JSValue *len = [context evaluateScript:@"p.x = 6; p.y = 8; p.length()"];
	expect([len toDouble] == 10 && p.x == 6, "JSExport properties and methods", [len toString]);
	JSValue *scaled = [context evaluateScript:@"p.scaledBy(0.5).length()"];
	expect([scaled toDouble] == 5, "JSExportAs", [scaled toString]);

	[context evaluateScript:@"null.boom"];
	expect([lastException containsString:@"TypeError"], "exception handler", lastException);

	JSValue *json = [context evaluateScript:@"JSON.stringify(JSON.parse('{\"a\":[1,{\"b\":null}]}'))"];
	expect([[json toString] isEqualToString:@"{\"a\":[1,{\"b\":null}]}"], "JSON", [json toString]);

	JSValue *re = [context evaluateScript:@"'2026-10-27'.replace(/(\\d+)-(\\d+)-(\\d+)/, '$3.$2.$1')"];
	expect([[re toString] isEqualToString:@"27.10.2026"], "RegExp", [re toString]);

	JSValue *date = [context evaluateScript:@"new Date(Date.UTC(2020, 1, 29)).toISOString()"];
	expect([[date toString] isEqualToString:@"2020-02-29T00:00:00.000Z"], "Date", [date toString]);

	[context evaluateScript:@"var settled = 'pending'; Promise.resolve(21).then(function (v) { settled = v * 2; });"];
	JSValue *settled = context[@"settled"];
	expect([settled toInt32] == 42, "Promise job runs after the script", [settled toString]);

	NSString *fib = @"function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); } fib(25)";
	double start = now();
	JSValue *f = [context evaluateScript:fib];
	double elapsed = now() - start;
	expect([f toInt32] == 75025, "fib(25)", [NSString stringWithFormat:@"%.0f ms", elapsed * 1000]);
}

int main(void)
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		testCAPI();
		testObjCAPI();
	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
