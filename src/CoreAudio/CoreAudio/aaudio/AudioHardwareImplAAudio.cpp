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

#include "AudioHardwareImplAAudio.h"
#include "AudioHardwareStreamAAudio.h"
#include "AAudioLibrary.h"
#include <CoreFoundation/CFRunLoop.h>
#include <algorithm>
#include <cmath>

AudioHardwareImplAAudio::AudioHardwareImplAAudio(AudioObjectID myId)
: AudioHardwareImpl(myId)
{
	m_name = CFSTR("Android");
	m_manufacturer = CFSTR("Android");
	m_uid = CFSTR("AAudio:SystemObject");
}

template <typename T>
static OSStatus returnValue(T value, UInt32* ioDataSize, void* outData)
{
	if (T* out = static_cast<T*>(outData); out && *ioDataSize >= sizeof(T))
		*out = value;
	*ioDataSize = sizeof(T);
	return kAudioHardwareNoError;
}

OSStatus AudioHardwareImplAAudio::getPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
	const void* inQualifierData, UInt32* ioDataSize, void* outData)
{
	switch (inAddress->mSelector)
	{
		case kAudioHardwarePropertyDefaultInputDevice:
			return returnValue<AudioDeviceID>(kAudioObjectSystemObject + 2, ioDataSize, outData);
		case kAudioHardwarePropertyDefaultOutputDevice:
			return returnValue<AudioDeviceID>(kAudioObjectSystemObject + 1, ioDataSize, outData);
		case kAudioHardwarePropertyDefaultSystemOutputDevice:
			return returnValue<AudioDeviceID>(kAudioObjectSystemObject + 3, ioDataSize, outData);
		case kAudioHardwarePropertyDevices:
		{
			const AudioDeviceID ids[] = { kAudioObjectSystemObject + 1, kAudioObjectSystemObject + 2, kAudioObjectSystemObject + 3 };
			UInt32 count = std::min<UInt32>(*ioDataSize / sizeof(AudioDeviceID), 3);
			if (AudioDeviceID* out = static_cast<AudioDeviceID*>(outData))
				std::copy(ids, ids + count, out);
			*ioDataSize = sizeof(ids);
			return kAudioHardwareNoError;
		}
		// Volumes are linear amplitudes.
		case kAudioDevicePropertyVolumeDecibelsToScalar:
			if (Float32* vol = static_cast<Float32*>(outData); vol && *ioDataSize == sizeof(Float32))
				*vol = std::pow(10.0f, *vol / 20.0f);
			*ioDataSize = sizeof(Float32);
			return kAudioHardwareNoError;
		case kAudioDevicePropertyVolumeScalarToDecibels:
			if (Float32* vol = static_cast<Float32*>(outData); vol && *ioDataSize == sizeof(Float32))
				*vol = *vol > 0 ? 20.0f * std::log10(*vol) : -INFINITY;
			*ioDataSize = sizeof(Float32);
			return kAudioHardwareNoError;
		case kAudioHardwarePropertyRunLoop:
			return returnValue<CFRunLoopRef>(nullptr, ioDataSize, outData);
	}

	return AudioHardwareImpl::getPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
}

OSStatus AudioHardwareImplAAudio::setPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
	const void* inQualifierData, UInt32 inDataSize, const void* inData)
{
	if (inAddress->mSelector == kAudioHardwarePropertyRunLoop)
		return kAudioHardwareNoError;
	return AudioHardwareImpl::setPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData);
}

AudioHardwareStream* AudioHardwareImplAAudio::createStream(AudioDeviceIOProc callback, void* clientData)
{
	// The system object, and input, which would need RECORD_AUDIO.
	return nullptr;
}

AudioHardwareImplAAudioOutput::AudioHardwareImplAAudioOutput(AudioObjectID myId, int32_t usage)
: AudioHardwareImplAAudio(myId), m_usage(usage)
{
	m_uid = CFSTR("AAudio:Output");
}

OSStatus AudioHardwareImplAAudioOutput::getPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
	const void* inQualifierData, UInt32* ioDataSize, void* outData)
{
	const bool output = inAddress->mScope == kAudioDevicePropertyScopeOutput;

	switch (inAddress->mSelector)
	{
		case kAudioDevicePropertyStreams:
			if (output || inAddress->mScope == kAudioObjectPropertyScopeGlobal)
				return returnValue<AudioStreamID>(1, ioDataSize, outData);
			*ioDataSize = 0;
			return kAudioHardwareNoError;
		case kAudioDevicePropertyPreferredChannelLayout:
		{
			AudioChannelLayout layout = {};
			layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
			return returnValue(layout, ioDataSize, outData);
		}
		case kAudioDevicePropertyStreamConfiguration:
		{
			// One buffer of interleaved channels, for output.
			UInt32 size = sizeof(AudioBufferList) + (output ? sizeof(AudioBuffer) : 0);
			if (AudioBufferList* abl = static_cast<AudioBufferList*>(outData); abl && *ioDataSize >= size)
			{
				abl->mNumberBuffers = output ? 1 : 0;
				if (output)
					abl->mBuffers[0] = { m_asbd.mChannelsPerFrame, 0, nullptr };
			}
			*ioDataSize = size;
			return kAudioHardwareNoError;
		}
	}

	return AudioHardwareImplAAudio::getPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
}

AudioHardwareStream* AudioHardwareImplAAudioOutput::createStream(AudioDeviceIOProc callback, void* clientData)
{
	return new AudioHardwareStreamAAudio(this, callback, clientData);
}

bool AudioHardwareImplAAudioOutput::validateFormat(const AudioStreamBasicDescription* asbd) const
{
	return AudioHardwareStreamAAudio::supports(*asbd);
}
