/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UINIB_H
#define UIKIT_UINIB_H

#import <Foundation/Foundation.h>

/* The options of -instantiateWithOwner:options: and -loadNibNamed:owner:options:. */
extern NSString *const UINibExternalObjects;

/* A compiled nib (an Interface Builder file as Xcode builds it for iOS 6
 * and later), instantiated as often as asked. */
@interface UINib : NSObject
+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundleOrNil;
+ (UINib *)nibWithData:(NSData *)data bundle:(NSBundle *)bundleOrNil;
/* The nib's top-level objects, without File's Owner and the other placeholders. */
- (NSArray *)instantiateWithOwner:(id)ownerOrNil options:(NSDictionary *)optionsOrNil;
@end

@interface NSBundle (UINibLoadingAdditions)
- (NSArray *)loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options;
@end

@interface NSObject (UINibLoadingAdditions)
/* Sent to each object a nib made, once all of them are made and connected. */
- (void)awakeFromNib;
- (void)prepareForInterfaceBuilder;
@end

#endif /* UIKIT_UINIB_H */
