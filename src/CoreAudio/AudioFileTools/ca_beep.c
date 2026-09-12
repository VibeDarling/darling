#ifndef __DARWIN_ONLY_UNIX_CONFORMANCE
#define __DARWIN_ONLY_UNIX_CONFORMANCE 1
#endif
#include <CoreAudio/CoreAudio.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <signal.h>
#include <dlfcn.h>
#include <sys/ucontext.h>

static void handle_crash(int sig, siginfo_t* info, void* ctx) {
    fprintf(stderr, "\n*** CRASH: Signal %d, Code: %d, Fault addr: %p ***\n",
            sig, info ? info->si_code : -1, info ? info->si_addr : NULL);
    if (ctx) {
        ucontext_t* uc = (ucontext_t*)ctx;
#if defined(__arm64__) || defined(__aarch64__)
        uintptr_t pc = uc->uc_mcontext->__ss.__pc;
        uintptr_t fp_reg = uc->uc_mcontext->__ss.__fp;
        uintptr_t sp = uc->uc_mcontext->__ss.__sp;
        fprintf(stderr, "PC: 0x%lx, FP: 0x%lx, SP: 0x%lx\n", pc, fp_reg, sp);
#endif
    }
    fflush(stderr);
    _exit(128 + sig);
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static volatile sig_atomic_t g_running = 1;
static uint64_t g_callbackCount = 0;
static float g_phase = 0.0f;
static float g_phaseInc = 0.0f;

static void handle_sigint(int sig) {
    (void)sig;
    g_running = 0;
}

static OSStatus audioCallback(
    AudioObjectID inDevice,
    const AudioTimeStamp* inNow,
    const AudioBufferList* inInputData,
    const AudioTimeStamp* inInputTime,
    AudioBufferList* outOutputData,
    const AudioTimeStamp* inOutputTime,
    void* inClientData)
{
    (void)inDevice; (void)inNow; (void)inInputData; (void)inInputTime;
    (void)inOutputTime; (void)inClientData;

    __atomic_add_fetch(&g_callbackCount, 1, __ATOMIC_RELAXED);

    if (!outOutputData || outOutputData->mNumberBuffers == 0)
        return noErr;

    AudioBuffer* buf = &outOutputData->mBuffers[0];
    float* out = (float*)buf->mData;
    if (!out)
        return noErr;

    // Format is stereo 32-bit float
    UInt32 frameCount = buf->mDataByteSize / (2 * sizeof(float));

    float phase = g_phase;
    float phaseInc = g_phaseInc;

    for (UInt32 i = 0; i < frameCount; i++) {
        float sample = sinf(phase) * 0.4f; // 40% amplitude
        out[i * 2]     = sample; // Left
        out[i * 2 + 1] = sample; // Right

        phase += phaseInc;
        if (phase >= 2.0f * (float)M_PI) {
            phase -= 2.0f * (float)M_PI;
        }
    }

    g_phase = phase;
    return noErr;
}

int main(int argc, char* argv[]) {
    int duration_seconds = (argc >= 2) ? atoi(argv[1]) : 3;
    float frequency = (argc >= 3) ? (float)atof(argv[2]) : 440.0f;

    if (duration_seconds <= 0) duration_seconds = 3;
    if (frequency <= 20.0f || frequency >= 20000.0f) frequency = 440.0f;

    signal(SIGINT, handle_sigint);
    signal(SIGTERM, handle_sigint);
    signal(SIGPIPE, SIG_IGN);

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = handle_crash;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);

    printf("=== Darling CoreAudio Tone Generator ===\n");
    printf("Tone: %.1f Hz (sine wave)\n", frequency);
    printf("Duration: %d seconds\n", duration_seconds);
    printf("========================================\n");

    // 1. Get default output device
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceID = kAudioDeviceUnknown;
    UInt32 size = sizeof(deviceID);

    OSStatus status = AudioObjectGetPropertyData(
        kAudioObjectSystemObject,
        &address,
        0, NULL,
        &size, &deviceID
    );

    if (status != noErr) {
        fprintf(stderr, "Error: AudioObjectGetPropertyData failed (status=%d)\n", (int)status);
        return 1;
    }
    printf("Found default audio device: ID=%u\n", (unsigned int)deviceID);

    // 2. Configure stream format (44100 Hz, 32-bit Float Stereo)
    const Float64 sampleRate = 44100.0;
    AudioObjectPropertyAddress formatAddress = {
        kAudioDevicePropertyStreamFormat,
        kAudioDevicePropertyScopeOutput,
        0
    };

    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = sampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian;
    asbd.mBytesPerPacket = 8;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 8;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 32;

    status = AudioObjectSetPropertyData(deviceID, &formatAddress, 0, NULL, sizeof(asbd), &asbd);
    if (status != noErr) {
        fprintf(stderr, "Warning: Setting stream format returned %d\n", (int)status);
    }

    g_phase = 0.0f;
    g_phaseInc = 2.0f * (float)M_PI * frequency / (float)sampleRate;

    // 3. Register IO callback
    AudioDeviceIOProcID procID = NULL;
    status = AudioDeviceCreateIOProcID(deviceID, audioCallback, NULL, &procID);
    if (status != noErr) {
        fprintf(stderr, "Error: AudioDeviceCreateIOProcID failed (%d)\n", (int)status);
        return 1;
    }

    // 4. Start playback
    printf("Starting CoreAudio playback...\n");
    status = AudioDeviceStart(deviceID, procID);
    if (status != noErr) {
        fprintf(stderr, "Error: AudioDeviceStart failed (%d)\n", (int)status);
        AudioDeviceDestroyIOProcID(deviceID, procID);
        return 1;
    }

    // 5. Monitor playback loop
    for (int sec = 1; sec <= duration_seconds && g_running; sec++) {
        sleep(1);
        uint64_t cb = __atomic_load_n(&g_callbackCount, __ATOMIC_RELAXED);
        printf("Playing: [%d / %d s] (callbacks: %llu)\n", sec, duration_seconds, (unsigned long long)cb);
        fflush(stdout);
    }

    // 6. Stop and cleanup
    printf("Stopping playback...\n");
    AudioDeviceStop(deviceID, procID);
    AudioDeviceDestroyIOProcID(deviceID, procID);

    uint64_t totalCb = __atomic_load_n(&g_callbackCount, __ATOMIC_RELAXED);
    printf("Done! Successfully played tone (%llu total callbacks processed).\n", (unsigned long long)totalCb);
    return 0;
}
