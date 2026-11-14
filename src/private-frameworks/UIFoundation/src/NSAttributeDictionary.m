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

#import <UIFoundation/NSAttributeDictionary.h>

@implementation NSAttributeDictionary {
    NSDictionary *_attributes;
}

+ (id)emptyAttributeDictionary
{
    static NSAttributeDictionary *empty;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ empty = [self newWithDictionary:nil]; });
    return empty;
}

+ (id)newWithDictionary:(NSDictionary *)dictionary
{
    NSAttributeDictionary *result = [self alloc];
    result->_attributes = dictionary ? [dictionary copy] : [NSDictionary new];
    return result;
}

- (NSUInteger)count { return [_attributes count]; }
- (id)objectForKey:(id)key { return [_attributes objectForKey:key]; }
- (NSEnumerator *)keyEnumerator { return [_attributes keyEnumerator]; }
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

- (void)dealloc
{
    [_attributes release];
    [super dealloc];
}

@end
