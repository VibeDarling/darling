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

#include "AudioHardwareImplPA.h"
#include "../stub.h"
#include "AudioHardwareStreamPA.h"
#include "PADispatchMainLoop.h"
#include <CoreFoundation/CFBundle.h>
#include <CoreFoundation/CFString.h>
#include <iostream>
#include <mutex>
#include <thread>

#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

AudioHardwareImplPA::AudioHardwareImplPA(AudioObjectID myId, const char* paRole)
: AudioHardwareImpl(myId), m_paRole(paRole)
{
	m_name = CFSTR("PulseAudio");
	m_manufacturer = CFSTR("PulseAudio");
	m_uid = CFSTR("PulseAudio:SystemObject");
}

AudioHardwareImplPA::~AudioHardwareImplPA()
{
	if (m_context)
	{
		pa_context_disconnect(m_context);
		pa_context_unref(m_context);
		m_context = nullptr;
	}
	m_loop.reset();
}

OSStatus AudioHardwareImplPA::getPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
	const void* inQualifierData, UInt32* ioDataSize, void* outData)
{
	switch (inAddress->mSelector)
	{
		// BEGIN kAudioObjectSystemObject properties
		case kAudioHardwarePropertyDefaultInputDevice: // returns AudioDeviceID
			if (AudioDeviceID* devId = static_cast<AudioDeviceID*>(outData); devId && *ioDataSize >= sizeof(AudioDeviceID))
			{
				*devId = kAudioObjectSystemObject + 2;
			}
			*ioDataSize = sizeof(AudioDeviceID);
			return kAudioHardwareNoError;
		case kAudioHardwarePropertyDefaultOutputDevice: // returns AudioDeviceID
			if (AudioDeviceID* devId = static_cast<AudioDeviceID*>(outData); devId && *ioDataSize >= sizeof(AudioDeviceID))
			{
				*devId = kAudioObjectSystemObject + 1;
			}
			*ioDataSize = sizeof(AudioDeviceID);
			return kAudioHardwareNoError;
		case kAudioHardwarePropertyDefaultSystemOutputDevice:
			if (AudioDeviceID* devId = static_cast<AudioDeviceID*>(outData); devId && *ioDataSize >= sizeof(AudioDeviceID))
			{
				*devId = kAudioObjectSystemObject + 3;
			}
			*ioDataSize = sizeof(AudioDeviceID);
			return kAudioHardwareNoError;
		case kAudioHardwarePropertyDevices:
		{
			UInt32 maxCount = *ioDataSize / sizeof(AudioDeviceID);
			if (AudioDeviceID* devId = static_cast<AudioDeviceID*>(outData); devId && maxCount > 0)
			{
				AudioDeviceID ids[] = {
					kAudioObjectSystemObject + 1, // output
					kAudioObjectSystemObject + 2, // input
					kAudioObjectSystemObject + 3  // system output ("event")
				};
				UInt32 count = std::min<UInt32>(maxCount, 3);
				for (UInt32 i = 0; i < count; i++)
					devId[i] = ids[i];
			}
			*ioDataSize = sizeof(AudioDeviceID) * 3;
			return kAudioHardwareNoError;
		}
		case kAudioDevicePropertyVolumeDecibelsToScalar:
		{
			if (Float32* vol = static_cast<Float32*>(outData); vol && *ioDataSize == sizeof(Float32))
			{
				*vol = pa_sw_volume_to_linear(pa_sw_volume_from_dB(*vol));
			}
			*ioDataSize = sizeof(Float32);
			return kAudioHardwareNoError;
		}
		case kAudioDevicePropertyVolumeScalarToDecibels:
		{
			if (Float32* vol = static_cast<Float32*>(outData); vol && *ioDataSize == sizeof(Float32))
			{
				*vol = pa_sw_volume_to_dB(pa_sw_volume_from_linear(*vol));
			}
			*ioDataSize = sizeof(Float32);
			return kAudioHardwareNoError;
		}
	}

	return AudioHardwareImpl::getPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
}
	
OSStatus AudioHardwareImplPA::setPropertyData(const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize,
	const void* inQualifierData, UInt32 inDataSize, const void* inData)
{
	return AudioHardwareImpl::setPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData);
}

AudioHardwareStream* AudioHardwareImplPA::createStream(AudioDeviceIOProc callback, void* clientData)
{
	// Must be called on a subclass instance
	return nullptr;
}

extern "C" char ***_NSGetArgv(void);

static void paContextStateCB(pa_context* c, void* priv)
{
	void (^cb)(pa_context*) = (void (^)(pa_context*)) priv;

	pa_context_state_t state = pa_context_get_state(c);
	if (state == PA_CONTEXT_READY)
	{
		// std::cout << "PA_CONTEXT_READY\n";

		cb(c);
		Block_release(cb);

		// FIXME: We won't be notified about later disconnects...
		pa_context_set_state_callback(c, nullptr, nullptr);
	}
	else if (state == PA_CONTEXT_FAILED)
	{
		std::cerr << "PulseAudio error: PA_CONTEXT_FAILED: " << pa_strerror(pa_context_errno(c)) << "\n";

		cb(nullptr);
		Block_release(cb);
		pa_context_set_state_callback(c, nullptr, nullptr);
	}
}

static const char* appNameFromExecutable()
{
	const char* name = (*_NSGetArgv())[0];
	const char* p = std::strrchr(name, '/');

	if (p && *(p+1))
		return p+1;
	return name;
}

void AudioHardwareImplPA::getPAContext(void (^cb)(pa_context*))
{
	// TODO: destruction
	static std::mutex mutex;

	if (m_context == nullptr)
	{
		std::unique_lock<std::mutex> l(mutex);

		if (m_context == nullptr)
		{
			const char* appname = appNameFromExecutable();
			const char* appid = "org.darlinghq.some-app";

			pa_proplist* proplist = pa_proplist_new();

			// Try to find a better application name & id from the bundle
			CFBundleRef mainBundle = CFBundleGetMainBundle();
			if (mainBundle)
			{
				CFStringRef ident = CFBundleGetIdentifier(mainBundle);
				if (ident)
					appid = CFStringGetCStringPtr(ident, kCFStringEncodingUTF8);

				CFDictionaryRef infoDict = CFBundleGetLocalInfoDictionary(mainBundle);
				if (!infoDict)
					infoDict = CFBundleGetInfoDictionary(mainBundle);
				
				if (infoDict)
				{
					CFStringRef name = (CFStringRef) CFDictionaryGetValue(infoDict, CFSTR("CFBundleDisplayName"));
					if (!name)
						name = (CFStringRef) CFDictionaryGetValue(infoDict, CFSTR("CFBundleName"));
					if (name)
						appname = CFStringGetCStringPtr(name, kCFStringEncodingUTF8);
				}
			}

			pa_proplist_sets(proplist, PA_PROP_APPLICATION_NAME, appname);
			pa_proplist_sets(proplist, PA_PROP_APPLICATION_ID, appid);
			if (m_paRole)
				pa_proplist_sets(proplist, PA_PROP_MEDIA_ROLE, m_paRole);
			// pa_proplist_sets(proplist, PA_PROP_APPLICATION_ICON_NAME, "icon-name");
			// pa_proplist_sets(proplist, PA_PROP_MEDIA_ROLE, "game");

			m_loop.reset(new PADispatchMainLoop);

			m_context = pa_context_new_with_proplist(m_loop->getAPI(), appname, proplist);
			pa_proplist_free(proplist);

			if (!m_context)
			{
				cb(nullptr);
				return;
			}

			pa_context_set_state_callback(m_context, paContextStateCB, Block_copy(cb));

			const char* server = getenv("PULSE_SERVER");
			char serverBuf[512] = {0};
			if (!server)
			{
				uid_t uid = getuid();
				char hostSocketPath[512];

				// 1. Standard Linux desktop (PipeWire / PulseAudio via systemd /run/user/<UID>)
				snprintf(hostSocketPath, sizeof(hostSocketPath), "/Volumes/SystemRoot/run/user/%u/pulse/native", uid);
				if (access(hostSocketPath, R_OK | W_OK) == 0)
				{
					snprintf(serverBuf, sizeof(serverBuf), "/run/user/%u/pulse/native", uid);
					server = serverBuf;
				}

				// 2. Termux UNIX socket paths ($PREFIX/var/run/pulse/native or standard static path)
				if (!server)
				{
					const char* termuxPrefix = getenv("PREFIX");
					if (!termuxPrefix || !termuxPrefix[0])
						termuxPrefix = getenv("TERMUX_PREFIX");
					if (!termuxPrefix || !termuxPrefix[0])
						termuxPrefix = "/data/data/com.termux/files/usr";

					snprintf(hostSocketPath, sizeof(hostSocketPath), "/Volumes/SystemRoot%s/var/run/pulse/native", termuxPrefix);
					if (access(hostSocketPath, R_OK | W_OK) == 0)
					{
						snprintf(serverBuf, sizeof(serverBuf), "%s/var/run/pulse/native", termuxPrefix);
						server = serverBuf;
					}
				}

				// 3. Local /run fallback
				if (!server)
				{
					snprintf(serverBuf, sizeof(serverBuf), "/run/user/%u/pulse/native", uid);
					if (access(serverBuf, R_OK | W_OK) == 0)
					{
						server = serverBuf;
					}
				}

				// 4. TCP fallback (standard in Termux, WSL, Docker, where PulseAudio listens on 127.0.0.1:4713)
				if (!server)
				{
					int fd = socket(AF_INET, SOCK_STREAM, 0);
					if (fd >= 0)
					{
						struct timeval tv = {0, 50000}; // 50ms timeout
						setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
						setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
						struct sockaddr_in sa;
						memset(&sa, 0, sizeof(sa));
						sa.sin_family = AF_INET;
						sa.sin_port = htons(4713);
						sa.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
						if (connect(fd, (struct sockaddr*)&sa, sizeof(sa)) == 0)
						{
							server = "tcp:127.0.0.1:4713";
						}
						close(fd);
					}
				}
			}

			if (pa_context_connect(m_context, server, PA_CONTEXT_NOFLAGS, nullptr) < 0)
			{
				std::cerr << "pa_context_connect() returned an error: " << pa_strerror(pa_context_errno(m_context)) << "\n";
				pa_context_set_state_callback(m_context, nullptr, nullptr);
				cb(nullptr);
				return;
			}

			m_loop->resume();
		}
	}
	else
		cb(m_context);
}

pa_sample_spec AudioHardwareImplPA::paSampleSpecForASBD(const AudioStreamBasicDescription& asbd, bool* convertSignedUnsigned)
{
	const bool isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat;
	const bool isSigned = asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger;
	const bool isBE = asbd.mFormatFlags & kAudioFormatFlagIsBigEndian;
	
	pa_sample_spec spec;
	
	spec.rate = asbd.mSampleRate;
	spec.channels = asbd.mChannelsPerFrame;
	spec.format = PA_SAMPLE_INVALID;

	if (convertSignedUnsigned)
		*convertSignedUnsigned = false;
	
	if (asbd.mFormatID == kAudioFormatLinearPCM)
	{
		if (isFloat)
			spec.format = isBE ? PA_SAMPLE_FLOAT32BE : PA_SAMPLE_FLOAT32LE;
		else
		{
			switch (asbd.mBitsPerChannel)
			{
				case 8:
					if (convertSignedUnsigned)
						*convertSignedUnsigned = isSigned;
					spec.format = PA_SAMPLE_U8;
					break;
				case 16:
					if (convertSignedUnsigned)
						*convertSignedUnsigned = !isSigned;
					
					spec.format = isBE ? PA_SAMPLE_S16BE : PA_SAMPLE_S16LE;
					break;
				case 24:
					if (convertSignedUnsigned)
						*convertSignedUnsigned = !isSigned;
					
					if (asbd.mFormatFlags & kAudioFormatFlagIsPacked)
						spec.format = isBE ? PA_SAMPLE_S24BE : PA_SAMPLE_S24LE;
					else
						spec.format = isBE ? PA_SAMPLE_S24_32BE : PA_SAMPLE_S24_32LE;
					break;
				case 32:
					if (convertSignedUnsigned)
						*convertSignedUnsigned = !isSigned;
					
					spec.format = isBE ? PA_SAMPLE_S32BE : PA_SAMPLE_S32LE;
					break;
			}
		}
	}
	
	return spec;
}

bool AudioHardwareImplPA::validateFormat(const AudioStreamBasicDescription* asbd) const
{
	pa_sample_spec spec = paSampleSpecForASBD(*asbd);
	return pa_sample_spec_valid(&spec);
}
