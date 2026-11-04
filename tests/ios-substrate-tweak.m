/*
 * The tweaks that ios-substrate.m expects SubstrateLoader to have loaded,
 * or not. Each build defines one of the TWEAK_ macros; ios-substrate.md
 * lists their filter plists.
 */

#import <Foundation/Foundation.h>
#import <substrate.h>
#include <stdlib.h>

#if defined(TWEAK_MAIN)

static IMP origValue;
static long repValue(id self, SEL _cmd) { return ((long (*)(id, SEL))origValue)(self, _cmd) * 100; }

static long (*origFunction)(long);
static long repFunction(long x) { return origFunction(x) + 1999; }

__attribute__((constructor))
static void tweakInit(void)
{
	setenv("SUBSTRATE_TEST_TWEAK", getenv("SUBSTRATE_TEST_APP_INITIALIZED") ? "after-app" : "before-app", 1);
	MSHookMessageEx(objc_getClass("STTweakTarget"), @selector(value), (IMP)repValue, &origValue);
	MSHookFunction(MSFindSymbol(NULL, "_st_tweak_function"), (void *)repFunction, (void **)&origFunction);
}

#else

#if defined(TWEAK_ANY)
#define TWEAK_VARIABLE "SUBSTRATE_TEST_ANY"
#elif defined(TWEAK_WRONG)
#define TWEAK_VARIABLE "SUBSTRATE_TEST_WRONG"
#elif defined(TWEAK_UIKIT)
#define TWEAK_VARIABLE "SUBSTRATE_TEST_UIKIT"
#elif defined(TWEAK_VERSION)
#define TWEAK_VARIABLE "SUBSTRATE_TEST_VERSION"
#elif defined(TWEAK_NOPLIST)
#define TWEAK_VARIABLE "SUBSTRATE_TEST_NOPLIST"
#endif

__attribute__((constructor))
static void tweakInit(void)
{
	setenv(TWEAK_VARIABLE, "1", 1);
}

#endif
