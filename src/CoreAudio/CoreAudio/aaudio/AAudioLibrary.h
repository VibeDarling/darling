/*
This file is part of Darling.

Copyright (C) 2026 Darling Team

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

#ifndef AAUDIOLIBRARY_H
#define AAUDIOLIBRARY_H
#include <stdint.h>

// Android's AAudio (libaaudio.so), opened at run time: the Mach-O tree is the
// same for Linux and Android, and only Android has it. The values are those
// of the NDK's <aaudio/AAudio.h>.
typedef struct AAudioStreamStruct AAudioStream;
typedef struct AAudioStreamBuilderStruct AAudioStreamBuilder;
typedef int32_t aaudio_result_t;

enum
{
	AAUDIO_OK = 0,
	AAUDIO_ERROR_DISCONNECTED = -899,

	AAUDIO_DIRECTION_OUTPUT = 0,

	AAUDIO_FORMAT_PCM_I16 = 1,
	AAUDIO_FORMAT_PCM_FLOAT = 2,

	AAUDIO_SHARING_MODE_SHARED = 1,

	AAUDIO_USAGE_ASSISTANCE_SONIFICATION = 13,
	AAUDIO_USAGE_GAME = 14,
};

struct AAudioLibrary
{
	aaudio_result_t (*createStreamBuilder)(AAudioStreamBuilder** builder);
	void (*setDirection)(AAudioStreamBuilder* builder, int32_t direction);
	void (*setSharingMode)(AAudioStreamBuilder* builder, int32_t sharingMode);
	void (*setSampleRate)(AAudioStreamBuilder* builder, int32_t sampleRate);
	void (*setChannelCount)(AAudioStreamBuilder* builder, int32_t channelCount);
	void (*setFormat)(AAudioStreamBuilder* builder, int32_t format);
	void (*setUsage)(AAudioStreamBuilder* builder, int32_t usage); // Android 9; may be null
	aaudio_result_t (*openStream)(AAudioStreamBuilder* builder, AAudioStream** stream);
	aaudio_result_t (*deleteBuilder)(AAudioStreamBuilder* builder);

	aaudio_result_t (*requestStart)(AAudioStream* stream);
	aaudio_result_t (*requestPause)(AAudioStream* stream);
	aaudio_result_t (*close)(AAudioStream* stream);
	aaudio_result_t (*write)(AAudioStream* stream, const void* buffer, int32_t numFrames, int64_t timeoutNanoseconds);
	int32_t (*getSampleRate)(AAudioStream* stream);
	int32_t (*getChannelCount)(AAudioStream* stream);
	int32_t (*getFormat)(AAudioStream* stream);
	int64_t (*getFramesRead)(AAudioStream* stream);
	const char* (*convertResultToText)(aaudio_result_t result);

	// The host's AAudio, or null where there is none (Linux).
	static const AAudioLibrary* get();
};

#endif
