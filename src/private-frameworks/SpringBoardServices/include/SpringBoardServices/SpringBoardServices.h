/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * SpringBoardServices: the C functions an app uses to ask SpringBoard about
 * installed applications. Apple never published this interface. Only the
 * functions a guest app is known to use are here, with the signatures that
 * app's own source declares; Darling answers from the installed bundles
 * through DarlingBoard.
 *
 * Provenance:
 * - Rung 5 (demand analysis): llvm-nm -u -m on Cydia's executable binds
 *   SBSSpringBoardServerPort, SBBundlePathForDisplayIdentifier,
 *   SBSCopyApplicationDisplayIdentifiers,
 *   SBSCopyLocalizedApplicationNameForDisplayIdentifier and
 *   SBSCopyIconImagePathForDisplayIdentifier from SpringBoardServices.
 * - Cydia's GPL source: iPhonePrivate.h declares those five (the signatures
 *   below); MobileCydia.mm looks up SBSCopyIconImagePNGDataForDisplayIdentifier,
 *   SBSSetInterceptsMenuButtonForever and SBReboot with dlsym and casts them
 *   to the types below, and shows how each result is used: a nonzero
 *   SBBundlePathForDisplayIdentifier result is failure, the path buffer is
 *   1024 bytes, the name and icon results are autoreleased by the caller.
 * Behaviour beyond that is Darling's (see each function).
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

/* Darling has no SpringBoard service port: MACH_PORT_NULL, which the
 * functions below that take a port accept and ignore. */
mach_port_t SBSSpringBoardServerPort(void);

/* Display identifiers are bundle identifiers. The results are returned
 * retained: the Core Foundation Create rule for "Copy" functions. */
NSArray *SBSCopyApplicationDisplayIdentifiers(bool active, bool debuggable);
NSString *SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
NSString *SBSCopyIconImagePathForDisplayIdentifier(NSString *identifier);
NSData *SBSCopyIconImagePNGDataForDisplayIdentifier(NSString *identifier);

/* Copies the bundle path into path (PATH_MAX, 1024, bytes); 0 on success. */
int SBBundlePathForDisplayIdentifier(mach_port_t port, const char *identifier, char *path);

/* Darling's home screen keeps the Home button: accepted and ignored. */
void SBSSetInterceptsMenuButtonForever(bool intercepts);

/* There is no device to reboot: does nothing. */
void SBReboot(mach_port_t port);

#ifdef __cplusplus
}
#endif

#endif /* SPRINGBOARDSERVICES_H */
