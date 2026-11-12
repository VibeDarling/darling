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

#ifndef COREVIDEO_CVOPENGLESTEXTURECACHE_H
#define COREVIDEO_CVOPENGLESTEXTURECACHE_H

#include <CoreVideo/CVBase.h>
#include <CoreVideo/CVReturn.h>
#include <CoreVideo/CVImageBuffer.h>
#include <CoreVideo/CVOpenGLESTexture.h>

#if defined(__OBJC__)
#import <OpenGLES/EAGL.h>
typedef EAGLContext *CVEAGLContext;
#else
typedef void *CVEAGLContext;
#endif

__BEGIN_DECLS

typedef struct CV_BRIDGED_TYPE(id) __CVOpenGLESTextureCache *CVOpenGLESTextureCacheRef;

CV_EXPORT const CFStringRef kCVOpenGLESTextureCacheMaximumTextureAgeKey;

CV_EXPORT CFTypeID CVOpenGLESTextureCacheGetTypeID(void);
CV_EXPORT CVReturn CVOpenGLESTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes,
	CVEAGLContext eaglContext, CFDictionaryRef textureAttributes, CVOpenGLESTextureCacheRef *cacheOut);
CV_EXPORT CVReturn CVOpenGLESTextureCacheCreateTextureFromImage(CFAllocatorRef allocator,
	CVOpenGLESTextureCacheRef textureCache, CVImageBufferRef sourceImage, CFDictionaryRef textureAttributes,
	GLenum target, GLint internalFormat, GLsizei width, GLsizei height, GLenum format, GLenum type,
	size_t planeIndex, CVOpenGLESTextureRef *textureOut);
CV_EXPORT void CVOpenGLESTextureCacheFlush(CVOpenGLESTextureCacheRef textureCache, CVOptionFlags options);

__END_DECLS

#endif
