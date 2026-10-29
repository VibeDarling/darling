/*
 * Checks Darling's Cydia Substrate: MSHookFunction on arm64 code that
 * starts with every kind of pc-relative instruction, with both the short
 * and the long patch, MSHookMessageEx, MSFindSymbol, MSHookMemory, and
 * the tweaks that SubstrateLoader loaded into this process (see
 * ios-substrate-tweak.m and ios-substrate.md).
 */

#import <Foundation/Foundation.h>
#import <substrate.h>
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static int failures;

static void expect(const char *name, bool ok)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
	if (!ok)
		failures++;
}

/* Two copies of each function, one hooked by a replacement within reach
 * of b (one instruction patched) and one by a far one (four patched).
 * Each starts with, or has within its first four instructions, an
 * instruction that addresses relative to pc. */
__asm__(
	".data\n"
	".p2align 3\n"
	"_t_data: .quad 8\n"
	".text\n"
	".macro TFUNCS sfx\n"
	".globl _t_plain\\sfx\n.p2align 4\n"
	"_t_plain\\sfx: add x0, x0, #1\n nop\n nop\n nop\n ret\n"

	".globl _t_b\\sfx\n.p2align 4\n"
	"_t_b\\sfx: b 1f\n brk #0\n brk #0\n brk #0\n1: add x0, x0, #2\n ret\n"

	".globl _t_bl\\sfx\n.p2align 4\n"
	"_t_bl\\sfx: mov x9, x30\n bl _t_add3\n mov x30, x9\n nop\n ret\n"

	".globl _t_cbz\\sfx\n.p2align 4\n"
	"_t_cbz\\sfx: cbz x0, 1f\n add x0, x0, #5\n ret\n nop\n1: mov x0, #55\n ret\n"

	".globl _t_tbz\\sfx\n.p2align 4\n"
	"_t_tbz\\sfx: tbz x0, #0, 1f\n add x0, x0, #6\n ret\n nop\n1: mov x0, #66\n ret\n"

	".globl _t_bcond\\sfx\n.p2align 4\n"
	"_t_bcond\\sfx: cmp x0, #0\n b.eq 1f\n add x0, x0, #4\n ret\n1: mov x0, #44\n ret\n"

	".globl _t_adr\\sfx\n.p2align 4\n"
	"_t_adr\\sfx: adr x1, 1f\n ldr x1, [x1]\n add x0, x0, x1\n ret\n1: .quad 7\n"

	".globl _t_adrp\\sfx\n.p2align 4\n"
	"_t_adrp\\sfx: adrp x1, _t_data@PAGE\n ldr x1, [x1, _t_data@PAGEOFF]\n add x0, x0, x1\n ret\n"

	".globl _t_ldrx\\sfx\n.p2align 4\n"
	"_t_ldrx\\sfx: ldr x1, 1f\n add x0, x0, x1\n ret\n nop\n1: .quad 9\n"

	".globl _t_ldrw\\sfx\n.p2align 4\n"
	"_t_ldrw\\sfx: ldr w1, 1f\n add x0, x0, x1\n ret\n nop\n1: .long 10\n .long 0xffffffff\n"

	".globl _t_ldrd\\sfx\n.p2align 4\n"
	"_t_ldrd\\sfx: ldr d0, 1f\n fmov x1, d0\n add x0, x0, x1\n ret\n1: .quad 11\n"
	".endm\n"
	"TFUNCS _n\n"
	"TFUNCS _f\n"

	".globl _t_add3\n.p2align 4\n"
	"_t_add3: add x0, x0, #3\n ret\n"
);

typedef long (*TFunc)(long);

#define TDECLARE(name) \
	long t_##name##_n(long); long t_##name##_f(long); \
	static TFunc orig_##name##_n, orig_##name##_f; \
	static long rep_##name##_n(long x) { return orig_##name##_n(x) + 1000; } \
	static long rep_##name##_f(long x) { return orig_##name##_f(x) + 1000; }

TDECLARE(plain)
TDECLARE(b)
TDECLARE(bl)
TDECLARE(cbz)
TDECLARE(tbz)
TDECLARE(bcond)
TDECLARE(adr)
TDECLARE(adrp)
TDECLARE(ldrx)
TDECLARE(ldrw)
TDECLARE(ldrd)

/* A stub out of reach of b that jumps to the replacement, so that hooking
 * with it takes the long patch. */
static void *farStub(void *replace)
{
	uintptr_t here = (uintptr_t)&farStub;
	for (uintptr_t hint = here + (4ull << 30); hint < here + (64ull << 30); hint += 1ull << 30) {
		uint32_t *page = mmap((void *)hint, 4096, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
		if (page == MAP_FAILED)
			continue;
		intptr_t distance = (intptr_t)page - (intptr_t)here;
		if (distance > (256 << 20) || distance < -(256 << 20)) {
			page[0] = 0x58000050; // ldr x16, #8
			page[1] = 0xd61f0200; // br x16
			memcpy(&page[2], &replace, sizeof(replace));
			sys_icache_invalidate(page, 16);
			return page;
		}
		munmap(page, 4096);
	}
	return NULL;
}

static bool nearPatch(void *target)
{
	return (*(uint32_t *)target & 0xfc000000) == 0x14000000;
}

static void checkFunction(const char *name, TFunc near, TFunc nearRep, TFunc *nearOrig,
	TFunc far, TFunc farRep, TFunc *farOrig, long *inputs, int count)
{
	long expected[4];
	for (int i = 0; i < count; i++)
		expected[i] = near(inputs[i]);

	MSHookFunction((void *)near, (void *)nearRep, (void **)nearOrig);
	void *stub = farStub((void *)farRep);
	MSHookFunction((void *)far, stub, (void **)farOrig);

	bool nearOk = nearPatch((void *)near) && *nearOrig != NULL;
	bool farOk = !nearPatch((void *)far) && stub != NULL && *farOrig != NULL;
	for (int i = 0; i < count && nearOk && farOk; i++) {
		nearOk = near(inputs[i]) == expected[i] + 1000 && (*nearOrig)(inputs[i]) == expected[i];
		farOk = far(inputs[i]) == expected[i] + 1000 && (*farOrig)(inputs[i]) == expected[i];
	}
	char label[128];
	snprintf(label, sizeof(label), "MSHookFunction %s, 1-instruction patch", name);
	expect(label, nearOk);
	snprintf(label, sizeof(label), "MSHookFunction %s, 4-instruction patch", name);
	expect(label, farOk);
}

#define TCHECK(name, ...) do { \
	long inputs[] = { __VA_ARGS__ }; \
	checkFunction(#name, t_##name##_n, rep_##name##_n, &orig_##name##_n, \
		t_##name##_f, rep_##name##_f, &orig_##name##_f, inputs, sizeof(inputs) / sizeof(inputs[0])); \
} while (0)

/* A hook of a hook: the second relocates the first's patch. */
static TFunc orig_plain_again;
static long rep_plain_again(long x) { return orig_plain_again(x) + 20000; }

static pid_t (*orig_getppid)(void);
static pid_t rep_getppid(void) { return orig_getppid() + 1000; }

__attribute__((noinline, used))
static long st_local(long x) { return x * 3; }

static const char st_text[] = "hello";

@interface STBase : NSObject
- (long)value;
+ (long)classValue;
@end
@implementation STBase
- (long)value { return 1; }
+ (long)classValue { return 10; }
@end

@interface STSub : STBase
@end
@implementation STSub
@end

@interface STOwn : NSObject
- (long)value;
@end
@implementation STOwn
- (long)value { return 3; }
@end

/* Hooked by the tweak. */
@interface STTweakTarget : NSObject
- (long)value;
@end
@implementation STTweakTarget
- (long)value { return 5; }
@end

/* Tweaks load before this runs. */
__attribute__((constructor))
static void st_initializer(void)
{
	setenv("SUBSTRATE_TEST_APP_INITIALIZED", "1", 1);
}

long st_tweak_function(long x) __attribute__((noinline));
long st_tweak_function(long x) { return x + 1; }

static IMP origOwnValue, origSubValue, origClassValue, origMissing;
static long repOwnValue(id self, SEL _cmd) { return ((long (*)(id, SEL))origOwnValue)(self, _cmd) + 100; }
static long repSubValue(id self, SEL _cmd) { return ((long (*)(id, SEL))origSubValue)(self, _cmd) + 200; }
static long repClassValue(id self, SEL _cmd) { return ((long (*)(id, SEL))origClassValue)(self, _cmd) + 300; }

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IOLBF, 0);
	@autoreleasepool {
		bool safeMode = getenv("_MSSafeMode") != NULL;

		// The tweaks, loaded before main by UIKit's initializer.
		if (safeMode) {
			expect("safe mode: no tweak loaded", getenv("SUBSTRATE_TEST_TWEAK") == NULL && [[STTweakTarget new] value] == 5);
			return failures != 0;
		}
		expect("tweak loaded (Executables filter)", getenv("SUBSTRATE_TEST_TWEAK") != NULL);
		expect("tweak loaded before the app's initializers", getenv("SUBSTRATE_TEST_TWEAK") && strcmp(getenv("SUBSTRATE_TEST_TWEAK"), "before-app") == 0);
		expect("tweak hooked a method of the app", [[STTweakTarget new] value] == 500);
		expect("tweak hooked a function of the app", st_tweak_function(1) == 2001);
		expect("Mode Any tweak loaded (Classes filter)", getenv("SUBSTRATE_TEST_ANY") != NULL);
		expect("tweak with an unmatched Bundles filter not loaded", getenv("SUBSTRATE_TEST_WRONG") == NULL);
		expect("tweak for com.apple.UIKit loaded (Bundles filter)", getenv("SUBSTRATE_TEST_UIKIT") != NULL);
		expect("tweak matching CoreFoundationVersion loaded", getenv("SUBSTRATE_TEST_VERSION") != NULL);
		expect("tweak without a plist not loaded", getenv("SUBSTRATE_TEST_NOPLIST") == NULL);

		TCHECK(plain, 1, 40);
		TCHECK(b, 1, 40);
		TCHECK(bl, 1, 40);
		TCHECK(cbz, 0, 7);
		TCHECK(tbz, 2, 7);
		TCHECK(bcond, 0, 7);
		TCHECK(adr, 1, 40);
		TCHECK(adrp, 1, 40);
		TCHECK(ldrx, 1, 40);
		TCHECK(ldrw, 1, 40);
		TCHECK(ldrd, 1, 40);

		MSHookFunction((void *)t_plain_f, (void *)rep_plain_again, (void **)&orig_plain_again);
		expect("MSHookFunction of a hooked function", t_plain_f(1) == 2 + 1000 + 20000 && orig_plain_again(1) == 2 + 1000);

		pid_t ppid = getppid();
		MSHookFunction(dlsym(RTLD_DEFAULT, "getppid"), (void *)rep_getppid, (void **)&orig_getppid);
		expect("MSHookFunction of a libSystem function", getppid() == ppid + 1000 && orig_getppid() == ppid);

		// MSHookMessageEx
		MSHookMessageEx([STOwn class], @selector(value), (IMP)repOwnValue, &origOwnValue);
		expect("MSHookMessageEx, own method", [[STOwn new] value] == 103 && ((long (*)(id, SEL))origOwnValue)([STOwn new], @selector(value)) == 3);
		MSHookMessageEx([STSub class], @selector(value), (IMP)repSubValue, &origSubValue);
		expect("MSHookMessageEx, inherited method", [[STSub new] value] == 201 && [[STBase new] value] == 1);
		MSHookMessageEx(object_getClass([STBase class]), @selector(classValue), (IMP)repClassValue, &origClassValue);
		expect("MSHookMessageEx, class method", [STBase classValue] == 310 && [STSub classValue] == 310);
		origMissing = (IMP)1;
		MSHookMessageEx([STBase class], @selector(noSuchMethod), (IMP)repOwnValue, &origMissing);
		expect("MSHookMessageEx, missing method", origMissing == NULL);

		// MSGetImageByName, MSFindSymbol
		char executable[1024];
		uint32_t size = sizeof(executable);
		_NSGetExecutablePath(executable, &size);
		MSImageRef image = MSGetImageByName(executable);
		expect("MSGetImageByName of the executable", image == _dyld_get_image_header(0));
		expect("MSGetImageByName by an iOS framework path", MSGetImageByName("/System/Library/Frameworks/UIKit.framework/UIKit") != NULL);
		expect("MSGetImageByName of something not loaded", MSGetImageByName("/nonexistent/libnothing.dylib") == NULL);
		expect("MSFindSymbol of a local symbol", MSFindSymbol(image, "_st_local") == (void *)st_local);
		expect("MSFindSymbol in any image", MSFindSymbol(NULL, "_getpid") == dlsym(RTLD_DEFAULT, "getpid"));
		expect("MSFindSymbol of a missing symbol", MSFindSymbol(NULL, "_no_such_symbol_here") == NULL);

		// MSHookMemory
		const char *volatile text = st_text;
		MSHookMemory((void *)st_text, "HELLO", 5);
		expect("MSHookMemory on read-only data", memcmp(text, "HELLO", 5) == 0);
	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
