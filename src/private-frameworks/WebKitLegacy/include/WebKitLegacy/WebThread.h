/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef WEBKITLEGACY_WEBTHREAD_H
#define WEBKITLEGACY_WEBTHREAD_H

#include <stdbool.h>

#ifdef __OBJC__
@class NSInvocation;
#endif

/*
 * iOS WebKit runs pages on a "web thread" and apps take this lock to touch
 * them from the main thread.  Darling talks to its engine from the main
 * thread only, so this is a plain recursive lock kept for compatibility.
 */
#ifdef __cplusplus
extern "C" {
#endif
void WebThreadLock(void);
void WebThreadUnlock(void);
void WebThreadUnlockFromAnyThread(void);
bool WebThreadIsLocked(void);
bool WebThreadIsCurrent(void);
bool WebThreadNotCurrent(void);
bool WebThreadIsEnabled(void);
void WebThreadEnable(void);
void WebThreadRun(void (^block)(void));
#ifdef __OBJC__
NSInvocation *WebThreadCreateNSInvocation(id target, SEL selector);
void WebThreadCallAPI(NSInvocation *invocation);
#endif
#ifdef __cplusplus
}
#endif

#endif
