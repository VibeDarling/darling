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

#include "AAudioLibrary.h"
#include <dispatch/dispatch.h>
#include <elfcalls.h>
#include <type_traits>

extern "C" struct elf_calls* _elfcalls;

static bool load(AAudioLibrary* lib)
{
	void* handle = _elfcalls->dlopen("libaaudio.so");
	if (!handle)
		return false;

	bool complete = true;
	auto symbol = [&](auto& fn, const char* name, bool required = true) {
		fn = reinterpret_cast<std::remove_reference_t<decltype(fn)>>(_elfcalls->dlsym(handle, name));
		if (!fn && required)
			complete = false;
	};

	symbol(lib->createStreamBuilder, "AAudio_createStreamBuilder");
	symbol(lib->setDirection, "AAudioStreamBuilder_setDirection");
	symbol(lib->setSharingMode, "AAudioStreamBuilder_setSharingMode");
	symbol(lib->setSampleRate, "AAudioStreamBuilder_setSampleRate");
	symbol(lib->setChannelCount, "AAudioStreamBuilder_setChannelCount");
	symbol(lib->setFormat, "AAudioStreamBuilder_setFormat");
	symbol(lib->setUsage, "AAudioStreamBuilder_setUsage", false);
	symbol(lib->openStream, "AAudioStreamBuilder_openStream");
	symbol(lib->deleteBuilder, "AAudioStreamBuilder_delete");
	symbol(lib->requestStart, "AAudioStream_requestStart");
	symbol(lib->requestPause, "AAudioStream_requestPause");
	symbol(lib->close, "AAudioStream_close");
	symbol(lib->write, "AAudioStream_write");
	symbol(lib->getSampleRate, "AAudioStream_getSampleRate");
	symbol(lib->getChannelCount, "AAudioStream_getChannelCount");
	symbol(lib->getFormat, "AAudioStream_getFormat");
	symbol(lib->getFramesRead, "AAudioStream_getFramesRead");
	symbol(lib->convertResultToText, "AAudio_convertResultToText");

	if (!complete)
		_elfcalls->dlclose(handle);
	return complete;
}

const AAudioLibrary* AAudioLibrary::get()
{
	static AAudioLibrary lib;
	static bool loaded;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		loaded = load(&lib);
	});
	return loaded ? &lib : nullptr;
}
