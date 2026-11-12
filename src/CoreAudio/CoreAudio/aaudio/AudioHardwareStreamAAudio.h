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

#ifndef AUDIOHARDWARESTREAMAAUDIO_H
#define AUDIOHARDWARESTREAMAAUDIO_H
#include "../AudioHardwareStream.h"
#include "AudioHardwareImplAAudio.h"
#include "AAudioLibrary.h"
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreAudio/AudioHardware.h>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <vector>
#include <pthread.h>

// Output to an AAudio stream. A thread of ours calls the IOProc a period at a
// time and writes the result with AAudio's blocking write, which paces it. No
// AAudio callback is used: they run on threads that are not Darwin threads,
// where Darwin code (the IOProc, malloc, locks) must not run.
class AudioHardwareStreamAAudio : public AudioHardwareStream
{
public:
	AudioHardwareStreamAAudio(AudioHardwareImplAAudioOutput* hw, AudioDeviceIOProc callback, void* clientData);
	~AudioHardwareStreamAAudio();

	void start() override;
	void stop() override;

	// Formats the IOProc may render in: interleaved linear PCM, integer or float.
	static bool supports(const AudioStreamBasicDescription& asbd);
private:
	static void* renderThread(void* self);
	void render();
	bool open();
	void close();
	// The IOProc's frames in the AAudio stream's format (I16 or float).
	void toHost(const uint8_t* in, UInt32 frames, void* out) const;
private:
	AudioHardwareImplAAudioOutput* m_aaHw;
	AudioDeviceIOProc m_callback;
	void* m_clientData;
	const AAudioLibrary* m_lib;
	AudioStreamBasicDescription m_asbd;

	AAudioStream* m_stream = nullptr;
	bool m_streamStarted = false;
	int32_t m_hostFormat = 0;

	// Held while the IOProc runs, so that once stop() returns it is not called
	// again until start(). Recursive: the IOProc may stop the device itself.
	std::recursive_mutex m_mutex;
	std::condition_variable_any m_wake;
	std::atomic<bool> m_running{false};
	bool m_rendering = true;
	pthread_t m_thread;
	bool m_threadStarted = false;
	Float64 m_sampleTime = 0;
};

#endif
