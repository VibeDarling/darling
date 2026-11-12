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

/*
 * The OpenGL ES texture cache. Apple's binds a pixel buffer's IOSurface to a texture without a
 * copy; Darling's pixel buffers have no IOSurface for a GL driver to bind, so the cache cannot be
 * made and callers upload the pixels themselves (glTexImage2D), as they do without a cache.
 */

#include <CoreVideo/CVOpenGLESTextureCache.h>

CFTypeID CVOpenGLESTextureGetTypeID(void) { return 0; /* _kCFRuntimeNotATypeID: not CF types */ }
GLenum CVOpenGLESTextureGetTarget(CVOpenGLESTextureRef image) { return 0; }
GLuint CVOpenGLESTextureGetName(CVOpenGLESTextureRef image) { return 0; }
Boolean CVOpenGLESTextureIsFlipped(CVOpenGLESTextureRef image) { return false; }

void CVOpenGLESTextureGetCleanTexCoords(CVOpenGLESTextureRef image, GLfloat lowerLeft[2],
	GLfloat lowerRight[2], GLfloat upperRight[2], GLfloat upperLeft[2])
{
	lowerLeft[0] = 0; lowerLeft[1] = 0;
	lowerRight[0] = 1; lowerRight[1] = 0;
	upperRight[0] = 1; upperRight[1] = 1;
	upperLeft[0] = 0; upperLeft[1] = 1;
}

CFTypeID CVOpenGLESTextureCacheGetTypeID(void) { return 0; /* _kCFRuntimeNotATypeID: not CF types */ }

CVReturn CVOpenGLESTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes,
	CVEAGLContext eaglContext, CFDictionaryRef textureAttributes, CVOpenGLESTextureCacheRef *cacheOut)
{
	if (cacheOut == NULL || eaglContext == NULL)
		return kCVReturnInvalidArgument;
	*cacheOut = NULL;
	return kCVReturnUnsupported;
}

CVReturn CVOpenGLESTextureCacheCreateTextureFromImage(CFAllocatorRef allocator,
	CVOpenGLESTextureCacheRef textureCache, CVImageBufferRef sourceImage, CFDictionaryRef textureAttributes,
	GLenum target, GLint internalFormat, GLsizei width, GLsizei height, GLenum format, GLenum type,
	size_t planeIndex, CVOpenGLESTextureRef *textureOut)
{
	if (textureOut != NULL)
		*textureOut = NULL;
	return textureCache == NULL ? kCVReturnInvalidArgument : kCVReturnUnsupported;
}

void CVOpenGLESTextureCacheFlush(CVOpenGLESTextureCacheRef textureCache, CVOptionFlags options)
{
}
