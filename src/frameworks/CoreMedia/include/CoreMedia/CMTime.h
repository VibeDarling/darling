/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#ifndef _CMTIME_H_
#define _CMTIME_H_

#include <CoreMedia/CMBase.h>

typedef int64_t CMTimeValue;
typedef int32_t CMTimeScale;
typedef int64_t CMTimeEpoch;
typedef CF_OPTIONS(uint32_t, CMTimeFlags) {
	kCMTimeFlags_Valid = (1UL << 0),
	kCMTimeFlags_HasBeenRounded = (1UL << 1),
	kCMTimeFlags_PositiveInfinity = (1UL << 2),
	kCMTimeFlags_NegativeInfinity = (1UL << 3),
	kCMTimeFlags_Indefinite = (1UL << 4),
	kCMTimeFlags_ImpliedValueFlagsMask = kCMTimeFlags_PositiveInfinity | kCMTimeFlags_NegativeInfinity | kCMTimeFlags_Indefinite
};

typedef struct
{
	CMTimeValue     value;
	CMTimeScale     timescale;
	CMTimeFlags     flags;
	CMTimeEpoch     epoch;
}
CMTime;

extern const CMTime kCMTimeInvalid;
extern const CMTime kCMTimeIndefinite;
extern const CMTime kCMTimePositiveInfinity;
extern const CMTime kCMTimeNegativeInfinity;
extern const CMTime kCMTimeZero;

typedef CF_ENUM(uint32_t, CMTimeRoundingMethod) {
	kCMTimeRoundingMethod_RoundHalfAwayFromZero = 1,
	kCMTimeRoundingMethod_RoundTowardZero = 2,
	kCMTimeRoundingMethod_RoundAwayFromZero = 3,
	kCMTimeRoundingMethod_QuickTime = 4,
	kCMTimeRoundingMethod_RoundTowardPositiveInfinity = 5,
	kCMTimeRoundingMethod_RoundTowardNegativeInfinity = 6,
	kCMTimeRoundingMethod_Default = kCMTimeRoundingMethod_RoundHalfAwayFromZero
};

#define CMTIME_IS_VALID(time) ((Boolean)(((time).flags & kCMTimeFlags_Valid) != 0))
#define CMTIME_IS_INVALID(time) (!CMTIME_IS_VALID(time))
#define CMTIME_IS_POSITIVE_INFINITY(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_PositiveInfinity) != 0)))
#define CMTIME_IS_NEGATIVE_INFINITY(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_NegativeInfinity) != 0)))
#define CMTIME_IS_INDEFINITE(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_Indefinite) != 0)))
#define CMTIME_IS_NUMERIC(time) ((Boolean)(((time).flags & (kCMTimeFlags_Valid | kCMTimeFlags_ImpliedValueFlagsMask)) == kCMTimeFlags_Valid))
#define CMTIME_HAS_BEEN_ROUNDED(time) ((Boolean)(CMTIME_IS_NUMERIC(time) && (((time).flags & kCMTimeFlags_HasBeenRounded) != 0)))

CM_EXPORT CMTime CMTimeMake(int64_t value, int32_t timescale);
CM_EXPORT CMTime CMTimeMakeWithEpoch(int64_t value, int32_t timescale, int64_t epoch);
CM_EXPORT CMTime CMTimeMakeWithSeconds(Float64 seconds, int32_t preferredTimescale);
CM_EXPORT Float64 CMTimeGetSeconds(CMTime time);
CM_EXPORT CMTime CMTimeConvertScale(CMTime time, int32_t newTimescale, CMTimeRoundingMethod method);
CM_EXPORT int32_t CMTimeCompare(CMTime time1, CMTime time2);
CM_EXPORT CMTime CMTimeAdd(CMTime lhs, CMTime rhs);
CM_EXPORT CMTime CMTimeSubtract(CMTime lhs, CMTime rhs);
CM_EXPORT CMTime CMTimeMultiply(CMTime time, int32_t multiplier);
CM_EXPORT CMTime CMTimeMaximum(CMTime time1, CMTime time2);
CM_EXPORT CMTime CMTimeMinimum(CMTime time1, CMTime time2);
CM_EXPORT CMTime CMTimeAbsoluteValue(CMTime time);

#endif
