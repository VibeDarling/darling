/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIPASTEBOARD_H
#define UIKIT_UIPASTEBOARD_H

#import <Foundation/Foundation.h>

/* Process-local for now: nothing reaches the host clipboard. */
@interface UIPasteboard : NSObject
+ (UIPasteboard *)generalPasteboard;
@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSURL *URL;
- (void)setValue:(id)value forPasteboardType:(NSString *)type;
@end

#endif /* UIKIT_UIPASTEBOARD_H */
