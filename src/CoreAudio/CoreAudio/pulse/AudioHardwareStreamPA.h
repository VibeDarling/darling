/*
This file is part of Darling.

Copyright (C) 2020 Lubos Dolezel

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

#ifndef AUDIOHARDWARESTREAMPA_H
#define AUDIOHARDWARESTREAMPA_H
#include "../AudioHardwareStream.h"
#include <pulse/pulseaudio.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreAudio/AudioHardware.h>
#include <CoreAudio/HostTime.h>
#include "AudioHardwareImplPA.h"
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <vector>
#include <pthread.h>

class AudioHardwareStreamPA : public AudioHardwareStream
{
public:
	AudioHardwareStreamPA(AudioHardwareImplPA* hw, AudioDeviceIOProc callback, void* clientData, bool isInput = false);
	~AudioHardwareStreamPA();

	void start() override;
	void stop(/*void(^cbDone)()*/) override;
protected:
	void transformSignedUnsigned(AudioBufferList* abl) const;
	static void paStreamWriteCB(pa_stream* s, size_t length, void* self);
	static void paStreamReadCB(pa_stream* s, size_t length, void* self);
protected:
	AudioHardwareImplPA* m_paHw = nullptr;
	AudioDeviceIOProc m_callback;
	void* m_clientData;
	pa_stream* m_stream = nullptr;
	bool m_convertSignedUnsigned = false;
	bool m_isInput = false;

	std::atomic<bool> m_running{false};
	Float64 m_sampleTime = 0.0;

	static void* ioThreadEntry(void* arg);
	void runIOThread();

	pthread_t m_ioThread = 0;
	std::atomic<bool> m_ioThreadRunning{false};

	std::vector<uint8_t> m_ringBuffer;
	size_t m_ringHead = 0;
	size_t m_ringTail = 0;
	size_t m_ringCount = 0;
	std::mutex m_ringMutex;
	std::condition_variable m_ringCvRead;
	std::condition_variable m_ringCvWrite;

	size_t ringWrite(const uint8_t* data, size_t size);
	size_t ringRead(uint8_t* data, size_t size);
};

#endif /* AUDIOHARDWARESTREAMPA_H */

