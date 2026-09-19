#include "CoreAudio/HostTime.h"
#include <mach/mach_time.h>

static mach_timebase_info_data_t getTimebase(void)
{
    static mach_timebase_info_data_t tb = {0, 0};
    if (tb.denom == 0) {
        mach_timebase_info(&tb);
    }
    return tb;
}

UInt64 AudioGetCurrentHostTime(void)
{
    return mach_absolute_time();
}

UInt64 AudioConvertHostTimeToNanos(UInt64 inHostTime)
{
    mach_timebase_info_data_t tb = getTimebase();
    if (tb.denom == 0) return inHostTime;
    return (inHostTime * tb.numer) / tb.denom;
}

UInt64 AudioConvertNanosToHostTime(UInt64 inNanos)
{
    mach_timebase_info_data_t tb = getTimebase();
    if (tb.numer == 0) return inNanos;
    return (inNanos * tb.denom) / tb.numer;
}

Float64 AudioGetHostClockFrequency(void)
{
    mach_timebase_info_data_t tb = getTimebase();
    if (tb.numer == 0) return 1000000000.0;
    return 1000000000.0 * ((Float64)tb.denom / (Float64)tb.numer);
}

UInt32 AudioGetHostClockMinimumTimeDelta(void)
{
    return 1;
}
