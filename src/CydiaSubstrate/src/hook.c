/*
 * This file is part of Darling.
 *
 * Copyright (C) 2026 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

// MSHookFunction and MSHookMemory: patching code in place.

#include <substrate.h>
#include <libkern/OSCacheControl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "internal.h"

bool MSDebug = false;

static pthread_mutex_t MSCodeLock = PTHREAD_MUTEX_INITIALIZER;

void MSLog(const char *format, ...)
{
	va_list args;
	va_start(args, format);
	fputs("Substrate: ", stderr);
	vfprintf(stderr, format, args);
	fputc('\n', stderr);
	va_end(args);
}

// Makes the pages under [start, start + size) writable and executable.
// They stay that way: their old protection can't be asked for, and
// restoring the wrong one would break writable data. Code is mapped
// private, so this only copies the pages; a mapping that still refuses
// PROT_WRITE is replaced with an anonymous copy of itself.
static bool MSMakeWritable(void *start, size_t size)
{
	uintptr_t page = getpagesize();
	uintptr_t first = (uintptr_t)start & ~(page - 1);
	uintptr_t last = ((uintptr_t)start + size + page - 1) & ~(page - 1);
	size_t length = last - first;

	if (mprotect((void *)first, length, PROT_READ | PROT_WRITE | PROT_EXEC) == 0)
		return true;

	void *copy = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
	if (copy == MAP_FAILED)
		return false;
	memcpy(copy, (void *)first, length);
	void *replaced = mmap((void *)first, length, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE | MAP_FIXED, -1, 0);
	if (replaced != MAP_FAILED)
		memcpy(replaced, copy, length);
	munmap(copy, length);
	return replaced != MAP_FAILED;
}

static bool MSWriteCode(void *target, const void *data, size_t size)
{
	if (!MSMakeWritable(target, size)) {
		MSLog("cannot write to %p", target);
		return false;
	}
	memcpy(target, data, size);
	sys_icache_invalidate(target, size);
	return true;
}

void MSHookMemory(void *target, const void *data, size_t size)
{
	pthread_mutex_lock(&MSCodeLock);
	MSWriteCode(target, data, size);
	pthread_mutex_unlock(&MSCodeLock);
}

// Trampolines (the relocated start of a hooked function, then a jump back
// to the rest of it) are carved out of executable pages that are never
// freed: a hook can't be undone safely while other threads may be in it.
static void *MSAllocateTrampoline(size_t size)
{
	static uint8_t *pool;
	static size_t used, capacity;

	size = (size + 15) & ~(size_t)15;
	if (pool == NULL || used + size > capacity) {
		capacity = 16384;
		pool = mmap(NULL, capacity, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
		if (pool == MAP_FAILED) {
			pool = NULL;
			return NULL;
		}
		used = 0;
	}
	void *result = pool + used;
	used += size;
	return result;
}

#if defined(__arm64__) || defined(__aarch64__)

#define A64_LDR(reg, offset) (0x58000000u | (((uint32_t)(offset) >> 2) << 5) | (reg)) // ldr x<reg>, #offset
#define A64_BR(reg)     (0xd61f0000u | ((reg) << 5))
#define A64_BLR(reg)    (0xd63f0000u | ((reg) << 5))
#define A64_B(offset)   (0x14000000u | (((uint32_t)(offset) >> 2) & 0x3ffffff))
#define A64_NOP         0xd503201fu

// The most instructions relocate() writes for one, and for the jump that
// leaves a trampoline.
#define A64_MAX_RELOCATED 6
#define A64_JUMP 4

static int64_t sext(uint64_t value, int bits)
{
	return (int64_t)(value << (64 - bits)) >> (64 - bits);
}

// ldr x<reg>, #8; br x<reg>; .quad dest
static uint32_t *emitJump(uint32_t *out, unsigned reg, uintptr_t dest)
{
	out[0] = A64_LDR(reg, 8);
	out[1] = A64_BR(reg);
	memcpy(&out[2], &dest, sizeof(dest));
	return out + 4;
}

// Copies the instruction that was at pc to out, rewriting the ones that
// address relative to pc to use an absolute address instead, by way of
// the scratch register reg.
static uint32_t *relocate(uint32_t insn, uintptr_t pc, unsigned reg, uint32_t *out)
{
	if ((insn & 0x7c000000) == 0x14000000) {
		// b, bl
		uintptr_t dest = pc + (sext(insn & 0x3ffffff, 26) << 2);
		if (insn & 0x80000000) {
			out[0] = A64_LDR(reg, 12);
			out[1] = A64_BLR(reg);
			out[2] = A64_B(12);
			memcpy(&out[3], &dest, sizeof(dest));
			return out + 5;
		}
		return emitJump(out, reg, dest);
	}

	uint32_t retargeted = 0;
	uintptr_t dest = 0;
	if ((insn & 0xff000010) == 0x54000000 || (insn & 0x7e000000) == 0x34000000) {
		// b.cond, cbz, cbnz: imm19
		dest = pc + (sext((insn >> 5) & 0x7ffff, 19) << 2);
		retargeted = (insn & ~(0x7ffffu << 5)) | (2u << 5);
	} else if ((insn & 0x7e000000) == 0x36000000) {
		// tbz, tbnz: imm14
		dest = pc + (sext((insn >> 5) & 0x3fff, 14) << 2);
		retargeted = (insn & ~(0x3fffu << 5)) | (2u << 5);
	}
	if (retargeted != 0) {
		// Taken: skip to the absolute jump. Not taken: jump over it.
		out[0] = retargeted;
		out[1] = A64_B(20);
		emitJump(out + 2, reg, dest);
		return out + 6;
	}

	if ((insn & 0x1f000000) == 0x10000000) {
		// adr, adrp
		int64_t imm = sext((((insn >> 5) & 0x7ffff) << 2) | ((insn >> 29) & 3), 21);
		uintptr_t value = (insn & 0x80000000) ? (pc & ~(uintptr_t)0xfff) + (imm << 12) : pc + imm;
		out[0] = A64_LDR(insn & 31, 8);
		out[1] = A64_B(12);
		memcpy(&out[2], &value, sizeof(value));
		return out + 4;
	}

	if ((insn & 0x3b000000) == 0x18000000) {
		// ldr (literal), ldrsw (literal), prfm (literal)
		uintptr_t address = pc + (sext((insn >> 5) & 0x7ffff, 19) << 2);
		uint32_t rt = insn & 31, opc = insn >> 30, simd = (insn >> 26) & 1;
		static const uint32_t loads[2][4] = {
			// ldr wt, ldr xt, ldrsw xt, prfm: from [x<reg>]
			{ 0xb9400000, 0xf9400000, 0xb9800000, A64_NOP },
			// ldr st, ldr dt, ldr qt
			{ 0xbd400000, 0xfd400000, 0x3dc00000, A64_NOP },
		};
		out[0] = A64_LDR(reg, 8);
		out[1] = A64_B(12);
		memcpy(&out[2], &address, sizeof(address));
		out[4] = loads[simd][opc] == A64_NOP ? A64_NOP : (loads[simd][opc] | (reg << 5) | rt);
		return out + 5;
	}

	out[0] = insn;
	return out + 1;
}

static void MSHookFunctionArm64(uint32_t *target, void *replace, void **result)
{
	// A replacement within reach of b only overwrites one instruction.
	intptr_t delta = (intptr_t)replace - (intptr_t)target;
	bool near = delta >= -(1 << 27) && delta < (1 << 27) && (delta & 3) == 0;
	size_t count = near ? 1 : 4;

	if (result != NULL) {
		uint32_t *trampoline = MSAllocateTrampoline((count * A64_MAX_RELOCATED + A64_JUMP) * 4);
		if (trampoline == NULL) {
			MSLog("out of memory for a trampoline for %p", target);
			*result = NULL;
			return;
		}
		// x16 and x17 are free at the start of a function, unless the
		// instructions moved here use one, as a hook's own patch uses
		// x16; then the trampoline keeps out of it. Any register field
		// that could name x17 counts.
		unsigned reg = 17;
		for (size_t i = 0; i < count; i++) {
			for (int shift = 0; shift <= 16; shift += 5 + (shift == 10))
				if (((target[i] >> shift) & 31) == 17)
					reg = 16;
		}
		uint32_t *out = trampoline;
		for (size_t i = 0; i < count; i++)
			out = relocate(target[i], (uintptr_t)&target[i], reg, out);
		out = emitJump(out, reg, (uintptr_t)(target + count));
		sys_icache_invalidate(trampoline, (out - trampoline) * 4);
		*result = trampoline;
	}

	uint32_t patch[4];
	if (near)
		patch[0] = A64_B(delta);
	else
		emitJump(patch, 16, (uintptr_t)replace);
	MSWriteCode(target, patch, count * 4);
}

#endif

void MSHookFunction(void *symbol, void *replace, void **result)
{
	if (MSDebug)
		MSLog("MSHookFunction(%p, %p, %p)", symbol, replace, result);
	if (symbol == NULL) {
		MSLog("MSHookFunction: no symbol to hook");
		if (result != NULL)
			*result = NULL;
		return;
	}

	pthread_mutex_lock(&MSCodeLock);
#if defined(__arm64__) || defined(__aarch64__)
	MSHookFunctionArm64(symbol, replace, result);
#else
	// Tweaks are built for arm64 only.
	MSLog("MSHookFunction(%p) is not supported on this architecture", symbol);
	if (result != NULL)
		*result = NULL;
#endif
	pthread_mutex_unlock(&MSCodeLock);
}
