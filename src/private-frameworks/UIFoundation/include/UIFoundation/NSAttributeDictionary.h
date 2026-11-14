/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#include <Foundation/Foundation.h>

// GUESS (no public source): the selectors are named by "unrecognized selector" exceptions in Stickies, Terminal, Audio MIDI
// Setup and Digital Color Meter; semantics are a shared empty instance and a +1 copy, behind the NSDictionary contract.
@interface NSAttributeDictionary : NSDictionary

+ (id)emptyAttributeDictionary;
+ (id)newWithDictionary:(NSDictionary *)dictionary;

@end
