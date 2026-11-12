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

#ifndef _CMTIMERANGE_H_
#define _CMTIMERANGE_H_

#include <CoreMedia/CMBase.h>
#include <CoreMedia/CMTime.h>

typedef struct {
	CMTime start;
	CMTime duration;
} CMTimeRange;

CM_EXPORT const CMTimeRange kCMTimeRangeZero;
CM_EXPORT const CMTimeRange kCMTimeRangeInvalid;

#define CMTIMERANGE_IS_VALID(range) ((Boolean)(CMTIME_IS_VALID((range).start) && CMTIME_IS_VALID((range).duration) \
	&& ((range).duration.epoch == 0) && ((range).duration.value >= 0)))
#define CMTIMERANGE_IS_INVALID(range) (!CMTIMERANGE_IS_VALID(range))
#define CMTIMERANGE_IS_INDEFINITE(range) ((Boolean)(CMTIMERANGE_IS_VALID(range) \
	&& (CMTIME_IS_INDEFINITE((range).start) || CMTIME_IS_INDEFINITE((range).duration))))
#define CMTIMERANGE_IS_EMPTY(range) ((Boolean)(CMTIMERANGE_IS_VALID(range) \
	&& CMTIME_COMPARE_INLINE((range).duration, ==, kCMTimeZero)))

CM_EXPORT CMTimeRange CMTimeRangeMake(CMTime start, CMTime duration);
CM_EXPORT CMTimeRange CMTimeRangeGetUnion(CMTimeRange range, CMTimeRange otherRange);
CM_EXPORT CMTimeRange CMTimeRangeGetIntersection(CMTimeRange range, CMTimeRange otherRange);
CM_EXPORT Boolean CMTimeRangeEqual(CMTimeRange range1, CMTimeRange range2);
CM_EXPORT Boolean CMTimeRangeContainsTime(CMTimeRange range, CMTime time);
CM_EXPORT Boolean CMTimeRangeContainsTimeRange(CMTimeRange range, CMTimeRange otherRange);
CM_EXPORT CMTime CMTimeRangeGetEnd(CMTimeRange range);
CM_EXPORT CMTimeRange CMTimeRangeFromTimeToTime(CMTime start, CMTime end);

#endif
