#include "AudioQueueOutput.h"
#include <CarbonCore/MacErrors.h>
#include <iostream>
#include <algorithm>
#include <cstring>

AudioQueueOutput::AudioQueueOutput(const AudioStreamBasicDescription *inFormat,
		AudioQueueOutputCallback inCallbackProc,
		void *inUserData, CFRunLoopRef inCallbackRunLoop,
		CFStringRef inCallbackRunLoopMode, UInt32 inFlags)
: AudioQueue(inFormat, inUserData, inCallbackRunLoop, inCallbackRunLoopMode, inFlags),
  m_callback(inCallbackProc)
{
}

AudioQueueOutput::~AudioQueueOutput()
{
	stop(true);
	if (m_outputDevice && m_ioProcID)
	{
		AudioDeviceDestroyIOProcID(m_outputDevice, m_ioProcID);
		m_ioProcID = nullptr;
	}
}

OSStatus AudioQueueOutput::create(const AudioStreamBasicDescription *inFormat,
		AudioQueueOutputCallback inCallbackProc,
		void *inUserData, CFRunLoopRef inCallbackRunLoop,
		CFStringRef inCallbackRunLoopMode, UInt32 inFlags,
		AudioQueueOutput** newQueue)
{
	if (!inFormat || !newQueue)
		return paramErr;

	*newQueue = new AudioQueueOutput(inFormat, inCallbackProc, inUserData,
			inCallbackRunLoop, inCallbackRunLoopMode, inFlags);
	return noErr;
}

OSStatus AudioQueueOutput::start(const AudioTimeStamp *inStartTime)
{
	std::unique_lock<std::recursive_mutex> lock(m_mutex);

	if (m_running && !m_paused)
		return noErr;

	if (m_paused)
	{
		m_paused = false;
		return noErr;
	}

	UInt32 propSize = sizeof(AudioDeviceID);
	OSStatus status = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &propSize, &m_outputDevice);
	if (status != noErr || m_outputDevice == 0)
	{
		std::cerr << "[AudioQueue] Failed to get default output device\n";
		return kAudioHardwareBadDeviceError;
	}

	// Try to set device stream format to match the AudioQueue's format before creating the IOProc
	AudioDeviceSetProperty(m_outputDevice, nullptr, 0, false,
			kAudioDevicePropertyStreamFormat, sizeof(m_format), &m_format);

	status = AudioDeviceCreateIOProcID(m_outputDevice, ioProcCallback, this, &m_ioProcID);
	if (status != noErr)
	{
		std::cerr << "[AudioQueue] AudioDeviceCreateIOProcID failed: " << status << "\n";
		return status;
	}

	status = AudioDeviceStart(m_outputDevice, m_ioProcID);
	if (status != noErr)
	{
		std::cerr << "[AudioQueue] AudioDeviceStart failed: " << status << "\n";
		AudioDeviceDestroyIOProcID(m_outputDevice, m_ioProcID);
		m_ioProcID = nullptr;
		return status;
	}

	m_running = true;
	m_paused = false;
	return noErr;
}

OSStatus AudioQueueOutput::prime(UInt32 inNumberOfFramesToPrepare, UInt32 *outNumberOfFramesPrepared)
{
	if (outNumberOfFramesPrepared)
		*outNumberOfFramesPrepared = inNumberOfFramesToPrepare;
	return noErr;
}

OSStatus AudioQueueOutput::flush()
{
	return noErr;
}

OSStatus AudioQueueOutput::stop(Boolean inImmediate)
{
	std::vector<AudioQueueBufferRef> toReturn;
	{
		std::unique_lock<std::recursive_mutex> lock(m_mutex);
		if (!m_running)
			return noErr;

		m_running = false;
		m_paused = false;

		if (m_outputDevice && m_ioProcID)
		{
			AudioDeviceStop(m_outputDevice, m_ioProcID);
		}

		if (inImmediate)
		{
			while (!m_buffers.empty())
			{
				toReturn.push_back(m_buffers.front().buf);
				m_buffers.pop_front();
			}
		}
	}

	for (AudioQueueBufferRef buf : toReturn)
	{
		if (m_callback)
			m_callback(m_userData, this, buf);
	}

	return noErr;
}

OSStatus AudioQueueOutput::pause()
{
	std::unique_lock<std::recursive_mutex> lock(m_mutex);
	m_paused = true;
	return noErr;
}

OSStatus AudioQueueOutput::reset()
{
	return stop(true);
}

OSStatus AudioQueueOutput::dispose(Boolean inImmediate)
{
	stop(inImmediate);
	if (m_outputDevice && m_ioProcID)
	{
		AudioDeviceDestroyIOProcID(m_outputDevice, m_ioProcID);
		m_ioProcID = nullptr;
	}
	delete this;
	return noErr;
}

OSStatus AudioQueueOutput::setOfflineRenderFormat(const AudioStreamBasicDescription *inFormat, const AudioChannelLayout *inLayout)
{
	return noErr;
}

OSStatus AudioQueueOutput::offlineRender(const AudioTimeStamp *inTimestamp, AudioQueueBufferRef ioBuffer, UInt32 inNumberFrames)
{
	return unimpErr;
}

OSStatus AudioQueueOutput::enqueueBuffer(AudioQueueBufferRef inBuffer,
		UInt32 inNumPacketDescs, const AudioStreamPacketDescription *inPacketDescs)
{
	if (!inBuffer)
		return paramErr;

	std::unique_lock<std::recursive_mutex> lock(m_mutex);
	m_buffers.push_back({inBuffer, 0});
	return noErr;
}

OSStatus AudioQueueOutput::ioProcCallback(AudioObjectID inDevice,
		const AudioTimeStamp* inNow, const AudioBufferList* inInputData,
		const AudioTimeStamp* inInputTime,
		AudioBufferList* outOutputData, const AudioTimeStamp* inOutputTime,
		void* inClientData)
{
	AudioQueueOutput* This = static_cast<AudioQueueOutput*>(inClientData);
	return This->fillOutput(outOutputData);
}

OSStatus AudioQueueOutput::fillOutput(AudioBufferList* outOutputData)
{
	if (!outOutputData || outOutputData->mNumberBuffers == 0)
		return noErr;

	void* pdata = outOutputData->mBuffers[0].mData;
	size_t requestedBytes = outOutputData->mBuffers[0].mDataByteSize;
	if (!pdata || requestedBytes == 0)
		return noErr;

	std::vector<AudioQueueBufferRef> completed;

	{
		std::unique_lock<std::recursive_mutex> lock(m_mutex);

		if (!m_running || m_paused)
		{
			memset(pdata, 0, requestedBytes);
			return noErr;
		}

		uint8_t* dst = static_cast<uint8_t*>(pdata);
		size_t remaining = requestedBytes;

		while (remaining > 0 && !m_buffers.empty())
		{
			auto& front = m_buffers.front();
			size_t inAvail = (front.buf->mAudioDataByteSize > front.bytesConsumed)
					? (front.buf->mAudioDataByteSize - front.bytesConsumed) : 0;

			if (inAvail == 0)
			{
				completed.push_back(front.buf);
				m_buffers.pop_front();
				continue;
			}

			size_t toCopy = std::min(remaining, inAvail);
			memcpy(dst, static_cast<const uint8_t*>(front.buf->mAudioData) + front.bytesConsumed, toCopy);
			dst += toCopy;
			remaining -= toCopy;
			front.bytesConsumed += toCopy;

			if (front.bytesConsumed >= front.buf->mAudioDataByteSize)
			{
				completed.push_back(front.buf);
				m_buffers.pop_front();
			}
		}

		if (remaining > 0)
		{
			memset(dst, 0, remaining);
		}
	}

	// Invoke callbacks for finished buffers outside the mutex so the client can refill & re-enqueue
	for (AudioQueueBufferRef buf : completed)
	{
		if (m_callback)
			m_callback(m_userData, this, buf);
	}

	return noErr;
}
