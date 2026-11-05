// JIT the way iOS apps do it: check for CS_DEBUGGED, then write code into
// MAP_JIT memory (pthread_jit_write_protect_np), a mprotect W^X page and a
// mach_vm_remap alias, flush the icache and run it. See ios-jit.md.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/mman.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>

#define CS_OPS_STATUS 0
#define CS_VALID 0x00000001
#define CS_DEBUGGED 0x10000000
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

#ifndef MAP_JIT
#define MAP_JIT 0x800
#endif

static int failures;

static void check(int ok, const char *what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

// movz w0, #imm; ret
static void emit_const(uint32_t *code, uint16_t imm)
{
	code[0] = 0x52800000u | ((uint32_t)imm << 5);
	code[1] = 0xd65f03c0u;
}

typedef int (*fn0)(void);
typedef int (*fn2)(int, int);

static void test_csops(void)
{
	uint32_t flags = 0;
	int r = csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags));
	printf("csops status = 0x%08x (r=%d)\n", flags, r);
	check(r == 0 && (flags & CS_VALID), "csops CS_OPS_STATUS answers CS_VALID");
	check(r == 0 && (flags & CS_DEBUGGED), "csops CS_OPS_STATUS answers CS_DEBUGGED (JIT allowed)");
}

static void test_map_jit(void)
{
	size_t len = 16384;
	uint32_t *code = mmap(NULL, len, PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
	check(code != MAP_FAILED, "mmap RWX MAP_JIT");
	if (code == MAP_FAILED)
		return;

	// Rewrite the same instructions many times: a stale icache shows up as
	// a wrong answer on cores that are not coherent (Cortex-A72).
	int wrong = 0;
	for (int i = 0; i < 2000; i++) {
		pthread_jit_write_protect_np(0);
		emit_const(code, (uint16_t)i);
		pthread_jit_write_protect_np(1);
		sys_icache_invalidate(code, 8);
		if (((fn0)code)() != i)
			wrong++;
	}
	check(wrong == 0, "MAP_JIT: 2000 rewrites of one function, each returns its new value");

	// add w0, w0, w1; ret
	pthread_jit_write_protect_np(0);
	code[64] = 0x0b010000u;
	code[65] = 0xd65f03c0u;
	pthread_jit_write_protect_np(1);
	sys_icache_invalidate(code + 64, 8);
	check(((fn2)(code + 64))(40, 2) == 42, "MAP_JIT: generated add(40, 2) == 42");
	munmap(code, len);
}

static void test_mprotect(void)
{
	size_t len = 16384;
	uint32_t *code = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
	check(code != MAP_FAILED, "mmap RW");
	if (code == MAP_FAILED)
		return;
	emit_const(code, 1234);
	int r = mprotect(code, len, PROT_READ | PROT_EXEC);
	check(r == 0, "mprotect RW -> RX");
	sys_icache_invalidate(code, 8);
	check(r == 0 && ((fn0)code)() == 1234, "mprotect W^X: generated code returns 1234");
	r = mprotect(code, len, PROT_READ | PROT_WRITE);
	emit_const(code, 4321);
	r |= mprotect(code, len, PROT_READ | PROT_EXEC);
	sys_icache_invalidate(code, 8);
	check(r == 0 && ((fn0)code)() == 4321, "mprotect W^X: rewritten code returns 4321");
	munmap(code, len);
}

static void test_remap_alias(void)
{
	// Dual mapping: execute through an RX view, write through an RW alias of
	// the same pages (mach_vm_remap with copy = FALSE).
	mach_vm_size_t len = 16384;
	mach_vm_address_t rx = 0, rw = 0;
	kern_return_t kr = mach_vm_allocate(mach_task_self(), &rx, len, VM_FLAGS_ANYWHERE);
	check(kr == KERN_SUCCESS, "mach_vm_allocate");
	if (kr != KERN_SUCCESS)
		return;
	vm_prot_t cur, max;
	kr = mach_vm_remap(mach_task_self(), &rw, len, 0, VM_FLAGS_ANYWHERE, mach_task_self(), rx,
			FALSE, &cur, &max, VM_INHERIT_NONE);
	check(kr == KERN_SUCCESS, "mach_vm_remap shared alias");
	if (kr != KERN_SUCCESS) {
		printf("  mach_vm_remap: %d (%s)\n", kr, mach_error_string(kr));
		return;
	}
	kr = mach_vm_protect(mach_task_self(), rx, len, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
	check(kr == KERN_SUCCESS, "mach_vm_protect original -> RX");
	emit_const((uint32_t *)rw, 777);
	sys_icache_invalidate((void *)rx, 8);
	check(*(uint32_t *)rx == *(uint32_t *)rw, "alias: a write through RW is visible through RX");
	if (*(uint32_t *)rx == *(uint32_t *)rw)
		check(((fn0)rx)() == 777, "alias: code written through RW runs from RX, returns 777");
}

int main(void)
{
#ifndef __arm64__
	puts("SKIP: the generated code is arm64");
	return 0;
#endif
	test_csops();
	test_map_jit();
	test_mprotect();
	test_remap_alias();
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
