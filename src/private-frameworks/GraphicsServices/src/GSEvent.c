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

#include <GraphicsServices/GraphicsServices.h>
#include <mach/mach_time.h>
#include <pthread.h>

const CFStringRef kGSEventReceiveRunLoopMode = CFSTR("GSEventReceiveRunLoopMode");

static pthread_mutex_t gs_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableArrayRef gs_mode_stack;
static GSEventCallBack gs_callback;
static Boolean gs_stop;
static Boolean gs_hardware_keyboard;

static void gs_ensure_stack(void)
{
	if (gs_mode_stack == NULL)
		gs_mode_stack = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
}

void GSInitialize(void)
{
	pthread_mutex_lock(&gs_lock);
	gs_ensure_stack();
	pthread_mutex_unlock(&gs_lock);
}

void GSEventInitialize(Boolean registerPurple)
{
	/* "Purple" was the SpringBoard event port; nothing listens for it here. */
	(void)registerPurple;
	GSInitialize();
}

static CFStringRef gs_copy_current_mode(void)
{
	CFStringRef mode;

	pthread_mutex_lock(&gs_lock);
	gs_ensure_stack();
	CFIndex count = CFArrayGetCount(gs_mode_stack);
	mode = count > 0 ? CFArrayGetValueAtIndex(gs_mode_stack, count - 1) : kCFRunLoopDefaultMode;
	CFRetain(mode);
	pthread_mutex_unlock(&gs_lock);
	return mode;
}

void GSEventRunModal(Boolean disallowsRestarts)
{
	(void)disallowsRestarts;
	GSInitialize();
	gs_stop = false;

	/* CFRunLoopRunInMode returns when stopped, which is how a push or pop
	   switches the mode we run in; only GSEventStopModal ends the loop. */
	while (!gs_stop) {
		CFStringRef mode = gs_copy_current_mode();
		SInt32 result = CFRunLoopRunInMode(mode, 1.0e10, false);
		CFRelease(mode);
		if (result == kCFRunLoopRunFinished && !gs_stop) {
			/* No sources in this mode yet: wait for one instead of spinning. */
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
		}
	}
}

void GSEventRun(void)
{
	GSEventRunModal(false);
}

void GSEventStopModal(void)
{
	gs_stop = true;
	CFRunLoopStop(CFRunLoopGetMain());
}

void GSEventPushRunLoopMode(CFStringRef mode)
{
	if (mode == NULL)
		return;
	pthread_mutex_lock(&gs_lock);
	gs_ensure_stack();
	CFArrayAppendValue(gs_mode_stack, mode);
	pthread_mutex_unlock(&gs_lock);
	CFRunLoopStop(CFRunLoopGetMain());
}

void GSEventPopRunLoopMode(CFStringRef mode)
{
	pthread_mutex_lock(&gs_lock);
	gs_ensure_stack();
	CFIndex count = CFArrayGetCount(gs_mode_stack);
	if (count > 0) {
		CFStringRef top = CFArrayGetValueAtIndex(gs_mode_stack, count - 1);
		if (mode == NULL || CFEqual(top, mode))
			CFArrayRemoveValueAtIndex(gs_mode_stack, count - 1);
	}
	pthread_mutex_unlock(&gs_lock);
	CFRunLoopStop(CFRunLoopGetMain());
}

void GSEventRegisterEventCallBack(GSEventCallBack callback)
{
	gs_callback = callback;
}

uint64_t GSCurrentEventTimestamp(void)
{
	return mach_absolute_time();
}

Boolean GSEventIsHardwareKeyboardAttached(void)
{
	return gs_hardware_keyboard;
}

void GSEventSetHardwareKeyboardAttached(Boolean attached)
{
	gs_hardware_keyboard = attached;
}
