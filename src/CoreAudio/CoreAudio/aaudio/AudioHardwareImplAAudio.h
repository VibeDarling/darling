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

#ifndef AUDIOHARDWAREIMPLAAUDIO_H
#define AUDIOHARDWAREIMPLAAUDIO_H
#include "../AudioHardwareImpl.h"

// Android's audio, through AAudio: the system object, and devices with the
// same ids as PulseAudio's (see AudioHardware.cpp). Input has no streams yet.
class AudioHardwareImplAAudio : public AudioHardwareImpl
{
public:
	AudioHardwareImplAAudio(AudioObjectID myId);

	OSStatus getPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
		const void* inQualifierData, UInt32* ioDataSize, void* outData) override;

	OSStatus setPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
		const void* inQualifierData, UInt32 inDataSize, const void* inData) override;
protected:
	AudioHardwareStream* createStream(AudioDeviceIOProc callback, void* clientData) override;
};

class AudioHardwareImplAAudioOutput : public AudioHardwareImplAAudio
{
public:
	// usage: an AAUDIO_USAGE_* value.
	AudioHardwareImplAAudioOutput(AudioObjectID myId, int32_t usage);

	OSStatus getPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
		const void* inQualifierData, UInt32* ioDataSize, void* outData) override;

	int32_t usage() const { return m_usage; }
protected:
	AudioHardwareStream* createStream(AudioDeviceIOProc callback, void* clientData) override;
	bool validateFormat(const AudioStreamBasicDescription* asbd) const override;
private:
	int32_t m_usage;
};

#endif
