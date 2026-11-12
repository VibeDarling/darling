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

#include "AudioHardwareStreamAAudio.h"
#include <CoreAudio/HostTime.h>
#include <alloca.h>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <iostream>

// DARLING_COREAUDIO_TRACE=1 logs each AAudio stream opened and closed.
static bool tracing()
{
	static const bool trace = getenv("DARLING_COREAUDIO_TRACE") != nullptr;
	return trace;
}

static bool isFloat(const AudioStreamBasicDescription& asbd)
{
	return asbd.mFormatFlags & kAudioFormatFlagIsFloat;
}

static bool isBigEndian(const AudioStreamBasicDescription& asbd)
{
	return asbd.mFormatFlags & kAudioFormatFlagIsBigEndian;
}

static UInt32 bytesPerSample(const AudioStreamBasicDescription& asbd)
{
	return asbd.mChannelsPerFrame ? asbd.mBytesPerFrame / asbd.mChannelsPerFrame : 0;
}

bool AudioHardwareStreamAAudio::supports(const AudioStreamBasicDescription& asbd)
{
	if (asbd.mFormatID != kAudioFormatLinearPCM || (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved))
		return false;
	if (asbd.mChannelsPerFrame < 1 || asbd.mChannelsPerFrame > 8 || asbd.mSampleRate < 4000 || asbd.mSampleRate > 192000)
		return false;
	if (isFloat(asbd))
		return asbd.mBitsPerChannel == 32;
	return asbd.mBitsPerChannel == 8 || asbd.mBitsPerChannel == 16 || asbd.mBitsPerChannel == 24 || asbd.mBitsPerChannel == 32;
}

AudioHardwareStreamAAudio::AudioHardwareStreamAAudio(AudioHardwareImplAAudioOutput* hw, AudioDeviceIOProc callback, void* clientData)
: AudioHardwareStream(hw, false), m_aaHw(hw), m_callback(callback), m_clientData(clientData),
	m_lib(AAudioLibrary::get()), m_asbd(hw->asbd())
{
	// The stream format AAudio takes as it is; anything else is converted to float.
	const bool native = !isBigEndian(m_asbd) && bytesPerSample(m_asbd) * 8 == m_asbd.mBitsPerChannel;
	if (native && isFloat(m_asbd))
		m_hostFormat = AAUDIO_FORMAT_PCM_FLOAT;
	else if (native && m_asbd.mBitsPerChannel == 16 && (m_asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger))
		m_hostFormat = AAUDIO_FORMAT_PCM_I16;
	else
		m_hostFormat = AAUDIO_FORMAT_PCM_FLOAT;
}

AudioHardwareStreamAAudio::~AudioHardwareStreamAAudio()
{
	{
		std::lock_guard<std::recursive_mutex> lock(m_mutex);
		m_running = false;
		m_rendering = false;
	}
	m_wake.notify_all();

	if (m_threadStarted)
	{
		// The IOProc may destroy its device itself, on the render thread.
		if (pthread_equal(pthread_self(), m_thread))
			pthread_detach(m_thread);
		else
			pthread_join(m_thread, nullptr);
	}
	else
		close();
}

void AudioHardwareStreamAAudio::start()
{
	if (!m_lib)
		return;

	std::lock_guard<std::recursive_mutex> lock(m_mutex);
	m_running = true;
	if (!m_threadStarted)
	{
		m_threadStarted = pthread_create(&m_thread, nullptr, renderThread, this) == 0;
		if (!m_threadStarted)
			std::cerr << "[CoreAudio AAudio] Cannot start the render thread\n";
	}
	m_wake.notify_all();
}

void AudioHardwareStreamAAudio::stop()
{
	// Waits for an IOProc call in progress on the render thread.
	std::lock_guard<std::recursive_mutex> lock(m_mutex);
	m_running = false;
	m_wake.notify_all();
}

bool AudioHardwareStreamAAudio::open()
{
	AAudioStreamBuilder* builder = nullptr;
	aaudio_result_t result = m_lib->createStreamBuilder(&builder);
	if (result != AAUDIO_OK)
	{
		std::cerr << "[CoreAudio AAudio] Cannot create a stream builder: " << m_lib->convertResultToText(result) << std::endl;
		return false;
	}

	m_lib->setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
	m_lib->setSharingMode(builder, AAUDIO_SHARING_MODE_SHARED);
	m_lib->setSampleRate(builder, int32_t(m_asbd.mSampleRate));
	m_lib->setChannelCount(builder, int32_t(m_asbd.mChannelsPerFrame));
	m_lib->setFormat(builder, m_hostFormat);
	if (m_lib->setUsage)
		m_lib->setUsage(builder, m_aaHw->usage());

	result = m_lib->openStream(builder, &m_stream);
	m_lib->deleteBuilder(builder);
	if (result != AAUDIO_OK)
	{
		std::cerr << "[CoreAudio AAudio] Cannot open an output stream (" << m_asbd.mSampleRate << " Hz, "
			<< m_asbd.mChannelsPerFrame << " channels): " << m_lib->convertResultToText(result) << std::endl;
		m_stream = nullptr;
		return false;
	}

	// AAudio resamples and remixes shared streams, so what was asked for is what it takes.
	const int32_t rate = m_lib->getSampleRate(m_stream), channels = m_lib->getChannelCount(m_stream);
	if (rate != int32_t(m_asbd.mSampleRate) || channels != int32_t(m_asbd.mChannelsPerFrame) || m_lib->getFormat(m_stream) != m_hostFormat)
	{
		std::cerr << "[CoreAudio AAudio] The output stream is " << rate << " Hz, " << channels
			<< " channels, not the format asked for\n";
		close();
		return false;
	}

	if (tracing())
		std::cerr << "[CoreAudio AAudio] Opened an output stream: " << rate << " Hz, " << channels << " channels, "
			<< (m_hostFormat == AAUDIO_FORMAT_PCM_FLOAT ? "float" : "16-bit") << std::endl;
	return true;
}

void AudioHardwareStreamAAudio::close()
{
	if (!m_stream)
		return;
	if (tracing())
		std::cerr << "[CoreAudio AAudio] Closing the output stream; the device read "
			<< m_lib->getFramesRead(m_stream) << " frames\n";
	m_lib->close(m_stream);
	m_stream = nullptr;
	m_streamStarted = false;
}

void* AudioHardwareStreamAAudio::renderThread(void* self)
{
	pthread_setname_np("CoreAudio render");
	static_cast<AudioHardwareStreamAAudio*>(self)->render();
	return nullptr;
}

void AudioHardwareStreamAAudio::render()
{
	const UInt32 bpf = m_asbd.mBytesPerFrame;
	const UInt32 frames = std::max<UInt32>(m_bufferSize / bpf, 64);
	const size_t hostBpf = m_asbd.mChannelsPerFrame * (m_hostFormat == AAUDIO_FORMAT_PCM_I16 ? sizeof(int16_t) : sizeof(float));
	std::vector<uint8_t> chunk(frames * bpf), host(frames * hostBpf);
	AudioBufferList* abl = static_cast<AudioBufferList*>(alloca(sizeof(AudioBufferList) + sizeof(AudioBuffer)));

	std::unique_lock<std::recursive_mutex> lock(m_mutex);
	while (m_rendering)
	{
		if (!m_running)
		{
			if (m_streamStarted)
			{
				m_lib->requestPause(m_stream);
				m_streamStarted = false;
			}
			m_wake.wait(lock, [this] { return m_running || !m_rendering; });
			continue;
		}

		if (!m_stream && !open())
		{
			m_wake.wait_for(lock, std::chrono::seconds(1));
			continue;
		}
		if (!m_streamStarted)
		{
			aaudio_result_t result = m_lib->requestStart(m_stream);
			if (result != AAUDIO_OK)
			{
				std::cerr << "[CoreAudio AAudio] Cannot start the output stream: " << m_lib->convertResultToText(result) << std::endl;
				close();
				m_wake.wait_for(lock, std::chrono::seconds(1));
				continue;
			}
			m_streamStarted = true;
		}

		AudioTimeStamp now = {};
		now.mFlags = kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid;
		now.mHostTime = AudioGetCurrentHostTime();
		now.mSampleTime = m_sampleTime;
		AudioTimeStamp outputTime = now;

		abl->mNumberBuffers = 1;
		abl->mBuffers[0].mNumberChannels = m_asbd.mChannelsPerFrame;
		abl->mBuffers[0].mData = chunk.data();
		abl->mBuffers[0].mDataByteSize = chunk.size();

		OSStatus status = m_callback(m_aaHw->id(), &now, nullptr, nullptr, abl, &outputTime, m_clientData);
		m_sampleTime += frames;

		UInt32 filled = status == noErr ? std::min<UInt32>(abl->mBuffers[0].mDataByteSize, chunk.size()) : 0;
		memset(chunk.data() + filled, 0, chunk.size() - filled);
		toHost(chunk.data(), frames, host.data());

		// The blocking write waits for room in AAudio's buffer: without the
		// lock, so that stop() need not wait for it.
		AAudioStream* stream = m_stream;
		lock.unlock();
		aaudio_result_t result = AAUDIO_OK;
		for (UInt32 done = 0; done < frames && m_running; )
		{
			result = m_lib->write(stream, host.data() + done * hostBpf, frames - done, 500 * 1000 * 1000LL);
			if (result < 0)
				break;
			done += result;
		}
		lock.lock();

		if (result < 0)
		{
			// Disconnected (headphones plugged or unplugged): a new stream goes to the new route.
			if (result != AAUDIO_ERROR_DISCONNECTED)
				std::cerr << "[CoreAudio AAudio] Writing failed: " << m_lib->convertResultToText(result) << std::endl;
			close();
		}
	}
	close();
}

template <typename T>
static T load(const uint8_t* p, bool bigEndian)
{
	T v;
	memcpy(&v, p, sizeof(v));
	if (bigEndian)
	{
		if constexpr (sizeof(T) == 2)
			v = __builtin_bswap16(v);
		else if constexpr (sizeof(T) == 4)
			v = __builtin_bswap32(v);
	}
	return v;
}

void AudioHardwareStreamAAudio::toHost(const uint8_t* in, UInt32 frames, void* out) const
{
	const size_t samples = size_t(frames) * m_asbd.mChannelsPerFrame;
	const UInt32 width = bytesPerSample(m_asbd);

	if (m_hostFormat == AAUDIO_FORMAT_PCM_I16 || (m_hostFormat == AAUDIO_FORMAT_PCM_FLOAT && isFloat(m_asbd) && !isBigEndian(m_asbd)))
	{
		memcpy(out, in, samples * width);
		return;
	}

	const bool be = isBigEndian(m_asbd);
	const bool isSigned = m_asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger;
	float* f = static_cast<float*>(out);

	for (size_t i = 0; i < samples; i++, in += width)
	{
		if (isFloat(m_asbd))
		{
			uint32_t bits = load<uint32_t>(in, be);
			memcpy(&f[i], &bits, sizeof(float));
			continue;
		}

		// The sample as a signed value, left-aligned in 32 bits.
		int32_t v;
		switch (m_asbd.mBitsPerChannel)
		{
			case 8:
				v = int32_t(uint32_t(in[0]) << 24);
				break;
			case 16:
				v = int32_t(uint32_t(load<uint16_t>(in, be)) << 16);
				break;
			case 24:
				if (width == 3)
					v = be ? int32_t(uint32_t(in[0]) << 24 | uint32_t(in[1]) << 16 | uint32_t(in[2]) << 8)
						: int32_t(uint32_t(in[2]) << 24 | uint32_t(in[1]) << 16 | uint32_t(in[0]) << 8);
				else // in the low bits of 32
					v = int32_t(load<uint32_t>(in, be) << 8);
				break;
			default:
				v = int32_t(load<uint32_t>(in, be));
				break;
		}
		if (!isSigned)
			v = int32_t(uint32_t(v) ^ 0x80000000u);
		f[i] = float(v) * (1.0f / 2147483648.0f);
	}
}
