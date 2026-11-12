/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* The runtime half of Swift's `#available` (and clang's
   __builtin_available): compiler-rt's os_version_check.c, which Apple's
   clang links statically into every binary from libclang_rt.<os>.a. Darling
   links without that archive, so each Swift binary built for iOS here
   (cmake/swift_ios.cmake) gets this private copy.

   The answers are the versions Darling presents: iOS 14.0 (UIDevice's
   systemVersion) and macOS 11.0. Inlined standard library code that asks
   then takes its back-deployment paths, which the 6.3.3 runtime keeps. */

#include <stdint.h>

#define PLATFORM_MACOS 1
#define PLATFORM_IOS 2
#define PLATFORM_MACCATALYST 6

static int32_t at_least(uint32_t major, uint32_t minor, uint32_t subminor,
                        uint32_t have_major, uint32_t have_minor)
{
	if (major != have_major)
		return major < have_major;
	if (minor != have_minor)
		return minor < have_minor;
	return subminor == 0;
}

__attribute__((visibility("hidden")))
int32_t __isPlatformVersionAtLeast(uint32_t platform, uint32_t major, uint32_t minor, uint32_t subminor)
{
	switch (platform) {
	case PLATFORM_IOS:
	case PLATFORM_MACCATALYST:
		return at_least(major, minor, subminor, 14, 0);
	case PLATFORM_MACOS:
		return at_least(major, minor, subminor, 11, 0);
	default:
		return 0;
	}
}

__attribute__((visibility("hidden")))
int32_t __isOSVersionAtLeast(int32_t major, int32_t minor, int32_t subminor)
{
	return __isPlatformVersionAtLeast(PLATFORM_IOS, major, minor, subminor);
}
