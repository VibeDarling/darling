// Plays tones through AudioQueue as iOS games do (SDL's iOS audio is an
// AudioQueue), and checks that the device takes them in real time. See
// ios-audio.md. Objective-C++: Darling's AudioToolbox headers need C++.
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <time.h>

static int failures;

static void expect(BOOL ok, NSString *what, NSString *detail)
{
	printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", what.UTF8String, detail ? ": " : "", detail ? detail.UTF8String : "");
	fflush(stdout);
	if (!ok)
		failures++;
}

typedef struct {
	AudioStreamBasicDescription format;
	double phase;
	UInt32 framesQueued, framesWanted;
	UInt32 framesDone; // __atomic: the queue's thread adds
	// When the device gave back the first buffer, and how much it had taken then.
	uint64_t firstDone; // ns
	UInt32 framesFirst;
} Tone;

static uint64_t nowNs(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000000000ull + ts.tv_nsec;
}

static double now(void)
{
	return nowNs() / 1e9;
}

// A 440 Hz tone at a quarter of full scale, in the queue's format.
static void fill(Tone *tone, AudioQueueBufferRef buffer)
{
	UInt32 frames = buffer->mAudioDataBytesCapacity / tone->format.mBytesPerFrame;
	UInt32 channels = tone->format.mChannelsPerFrame;
	BOOL isFloat = tone->format.mFormatFlags & kAudioFormatFlagIsFloat;
	for (UInt32 i = 0; i < frames; i++) {
		float v = 0.25f * sinf(tone->phase);
		tone->phase += 2 * M_PI * 440 / tone->format.mSampleRate;
		for (UInt32 c = 0; c < channels; c++) {
			if (isFloat)
				((float *)buffer->mAudioData)[i * channels + c] = v;
			else
				((int16_t *)buffer->mAudioData)[i * channels + c] = (int16_t)(v * 32767);
		}
	}
	buffer->mAudioDataByteSize = frames * tone->format.mBytesPerFrame;
	tone->framesQueued += frames;
}

static void done(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
	Tone *tone = (Tone *)context;
	UInt32 frames = __atomic_add_fetch(&tone->framesDone, buffer->mAudioDataByteSize / tone->format.mBytesPerFrame, __ATOMIC_RELAXED);
	if (!tone->firstDone) {
		tone->framesFirst = frames;
		__atomic_store_n(&tone->firstDone, nowNs(), __ATOMIC_RELEASE);
	}
	if (tone->framesQueued < tone->framesWanted) {
		fill(tone, buffer);
		AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	}
}

static void play(NSString *name, Float64 rate, UInt32 channels, BOOL isFloat, double seconds)
{
	Tone tone {};
	tone.format.mSampleRate = rate;
	tone.format.mFormatID = kAudioFormatLinearPCM;
	tone.format.mFormatFlags = isFloat ? kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
		: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	tone.format.mBitsPerChannel = isFloat ? 32 : 16;
	tone.format.mChannelsPerFrame = channels;
	tone.format.mFramesPerPacket = 1;
	tone.format.mBytesPerFrame = tone.format.mBytesPerPacket = channels * tone.format.mBitsPerChannel / 8;
	tone.framesWanted = (UInt32)(rate * seconds);

	AudioQueueRef queue = NULL;
	OSStatus status = AudioQueueNewOutput(&tone.format, done, &tone, NULL, NULL, 0, &queue);
	expect(status == noErr, [NSString stringWithFormat:@"%@: an output queue", name], [NSString stringWithFormat:@"%d", (int)status]);
	if (status != noErr)
		return;

	for (int i = 0; i < 3; i++) {
		AudioQueueBufferRef buffer;
		AudioQueueAllocateBuffer(queue, 2048 * tone.format.mBytesPerFrame, &buffer);
		fill(&tone, buffer);
		AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	}

	double start = now();
	status = AudioQueueStart(queue, NULL);
	expect(status == noErr, [NSString stringWithFormat:@"%@: it starts", name], [NSString stringWithFormat:@"%d", (int)status]);

	// Until the device has taken all of it, or for three times as long.
	while (__atomic_load_n(&tone.framesDone, __ATOMIC_RELAXED) < tone.framesWanted && now() - start < seconds * 3 + 3)
		usleep(20 * 1000);
	double end = now(), first = __atomic_load_n(&tone.firstDone, __ATOMIC_ACQUIRE) / 1e9;
	UInt32 framesDone = __atomic_load_n(&tone.framesDone, __ATOMIC_RELAXED);

	expect(first && first - start < 3, [NSString stringWithFormat:@"%@: the device takes the first buffer", name],
		first ? [NSString stringWithFormat:@"after %.2f s", first - start] : @"never");
	// From the first buffer on, so that opening the device does not count. Taken
	// faster would be a device that drops it; slower, one that stalls.
	double speed = first && end > first ? (framesDone - tone.framesFirst) / tone.format.mSampleRate / (end - first) : 0;
	expect(framesDone >= tone.framesWanted && speed > 0.8 && speed < 1.25,
		[NSString stringWithFormat:@"%@: the device plays it in real time", name],
		[NSString stringWithFormat:@"%.2f s of audio in %.2f s", (framesDone - tone.framesFirst) / tone.format.mSampleRate, end - first]);

	status = AudioQueueStop(queue, true);
	expect(status == noErr, [NSString stringWithFormat:@"%@: it stops", name], [NSString stringWithFormat:@"%d", (int)status]);
	AudioQueueDispose(queue, true);
}

int main(void)
{
	@autoreleasepool {
		NSError *error = nil;
		AVAudioSession *session = [AVAudioSession sharedInstance];
		BOOL ok = [session setCategory:AVAudioSessionCategoryPlayback error:&error] && [session setActive:YES error:&error];
		expect(ok, @"the audio session takes the playback category and activates", error.description);

		play(@"44.1 kHz stereo 16-bit", 44100, 2, NO, 2);
		play(@"22.05 kHz mono float", 22050, 1, YES, 2);
		// After a stop, a queue plays again (SDL stops and restarts for each song).
		play(@"44.1 kHz stereo 16-bit again", 44100, 2, NO, 1);

		printf("%d failures\n", failures);
		return failures != 0;
	}
}
