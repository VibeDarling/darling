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

#ifndef COREVIDEO_CVOPENGLESTEXTURE_H
#define COREVIDEO_CVOPENGLESTEXTURE_H

#include <CoreVideo/CVImageBuffer.h>
#include <OpenGLES/gltypes.h>

__BEGIN_DECLS

typedef CVImageBufferRef CVOpenGLESTextureRef;

CV_EXPORT CFTypeID CVOpenGLESTextureGetTypeID(void);
CV_EXPORT GLenum CVOpenGLESTextureGetTarget(CVOpenGLESTextureRef image);
CV_EXPORT GLuint CVOpenGLESTextureGetName(CVOpenGLESTextureRef image);
CV_EXPORT Boolean CVOpenGLESTextureIsFlipped(CVOpenGLESTextureRef image);
CV_EXPORT void CVOpenGLESTextureGetCleanTexCoords(CVOpenGLESTextureRef image, GLfloat lowerLeft[2],
	GLfloat lowerRight[2], GLfloat upperRight[2], GLfloat upperLeft[2]);

__END_DECLS

#endif
