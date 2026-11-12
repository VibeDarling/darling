/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

/*
 * The CoreMedia that codec code (VideoToolbox clients such as VLC) calls. Times are computed; format
 * descriptions, block buffers and sample buffers cannot be made yet, which fails the way a missing
 * codec does: callers fall back to software decoding.
 */

#include <CoreMedia/CoreMedia.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static void unimplemented(const char *function)
{
	if (getenv("STUB_VERBOSE") != NULL)
		fprintf(stderr, "CoreMedia: %s is not implemented\n", function);
}

#pragma mark - CMTime

CMTime CMTimeMake(int64_t value, int32_t timescale)
{
	return CMTimeMakeWithEpoch(value, timescale, 0);
}

CMTime CMTimeMakeWithEpoch(int64_t value, int32_t timescale, int64_t epoch)
{
	if (timescale <= 0)
		return kCMTimeInvalid;
	CMTime time = { value, timescale, kCMTimeFlags_Valid, epoch };
	return time;
}

CMTime CMTimeMakeWithSeconds(Float64 seconds, int32_t preferredTimescale)
{
	if (isnan(seconds) || preferredTimescale <= 0)
		return kCMTimeInvalid;
	if (isinf(seconds))
		return seconds > 0 ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
	CMTime time = CMTimeMake((int64_t) llround(seconds * preferredTimescale), preferredTimescale);
	if ((Float64) time.value / preferredTimescale != seconds)
		time.flags |= kCMTimeFlags_HasBeenRounded;
	return time;
}

Float64 CMTimeGetSeconds(CMTime time)
{
	if (CMTIME_IS_POSITIVE_INFINITY(time))
		return INFINITY;
	if (CMTIME_IS_NEGATIVE_INFINITY(time))
		return -INFINITY;
	if (!CMTIME_IS_NUMERIC(time))
		return NAN;
	return (Float64) time.value / time.timescale;
}

static int64_t rounded_quotient(__int128 numerator, int64_t denominator, CMTimeRoundingMethod method)
{
	__int128 quotient = numerator / denominator, remainder = numerator % denominator;
	if (remainder == 0)
		return (int64_t) quotient;
	int negative = (numerator < 0) != (denominator < 0);
	__int128 twice = remainder < 0 ? -2 * remainder : 2 * remainder;
	__int128 magnitude = denominator < 0 ? -(__int128) denominator : denominator;
	switch (method) {
	case kCMTimeRoundingMethod_RoundTowardZero:
		return (int64_t) quotient;
	case kCMTimeRoundingMethod_RoundAwayFromZero:
		return (int64_t) (negative ? quotient - 1 : quotient + 1);
	case kCMTimeRoundingMethod_RoundTowardPositiveInfinity:
		return (int64_t) (negative ? quotient : quotient + 1);
	case kCMTimeRoundingMethod_RoundTowardNegativeInfinity:
		return (int64_t) (negative ? quotient - 1 : quotient);
	case kCMTimeRoundingMethod_QuickTime: /* toward zero when shrinking the timescale, else half away */
	case kCMTimeRoundingMethod_RoundHalfAwayFromZero:
	default:
		if (twice >= magnitude)
			return (int64_t) (negative ? quotient - 1 : quotient + 1);
		return (int64_t) quotient;
	}
}

CMTime CMTimeConvertScale(CMTime time, int32_t newTimescale, CMTimeRoundingMethod method)
{
	if (!CMTIME_IS_NUMERIC(time) || newTimescale <= 0)
		return CMTIME_IS_VALID(time) && newTimescale > 0 ? time : kCMTimeInvalid;
	if (time.timescale == newTimescale)
		return time;
	__int128 scaled = (__int128) time.value * newTimescale;
	CMTime result = { rounded_quotient(scaled, time.timescale, method), newTimescale, time.flags, time.epoch };
	if (scaled % time.timescale != 0)
		result.flags |= kCMTimeFlags_HasBeenRounded;
	return result;
}

int32_t CMTimeCompare(CMTime time1, CMTime time2)
{
	/* Invalid < negative infinity < numeric < positive infinity < indefinite, as documented. */
	int rank1 = !CMTIME_IS_VALID(time1) ? 0 : CMTIME_IS_NEGATIVE_INFINITY(time1) ? 1 : CMTIME_IS_INDEFINITE(time1) ? 4
		: CMTIME_IS_POSITIVE_INFINITY(time1) ? 3 : 2;
	int rank2 = !CMTIME_IS_VALID(time2) ? 0 : CMTIME_IS_NEGATIVE_INFINITY(time2) ? 1 : CMTIME_IS_INDEFINITE(time2) ? 4
		: CMTIME_IS_POSITIVE_INFINITY(time2) ? 3 : 2;
	if (rank1 != rank2 || rank1 != 2)
		return rank1 < rank2 ? -1 : rank1 > rank2 ? 1 : 0;
	if (time1.epoch != time2.epoch)
		return time1.epoch < time2.epoch ? -1 : 1;
	__int128 left = (__int128) time1.value * time2.timescale, right = (__int128) time2.value * time1.timescale;
	return left < right ? -1 : left > right ? 1 : 0;
}

static int64_t gcd64(int64_t a, int64_t b)
{
	while (b != 0) {
		int64_t t = a % b;
		a = b;
		b = t;
	}
	return a;
}

/* Sum of two times, rhs negated when subtracting. Different epochs or opposite infinities give an
   invalid time; numeric operands meet at the least common multiple of their timescales, or at the
   larger timescale, rounded, when that does not fit. */
static CMTime add_times(CMTime lhs, CMTime rhs, int negate)
{
	if (!CMTIME_IS_VALID(lhs) || !CMTIME_IS_VALID(rhs))
		return kCMTimeInvalid;
	if (CMTIME_IS_INDEFINITE(lhs) || CMTIME_IS_INDEFINITE(rhs))
		return kCMTimeIndefinite;
	int lhsInf = CMTIME_IS_POSITIVE_INFINITY(lhs) ? 1 : CMTIME_IS_NEGATIVE_INFINITY(lhs) ? -1 : 0;
	int rhsInf = CMTIME_IS_POSITIVE_INFINITY(rhs) ? 1 : CMTIME_IS_NEGATIVE_INFINITY(rhs) ? -1 : 0;
	if (negate)
		rhsInf = -rhsInf;
	if (lhsInf != 0 || rhsInf != 0) {
		if (lhsInf != 0 && rhsInf != 0 && lhsInf != rhsInf)
			return kCMTimeInvalid;
		return (lhsInf ? lhsInf : rhsInf) > 0 ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
	}
	if (lhs.epoch != rhs.epoch)
		return kCMTimeInvalid;

	int64_t lcm = (int64_t) lhs.timescale / gcd64(lhs.timescale, rhs.timescale) * rhs.timescale;
	int32_t timescale = lcm <= INT32_MAX ? (int32_t) lcm : (lhs.timescale > rhs.timescale ? lhs.timescale : rhs.timescale);
	CMTime a = CMTimeConvertScale(lhs, timescale, kCMTimeRoundingMethod_Default);
	CMTime b = CMTimeConvertScale(rhs, timescale, kCMTimeRoundingMethod_Default);
	__int128 value = (__int128) a.value + (negate ? -(__int128) b.value : (__int128) b.value);
	if (value > INT64_MAX)
		return kCMTimePositiveInfinity;
	if (value < INT64_MIN)
		return kCMTimeNegativeInfinity;
	CMTime result = { (int64_t) value, timescale, kCMTimeFlags_Valid, lhs.epoch };
	if ((a.flags | b.flags) & kCMTimeFlags_HasBeenRounded)
		result.flags |= kCMTimeFlags_HasBeenRounded;
	return result;
}

CMTime CMTimeAdd(CMTime lhs, CMTime rhs) { return add_times(lhs, rhs, 0); }
CMTime CMTimeSubtract(CMTime lhs, CMTime rhs) { return add_times(lhs, rhs, 1); }

CMTime CMTimeMultiply(CMTime time, int32_t multiplier)
{
	if (!CMTIME_IS_VALID(time) || CMTIME_IS_INDEFINITE(time))
		return time;
	if (CMTIME_IS_POSITIVE_INFINITY(time) || CMTIME_IS_NEGATIVE_INFINITY(time)) {
		if (multiplier == 0)
			return kCMTimeInvalid;
		return (CMTIME_IS_POSITIVE_INFINITY(time)) == (multiplier > 0) ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
	}
	__int128 value = (__int128) time.value * multiplier;
	if (value > INT64_MAX)
		return kCMTimePositiveInfinity;
	if (value < INT64_MIN)
		return kCMTimeNegativeInfinity;
	time.value = (int64_t) value;
	return time;
}

CMTime CMTimeMaximum(CMTime time1, CMTime time2)
{
	if (!CMTIME_IS_VALID(time1) || !CMTIME_IS_VALID(time2))
		return kCMTimeInvalid;
	return CMTimeCompare(time1, time2) >= 0 ? time1 : time2;
}

CMTime CMTimeMinimum(CMTime time1, CMTime time2)
{
	if (!CMTIME_IS_VALID(time1) || !CMTIME_IS_VALID(time2))
		return kCMTimeInvalid;
	return CMTimeCompare(time1, time2) <= 0 ? time1 : time2;
}

CMTime CMTimeAbsoluteValue(CMTime time)
{
	if (CMTIME_IS_NEGATIVE_INFINITY(time))
		return kCMTimePositiveInfinity;
	if (CMTIME_IS_NUMERIC(time) && time.value < 0)
		time.value = -time.value;
	return time;
}

#pragma mark - Format descriptions

CFTypeID CMFormatDescriptionGetTypeID(void) { return 0; /* _kCFRuntimeNotATypeID: not a CF type yet */ }
CMMediaType CMFormatDescriptionGetMediaType(CMFormatDescriptionRef desc) { return 0; }
FourCharCode CMFormatDescriptionGetMediaSubType(CMFormatDescriptionRef desc) { return 0; }
CFDictionaryRef CMFormatDescriptionGetExtensions(CMFormatDescriptionRef desc) { return NULL; }
CFPropertyListRef CMFormatDescriptionGetExtension(CMFormatDescriptionRef desc, CFStringRef extensionKey) { return NULL; }

OSStatus CMVideoFormatDescriptionCreate(CFAllocatorRef allocator, CMVideoCodecType codecType, int32_t width,
	int32_t height, CFDictionaryRef extensions, CMVideoFormatDescriptionRef *formatDescriptionOut)
{
	unimplemented(__func__);
	if (formatDescriptionOut != NULL)
		*formatDescriptionOut = NULL;
	return kCMFormatDescriptionError_AllocationFailed;
}

CMVideoDimensions CMVideoFormatDescriptionGetDimensions(CMVideoFormatDescriptionRef videoDesc)
{
	CMVideoDimensions dimensions = { 0, 0 };
	return dimensions;
}

OSStatus CMVideoFormatDescriptionGetH264ParameterSetAtIndex(CMFormatDescriptionRef videoDesc, size_t parameterSetIndex,
	const uint8_t **parameterSetPointerOut, size_t *parameterSetSizeOut, size_t *parameterSetCountOut,
	int *NALUnitHeaderLengthOut)
{
	return kCMFormatDescriptionError_InvalidParameter;
}

OSStatus CMAudioFormatDescriptionCreate(CFAllocatorRef allocator, const AudioStreamBasicDescription *asbd,
	size_t layoutSize, const AudioChannelLayout *layout, size_t magicCookieSize, const void *magicCookie,
	CFDictionaryRef extensions, CMAudioFormatDescriptionRef *formatDescriptionOut)
{
	unimplemented(__func__);
	if (formatDescriptionOut != NULL)
		*formatDescriptionOut = NULL;
	if (asbd == NULL || formatDescriptionOut == NULL)
		return kCMFormatDescriptionError_InvalidParameter;
	return kCMFormatDescriptionError_AllocationFailed;
}

const AudioStreamBasicDescription *CMAudioFormatDescriptionGetStreamBasicDescription(CMAudioFormatDescriptionRef desc)
{
	return NULL;
}

const AudioChannelLayout *CMAudioFormatDescriptionGetChannelLayout(CMAudioFormatDescriptionRef desc, size_t *sizeOut)
{
	if (sizeOut != NULL)
		*sizeOut = 0;
	return NULL;
}

const void *CMAudioFormatDescriptionGetMagicCookie(CMAudioFormatDescriptionRef desc, size_t *sizeOut)
{
	if (sizeOut != NULL)
		*sizeOut = 0;
	return NULL;
}

#pragma mark - Block buffers

CFTypeID CMBlockBufferGetTypeID(void) { return 0; /* _kCFRuntimeNotATypeID: not a CF type yet */ }

OSStatus CMBlockBufferCreateWithMemoryBlock(CFAllocatorRef structureAllocator, void *memoryBlock, size_t blockLength,
	CFAllocatorRef blockAllocator, const CMBlockBufferCustomBlockSource *customBlockSource, size_t offsetToData,
	size_t dataLength, CMBlockBufferFlags flags, CMBlockBufferRef *blockBufferOut)
{
	unimplemented(__func__);
	if (blockBufferOut != NULL)
		*blockBufferOut = NULL;
	return kCMBlockBufferStructureAllocationFailedErr;
}

size_t CMBlockBufferGetDataLength(CMBlockBufferRef theBuffer) { return 0; }

OSStatus CMBlockBufferGetDataPointer(CMBlockBufferRef theBuffer, size_t offset, size_t *lengthAtOffsetOut,
	size_t *totalLengthOut, char **dataPointerOut)
{
	return theBuffer == NULL ? kCMBlockBufferBadPointerParameterErr : kCMBlockBufferEmptyBBufErr;
}

#pragma mark - Sample buffers

CFTypeID CMSampleBufferGetTypeID(void) { return 0; /* _kCFRuntimeNotATypeID: not a CF type yet */ }

OSStatus CMSampleBufferCreate(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, Boolean dataReady,
	CMSampleBufferMakeDataReadyCallback makeDataReadyCallback, void *makeDataReadyRefcon,
	CMFormatDescriptionRef formatDescription, CMItemCount numSamples, CMItemCount numSampleTimingEntries,
	const CMSampleTimingInfo *sampleTimingArray, CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray,
	CMSampleBufferRef *sampleBufferOut)
{
	unimplemented(__func__);
	if (sampleBufferOut != NULL)
		*sampleBufferOut = NULL;
	return kCMSampleBufferError_AllocationFailed;
}

OSStatus CMSampleBufferCreateReady(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer,
	CMFormatDescriptionRef formatDescription, CMItemCount numSamples, CMItemCount numSampleTimingEntries,
	const CMSampleTimingInfo *sampleTimingArray, CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray,
	CMSampleBufferRef *sampleBufferOut)
{
	return CMSampleBufferCreate(allocator, dataBuffer, true, NULL, NULL, formatDescription, numSamples,
		numSampleTimingEntries, sampleTimingArray, numSampleSizeEntries, sampleSizeArray, sampleBufferOut);
}

CMBlockBufferRef CMSampleBufferGetDataBuffer(CMSampleBufferRef sbuf) { return NULL; }
CMTime CMSampleBufferGetDecodeTimeStamp(CMSampleBufferRef sbuf) { return kCMTimeInvalid; }
CMTime CMSampleBufferGetPresentationTimeStamp(CMSampleBufferRef sbuf) { return kCMTimeInvalid; }
CMTime CMSampleBufferGetDuration(CMSampleBufferRef sbuf) { return kCMTimeInvalid; }
CMFormatDescriptionRef CMSampleBufferGetFormatDescription(CMSampleBufferRef sbuf) { return NULL; }
CFArrayRef CMSampleBufferGetSampleAttachmentsArray(CMSampleBufferRef sbuf, Boolean createIfNecessary) { return NULL; }
CMItemCount CMSampleBufferGetNumSamples(CMSampleBufferRef sbuf) { return 0; }

OSStatus CMSampleBufferCallForEachSample(CMSampleBufferRef sbuf,
	OSStatus (*callback)(CMSampleBufferRef sampleBuffer, CMItemCount index, void *refcon), void *refcon)
{
	return sbuf == NULL ? kCMSampleBufferError_RequiredParameterMissing : kCMSampleBufferError_BufferHasNoSampleSizes;
}
