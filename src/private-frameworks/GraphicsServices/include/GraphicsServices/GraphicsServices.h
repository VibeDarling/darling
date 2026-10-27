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

#ifndef _GraphicsServices_H_
#define _GraphicsServices_H_

/* iOS GraphicsServices, best effort from class-dumped symbol names and
   public reverse-engineering. Since iOS 7 events go through BackBoard and
   IOHIDEvent, so what is left here is the run loop UIApplicationMain sits in
   and a few process-wide screen facts. */

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

#include <CoreGraphics/CGGeometry.h>

CF_EXTERN_C_BEGIN

typedef struct __GSEvent *GSEventRef;
typedef void (*GSEventCallBack)(GSEventRef event);

/* The mode GSEventRunModal runs the main run loop in. */
extern const CFStringRef kGSEventReceiveRunLoopMode;

void GSInitialize(void);
void GSEventInitialize(Boolean registerPurple);

/* Run the main run loop until GSEventStopModal; pushed modes take over while
   they are on top of the stack. */
void GSEventRunModal(Boolean disallowsRestarts);
void GSEventRun(void);
void GSEventStopModal(void);
void GSEventPushRunLoopMode(CFStringRef mode);
void GSEventPopRunLoopMode(CFStringRef mode);

/* No event source delivers GSEvents any more; the callback is kept so that
   callers can register one. */
void GSEventRegisterEventCallBack(GSEventCallBack callback);

/* mach_absolute_time() at the event currently being handled, or now. */
uint64_t GSCurrentEventTimestamp(void);

Boolean GSEventIsHardwareKeyboardAttached(void);
void GSEventSetHardwareKeyboardAttached(Boolean attached);

/* Screen facts, in points. Defaults to 1024x768 at scale 1, the same
   fallback UIScreen uses, until whoever owns the display sets them. */
void GSSetMainScreenInfo(CGSize size, CGFloat scale, int orientation);
CGSize GSMainScreenSize(void);
CGSize GSMainScreenPixelSize(void);
CGFloat GSMainScreenScaleFactor(void);
int GSMainScreenOrientation(void);

const char *GSSystemRootDirectory(void);

CF_EXTERN_C_END

#endif
