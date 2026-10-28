/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * SpringBoardServices: the C functions apps (package managers, settings
 * panes, tweaks) use to ask SpringBoard about installed applications and to
 * launch them.  Apple never published this interface; the signatures are the
 * ones jailbreak software has used for years (Cydia's iPhonePrivate.h, the
 * iOS runtime headers).  Darling answers from the installed bundles, as
 * FrontBoardServices does, and launches through frontboardd.
 */

#ifndef SPRINGBOARDSERVICES_H
#define SPRINGBOARDSERVICES_H

#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach.h>
#include <stdbool.h>

#ifdef __OBJC__
@class NSArray, NSData, NSString;
#else
typedef struct objc_object NSArray;
typedef struct objc_object NSData;
typedef struct objc_object NSString;
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* A send right to SpringBoard's service port, or MACH_PORT_NULL. */
mach_port_t SBSSpringBoardServerPort(void);

/* Display identifiers are bundle identifiers.  The arrays and strings are
 * returned retained (the Create rule). */
NSArray *SBSCopyApplicationDisplayIdentifiers(bool onlyActive, bool debuggable);
NSString *SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
NSString *SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);
NSData *SBSCopyIconImagePNGDataForDisplayIdentifier(NSString *identifier);
NSString *SBSCopyBundlePathForDisplayIdentifier(NSString *identifier);
NSString *SBSCopyExecutablePathForDisplayIdentifier(NSString *identifier);
NSString *SBSCopyFrontmostApplicationDisplayIdentifier(void);

/* Copies the bundle path into path (PATH_MAX bytes); 0 on success. */
int SBBundlePathForDisplayIdentifier(mach_port_t port, const char *identifier, char *path);

/* 0 on success. */
int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);
int SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFStringRef identifier, CFDictionaryRef options, Boolean suspended);
bool SBSOpenSensitiveURLAndUnlock(CFURLRef url, bool unlock);

/* Darling's SpringBoard keeps the Home button; these are accepted and ignored. */
void SBSSetInterceptsMenuButtonForever(bool intercepts);
void SBSSuspendFrontmostApplication(void);

/* There is no device to reboot: these return an error (nonzero). */
int SBReboot(mach_port_t port);
int SBShutDown(mach_port_t port);

#ifdef __cplusplus
}
#endif

#endif /* SPRINGBOARDSERVICES_H */
