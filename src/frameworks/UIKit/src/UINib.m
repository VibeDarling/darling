/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <UIKit/UINib.h>
#import <UIKit/UIStoryboard.h>
#import <UIKit/UIStoryboardSegue.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UITabBarController.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIGeometry.h>
#import <AppKit/NSParagraphStyle.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

/*
 * Compiled nibs. ibtool writes iOS nibs (6 and later) in its "NIBArchive"
 * format:
 *
 *   "NIBArchive", then ten little-endian 32-bit words: format (1), coder
 *   version (9 or 10), and the count and file offset of the objects, keys,
 *   values and class names.
 *
 * Numbers in the tables are variable length: seven bits per byte, low
 * first, the top bit set on the last byte.
 *
 *   object:     class name index, first value index, value count
 *   key:        length, UTF-8 bytes
 *   value:      key index, a type byte, then by type: 0-3 signed integers
 *               of 1, 2, 4 or 8 bytes; 4 false; 5 true; 6 float; 7 double;
 *               8 data (length, bytes); 9 nil; 10 an object (32-bit index)
 *   class name: length, count of fallback classes, those 32-bit class
 *               indices, the NUL-terminated name
 *
 * Object 0 is the root, holding UINibTopLevelObjectsKey, UINibObjectsKey
 * and UINibConnectionsKey. Collections hold their members under repeated
 * UINibEncoderEmptyKey values; strings their UTF-8 bytes under NS.bytes;
 * geometry is data, a type byte (7, double) then the numbers.
 */

NSString *const UINibExternalObjects = @"UINibExternalObjects";

enum {
	UIKitNibInt8, UIKitNibInt16, UIKitNibInt32, UIKitNibInt64,
	UIKitNibFalse, UIKitNibTrue, UIKitNibFloat, UIKitNibDouble,
	UIKitNibBytes, UIKitNibNil, UIKitNibObject,
};

typedef struct {
	uint32_t className;
	uint32_t firstValue;
	uint32_t valueCount;
} UIKitNibObjectEntry;

typedef struct {
	uint32_t key;
	uint8_t type;
	uint32_t length;
	const uint8_t *bytes;
} UIKitNibValueEntry;

static BOOL UIKitNibVarint(const uint8_t **cursor, const uint8_t *end, uint32_t *result)
{
	uint64_t value = 0;
	for (int shift = 0; *cursor < end && shift < 35; shift += 7) {
		uint8_t byte = *(*cursor)++;
		value |= (uint64_t)(byte & 0x7f) << shift;
		if (byte & 0x80) {
			*result = (uint32_t)value;
			return YES;
		}
	}
	return NO;
}

static uint32_t UIKitNibWord(const uint8_t *bytes)
{
	return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

/* File's Owner's stand-in for IBFirstResponder: an action sent to it goes
 * to the first responder, as a control with a nil target does. */
@interface UIKitNibFirstResponder : NSObject
+ (instancetype)placeholder;
@end

@implementation UIKitNibFirstResponder
+ (instancetype)placeholder
{
	static UIKitNibFirstResponder *placeholder;
	if (placeholder == nil)
		placeholder = [[self alloc] init];
	return placeholder;
}
@end

@interface UINibDecoder : NSCoder
- (instancetype)initWithData:(NSData *)data bundle:(NSBundle *)bundle owner:(id)owner externalObjects:(NSDictionary *)externalObjects;
- (id)rootObjectForKey:(NSString *)key;
- (BOOL)isPlaceholder:(id)object;
@property (nonatomic, readonly) NSBundle *bundle;
@end

@implementation UINibDecoder {
	NSData *_data;
	NSBundle *_bundle;
	id _owner;
	NSDictionary *_externalObjects;
	NSArray<NSString *> *_classNames;
	NSArray<NSArray<NSNumber *> *> *_fallbackClasses;
	NSDictionary<NSString *, NSNumber *> *_keyIndexes;
	UIKitNibObjectEntry *_objects;
	uint32_t _objectCount;
	UIKitNibValueEntry *_values;
	uint32_t _valueCount;
	/* Per object: NSNull until it is made; kept while it is being made, so
	 * that an object referring back to one being decoded gets it. */
	NSMutableArray *_instances;
	NSHashTable *_placeholders;
	uint32_t _current;
}

- (instancetype)initWithData:(NSData *)data bundle:(NSBundle *)bundle owner:(id)owner externalObjects:(NSDictionary *)externalObjects
{
	if ((self = [super init]) == nil)
		return nil;
	_data = data;
	_bundle = bundle ?: [NSBundle mainBundle];
	_owner = owner;
	_externalObjects = externalObjects;
	_placeholders = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory];
	if (![self parse])
		return nil;
	_instances = [NSMutableArray arrayWithCapacity:_objectCount];
	for (uint32_t i = 0; i < _objectCount; i++)
		[_instances addObject:[NSNull null]];
	return self;
}

- (void)dealloc
{
	free(_objects);
	free(_values);
}

- (BOOL)parse
{
	const uint8_t *bytes = [_data bytes];
	NSUInteger length = [_data length];
	if (length < 50 || memcmp(bytes, "NIBArchive", 10) != 0)
		return NO;
	uint32_t header[10];
	for (int i = 0; i < 10; i++)
		header[i] = UIKitNibWord(bytes + 10 + 4 * i);
	uint32_t objectCount = header[2], objectOffset = header[3];
	uint32_t keyCount = header[4], keyOffset = header[5];
	uint32_t valueCount = header[6], valueOffset = header[7];
	uint32_t classCount = header[8], classOffset = header[9];
	const uint8_t *end = bytes + length;
	if (objectOffset > length || keyOffset > length || valueOffset > length || classOffset > length)
		return NO;

	NSMutableArray *classNames = [NSMutableArray arrayWithCapacity:classCount];
	NSMutableArray *fallbacks = [NSMutableArray arrayWithCapacity:classCount];
	const uint8_t *cursor = bytes + classOffset;
	for (uint32_t i = 0; i < classCount; i++) {
		uint32_t nameLength, extra;
		if (!UIKitNibVarint(&cursor, end, &nameLength) || !UIKitNibVarint(&cursor, end, &extra)
		    || (uint64_t)extra * 4 + nameLength > (uint64_t)(end - cursor))
			return NO;
		NSMutableArray *classFallbacks = [NSMutableArray arrayWithCapacity:extra];
		for (uint32_t j = 0; j < extra; j++, cursor += 4)
			[classFallbacks addObject:@(UIKitNibWord(cursor))];
		NSUInteger nameBytes = nameLength > 0 && cursor[nameLength - 1] == 0 ? nameLength - 1 : nameLength;
		NSString *name = [[NSString alloc] initWithBytes:cursor length:nameBytes encoding:NSUTF8StringEncoding];
		[classNames addObject:name ?: @""];
		[fallbacks addObject:classFallbacks];
		cursor += nameLength;
	}

	NSMutableDictionary *keyIndexes = [NSMutableDictionary dictionaryWithCapacity:keyCount];
	cursor = bytes + keyOffset;
	for (uint32_t i = 0; i < keyCount; i++) {
		uint32_t keyLength;
		if (!UIKitNibVarint(&cursor, end, &keyLength) || keyLength > (uint32_t)(end - cursor))
			return NO;
		NSString *key = [[NSString alloc] initWithBytes:cursor length:keyLength encoding:NSUTF8StringEncoding];
		if (key != nil && [keyIndexes objectForKey:key] == nil)
			[keyIndexes setObject:@(i) forKey:key];
		cursor += keyLength;
	}

	_values = calloc(valueCount ? valueCount : 1, sizeof(UIKitNibValueEntry));
	cursor = bytes + valueOffset;
	for (uint32_t i = 0; i < valueCount; i++) {
		UIKitNibValueEntry *value = &_values[i];
		if (!UIKitNibVarint(&cursor, end, &value->key) || cursor >= end)
			return NO;
		value->type = *cursor++;
		static const uint8_t sizes[] = { 1, 2, 4, 8, 0, 0, 4, 8, 0, 0, 4 };
		if (value->type > UIKitNibObject)
			return NO;
		if (value->type == UIKitNibBytes) {
			if (!UIKitNibVarint(&cursor, end, &value->length))
				return NO;
		} else {
			value->length = sizes[value->type];
		}
		if (value->length > (uint32_t)(end - cursor))
			return NO;
		value->bytes = cursor;
		cursor += value->length;
	}
	_valueCount = valueCount;

	_objects = calloc(objectCount ? objectCount : 1, sizeof(UIKitNibObjectEntry));
	cursor = bytes + objectOffset;
	for (uint32_t i = 0; i < objectCount; i++) {
		UIKitNibObjectEntry *object = &_objects[i];
		if (!UIKitNibVarint(&cursor, end, &object->className) || !UIKitNibVarint(&cursor, end, &object->firstValue)
		    || !UIKitNibVarint(&cursor, end, &object->valueCount))
			return NO;
		if (object->className >= classCount || (uint64_t)object->firstValue + object->valueCount > valueCount)
			return NO;
	}
	_objectCount = objectCount;
	_classNames = classNames;
	_fallbackClasses = fallbacks;
	_keyIndexes = keyIndexes;
	return objectCount > 0;
}

- (NSBundle *)bundle { return _bundle; }
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)requiresSecureCoding { return NO; }
- (unsigned)systemVersion { return 2000; }

#pragma mark Values

- (const UIKitNibValueEntry *)entryForKey:(NSString *)key inObject:(uint32_t)index
{
	NSNumber *keyIndex = [_keyIndexes objectForKey:key];
	if (keyIndex == nil || index >= _objectCount)
		return NULL;
	uint32_t wanted = [keyIndex unsignedIntValue];
	const UIKitNibObjectEntry *object = &_objects[index];
	for (uint32_t i = 0; i < object->valueCount; i++) {
		const UIKitNibValueEntry *value = &_values[object->firstValue + i];
		if (value->key == wanted)
			return value;
	}
	return NULL;
}

- (const UIKitNibValueEntry *)entryForKey:(NSString *)key
{
	return [self entryForKey:key inObject:_current];
}

static int64_t UIKitNibInteger(const UIKitNibValueEntry *value)
{
	int64_t result = 0;
	switch (value->type) {
	case UIKitNibInt8: return (int8_t)value->bytes[0];
	case UIKitNibInt16: return (int16_t)(value->bytes[0] | (value->bytes[1] << 8));
	case UIKitNibInt32: return (int32_t)UIKitNibWord(value->bytes);
	case UIKitNibInt64: memcpy(&result, value->bytes, 8); return result;
	case UIKitNibTrue: return 1;
	case UIKitNibFloat: { float f; memcpy(&f, value->bytes, 4); return (int64_t)f; }
	case UIKitNibDouble: { double d; memcpy(&d, value->bytes, 8); return (int64_t)d; }
	default: return 0;
	}
}

static double UIKitNibReal(const UIKitNibValueEntry *value)
{
	if (value->type == UIKitNibFloat) {
		float f;
		memcpy(&f, value->bytes, 4);
		return f;
	}
	if (value->type == UIKitNibDouble) {
		double d;
		memcpy(&d, value->bytes, 8);
		return d;
	}
	return (double)UIKitNibInteger(value);
}

- (BOOL)containsValueForKey:(NSString *)key
{
	return [self entryForKey:key] != NULL;
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	return value != NULL && UIKitNibInteger(value) != 0;
}

- (int)decodeIntForKey:(NSString *)key
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	return value != NULL ? (int)UIKitNibInteger(value) : 0;
}

- (int32_t)decodeInt32ForKey:(NSString *)key { return [self decodeIntForKey:key]; }

- (int64_t)decodeInt64ForKey:(NSString *)key
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	return value != NULL ? UIKitNibInteger(value) : 0;
}

- (NSInteger)decodeIntegerForKey:(NSString *)key { return (NSInteger)[self decodeInt64ForKey:key]; }

- (double)decodeDoubleForKey:(NSString *)key
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	return value != NULL ? UIKitNibReal(value) : 0;
}

- (float)decodeFloatForKey:(NSString *)key { return (float)[self decodeDoubleForKey:key]; }

- (const uint8_t *)decodeBytesForKey:(NSString *)key returnedLength:(NSUInteger *)length
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	if (value == NULL || value->type != UIKitNibBytes) {
		if (length != NULL)
			*length = 0;
		return NULL;
	}
	if (length != NULL)
		*length = value->length;
	return value->bytes;
}

/* Geometry: a type byte, then that many numbers of it. */
- (NSUInteger)decodeNumbers:(double *)numbers count:(NSUInteger)count forKey:(NSString *)key
{
	NSUInteger length;
	const uint8_t *bytes = [self decodeBytesForKey:key returnedLength:&length];
	memset(numbers, 0, count * sizeof(double));
	if (bytes == NULL || length < 1)
		return 0;
	NSUInteger size = bytes[0] == UIKitNibFloat ? 4 : bytes[0] == UIKitNibDouble ? 8 : 0;
	if (size == 0)
		return 0;
	NSUInteger available = (length - 1) / size;
	if (available > count)
		available = count;
	for (NSUInteger i = 0; i < available; i++) {
		if (size == 4) {
			float f;
			memcpy(&f, bytes + 1 + 4 * i, 4);
			numbers[i] = f;
		} else {
			memcpy(&numbers[i], bytes + 1 + 8 * i, 8);
		}
	}
	return available;
}

- (CGPoint)decodeCGPointForKey:(NSString *)key
{
	double n[2];
	[self decodeNumbers:n count:2 forKey:key];
	return CGPointMake(n[0], n[1]);
}

- (CGSize)decodeCGSizeForKey:(NSString *)key
{
	double n[2];
	[self decodeNumbers:n count:2 forKey:key];
	return CGSizeMake(n[0], n[1]);
}

- (CGRect)decodeCGRectForKey:(NSString *)key
{
	double n[4];
	[self decodeNumbers:n count:4 forKey:key];
	return CGRectMake(n[0], n[1], n[2], n[3]);
}

- (UIEdgeInsets)decodeUIEdgeInsetsForKey:(NSString *)key
{
	double n[4];
	[self decodeNumbers:n count:4 forKey:key];
	return UIEdgeInsetsMake(n[0], n[1], n[2], n[3]);
}

- (UIOffset)decodeUIOffsetForKey:(NSString *)key
{
	double n[2];
	[self decodeNumbers:n count:2 forKey:key];
	return UIOffsetMake(n[0], n[1]);
}

- (CGAffineTransform)decodeCGAffineTransformForKey:(NSString *)key
{
	double n[6];
	if ([self decodeNumbers:n count:6 forKey:key] < 6)
		return CGAffineTransformIdentity;
	return CGAffineTransformMake(n[0], n[1], n[2], n[3], n[4], n[5]);
}

#pragma mark Objects

- (id)decodeObjectForKey:(NSString *)key
{
	const UIKitNibValueEntry *value = [self entryForKey:key];
	if (value == NULL)
		return nil;
	switch (value->type) {
	case UIKitNibObject:
		return [self objectAtIndex:UIKitNibWord(value->bytes)];
	case UIKitNibBytes:
		return [NSData dataWithBytes:value->bytes length:value->length];
	case UIKitNibNil:
		return nil;
	case UIKitNibFalse:
	case UIKitNibTrue:
		return @(value->type == UIKitNibTrue);
	case UIKitNibFloat:
	case UIKitNibDouble:
		return @(UIKitNibReal(value));
	default:
		return @(UIKitNibInteger(value));
	}
}

- (id)decodeObjectOfClass:(Class)cls forKey:(NSString *)key { return [self decodeObjectForKey:key]; }
- (id)decodeObjectOfClasses:(NSSet *)classes forKey:(NSString *)key { return [self decodeObjectForKey:key]; }
- (id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error { return [self decodeObjectForKey:key]; }

- (id)rootObjectForKey:(NSString *)key
{
	uint32_t saved = _current;
	_current = 0;
	id object = [self decodeObjectForKey:key];
	_current = saved;
	return object;
}

/* The members a collection holds, in order. */
- (NSArray *)membersOfObject:(uint32_t)index
{
	NSNumber *keyIndex = [_keyIndexes objectForKey:@"UINibEncoderEmptyKey"];
	NSMutableArray *members = [NSMutableArray array];
	if (keyIndex == nil)
		return members;
	const UIKitNibObjectEntry *object = &_objects[index];
	for (uint32_t i = 0; i < object->valueCount; i++) {
		const UIKitNibValueEntry *value = &_values[object->firstValue + i];
		if (value->key != [keyIndex unsignedIntValue])
			continue;
		id member = value->type == UIKitNibObject ? [self objectAtIndex:UIKitNibWord(value->bytes)] : nil;
		[members addObject:member ?: [NSNull null]];
	}
	return members;
}

- (BOOL)isPlaceholder:(id)object
{
	return object != nil && [_placeholders containsObject:object];
}

- (id)placeholderWithIdentifier:(NSString *)identifier
{
	id object;
	if ([identifier isEqualToString:@"IBFilesOwner"])
		object = _owner;
	else if ([identifier isEqualToString:@"IBFirstResponder"])
		object = [UIKitNibFirstResponder placeholder];
	else
		object = [_externalObjects objectForKey:identifier];
	if (object == nil && ![identifier isEqualToString:@"IBFilesOwner"])
		NSLog(@"UINib: the nib refers to an external object %@ it was not given", identifier);
	if (object != nil)
		[_placeholders addObject:object];
	return object;
}

/* What an archived class becomes: itself, else the classes the nib names
 * as its fallbacks. */
- (Class)classForName:(uint32_t)classIndex
{
	NSString *name = [_classNames objectAtIndex:classIndex];
	Class cls = NSClassFromString(name);
	if (cls != Nil)
		return cls;
	for (NSNumber *fallback in [_fallbackClasses objectAtIndex:classIndex]) {
		if ([fallback unsignedIntValue] < [_classNames count] && (cls = NSClassFromString([_classNames objectAtIndex:[fallback unsignedIntValue]])) != Nil)
			return cls;
	}
	return Nil;
}

- (id)objectAtIndex:(uint32_t)index
{
	if (index >= _objectCount)
		return nil;
	/* Objects that decode to nil are remembered as this. */
	static NSObject *nothing;
	if (nothing == nil)
		nothing = [[NSObject alloc] init];
	id existing = [_instances objectAtIndex:index];
	if (existing != [NSNull null])
		return existing == nothing ? nil : existing;

	uint32_t saved = _current;
	_current = index;
	id object = [self makeObject:index];
	_current = saved;
	[_instances replaceObjectAtIndex:index withObject:object ?: nothing];
	return object;
}

/* Records an object before it is initialized, so that the objects it
 * decodes can refer back to it. */
- (void)noteObject:(id)object
{
	[_instances replaceObjectAtIndex:_current withObject:object];
}

- (id)makeObject:(uint32_t)index
{
	NSString *className = [_classNames objectAtIndex:_objects[index].className];

	if ([className isEqualToString:@"NSString"] || [className isEqualToString:@"NSMutableString"]
	    || [className isEqualToString:@"NSLocalizableString"]) {
		NSUInteger length;
		const uint8_t *bytes = [self decodeBytesForKey:@"NS.bytes" returnedLength:&length];
		NSString *string = [[NSString alloc] initWithBytes:bytes ?: (const uint8_t *)"" length:length encoding:NSUTF8StringEncoding] ?: @"";
		return [className isEqualToString:@"NSMutableString"] ? [string mutableCopy] : string;
	}
	if ([className isEqualToString:@"NSArray"] || [className isEqualToString:@"NSMutableArray"]) {
		NSArray *members = [self membersOfObject:index];
		return [className isEqualToString:@"NSMutableArray"] ? [members mutableCopy] : members;
	}
	if ([className isEqualToString:@"NSSet"] || [className isEqualToString:@"NSMutableSet"])
		return [NSMutableSet setWithArray:[self membersOfObject:index]];
	if ([className isEqualToString:@"NSOrderedSet"] || [className isEqualToString:@"NSMutableOrderedSet"])
		return [NSMutableOrderedSet orderedSetWithArray:[self membersOfObject:index]];
	if ([className isEqualToString:@"NSDictionary"] || [className isEqualToString:@"NSMutableDictionary"]) {
		NSArray *members = [self membersOfObject:index];
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[members count] / 2];
		for (NSUInteger i = 0; i + 1 < [members count]; i += 2) {
			id key = [members objectAtIndex:i], value = [members objectAtIndex:i + 1];
			if (key != [NSNull null])
				[dictionary setObject:value forKey:key];
		}
		return dictionary;
	}
	if ([className isEqualToString:@"NSNumber"]) {
		if ([self containsValueForKey:@"NS.dblval"])
			return @([self decodeDoubleForKey:@"NS.dblval"]);
		if ([self containsValueForKey:@"NS.boolval"])
			return @([self decodeBoolForKey:@"NS.boolval"]);
		return @([self decodeInt64ForKey:@"NS.intval"]);
	}
	if ([className isEqualToString:@"NSNull"])
		return [NSNull null];
	if ([className isEqualToString:@"NSAttributedString"] || [className isEqualToString:@"NSMutableAttributedString"]) {
		NSString *string = [self decodeObjectForKey:@"NSString"] ?: @"";
		NSDictionary *attributes = [self decodeObjectForKey:@"NSAttributes"];
		if (![attributes isKindOfClass:[NSDictionary class]])
			attributes = nil;
		return [[NSMutableAttributedString alloc] initWithString:string attributes:attributes];
	}
	if ([className isEqualToString:@"NSParagraphStyle"] || [className isEqualToString:@"NSMutableParagraphStyle"]) {
		NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
		[style setAlignment:[self decodeIntegerForKey:@"NSAlignment"]];
		if ([self containsValueForKey:@"NSLineBreakMode"])
			[style setLineBreakMode:[self decodeIntegerForKey:@"NSLineBreakMode"]];
		return style;
	}
	if ([className isEqualToString:@"UIProxyObject"])
		return [self placeholderWithIdentifier:[self decodeObjectForKey:@"UIProxiedObjectIdentifier"]];

	Class cls;
	BOOL custom = NO;
	if ([className isEqualToString:@"UIClassSwapper"]) {
		/* An object of the app's class, archived as the UIKit class it
		 * derives from (or as UICustomObject, a plain object). */
		NSString *name = [self decodeObjectForKey:@"UIClassName"];
		NSString *original = [self decodeObjectForKey:@"UIOriginalClassName"];
		custom = [original isEqualToString:@"UICustomObject"];
		cls = NSClassFromString(name);
		if (cls == Nil) {
			NSLog(@"Unknown class %@ in Interface Builder file.", name);
			cls = custom ? [NSObject class] : NSClassFromString(original);
		}
	} else {
		cls = [self classForName:_objects[index].className];
		if (cls == Nil) {
			NSLog(@"UINib: no class %@; the nib's object is left out", className);
			return nil;
		}
	}
	if (cls == Nil)
		return nil;

	id object = [cls alloc];
	[self noteObject:object];
	if (custom || ![object respondsToSelector:@selector(initWithCoder:)])
		object = [object init];
	else
		object = [object initWithCoder:self];
	if (object != nil && [object respondsToSelector:@selector(awakeAfterUsingCoder:)])
		object = [object awakeAfterUsingCoder:self];
	return object;
}

@end

NSBundle *UIKitNibBundle(NSCoder *coder)
{
	return [coder isKindOfClass:[UINibDecoder class]] ? [(UINibDecoder *)coder bundle] : [NSBundle mainBundle];
}

#pragma mark - Connections

/* Archived connections, made once every object exists. */
@interface UIRuntimeConnection : NSObject <NSCoding> {
@protected
	id _source;
	id _destination;
	NSString *_label;
}
- (void)connect;
@end

@implementation UIRuntimeConnection

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) {
		_source = [coder decodeObjectForKey:@"UISource"];
		_destination = [coder decodeObjectForKey:@"UIDestination"];
		_label = [coder decodeObjectForKey:@"UILabel"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder { }
- (void)connect { }

@end

/* source.label = destination */
@interface UIRuntimeOutletConnection : UIRuntimeConnection
@end

@implementation UIRuntimeOutletConnection

- (void)connect
{
	if (_source == nil || [_label length] == 0 || [_destination isKindOfClass:[UIKitNibFirstResponder class]])
		return;
	@try {
		[_source setValue:_destination forKey:_label];
	} @catch (NSException *exception) {
		NSLog(@"UINib: cannot connect the outlet %@ of %@: %@", _label, [_source class], [exception reason]);
	}
}

@end

/* An outlet collection: source.label gets the destinations, in order. */
@interface UIRuntimeOutletCollectionConnection : UIRuntimeConnection {
	NSArray *_destinations;
	BOOL _adds;
}
@end

@implementation UIRuntimeOutletCollectionConnection

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder])) {
		_destinations = [coder decodeObjectForKey:@"UIDestinations"];
		_adds = [coder decodeBoolForKey:@"UIAddsContentToExistingCollection"];
	}
	return self;
}

- (void)connect
{
	if (_source == nil || [_label length] == 0)
		return;
	NSMutableArray *collection = [NSMutableArray array];
	@try {
		if (_adds || _destinations == nil) {
			id existing = [_source valueForKey:_label];
			if ([existing isKindOfClass:[NSArray class]])
				[collection addObjectsFromArray:existing];
		}
		if (_destinations != nil)
			[collection addObjectsFromArray:_destinations];
		else if (_destination != nil)
			[collection addObject:_destination];
		[_source setValue:collection forKey:_label];
	} @catch (NSException *exception) {
		NSLog(@"UINib: cannot connect the outlet collection %@ of %@: %@", _label, [_source class], [exception reason]);
	}
}

@end

/* An action: the source sends label to the destination (the first
 * responder for IBFirstResponder). */
@interface UIRuntimeEventConnection : UIRuntimeConnection {
	UIControlEvents _events;
}
@end

@implementation UIRuntimeEventConnection

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]))
		_events = [coder containsValueForKey:@"UIEventMask"] ? (UIControlEvents)[coder decodeIntegerForKey:@"UIEventMask"] : UIControlEventTouchUpInside;
	return self;
}

- (void)connect
{
	if (_source == nil || [_label length] == 0)
		return;
	SEL action = NSSelectorFromString(_label);
	id target = [_destination isKindOfClass:[UIKitNibFirstResponder class]] ? nil : _destination;
	if ([_source isKindOfClass:[UIControl class]]) {
		[(UIControl *)_source addTarget:target action:action forControlEvents:_events];
	} else if ([_source isKindOfClass:[UIGestureRecognizer class]]) {
		[(UIGestureRecognizer *)_source addTarget:target action:action];
	} else if ([_source respondsToSelector:@selector(setTarget:)] && [_source respondsToSelector:@selector(setAction:)]) {
		[_source setTarget:target];
		[_source setAction:action];
	} else {
		NSLog(@"UINib: %@ cannot send actions (%@)", [_source class], _label);
	}
}

@end

/* Interface Builder's "User Defined Runtime Attributes". */
@interface UIRuntimeKeyValuePair : NSObject <NSCoding>
- (void)apply;
@end

@implementation UIRuntimeKeyValuePair {
	id _object;
	NSString *_keyPath;
	id _value;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) {
		_object = [coder decodeObjectForKey:@"UIObject"];
		_keyPath = [coder decodeObjectForKey:@"UIKeyPath"];
		_value = [coder decodeObjectForKey:@"UIValue"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder { }

- (void)apply
{
	if (_object == nil || [_keyPath length] == 0)
		return;
	@try {
		[_object setValue:_value forKeyPath:_keyPath];
	} @catch (NSException *exception) {
		NSLog(@"UINib: cannot set %@ of %@: %@", _keyPath, [_object class], [exception reason]);
	}
}

@end

#pragma mark - UINib

/* Name~iphone first, then Name; a .nib is a file, or a directory holding
 * runtime.nib (for iOS 6 and later) next to objects.nib (older systems). */
static NSString *UIKitNibPath(NSBundle *bundle, NSString *name)
{
	if ([name length] == 0)
		return nil;
	if ([[name pathExtension] isEqualToString:@"nib"])
		name = [name stringByDeletingPathExtension];
	NSString *path = nil;
	if ([name isAbsolutePath]) {
		for (NSString *candidate in @[ [name stringByAppendingString:@"~iphone.nib"], [name stringByAppendingPathExtension:@"nib"] ]) {
			if ([[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
				path = candidate;
				break;
			}
		}
	} else {
		path = [bundle pathForResource:[name stringByAppendingString:@"~iphone"] ofType:@"nib"] ?: [bundle pathForResource:name ofType:@"nib"];
	}
	return path;
}

static NSData *UIKitNibData(NSString *path)
{
	BOOL directory = NO;
	if (path == nil || ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory])
		return nil;
	if (directory) {
		NSString *runtime = [path stringByAppendingPathComponent:@"runtime.nib"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:runtime]) {
			NSLog(@"UINib: %@ has no runtime.nib (only nibs compiled for iOS 6 and later load)", path);
			return nil;
		}
		path = runtime;
	}
	return [NSData dataWithContentsOfFile:path];
}

@implementation UINib {
	NSData *_data;
	NSBundle *_bundle;
	NSString *_name;
}

+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundleOrNil
{
	NSBundle *bundle = bundleOrNil ?: [NSBundle mainBundle];
	NSString *path = UIKitNibPath(bundle, name);
	if (path == nil)
		return nil;
	UINib *nib = [[self alloc] init];
	nib->_bundle = bundle;
	nib->_name = path;
	return nib;
}

+ (UINib *)nibWithData:(NSData *)data bundle:(NSBundle *)bundleOrNil
{
	if (data == nil)
		return nil;
	UINib *nib = [[self alloc] init];
	nib->_data = data;
	nib->_bundle = bundleOrNil ?: [NSBundle mainBundle];
	return nib;
}

- (NSArray *)instantiateWithOwner:(id)ownerOrNil options:(NSDictionary *)optionsOrNil
{
	if (_data == nil)
		_data = UIKitNibData(_name);
	UINibDecoder *decoder = [[UINibDecoder alloc] initWithData:_data bundle:_bundle owner:ownerOrNil externalObjects:[optionsOrNil objectForKey:UINibExternalObjects]];
	if (decoder == nil) {
		[NSException raise:NSInternalInconsistencyException format:@"Could not load the nib %@: not a compiled nib", _name ?: @"(data)"];
		return nil;
	}

	NSArray *topLevel = [decoder rootObjectForKey:@"UINibTopLevelObjectsKey"];
	NSArray *objects = [decoder rootObjectForKey:@"UINibObjectsKey"];
	NSArray *connections = [decoder rootObjectForKey:@"UINibConnectionsKey"];
	NSArray *pairs = [decoder rootObjectForKey:@"UINibKeyValuePairsKey"];
	NSArray *visibleWindows = [decoder rootObjectForKey:@"UINibVisibleWindowsKey"];

	for (id connection in connections) {
		if ([connection respondsToSelector:@selector(connect)])
			[connection connect];
	}
	for (id pair in pairs) {
		if ([pair respondsToSelector:@selector(apply)])
			[pair apply];
	}
	NSMutableArray *awake = [NSMutableArray array];
	for (id object in [objects isKindOfClass:[NSArray class]] ? objects : topLevel) {
		if (object != [NSNull null] && ![decoder isPlaceholder:object] && [awake indexOfObjectIdenticalTo:object] == NSNotFound)
			[awake addObject:object];
	}
	for (id object in awake)
		[object awakeFromNib];
	for (UIWindow *window in visibleWindows) {
		if ([window isKindOfClass:[UIWindow class]])
			[window makeKeyAndVisible];
	}

	NSMutableArray *result = [NSMutableArray array];
	for (id object in topLevel) {
		if (object != [NSNull null] && ![decoder isPlaceholder:object])
			[result addObject:object];
	}
	return result;
}

@end

@implementation NSBundle (UINibLoadingAdditions)

- (NSArray *)loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options
{
	UINib *nib = [UINib nibWithNibName:name bundle:self];
	if (nib == nil) {
		[NSException raise:NSInternalInconsistencyException format:@"Could not load NIB in bundle: '%@' with name '%@'", self, name];
		return nil;
	}
	return [nib instantiateWithOwner:owner options:options];
}

@end

@implementation NSObject (UINibLoadingAdditions)
- (void)awakeFromNib { }
- (void)prepareForInterfaceBuilder { }
@end

@implementation NSObject (UIKitNibDecoding)
- (void)uikitDecodeNib:(NSCoder *)coder { }
@end

IMP UIKitOwnImplementation(Class cls, SEL selector)
{
	static const char *image;
	if (image == NULL)
		image = class_getImageName([UIView class]);
	Class own = cls;
	while (own != Nil && (class_getImageName(own) == NULL || strcmp(class_getImageName(own), image) != 0))
		own = class_getSuperclass(own);
	return class_getMethodImplementation(own ?: cls, selector);
}

#pragma mark - Geometry in other archives

@implementation NSCoder (UIGeometryKeyedCoding)

- (void)encodeCGPoint:(CGPoint)point forKey:(NSString *)key { [self encodeObject:NSStringFromCGPoint(point) forKey:key]; }
- (void)encodeCGSize:(CGSize)size forKey:(NSString *)key { [self encodeObject:NSStringFromCGSize(size) forKey:key]; }
- (void)encodeCGRect:(CGRect)rect forKey:(NSString *)key { [self encodeObject:NSStringFromCGRect(rect) forKey:key]; }
- (void)encodeCGAffineTransform:(CGAffineTransform)transform forKey:(NSString *)key { [self encodeObject:NSStringFromCGAffineTransform(transform) forKey:key]; }
- (void)encodeUIEdgeInsets:(UIEdgeInsets)insets forKey:(NSString *)key { [self encodeObject:NSStringFromUIEdgeInsets(insets) forKey:key]; }
- (void)encodeUIOffset:(UIOffset)offset forKey:(NSString *)key { [self encodeObject:NSStringFromCGPoint(CGPointMake(offset.horizontal, offset.vertical)) forKey:key]; }

static NSString *UIKitArchivedString(NSCoder *coder, NSString *key)
{
	id value = [coder decodeObjectForKey:key];
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (CGPoint)decodeCGPointForKey:(NSString *)key { NSString *s = UIKitArchivedString(self, key); return s ? CGPointFromString(s) : CGPointZero; }
- (CGSize)decodeCGSizeForKey:(NSString *)key { NSString *s = UIKitArchivedString(self, key); return s ? CGSizeFromString(s) : CGSizeZero; }
- (CGRect)decodeCGRectForKey:(NSString *)key { NSString *s = UIKitArchivedString(self, key); return s ? CGRectFromString(s) : CGRectZero; }
- (CGAffineTransform)decodeCGAffineTransformForKey:(NSString *)key { NSString *s = UIKitArchivedString(self, key); return s ? CGAffineTransformFromString(s) : CGAffineTransformIdentity; }
- (UIEdgeInsets)decodeUIEdgeInsetsForKey:(NSString *)key { NSString *s = UIKitArchivedString(self, key); return s ? UIEdgeInsetsFromString(s) : UIEdgeInsetsZero; }

- (UIOffset)decodeUIOffsetForKey:(NSString *)key
{
	NSString *s = UIKitArchivedString(self, key);
	CGPoint point = s ? CGPointFromString(s) : CGPointZero;
	return UIOffsetMake(point.x, point.y);
}

@end

#pragma mark - Storyboards

/* File's Owner of a scene's nib: the nib connects its view controller to it. */
@interface UIStoryboardScene : NSObject
@property (nonatomic, strong) UIViewController *sceneViewController;
@end

@implementation UIStoryboardScene
@end

@interface UIStoryboard ()
- (NSBundle *)uikitBundle;
- (NSString *)uikitPathForNibNamed:(NSString *)name;
@end

static char UIKitStoryboardKey, UIKitStoryboardIdentifierKey, UIKitSegueTemplatesKey, UIKitViewExternalsKey;

@implementation UIStoryboard {
	NSString *_path;
	NSBundle *_bundle;
	NSDictionary *_info;
}

+ (UIStoryboard *)storyboardWithName:(NSString *)name bundle:(NSBundle *)storyboardBundleOrNil
{
	NSBundle *bundle = storyboardBundleOrNil ?: [NSBundle mainBundle];
	NSString *path = [bundle pathForResource:[name stringByAppendingString:@"~iphone"] ofType:@"storyboardc"]
		?: [bundle pathForResource:name ofType:@"storyboardc"];
	NSDictionary *info = path != nil ? [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]] : nil;
	if (info == nil) {
		[NSException raise:NSInvalidArgumentException format:@"Could not find a storyboard named '%@' in bundle %@", name, bundle];
		return nil;
	}
	UIStoryboard *storyboard = [[self alloc] init];
	storyboard->_path = path;
	storyboard->_bundle = bundle;
	storyboard->_info = info;
	return storyboard;
}

- (NSBundle *)uikitBundle { return _bundle; }

- (NSString *)uikitPathForNibNamed:(NSString *)name
{
	return [_path stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"nib"]];
}

- (UIViewController *)instantiateInitialViewController
{
	NSString *identifier = [_info objectForKey:@"UIStoryboardDesignatedEntryPointIdentifier"];
	return identifier != nil ? [self instantiateViewControllerWithIdentifier:identifier] : nil;
}

- (UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier
{
	NSString *nibName = [[_info objectForKey:@"UIViewControllerIdentifiersToNibNames"] objectForKey:identifier];
	if (nibName == nil) {
		[NSException raise:NSInvalidArgumentException format:@"Storyboard (%@) doesn't contain a view controller with identifier '%@'", self, identifier];
		return nil;
	}
	UINib *nib = [UINib nibWithData:UIKitNibData([self uikitPathForNibNamed:nibName]) bundle:_bundle];
	UIStoryboardScene *scene = [[UIStoryboardScene alloc] init];
	NSArray *objects = [nib instantiateWithOwner:scene options:@{ UINibExternalObjects : @{ @"UIStoryboardPlaceholder" : self } }];
	UIViewController *controller = [scene sceneViewController];
	if (controller == nil) {
		for (id object in objects) {
			if ([object isKindOfClass:[UIViewController class]]) {
				controller = object;
				break;
			}
		}
	}
	if (controller != nil) {
		objc_setAssociatedObject(controller, &UIKitStoryboardKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		if (objc_getAssociatedObject(controller, &UIKitStoryboardIdentifierKey) == nil)
			objc_setAssociatedObject(controller, &UIKitStoryboardIdentifierKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
		/* A container's relationships (a navigation controller's root). */
		[controller uikitPerformSeguesOnLoad:NO];
	}
	return controller;
}

@end

/* A segue as the storyboard describes it; it makes the segue when performed. */
@interface UIStoryboardSegueTemplate : NSObject <NSCoding> {
@protected
	NSString *_identifier;
	NSString *_destinationIdentifier;
	NSString *_segueClassName;
	BOOL _performOnViewLoad;
}
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, readonly) NSString *identifier;
- (void)perform:(id)sender;
- (void)uikitPerformWithSender:(id)sender;
- (BOOL)uikitPerformsOnViewLoad;
- (UIStoryboardSegue *)segueWithDestinationViewController:(UIViewController *)destination;
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source;
@end

@implementation UIStoryboardSegueTemplate

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) {
		_identifier = [coder decodeObjectForKey:@"UIIdentifier"];
		_destinationIdentifier = [coder decodeObjectForKey:@"UIDestinationViewControllerIdentifier"];
		_segueClassName = [coder decodeObjectForKey:@"UISegueClassName"];
		_performOnViewLoad = [coder decodeBoolForKey:@"UIPerformOnViewLoad"];
		_viewController = [coder decodeObjectForKey:@"UIViewController"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder { }
- (NSString *)identifier { return _identifier; }
- (BOOL)uikitPerformsOnViewLoad { return _performOnViewLoad; }

- (UIViewController *)destinationViewController
{
	UIStoryboard *storyboard = [_viewController storyboard];
	return _destinationIdentifier != nil ? [storyboard instantiateViewControllerWithIdentifier:_destinationIdentifier] : nil;
}

- (UIStoryboardSegue *)segueWithDestinationViewController:(UIViewController *)destination
{
	Class segueClass = _segueClassName != nil ? NSClassFromString(_segueClassName) : Nil;
	UIViewController *source = _viewController;
	if (segueClass != Nil && [segueClass isSubclassOfClass:[UIStoryboardSegue class]])
		return [[segueClass alloc] initWithIdentifier:_identifier source:source destination:destination];
	__weak UIStoryboardSegueTemplate *weakSelf = self;
	return [UIStoryboardSegue segueWithIdentifier:_identifier source:source destination:destination performHandler:^{
		[weakSelf uikitShow:destination from:source];
	}];
}

- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	[source showViewController:destination sender:source];
}

- (void)uikitPerformWithSender:(id)sender
{
	UIViewController *source = _viewController;
	UIViewController *destination = [self destinationViewController];
	if (source == nil || destination == nil) {
		NSLog(@"UIStoryboardSegue: cannot perform segue %@ (no source or destination)", _identifier);
		return;
	}
	UIStoryboardSegue *segue = [self segueWithDestinationViewController:destination];
	[source prepareForSegue:segue sender:sender];
	[segue perform];
}

/* What a button connected to the segue sends. */
- (void)perform:(id)sender
{
	UIViewController *source = _viewController;
	if (_identifier != nil && source != nil && ![source shouldPerformSegueWithIdentifier:_identifier sender:sender])
		return;
	[self uikitPerformWithSender:sender];
}

@end

@interface UIStoryboardShowSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardShowSegueTemplate
@end

@interface UIStoryboardPushSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardPushSegueTemplate
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	UINavigationController *navigation = [source isKindOfClass:[UINavigationController class]] ? (UINavigationController *)source : [source navigationController];
	if (navigation != nil)
		[navigation pushViewController:destination animated:YES];
	else
		[source presentViewController:destination animated:YES completion:nil];
}
@end

@interface UIStoryboardShowDetailSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardShowDetailSegueTemplate
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	[source showDetailViewController:destination sender:source];
}
@end

@interface UIStoryboardPresentationSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardPresentationSegueTemplate
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	[source presentViewController:destination animated:YES completion:nil];
}
@end

@interface UIStoryboardModalSegueTemplate : UIStoryboardPresentationSegueTemplate
@end
@implementation UIStoryboardModalSegueTemplate
@end

@interface UIStoryboardPopoverPresentationSegueTemplate : UIStoryboardPresentationSegueTemplate
@end
@implementation UIStoryboardPopoverPresentationSegueTemplate
@end

/* A container's child: added when the container's view loads. */
@interface UIStoryboardEmbedSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardEmbedSegueTemplate
- (BOOL)uikitPerformsOnViewLoad { return YES; }
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	[source addChildViewController:destination];
	UIView *container = [source view];
	[[destination view] setFrame:[container bounds]];
	[[destination view] setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[container addSubview:[destination view]];
	[destination didMoveToParentViewController:source];
}
@end

/* A navigation controller's root, a tab bar controller's tabs. */
@interface UIStoryboardRelationshipSegueTemplate : UIStoryboardSegueTemplate
@end
@implementation UIStoryboardRelationshipSegueTemplate
- (void)uikitShow:(UIViewController *)destination from:(UIViewController *)source
{
	if ([source isKindOfClass:[UINavigationController class]]) {
		[(UINavigationController *)source setViewControllers:@[ destination ] animated:NO];
	} else if ([source isKindOfClass:[UITabBarController class]]) {
		UITabBarController *tabs = (UITabBarController *)source;
		[tabs setViewControllers:[[tabs viewControllers] ?: @[] arrayByAddingObject:destination] animated:NO];
	} else {
		[source addChildViewController:destination];
	}
}
@end

@implementation UIViewController (UIStoryboard)

- (UIStoryboard *)storyboard
{
	return objc_getAssociatedObject(self, &UIKitStoryboardKey);
}

/* Set by the scene's nib (its "storyboard" outlet). */
- (void)setStoryboard:(UIStoryboard *)storyboard
{
	objc_setAssociatedObject(self, &UIKitStoryboardKey, storyboard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIViewController (UIKitStoryboardPrivate)

- (void)uikitSetStoryboardIdentifier:(NSString *)identifier
{
	objc_setAssociatedObject(self, &UIKitStoryboardIdentifierKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)uikitSetSegueTemplates:(NSArray *)templates
{
	for (UIStoryboardSegueTemplate *segueTemplate in templates) {
		if ([segueTemplate isKindOfClass:[UIStoryboardSegueTemplate class]] && [segueTemplate viewController] == nil)
			[segueTemplate setViewController:self];
	}
	objc_setAssociatedObject(self, &UIKitSegueTemplatesKey, templates, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)uikitSetViewExternalObjects:(NSDictionary *)objects
{
	objc_setAssociatedObject(self, &UIKitViewExternalsKey, objects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* Relationship and embed segues run as soon as the view controller (for a
 * container) or its view exists. */
- (void)uikitPerformSeguesOnLoad:(BOOL)viewLoaded
{
	for (UIStoryboardSegueTemplate *segueTemplate in objc_getAssociatedObject(self, &UIKitSegueTemplatesKey)) {
		if (![segueTemplate isKindOfClass:[UIStoryboardSegueTemplate class]])
			continue;
		BOOL relationship = [segueTemplate isKindOfClass:[UIStoryboardRelationshipSegueTemplate class]];
		BOOL embed = [segueTemplate isKindOfClass:[UIStoryboardEmbedSegueTemplate class]] || [segueTemplate uikitPerformsOnViewLoad];
		if ((relationship && !viewLoaded) || (embed && !relationship && viewLoaded))
			[segueTemplate uikitPerformWithSender:self];
	}
}

/* The view's nib: the one the view controller was given, else one named
 * after its class ("MyView" for MyViewController, then "MyViewController"). */
- (BOOL)uikitLoadViewFromNib
{
	NSString *name = [self nibName];
	UIStoryboard *storyboard = [self storyboard];
	NSData *data = nil;
	NSBundle *bundle = [self nibBundle] ?: [NSBundle mainBundle];
	if (name != nil && storyboard != nil) {
		data = UIKitNibData([storyboard uikitPathForNibNamed:name]);
		bundle = [storyboard uikitBundle];
	}
	if (data == nil) {
		NSMutableArray *names = [NSMutableArray array];
		if (name != nil) {
			[names addObject:name];
		} else {
			for (Class cls = [self class]; cls != Nil && cls != [UIViewController class]; cls = [cls superclass]) {
				NSString *className = NSStringFromClass(cls);
				if ([className hasSuffix:@"Controller"])
					[names addObject:[className substringToIndex:[className length] - [@"Controller" length]]];
				[names addObject:className];
				/* Only the class's own name, as on iOS. */
				break;
			}
		}
		for (NSString *candidate in names) {
			if ((data = UIKitNibData(UIKitNibPath(bundle, candidate))) != nil)
				break;
		}
	}
	if (data == nil) {
		if (name != nil)
			NSLog(@"UIViewController: could not load the nib %@ of %@", name, [self class]);
		return NO;
	}
	NSDictionary *externals = objc_getAssociatedObject(self, &UIKitViewExternalsKey);
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	if ([externals count] > 0 || storyboard != nil) {
		NSMutableDictionary *objects = [NSMutableDictionary dictionaryWithDictionary:externals ?: @{}];
		if (storyboard != nil)
			[objects setObject:storyboard forKey:@"UIStoryboardPlaceholder"];
		[options setObject:objects forKey:UINibExternalObjects];
	}
	[[UINib nibWithData:data bundle:bundle] instantiateWithOwner:self options:options];
	if (![self isViewLoaded])
		NSLog(@"UIViewController: %@ loaded its nib but the view outlet was not set", [self class]);
	return [self isViewLoaded];
}

- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
	for (UIStoryboardSegueTemplate *segueTemplate in objc_getAssociatedObject(self, &UIKitSegueTemplatesKey)) {
		if ([segueTemplate isKindOfClass:[UIStoryboardSegueTemplate class]] && [[segueTemplate identifier] isEqualToString:identifier]) {
			[segueTemplate uikitPerformWithSender:sender];
			return;
		}
	}
	[NSException raise:NSInvalidArgumentException format:@"Receiver (%@) has no segue with identifier '%@'", self, identifier];
}

@end

#pragma mark - The main interface file

/* UIMainStoryboardFile or NSMainNibFile (or their ~iphone forms) from
 * Info.plist, before the delegate hears that launching finished. */
void UIKitLoadMainInterface(UIApplication *application)
{
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *storyboardName = [bundle objectForInfoDictionaryKey:@"UIMainStoryboardFile~iphone"] ?: [bundle objectForInfoDictionaryKey:@"UIMainStoryboardFile"];
	NSString *nibName = [bundle objectForInfoDictionaryKey:@"NSMainNibFile~iphone"] ?: [bundle objectForInfoDictionaryKey:@"NSMainNibFile"];
	if (storyboardName != nil) {
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:bundle];
		UIViewController *controller = [storyboard instantiateInitialViewController];
		id delegate = [application delegate];
		UIWindow *window = [delegate respondsToSelector:@selector(window)] ? [delegate window] : nil;
		if (window == nil) {
			window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
			if ([delegate respondsToSelector:@selector(setWindow:)])
				[delegate setWindow:window];
			else
				objc_setAssociatedObject(application, &UIKitStoryboardKey, window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		[window setRootViewController:controller];
	} else if (nibName != nil) {
		[bundle loadNibNamed:nibName owner:application options:nil];
	}
}

/* The main storyboard's window, shown once launching finished. */
void UIKitShowMainInterface(UIApplication *application)
{
	NSBundle *bundle = [NSBundle mainBundle];
	if ([bundle objectForInfoDictionaryKey:@"UIMainStoryboardFile~iphone"] == nil && [bundle objectForInfoDictionaryKey:@"UIMainStoryboardFile"] == nil)
		return;
	id delegate = [application delegate];
	UIWindow *window = [delegate respondsToSelector:@selector(window)] ? [delegate window] : objc_getAssociatedObject(application, &UIKitStoryboardKey);
	if (window != nil && [window isHidden])
		[window makeKeyAndVisible];
}
