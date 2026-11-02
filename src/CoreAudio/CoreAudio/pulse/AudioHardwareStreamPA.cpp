/*
This file is part of Darling.

Copyright (C) 2020 Lubos Dolezel
Copyright (C) 2026 VibeDarling Project

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

#include "AudioHardwareStreamPA.h"
#include "AudioHardwareImplPA.h"
#include <iostream>
#include <algorithm>
#include <cstring>
#include <vector>
#include <type_traits>
#include <limits>

AudioHardwareStreamPA::AudioHardwareStreamPA(AudioHardwareImplPA* hw, AudioDeviceIOProc callback, void* clientData, bool isInput)
: AudioHardwareStream(hw, isInput), m_paHw(hw), m_callback(callback), m_clientData(clientData), m_isInput(isInput)
{
	m_ringBuffer.resize(65536);
	hw->getPAContext(^(pa_context* context) {
		if (!context)
		{
			std::cerr << "[CoreAudio PA] Failed to get PulseAudio context\n";
			return;
		}
		
		pa_sample_spec spec = AudioHardwareImplPA::paSampleSpecForASBD(hw->asbd(), &m_convertSignedUnsigned);
		
		if (!pa_sample_spec_valid(&spec))
		{
			std::cerr << "[CoreAudio PA] Failed to create a valid pa_sample_spec\n";
			return;
		}

		PAThreadedMainLoop* loop = hw->loop();
		if (loop) loop->lock();

		m_stream = pa_stream_new(context, isInput ? "CoreAudio Input" : "CoreAudio Output", &spec, nullptr);
		if (!m_stream)
		{
			std::cerr << "[CoreAudio PA] pa_stream_new failed\n";
			if (loop) loop->unlock();
			return;
		}

		pa_stream_set_state_callback(m_stream, [](pa_stream *s, void *userdata) {
			AudioHardwareStreamPA* This = static_cast<AudioHardwareStreamPA*>(userdata);
			pa_stream_state_t state = pa_stream_get_state(s);
			if (state == PA_STREAM_READY)
			{
				if (This->m_running)
				{
					pa_operation* op = pa_stream_cork(s, 0, nullptr, nullptr);
					if (op) pa_operation_unref(op);
					pa_operation* op2 = pa_stream_trigger(s, nullptr, nullptr);
					if (op2) pa_operation_unref(op2);
				}
			}
			else if (state == PA_STREAM_FAILED)
			{
				std::cerr << "[CoreAudio PA] PulseAudio stream failed: " << pa_strerror(pa_context_errno(pa_stream_get_context(s))) << std::endl;
			}
			if (This->m_paHw && This->m_paHw->loop())
				This->m_paHw->loop()->signal(0);
		}, this);

		if (!isInput)
		{
			struct pa_buffer_attr battr;
			battr.fragsize = uint32_t(-1);
			battr.maxlength = uint32_t(-1);
			battr.minreq = uint32_t(-1);
			battr.prebuf = 0;
			battr.tlength = uint32_t(-1);

			pa_cvolume cvol;
			pa_cvolume_set(&cvol, spec.channels, PA_VOLUME_NORM);

			pa_stream_set_write_callback(m_stream, paStreamWriteCB, this);

			pa_stream_connect_playback(m_stream, nullptr, &battr,
				pa_stream_flags_t(PA_STREAM_INTERPOLATE_TIMING | PA_STREAM_ADJUST_LATENCY | PA_STREAM_AUTO_TIMING_UPDATE | PA_STREAM_START_UNMUTED),
				&cvol, nullptr);
		}
		else
		{
			struct pa_buffer_attr battr;
			battr.fragsize = uint32_t(-1);
			battr.maxlength = uint32_t(m_bufferSize);
			battr.minreq = uint32_t(-1);
			battr.prebuf = battr.maxlength;
			battr.tlength = uint32_t(-1);

			pa_stream_set_read_callback(m_stream, paStreamReadCB, this);

			pa_stream_connect_record(m_stream, nullptr, &battr,
				pa_stream_flags_t(PA_STREAM_INTERPOLATE_TIMING | PA_STREAM_ADJUST_LATENCY | PA_STREAM_AUTO_TIMING_UPDATE)
			);
		}

		if (loop) loop->unlock();
	});
}

AudioHardwareStreamPA::~AudioHardwareStreamPA()
{
	stop();

	PAThreadedMainLoop* loop = m_paHw ? m_paHw->loop() : nullptr;
	if (loop) loop->lock();

	if (m_stream)
	{
		pa_stream_disconnect(m_stream);
		pa_stream_unref(m_stream);
		m_stream = nullptr;
	}

	if (loop) loop->unlock();
}

size_t AudioHardwareStreamPA::ringWrite(const uint8_t* data, size_t size)
{
	std::unique_lock<std::mutex> lock(m_ringMutex);
	size_t written = 0;
	while (written < size)
	{
		size_t space = m_ringBuffer.size() - m_ringCount;
		if (space == 0)
			break;
		size_t chunk = std::min(size - written, std::min(space, m_ringBuffer.size() - m_ringHead));
		memcpy(&m_ringBuffer[m_ringHead], data + written, chunk);
		m_ringHead = (m_ringHead + chunk) % m_ringBuffer.size();
		m_ringCount += chunk;
		written += chunk;
	}
	m_ringCvRead.notify_one();
	return written;
}

size_t AudioHardwareStreamPA::ringRead(uint8_t* data, size_t size)
{
	std::unique_lock<std::mutex> lock(m_ringMutex);
	size_t read_bytes = 0;
	while (read_bytes < size && m_ringCount > 0)
	{
		size_t chunk = std::min(size - read_bytes, std::min(m_ringCount, m_ringBuffer.size() - m_ringTail));
		memcpy(data + read_bytes, &m_ringBuffer[m_ringTail], chunk);
		m_ringTail = (m_ringTail + chunk) % m_ringBuffer.size();
		m_ringCount -= chunk;
		read_bytes += chunk;
	}
	m_ringCvWrite.notify_one();
	return read_bytes;
}

void* AudioHardwareStreamPA::ioThreadEntry(void* arg)
{
	static_cast<AudioHardwareStreamPA*>(arg)->runIOThread();
	return nullptr;
}

void AudioHardwareStreamPA::runIOThread()
{
	size_t bufSize = m_bufferSize ? m_bufferSize : 2048;
	std::vector<uint8_t> tmp(bufSize);
	std::vector<uint8_t> ablMem(sizeof(AudioBufferList) + sizeof(AudioBuffer));
	AudioBufferList* abl = reinterpret_cast<AudioBufferList*>(ablMem.data());

	while (m_running.load(std::memory_order_relaxed) && m_ioThreadRunning.load(std::memory_order_relaxed))
	{
		{
			std::unique_lock<std::mutex> lock(m_ringMutex);
			m_ringCvWrite.wait_for(lock, std::chrono::milliseconds(20), [this, bufSize]() {
				return !m_running.load(std::memory_order_relaxed) ||
				       !m_ioThreadRunning.load(std::memory_order_relaxed) ||
				       (m_ringBuffer.size() - m_ringCount >= bufSize);
			});
		}
		if (!m_running.load(std::memory_order_acquire) || !m_ioThreadRunning.load(std::memory_order_acquire))
			break;

		AudioTimeStamp nowTs = {0};
		nowTs.mFlags = kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid;
		nowTs.mHostTime = AudioGetCurrentHostTime();
		nowTs.mSampleTime = m_sampleTime;
		AudioTimeStamp outTs = nowTs;

		abl->mNumberBuffers = 1;
		abl->mBuffers[0].mNumberChannels = m_paHw->asbd().mChannelsPerFrame ? m_paHw->asbd().mChannelsPerFrame : 2;
		abl->mBuffers[0].mData = tmp.data();
		abl->mBuffers[0].mDataByteSize = bufSize;

		OSStatus status = m_callback(m_paHw->id(), &nowTs, nullptr, nullptr, abl, &outTs, m_clientData);

		UInt32 bpf = m_paHw->asbd().mBytesPerFrame ? m_paHw->asbd().mBytesPerFrame : 4;
		m_sampleTime += (Float64)(bufSize / bpf);

		if (status != noErr || !abl->mBuffers[0].mDataByteSize)
		{
			memset(tmp.data(), 0, bufSize);
		}
		else if (abl->mBuffers[0].mDataByteSize < bufSize)
		{
			memset(tmp.data() + abl->mBuffers[0].mDataByteSize, 0, bufSize - abl->mBuffers[0].mDataByteSize);
		}

		if (m_convertSignedUnsigned)
			transformSignedUnsigned(abl);

		ringWrite(tmp.data(), bufSize);
	}
}

void AudioHardwareStreamPA::start()
{
	PAThreadedMainLoop* loop = m_paHw ? m_paHw->loop() : nullptr;
	if (loop) loop->lock();

	m_running.store(true, std::memory_order_release);
	if (m_stream)
	{
		int waitCycles = 20; // 20 * 50ms = 1000ms max wait
		while (pa_stream_get_state(m_stream) == PA_STREAM_CREATING && waitCycles-- > 0)
		{
			if (loop) loop->wait();
			else break;
		}
		if (pa_stream_get_state(m_stream) == PA_STREAM_READY)
		{
			pa_operation* op = pa_stream_cork(m_stream, 0, nullptr, nullptr);
			if (op) pa_operation_unref(op);
			pa_operation* op2 = pa_stream_trigger(m_stream, nullptr, nullptr);
			if (op2) pa_operation_unref(op2);
		}
	}

	if (loop) loop->unlock();

	if (!m_isInput && !m_ioThreadRunning.load(std::memory_order_acquire))
	{
		m_ioThreadRunning.store(true, std::memory_order_release);
		pthread_create(&m_ioThread, nullptr, ioThreadEntry, this);
	}
}

void AudioHardwareStreamPA::stop()
{
	PAThreadedMainLoop* loop = m_paHw ? m_paHw->loop() : nullptr;
	if (loop) loop->lock();

	if (m_stream && pa_stream_get_state(m_stream) == PA_STREAM_READY)
	{
		pa_stream_cork(m_stream, true, nullptr, nullptr);
	}

	if (loop) loop->unlock();

	if (m_ioThreadRunning.load(std::memory_order_acquire))
	{
		{
			std::unique_lock<std::mutex> lock(m_ringMutex);
			m_ioThreadRunning.store(false, std::memory_order_release);
			m_running.store(false, std::memory_order_release);
			m_ringCvWrite.notify_all();
			m_ringCvRead.notify_all();
		}
		pthread_join(m_ioThread, nullptr);
		m_ioThread = 0;
	}
}

void AudioHardwareStreamPA::paStreamWriteCB(pa_stream* s, size_t length, void* self)
{
	AudioHardwareStreamPA* This = static_cast<AudioHardwareStreamPA*>(self);
	if (!This)
		return;

	if (!This->m_running.load(std::memory_order_relaxed))
	{
		uint8_t zeroChunk[4096] = {0};
		size_t done = 0;
		while (done < length)
		{
			size_t rqsize = std::min<size_t>(sizeof(zeroChunk), length - done);
			if (pa_stream_write(This->m_stream, zeroChunk, rqsize, nullptr, 0, PA_SEEK_RELATIVE) < 0)
				break;
			done += rqsize;
		}
		return;
	}

	if (pa_stream_is_corked(This->m_stream))
	{
		pa_operation* op = pa_stream_cork(This->m_stream, 0, nullptr, nullptr);
		if (op) pa_operation_unref(op);
		pa_operation* op2 = pa_stream_trigger(This->m_stream, nullptr, nullptr);
		if (op2) pa_operation_unref(op2);
	}

	uint8_t chunk[4096];
	size_t done = 0;

	while (done < length && This->m_running.load(std::memory_order_relaxed))
	{
		size_t rqsize = std::min<size_t>(sizeof(chunk), length - done);
		size_t got = This->ringRead(chunk, rqsize);
		if (got < rqsize)
		{
			memset(chunk + got, 0, rqsize - got);
		}

		int rv = pa_stream_write(This->m_stream, chunk, rqsize, nullptr, 0, PA_SEEK_RELATIVE);
		if (rv < 0)
			break;

		done += rqsize;
	}
}

void AudioHardwareStreamPA::paStreamReadCB(pa_stream* s, size_t length, void* self)
{
	AudioHardwareStreamPA* This = static_cast<AudioHardwareStreamPA*>(self);

	if (!This || !This->m_running.load(std::memory_order_relaxed))
		return;

	AudioTimeStamp fake = {0};
	fake.mFlags = kAudioTimeStampHostTimeValid;
	fake.mHostTime = AudioGetCurrentHostTime();

	std::vector<uint8_t> ablMem(sizeof(AudioBufferList) + sizeof(AudioBuffer));
	AudioBufferList* abl = reinterpret_cast<AudioBufferList*>(ablMem.data());
	std::vector<uint8_t> hole;

	while (true)
	{
		abl->mNumberBuffers = 1;
		abl->mBuffers[0].mNumberChannels = This->m_paHw->asbd().mChannelsPerFrame ? This->m_paHw->asbd().mChannelsPerFrame : 2;

		size_t nbytes = 0;
		const void* pdata = nullptr;

		int rv = pa_stream_peek(This->m_stream, &pdata, &nbytes);

		if (rv < 0 || !nbytes)
		{
			break;
		}

		if (pdata)
		{
			hole.resize(nbytes);
			memcpy(hole.data(), pdata, nbytes);
			abl->mBuffers[0].mData = hole.data();
		}
		else
		{
			hole.assign(nbytes, 0);
			abl->mBuffers[0].mData = hole.data();
		}
		abl->mBuffers[0].mDataByteSize = nbytes;

		if (This->m_convertSignedUnsigned)
			This->transformSignedUnsigned(abl);

		OSStatus status = This->m_callback(This->m_paHw->id(), &fake, abl, &fake, nullptr, nullptr, This->m_clientData);

		pa_stream_drop(This->m_stream);

		if (status != noErr)
		{
			pa_stream_cork(This->m_stream, true, nullptr, nullptr);
			break;
		}
	}
}

template <typename T>
void transform(typename std::make_unsigned<T>::type* data)
{
	typedef typename std::make_unsigned<T>::type unsigned_type;
	constexpr unsigned_type msb = static_cast<unsigned_type>(1) << (sizeof(unsigned_type) * 8 - 1);
	*data ^= msb;
}

void AudioHardwareStreamPA::transformSignedUnsigned(AudioBufferList* abl) const
{
	const AudioStreamBasicDescription& asbd = m_paHw->asbd();
	const bool revEndian = (asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) != (asbd.mFormatFlags & kAudioFormatFlagsNativeEndian);

	for (int i = 0; i < abl->mNumberBuffers; i++)
	{
		AudioBuffer* buf = &abl->mBuffers[i];

		switch (asbd.mBitsPerChannel)
		{
			case 8:
				for (int j = 0; j < buf->mDataByteSize; j++)
					transform<uint8_t>(reinterpret_cast<uint8_t*>(buf->mData) + j);
				break;
			case 16:
				if (!revEndian)
				{
					for (int j = 0; j < buf->mDataByteSize / sizeof(uint16_t); j++)
						transform<uint16_t>(reinterpret_cast<uint16_t*>(buf->mData) + j);
				}
				else
				{
					for (int j = 0; j < buf->mDataByteSize / sizeof(uint16_t); j++)
					{
						uint16_t v = __builtin_bswap16(*(reinterpret_cast<uint16_t*>(buf->mData) + j));
						transform<uint16_t>(&v);
						*(reinterpret_cast<uint16_t*>(buf->mData) + j) = __builtin_bswap16(v);
					}
				}
				break;
			case 24:
				for (size_t j = 0; j + 3 <= buf->mDataByteSize; j += 3)
				{
					uint8_t* p = reinterpret_cast<uint8_t*>(buf->mData) + j;
					uint32_t v;
					if (!revEndian)
						v = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
					else
						v = ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | (uint32_t)p[2];

					if (v & 0x800000)
						v |= 0xff000000;

					transform<uint32_t>(&v);

					if (!revEndian)
					{
						p[0] = v & 0xff;
						p[1] = (v >> 8) & 0xff;
						p[2] = (v >> 16) & 0xff;
					}
					else
					{
						p[0] = (v >> 16) & 0xff;
						p[1] = (v >> 8) & 0xff;
						p[2] = v & 0xff;
					}
				}
				break;
			case 32:
				if (!revEndian)
				{
					for (int j = 0; j < buf->mDataByteSize / sizeof(uint32_t); j++)
						transform<uint32_t>(reinterpret_cast<uint32_t*>(buf->mData) + j);
				}
				else
				{
					for (int j = 0; j < buf->mDataByteSize / sizeof(uint32_t); j++)
					{
						uint32_t v = __builtin_bswap32(*(reinterpret_cast<uint32_t*>(buf->mData) + j));
						transform<uint32_t>(&v);
						*(reinterpret_cast<uint32_t*>(buf->mData) + j) = __builtin_bswap32(v);
					}
				}
				break;
		}
	}
}
