#include "AudioQueue.h"
#include "AudioQueueBase.h"
#include "AudioQueueOutput.h"
#include <CarbonCore/MacErrors.h>
#include <stdlib.h>
#include <stdio.h>
#include <new>

static bool isStubVerbose() {
	static const bool verbose = (getenv("STUB_VERBOSE") != nullptr);
	return verbose;
}

OSStatus AudioQueueStart(AudioQueueRef inAQ, const AudioTimeStamp *inStartTime)
{
	return inAQ->start(inStartTime);
}

OSStatus AudioQueuePrime(AudioQueueRef inAQ, UInt32 inNumberOfFramesToPrepare, UInt32 *outNumberOfFramesPrepared)
{
	return inAQ->prime(inNumberOfFramesToPrepare, outNumberOfFramesPrepared);
}

OSStatus AudioQueueFlush(AudioQueueRef inAQ)
{
	return inAQ->flush();
}

OSStatus AudioQueueStop(AudioQueueRef inAQ, Boolean inImmediate)
{
	return inAQ->stop(inImmediate);
}

OSStatus AudioQueuePause(AudioQueueRef inAQ)
{
	return inAQ->pause();
}

OSStatus AudioQueueReset(AudioQueueRef inAQ)
{
	return inAQ->reset();
}

OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription *inFormat,
		AudioQueueOutputCallback inCallbackProc,
		void *inUserData, CFRunLoopRef inCallbackRunLoop,
		CFStringRef inCallbackRunLoopMode, UInt32 inFlags,
		AudioQueueRef *outAQ)
{
	return AudioQueueOutput::create(inFormat, inCallbackProc, inUserData,
			inCallbackRunLoop, inCallbackRunLoopMode, inFlags,
			(AudioQueueOutput**) outAQ);
}

OSStatus AudioQueueNewInput(const AudioStreamBasicDescription *inFormat,
		AudioQueueInputCallback inCallbackProc,
		void *inUserData, CFRunLoopRef inCallbackRunLoop,
		CFStringRef inCallbackRunLoopMode, UInt32 inFlags,
		AudioQueueRef *outAQ)
{
	*outAQ = nullptr;
	return unimpErr;
}

OSStatus AudioQueueDispose(AudioQueueRef inAQ, Boolean inImmediate)
{
	return inAQ->dispose(inImmediate);
}

OSStatus AudioQueueGetParameter(AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue *outValue)
{
	return inAQ->getParameter(inParamID, outValue);
}

OSStatus AudioQueueSetParameter(AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue inValue)
{
	return inAQ->setParameter(inParamID, inValue);
}
 
OSStatus AudioQueueGetProperty(AudioQueueRef inAQ, AudioQueuePropertyID inID, void *outData, UInt32 *ioDataSize)
{
	return inAQ->getProperty(inID, outData, ioDataSize);
}

OSStatus AudioQueueSetProperty(AudioQueueRef inAQ, AudioQueuePropertyID inID, const void *inData, UInt32 inDataSize)
{
	return inAQ->setProperty(inID, inData, inDataSize);
}

OSStatus AudioQueueGetPropertySize(AudioQueueRef inAQ, AudioQueuePropertyID inID, UInt32 *outDataSize)
{
	return inAQ->getPropertySize(inID, outDataSize);
}

OSStatus AudioQueueAddPropertyListener(AudioQueueRef inAQ, AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc, void *inUserData)
{
	return inAQ->addPropertyListener(inID, inProc, inUserData);
}

OSStatus AudioQueueRemovePropertyListener(AudioQueueRef inAQ, AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc, void *inUserData)
{
	return inAQ->addPropertyListener(inID, inProc, inUserData);
}

OSStatus AudioQueueSetOfflineRenderFormat(AudioQueueRef inAQ, const AudioStreamBasicDescription *inFormat, const AudioChannelLayout *inLayout)
{
	return inAQ->setOfflineRenderFormat(inFormat, inLayout);
}

OSStatus AudioQueueOfflineRender(AudioQueueRef inAQ, const AudioTimeStamp *inTimestamp, AudioQueueBufferRef ioBuffer, UInt32 inNumberFrames)
{
	return inAQ->offlineRender(inTimestamp, ioBuffer, inNumberFrames);
}

OSStatus AudioQueueAllocateBuffer(AudioQueueRef inAQ, UInt32 inBufferByteSize, AudioQueueBufferRef *outBuffer)
{
	if (!outBuffer || inBufferByteSize == 0)
		return paramErr;

	void* mem = malloc(sizeof(AudioQueueBuffer));
	if (!mem)
		return memFullErr;

	void* data = malloc(inBufferByteSize);
	if (!data) {
		free(mem);
		return memFullErr;
	}

	AudioQueueBuffer* buf = new (mem) AudioQueueBuffer{
		inBufferByteSize,
		data,
		0,
		nullptr,
		0,
		nullptr,
		0
	};

	*outBuffer = buf;
	return noErr;
}

OSStatus AudioQueueAllocateBufferWithPacketDescriptions(AudioQueueRef inAQ,
		UInt32 inBufferByteSize, UInt32 inNumberPacketDescriptions,
		AudioQueueBufferRef *outBuffer)
{
	OSStatus err = AudioQueueAllocateBuffer(inAQ, inBufferByteSize, outBuffer);
	if (err != noErr)
		return err;

	if (inNumberPacketDescriptions > 0) {
		AudioQueueBuffer* buf = *outBuffer;
		buf->mPacketDescriptions = (AudioStreamPacketDescription*) malloc(sizeof(AudioStreamPacketDescription) * inNumberPacketDescriptions);
		if (!buf->mPacketDescriptions) {
			AudioQueueFreeBuffer(inAQ, buf);
			*outBuffer = nullptr;
			return memFullErr;
		}
		buf->mPacketDescriptionCapacity = inNumberPacketDescriptions;
	}
	return noErr;
}

OSStatus AudioQueueFreeBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
	if (!inBuffer)
		return paramErr;
	if (inBuffer->mAudioData)
		free(inBuffer->mAudioData);
	if (inBuffer->mPacketDescriptions)
		free(inBuffer->mPacketDescriptions);
	free(inBuffer);
	return noErr;
}

OSStatus AudioQueueEnqueueBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
		UInt32 inNumPacketDescs, const AudioStreamPacketDescription *inPacketDescs)
{
	if (!inAQ || !inBuffer)
		return paramErr;
	return inAQ->enqueueBuffer(inBuffer, inNumPacketDescs, inPacketDescs);
}

OSStatus AudioQueueEnqueueBufferWithParameters(AudioQueueRef inAQ,
		AudioQueueBufferRef inBuffer, UInt32 inNumPacketDescs,
		const AudioStreamPacketDescription *inPacketDescs,
		UInt32 inTrimFramesAtStart, UInt32 inTrimFramesAtEnd,
		UInt32 inNumParamValues, const AudioQueueParameterEvent *inParamValues,
		const AudioTimeStamp *inStartTime, AudioTimeStamp *outActualStartTime)
{
	if (!inAQ || !inBuffer)
		return paramErr;
	return inAQ->enqueueBuffer(inBuffer, inNumPacketDescs, inPacketDescs);
}
