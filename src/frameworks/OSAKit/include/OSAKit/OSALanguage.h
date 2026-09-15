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

#include <Foundation/Foundation.h>

@interface OSALanguage : NSObject

+ (NSArray *)availableLanguages;
+ (OSALanguage *)defaultLanguage;
+ (void)setDefaultLanguage:(OSALanguage *)language;
+ (OSALanguage *)languageForName:(NSString *)name;
+ (OSALanguage *)languageForSubType:(OSType)subType;

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *info;
@property (readonly, copy) NSString *version;
@property (readonly) OSType type;
@property (readonly) OSType subType;
@property (readonly) OSType manufacturer;
@property (readonly) NSUInteger features;
@property (readonly, getter=isThreadSafe) BOOL threadSafe;

@end
