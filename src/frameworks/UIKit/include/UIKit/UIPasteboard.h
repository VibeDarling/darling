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

@class UIImage, UIColor;

/* Process-local for now: nothing reaches the host clipboard. Items are
 * dictionaries from type identifiers to values, as on iOS. */
@interface UIPasteboard : NSObject
+ (UIPasteboard *)generalPasteboard;
+ (UIPasteboard *)pasteboardWithName:(NSString *)name create:(BOOL)create;
+ (UIPasteboard *)pasteboardWithUniqueName;
+ (void)removePasteboardWithName:(NSString *)name;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, getter=isPersistent) BOOL persistent;
@property (nonatomic, readonly) NSInteger changeCount;
@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
- (void)addItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items options:(NSDictionary *)options;
- (NSArray<NSString *> *)pasteboardTypes;
- (BOOL)containsPasteboardTypes:(NSArray<NSString *> *)types;
- (NSData *)dataForPasteboardType:(NSString *)type;
- (id)valueForPasteboardType:(NSString *)type;
- (void)setValue:(id)value forPasteboardType:(NSString *)type;
- (void)setData:(NSData *)data forPasteboardType:(NSString *)type;
- (NSArray *)pasteboardTypesForItemSet:(NSIndexSet *)itemSet;
- (BOOL)containsPasteboardTypes:(NSArray<NSString *> *)types inItemSet:(NSIndexSet *)itemSet;
- (NSIndexSet *)itemSetWithPasteboardTypes:(NSArray<NSString *> *)types;
- (NSArray *)valuesForPasteboardType:(NSString *)type inItemSet:(NSIndexSet *)itemSet;
- (NSArray *)dataForPasteboardType:(NSString *)type inItemSet:(NSIndexSet *)itemSet;
@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSArray<NSString *> *strings;
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) NSArray<NSURL *> *URLs;
@property (nonatomic, copy) UIImage *image;
@property (nonatomic, copy) NSArray<UIImage *> *images;
@property (nonatomic, copy) UIColor *color;
@property (nonatomic, copy) NSArray<UIColor *> *colors;
@property (nonatomic, readonly) BOOL hasStrings;
@property (nonatomic, readonly) BOOL hasURLs;
@property (nonatomic, readonly) BOOL hasImages;
@property (nonatomic, readonly) BOOL hasColors;
@end

extern NSString *const UIPasteboardNameGeneral;
extern NSString *const UIPasteboardNameFind;

#endif /* UIKIT_UIPASTEBOARD_H */
