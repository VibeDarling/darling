/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* playSoundFileNamed: — sound effects, mixed into one audio queue, which
   runs from the first sound on. Reads uncompressed WAV and CAF files. */

#import "SKInternal.h"
#import <CoreAudio/CoreAudioTypes.h>
#include <os/lock.h>

/* AudioToolbox's audio queues, as Apple's AudioQueue.h has them (Darling's
   header is C++). */
typedef struct OpaqueAudioQueue *AudioQueueRef;
typedef struct AudioQueueBuffer {
	const UInt32 mAudioDataBytesCapacity;
	void *const mAudioData;
	UInt32 mAudioDataByteSize;
	void *mUserData;
	const UInt32 mPacketDescriptionCapacity;
	AudioStreamPacketDescription *const mPacketDescriptions;
	UInt32 mPacketDescriptionCount;
} AudioQueueBuffer, *AudioQueueBufferRef;
typedef void (*AudioQueueOutputCallback)(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
extern OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription *inFormat, AudioQueueOutputCallback inCallbackProc,
	void *inUserData, CFRunLoopRef inCallbackRunLoop, CFStringRef inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef *outAQ);
extern OSStatus AudioQueueAllocateBuffer(AudioQueueRef inAQ, UInt32 inBufferByteSize, AudioQueueBufferRef *outBuffer);
extern OSStatus AudioQueueEnqueueBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, UInt32 inNumPacketDescs, const AudioStreamPacketDescription *inPacketDescs);
extern OSStatus AudioQueueStart(AudioQueueRef inAQ, const AudioTimeStamp *inStartTime);

#define SK_RATE 44100
#define SK_FRAMES 1024
#define SK_BUFFERS 3

@interface SKSoundData : NSObject {
@public
	NSData *_samples; /* 16-bit stereo at SK_RATE */
	size_t _frames;
}
@end

@implementation SKSoundData
@end

typedef struct SKVoice {
	CFDataRef samples;
	size_t frames, at;
	struct SKVoice *next;
} SKVoice;

static os_unfair_lock sLock = OS_UNFAIR_LOCK_INIT;
static SKVoice *sVoices;
static AudioQueueRef sQueue;

static uint32_t SKLE32(const uint8_t *p) { return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24; }
static uint16_t SKLE16(const uint8_t *p) { return p[0] | p[1] << 8; }
static uint32_t SKBE32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static uint64_t SKBE64(const uint8_t *p) { return (uint64_t)SKBE32(p) << 32 | SKBE32(p + 4); }

/* PCM in the file's format, to 16-bit stereo at SK_RATE. */
static SKSoundData *SKConvert(const uint8_t *pcm, size_t length, double rate, int channels, int bits, BOOL bigEndian, BOOL isFloat)
{
	if (channels < 1 || rate <= 0 || (bits != 8 && bits != 16 && bits != 24 && bits != 32))
		return nil;
	size_t frameBytes = channels * (bits / 8);
	size_t inFrames = length / frameBytes;
	size_t outFrames = (size_t)(inFrames * SK_RATE / rate);
	NSMutableData *out = [NSMutableData dataWithLength:outFrames * 4];
	int16_t *o = out.mutableBytes;
	for (size_t i = 0; i < outFrames; i++) {
		size_t f = MIN((size_t)(i * rate / SK_RATE), inFrames - 1);
		for (int c = 0; c < 2; c++) {
			const uint8_t *p = pcm + f * frameBytes + MIN(c, channels - 1) * (bits / 8);
			double v;
			switch (bits) {
			case 8:
				v = (p[0] - 128) / 128.0;
				break;
			case 16:
				v = (int16_t)(bigEndian ? (p[0] << 8 | p[1]) : SKLE16(p)) / 32768.0;
				break;
			case 24: {
				int32_t s = bigEndian ? (p[0] << 24 | p[1] << 16 | p[2] << 8) : (p[2] << 24 | p[1] << 16 | p[0] << 8);
				v = s / 2147483648.0;
				break;
			}
			default: {
				uint32_t u = bigEndian ? SKBE32(p) : SKLE32(p);
				if (isFloat) {
					float fl;
					memcpy(&fl, &u, 4);
					v = fl;
				} else
					v = (int32_t)u / 2147483648.0;
				break;
			}
			}
			o[i * 2 + c] = (int16_t)MAX(-32768, MIN(32767, v * 32767));
		}
	}
	SKSoundData *data = [SKSoundData new];
	data->_samples = out;
	data->_frames = outFrames;
	return data;
}

static SKSoundData *SKReadWAV(NSData *file)
{
	const uint8_t *p = file.bytes;
	size_t n = file.length, at = 12;
	int channels = 0, bits = 0, format = 0;
	double rate = 0;
	while (at + 8 <= n) {
		uint32_t size = SKLE32(p + at + 4);
		const uint8_t *chunk = p + at + 8;
		if (memcmp(p + at, "fmt ", 4) == 0 && size >= 16 && at + 8 + 16 <= n) {
			format = SKLE16(chunk);
			channels = SKLE16(chunk + 2);
			rate = SKLE32(chunk + 4);
			bits = SKLE16(chunk + 14);
		} else if (memcmp(p + at, "data", 4) == 0) {
			size = (uint32_t)MIN(size, n - at - 8);
			/* PCM, IEEE float, or the extensible format (PCM, here). */
			if (format != 1 && format != 3 && format != 0xFFFE)
				return nil;
			return SKConvert(chunk, size, rate, channels, bits, NO, format == 3);
		}
		at += 8 + size + (size & 1);
	}
	return nil;
}

static SKSoundData *SKReadCAF(NSData *file)
{
	const uint8_t *p = file.bytes;
	size_t n = file.length, at = 8;
	double rate = 0;
	uint32_t flags = 0, channels = 0, bits = 0;
	BOOL lpcm = NO;
	while (at + 12 <= n) {
		uint64_t size = SKBE64(p + at + 4);
		const uint8_t *chunk = p + at + 12;
		if (memcmp(p + at, "desc", 4) == 0 && at + 12 + 32 <= n) {
			uint64_t r = SKBE64(chunk);
			memcpy(&rate, &r, 8);
			lpcm = memcmp(chunk + 8, "lpcm", 4) == 0;
			flags = SKBE32(chunk + 12);
			channels = SKBE32(chunk + 24);
			bits = SKBE32(chunk + 28);
		} else if (memcmp(p + at, "data", 4) == 0) {
			if (!lpcm)
				return nil;
			/* An edit count, then the samples; -1 means to the end. */
			size_t length = size == UINT64_MAX || at + 12 + size > n ? n - at - 12 : (size_t)size;
			if (length < 4)
				return nil;
			return SKConvert(chunk + 4, length - 4, rate, channels, bits, !(flags & 2), flags & 1);
		}
		if (size == UINT64_MAX)
			break;
		at += 12 + size;
	}
	return nil;
}

static SKSoundData *SKLoadSound(NSString *name)
{
	static NSMutableDictionary<NSString *, id> *cache;
	static os_unfair_lock cacheLock = OS_UNFAIR_LOCK_INIT;
	os_unfair_lock_lock(&cacheLock);
	if (cache == nil)
		cache = [NSMutableDictionary dictionary];
	id cached = cache[name];
	os_unfair_lock_unlock(&cacheLock);
	if (cached != nil)
		return cached == [NSNull null] ? nil : cached;

	NSString *path = [name isAbsolutePath] ? name : [[NSBundle mainBundle] pathForResource:name ofType:nil];
	if (path == nil)
		path = [[NSBundle mainBundle] pathForResource:[name lastPathComponent] ofType:nil];
	NSData *file = path != nil ? [NSData dataWithContentsOfFile:path] : nil;
	SKSoundData *sound = nil;
	if (file.length >= 12 && memcmp(file.bytes, "RIFF", 4) == 0 && memcmp((const char *)file.bytes + 8, "WAVE", 4) == 0)
		sound = SKReadWAV(file);
	else if (file.length >= 8 && memcmp(file.bytes, "caff", 4) == 0)
		sound = SKReadCAF(file);
	if (sound == nil)
		NSLog(@"SpriteKit: cannot play sound %@", name);
	os_unfair_lock_lock(&cacheLock);
	cache[name] = sound ?: [NSNull null];
	os_unfair_lock_unlock(&cacheLock);
	return sound;
}

static void SKMix(void *info, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
	int16_t *out = buffer->mAudioData;
	int32_t mix[SK_FRAMES * 2];
	memset(mix, 0, sizeof(mix));
	os_unfair_lock_lock(&sLock);
	for (SKVoice **link = &sVoices; *link != NULL;) {
		SKVoice *voice = *link;
		const int16_t *samples = (const int16_t *)CFDataGetBytePtr(voice->samples);
		size_t n = MIN((size_t)SK_FRAMES, voice->frames - voice->at);
		for (size_t i = 0; i < n * 2; i++)
			mix[i] += samples[voice->at * 2 + i];
		voice->at += n;
		if (voice->at >= voice->frames) {
			*link = voice->next;
			CFRelease(voice->samples);
			free(voice);
		} else
			link = &voice->next;
	}
	os_unfair_lock_unlock(&sLock);
	for (size_t i = 0; i < SK_FRAMES * 2; i++)
		out[i] = (int16_t)MAX(-32768, MIN(32767, mix[i]));
	buffer->mAudioDataByteSize = SK_FRAMES * 4;
	AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

static void SKStartQueue(void)
{
	if (sQueue != NULL)
		return;
	AudioStreamBasicDescription format = {
		.mSampleRate = SK_RATE,
		.mFormatID = kAudioFormatLinearPCM,
		.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
		.mBytesPerPacket = 4,
		.mFramesPerPacket = 1,
		.mBytesPerFrame = 4,
		.mChannelsPerFrame = 2,
		.mBitsPerChannel = 16,
	};
	AudioQueueRef queue = NULL;
	OSStatus status = AudioQueueNewOutput(&format, SKMix, NULL, NULL, NULL, 0, &queue);
	if (status != noErr) {
		NSLog(@"SpriteKit: no audio output (%d)", (int)status);
		return;
	}
	sQueue = queue;
	for (int i = 0; i < SK_BUFFERS; i++) {
		AudioQueueBufferRef buffer = NULL;
		if (AudioQueueAllocateBuffer(queue, SK_FRAMES * 4, &buffer) != noErr)
			continue;
		memset(buffer->mAudioData, 0, SK_FRAMES * 4);
		buffer->mAudioDataByteSize = SK_FRAMES * 4;
		AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	}
	AudioQueueStart(queue, NULL);
}

NSTimeInterval SKPlaySound(NSString *name)
{
	if (name.length == 0)
		return 0;
	SKSoundData *sound = SKLoadSound(name);
	if (sound == nil || sound->_frames == 0)
		return 0;
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("SpriteKit sounds", DISPATCH_QUEUE_SERIAL);
	});
	SKVoice *voice = calloc(1, sizeof(SKVoice));
	voice->samples = CFBridgingRetain(sound->_samples);
	voice->frames = sound->_frames;
	/* Starting the device can take a while: not on the game's thread. */
	dispatch_async(queue, ^{
		os_unfair_lock_lock(&sLock);
		voice->next = sVoices;
		sVoices = voice;
		os_unfair_lock_unlock(&sLock);
		SKStartQueue();
	});
	return (NSTimeInterval)sound->_frames / SK_RATE;
}
