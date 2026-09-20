#include "AudioQueueBase.h"
#include "stub.h"
#include <CarbonCore/MacErrors.h>
#include <cstring>

AudioQueue::AudioQueue(const AudioStreamBasicDescription* format, void* userData,
			CFRunLoopRef runloop, CFStringRef runloopMode, UInt32 flags)
: m_format(*format), m_userData(userData), m_flags(flags)
{
	if (runloop)
		m_runloop = (CFRunLoopRef) CFRetain(runloop);
	else
		m_runloop = nullptr;

	if (runloopMode)
		m_runloopMode = (CFStringRef) CFRetain(runloopMode);
	else
		m_runloopMode = nullptr;
}

AudioQueue::~AudioQueue()
{
	if (m_runloop)
		CFRelease(m_runloop);
	if (m_runloopMode)
		CFRelease(m_runloopMode);
}

OSStatus AudioQueue::getParameter(AudioQueueParameterID inParamID, AudioQueueParameterValue *outValue)
{
	STUB();
	return unimpErr;
}

OSStatus AudioQueue::setParameter(AudioQueueParameterID inParamID, AudioQueueParameterValue inValue)
{
	STUB();
	return unimpErr;
}

OSStatus AudioQueue::getProperty(AudioQueuePropertyID inID, void *outData, UInt32 *ioDataSize)
{
	if (!ioDataSize)
		return paramErr;

	switch (inID)
	{
		case kAudioQueueProperty_IsRunning:
		{
			if (outData && *ioDataSize >= sizeof(UInt32))
			{
				*(UInt32*)outData = m_running ? 1 : 0;
			}
			*ioDataSize = sizeof(UInt32);
			return noErr;
		}
		case kAudioQueueProperty_StreamDescription:
		{
			if (outData && *ioDataSize >= sizeof(AudioStreamBasicDescription))
			{
				memcpy(outData, &m_format, sizeof(AudioStreamBasicDescription));
			}
			*ioDataSize = sizeof(AudioStreamBasicDescription);
			return noErr;
		}
		case kAudioQueueProperty_MaximumOutputPacketSize:
		{
			if (outData && *ioDataSize >= sizeof(UInt32))
			{
				*(UInt32*)outData = m_format.mBytesPerPacket ? m_format.mBytesPerPacket : 4;
			}
			*ioDataSize = sizeof(UInt32);
			return noErr;
		}
		case kAudioQueueProperty_ChannelLayout:
		{
			if (outData && *ioDataSize >= sizeof(AudioChannelLayout))
			{
				AudioChannelLayout* layout = (AudioChannelLayout*)outData;
				memset(layout, 0, sizeof(AudioChannelLayout));
				layout->mChannelLayoutTag = (m_format.mChannelsPerFrame == 1) ?
					kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo;
			}
			*ioDataSize = sizeof(AudioChannelLayout);
			return noErr;
		}
		default:
			return noErr;
	}
}

OSStatus AudioQueue::setProperty(AudioQueuePropertyID inID, const void *inData, UInt32 inDataSize)
{
	switch (inID)
	{
		case kAudioQueueProperty_ChannelLayout:
		case kAudioQueueProperty_CurrentDevice:
		case kAudioQueueProperty_MagicCookie:
			return noErr;
		default:
			return noErr;
	}
}

OSStatus AudioQueue::getPropertySize(AudioQueuePropertyID inID, UInt32 *outDataSize)
{
	if (!outDataSize)
		return paramErr;

	switch (inID)
	{
		case kAudioQueueProperty_IsRunning:
		case kAudioQueueProperty_MaximumOutputPacketSize:
			*outDataSize = sizeof(UInt32);
			return noErr;
		case kAudioQueueProperty_StreamDescription:
			*outDataSize = sizeof(AudioStreamBasicDescription);
			return noErr;
		case kAudioQueueProperty_ChannelLayout:
			*outDataSize = sizeof(AudioChannelLayout);
			return noErr;
		default:
			*outDataSize = sizeof(UInt32);
			return noErr;
	}
}

OSStatus AudioQueue::addPropertyListener(AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc, void *inUserData)
{
	STUB();
	return unimpErr;
}

OSStatus AudioQueue::removePropertyListener(AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc, void *inUserData)
{
	STUB();
	return unimpErr;
}
