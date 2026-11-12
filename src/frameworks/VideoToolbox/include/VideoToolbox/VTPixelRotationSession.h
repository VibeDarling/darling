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

#ifndef _VTPIXELROTATIONSESSION_H_
#define _VTPIXELROTATIONSESSION_H_

#include <VideoToolbox/VTBase.h>
#include <VideoToolbox/VTErrors.h>
#include <VideoToolbox/VTSession.h>
#include <CoreVideo/CoreVideo.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef struct CF_BRIDGED_TYPE(id) OpaqueVTPixelRotationSession *VTPixelRotationSessionRef;

VT_EXPORT OSStatus VTPixelRotationSessionCreate(CFAllocatorRef allocator,
	CF_RETURNS_RETAINED VTPixelRotationSessionRef *pixelRotationSessionOut);
VT_EXPORT void VTPixelRotationSessionInvalidate(VTPixelRotationSessionRef session);
VT_EXPORT CFTypeID VTPixelRotationSessionGetTypeID(void);
VT_EXPORT OSStatus VTPixelRotationSessionRotateImage(VTPixelRotationSessionRef session,
	CVPixelBufferRef sourceBuffer, CVPixelBufferRef destinationBuffer);

VT_EXPORT const CFStringRef kVTPixelRotationPropertyKey_Rotation;
VT_EXPORT const CFStringRef kVTRotation_0;
VT_EXPORT const CFStringRef kVTRotation_CW90;
VT_EXPORT const CFStringRef kVTRotation_180;
VT_EXPORT const CFStringRef kVTRotation_CCW90;
VT_EXPORT const CFStringRef kVTPixelRotationPropertyKey_FlipHorizontalOrientation;
VT_EXPORT const CFStringRef kVTPixelRotationPropertyKey_FlipVerticalOrientation;

CF_IMPLICIT_BRIDGING_DISABLED

#endif
