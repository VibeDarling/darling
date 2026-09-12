#ifdef __DARWIN_UNIX03
#undef __DARWIN_UNIX03
#endif
#define __DARWIN_UNIX03 1
#include <CoreAudio/CoreAudio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <execinfo.h>

#pragma pack(push, 1)
typedef struct {
    char riff[4];        // "RIFF"
    uint32_t overall_size;
    char wave[4];        // "WAVE"
} RiffHeader;

typedef struct {
    char chunk_id[4];
    uint32_t chunk_size;
} ChunkHeader;

typedef struct {
    uint16_t format_type;     // 1 for PCM
    uint16_t channels;
    uint32_t sample_rate;
    uint32_t byte_rate;
    uint16_t block_align;
    uint16_t bits_per_sample;
} FmtChunk;
#pragma pack(pop)

static int16_t* g_samples = NULL;
static uint32_t g_totalFrames = 0;
static uint32_t g_currentFrame = 0;
static volatile sig_atomic_t g_running = 1;

static void handle_sigint(int sig) {
    (void)sig;
    g_running = 0;
}

#include <dlfcn.h>
#include <sys/ucontext.h>

static void handle_crash(int sig, siginfo_t* info, void* ctx) {
    fprintf(stderr, "\n*** CRASH: Signal %d received! Code: %d, Fault addr: %p ***\n",
            sig, info ? info->si_code : -1, info ? info->si_addr : NULL);
    if (ctx) {
        ucontext_t* uc = (ucontext_t*)ctx;
#if defined(__x86_64__)
        uintptr_t pc = uc->uc_mcontext->__ss.__rip;
        uintptr_t fp_reg = uc->uc_mcontext->__ss.__rbp;
        uintptr_t sp = uc->uc_mcontext->__ss.__rsp;
#elif defined(__arm64__) || defined(__aarch64__)
        uintptr_t pc = uc->uc_mcontext->__ss.__pc;
        uintptr_t fp_reg = uc->uc_mcontext->__ss.__fp;
        uintptr_t sp = uc->uc_mcontext->__ss.__sp;
#elif defined(__i386__)
        uintptr_t pc = uc->uc_mcontext->__ss.__eip;
        uintptr_t fp_reg = uc->uc_mcontext->__ss.__ebp;
        uintptr_t sp = uc->uc_mcontext->__ss.__esp;
#else
        uintptr_t pc = 0, fp_reg = 0, sp = 0;
#endif
        fprintf(stderr, "PC: 0x%lx, FP: 0x%lx, SP: 0x%lx\n", pc, fp_reg, sp);
        Dl_info dlinfo;
        if (dladdr((void*)pc, &dlinfo)) {
            fprintf(stderr, "Location: %s (%s + 0x%lx)\n",
                    dlinfo.dli_fname ? dlinfo.dli_fname : "?",
                    dlinfo.dli_sname ? dlinfo.dli_sname : "?",
                    pc - (uintptr_t)dlinfo.dli_saddr);
        }
        uintptr_t cur_rbp = fp_reg;
        for (int frame = 0; frame < 20 && cur_rbp; frame++) {
            uintptr_t* fp = (uintptr_t*)cur_rbp;
            uintptr_t next_rbp = fp[0];
            uintptr_t ret_rip = fp[1];
            if (!ret_rip) break;
            Dl_info f_info;
            if (dladdr((void*)ret_rip, &f_info)) {
                fprintf(stderr, "#%d 0x%lx in %s (%s + 0x%lx)\n",
                        frame, ret_rip,
                        f_info.dli_fname ? f_info.dli_fname : "?",
                        f_info.dli_sname ? f_info.dli_sname : "?",
                        ret_rip - (uintptr_t)f_info.dli_saddr);
            } else {
                fprintf(stderr, "#%d 0x%lx\n", frame, ret_rip);
            }
            if (next_rbp <= cur_rbp || next_rbp > cur_rbp + 0x100000) break;
            cur_rbp = next_rbp;
        }
    }
    fflush(stderr);
    _exit(128 + sig);
}

static uint64_t g_callbackCount = 0;

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

    UInt32 frameCount = buf->mDataByteSize / (2 * sizeof(float));
    uint32_t cur = __atomic_load_n(&g_currentFrame, __ATOMIC_RELAXED);

    if (cur >= g_totalFrames || !g_samples) {
        memset(out, 0, buf->mDataByteSize);
        return noErr;
    }

    uint32_t toCopy = frameCount;
    if (cur + toCopy > g_totalFrames)
        toCopy = g_totalFrames - cur;

    const int16_t* src = g_samples + (size_t)cur * 2;
    for (uint32_t i = 0; i < toCopy; i++) {
        out[i * 2]     = (float)src[i * 2]     * (1.0f / 32768.0f);
        out[i * 2 + 1] = (float)src[i * 2 + 1] * (1.0f / 32768.0f);
    }

    if (toCopy < frameCount) {
        memset(out + toCopy * 2, 0, (frameCount - toCopy) * 2 * sizeof(float));
    }

    __atomic_add_fetch(&g_currentFrame, toCopy, __ATOMIC_RELAXED);
    return noErr;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <wav_file> [seconds_to_play]\n", argv[0]);
        return 1;
    }

    const char* filepath = argv[1];
    int max_seconds = (argc >= 3) ? atoi(argv[2]) : 220;

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

    FILE* f = fopen(filepath, "rb");
    if (!f) {
        perror("Failed to open WAV file");
        return 1;
    }

    RiffHeader riff;
    if (fread(&riff, 1, sizeof(riff), f) != sizeof(riff)) {
        fprintf(stderr, "Failed to read RIFF header\n");
        fclose(f);
        return 1;
    }

    if (strncmp(riff.riff, "RIFF", 4) != 0 || strncmp(riff.wave, "WAVE", 4) != 0) {
        fprintf(stderr, "Not a valid RIFF/WAVE file\n");
        fclose(f);
        return 1;
    }

    FmtChunk fmt = {0};
    int found_fmt = 0;
    int found_data = 0;
    long data_pos = 0;
    uint32_t data_len = 0;

    while (!feof(f)) {
        ChunkHeader ch;
        if (fread(&ch, 1, sizeof(ch), f) != sizeof(ch))
            break;

        if (strncmp(ch.chunk_id, "fmt ", 4) == 0) {
            size_t to_read = (ch.chunk_size < sizeof(fmt)) ? ch.chunk_size : sizeof(fmt);
            if (fread(&fmt, 1, to_read, f) != to_read)
                break;
            if (ch.chunk_size > to_read)
                fseek(f, ch.chunk_size - to_read, SEEK_CUR);
            found_fmt = 1;
        } else if (strncmp(ch.chunk_id, "data", 4) == 0) {
            found_data = 1;
            data_pos = ftell(f);
            data_len = ch.chunk_size;
            break;
        } else {
            fseek(f, ch.chunk_size, SEEK_CUR);
        }
    }

    if (!found_fmt || !found_data) {
        fprintf(stderr, "Could not find valid fmt or data chunk in WAV file\n");
        fclose(f);
        return 1;
    }

    if (fmt.format_type != 1 || fmt.bits_per_sample != 16 || fmt.channels != 2) {
        fprintf(stderr, "Unsupported format: only 16-bit stereo PCM supported\n");
        fclose(f);
        return 1;
    }

    printf("Loading audio into memory (%u bytes, %.2f MB)...\n", data_len, (double)data_len / (1024.0 * 1024.0));
    g_samples = (int16_t*)malloc(data_len);
    if (!g_samples) {
        fprintf(stderr, "Failed to allocate memory for samples\n");
        fclose(f);
        return 1;
    }

    fseek(f, data_pos, SEEK_SET);
    size_t bytesRead = fread(g_samples, 1, data_len, f);
    fclose(f);

    g_totalFrames = (uint32_t)(bytesRead / (2 * sizeof(int16_t)));
    g_currentFrame = 0;

    double duration = (double)g_totalFrames / (double)fmt.sample_rate;

    printf("=== WAV Info ===\n");
    printf("Sample rate: %u Hz\n", fmt.sample_rate);
    printf("Duration: %.2f seconds (playing for %d seconds)\n", duration, max_seconds);
    printf("================\n");

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
        fprintf(stderr, "Failed to get default output device: %d\n", (int)status);
        free(g_samples);
        return 1;
    }

    AudioObjectPropertyAddress formatAddress = {
        kAudioDevicePropertyStreamFormat,
        kAudioDevicePropertyScopeOutput,
        0
    };

    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = (Float64)fmt.sample_rate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian;
    asbd.mBytesPerPacket = 8;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 8;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 32;

    AudioObjectSetPropertyData(deviceID, &formatAddress, 0, NULL, sizeof(asbd), &asbd);

    AudioDeviceIOProcID procID = NULL;
    status = AudioDeviceCreateIOProcID(deviceID, audioCallback, NULL, &procID);
    if (status != noErr) {
        fprintf(stderr, "AudioDeviceCreateIOProcID failed: %d\n", (int)status);
        free(g_samples);
        return 1;
    }

    printf("Starting playback...\n");
    status = AudioDeviceStart(deviceID, procID);
    if (status != noErr) {
        fprintf(stderr, "AudioDeviceStart failed: %d\n", (int)status);
        AudioDeviceDestroyIOProcID(deviceID, procID);
        free(g_samples);
        return 1;
    }

    int actual_max = (max_seconds < (int)duration) ? max_seconds : (int)duration + 1;

    for (int sec = 1; sec <= actual_max && g_running; sec++) {
        sleep(1);
        uint32_t cur = __atomic_load_n(&g_currentFrame, __ATOMIC_RELAXED);
        double played_sec = (double)cur / (double)fmt.sample_rate;
        uint64_t cb = __atomic_load_n(&g_callbackCount, __ATOMIC_RELAXED);
        printf("\rPlayback: [%d / %d s] (%.1f s played, cb=%llu)", sec, actual_max, played_sec, (unsigned long long)cb);
        fflush(stdout);
        if (cur >= g_totalFrames)
            break;
    }
    printf("\n");

    printf("Stopping playback...\n");
    AudioDeviceStop(deviceID, procID);
    AudioDeviceDestroyIOProcID(deviceID, procID);

    free(g_samples);
    printf("Playback finished successfully!\n");
    return 0;
}
