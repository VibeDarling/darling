/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef WEBKITLEGACY_WEBSCRIPTOBJECT_H
#define WEBKITLEGACY_WEBSCRIPTOBJECT_H

#import <Foundation/Foundation.h>
#include <JavaScriptCore/JavaScriptCore.h>

/*
 * The WebScripting informal protocol, as WebKit documents it: a class lists
 * what scripts may see.  NSObject answers "excluded" for everything, so a
 * class exposes nothing until it overrides these.
 */
@interface NSObject (WebScripting)
+ (NSString *)webScriptNameForSelector:(SEL)selector;
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector;
+ (NSString *)webScriptNameForKey:(const char *)name;
+ (BOOL)isKeyExcludedFromWebScript:(const char *)name;
@end

/* Optional WebScripting methods: NSObject does not implement these. */
@interface NSObject (WebScriptingOptional)
- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)arguments;
- (id)invokeDefaultMethodWithArguments:(NSArray *)arguments;
- (void)finalizeForWebScript;
@end

/*
 * A JavaScript object in a page.  Darling's pages run in a separate web
 * engine (see DWKBridge.h), so this is a handle; every message is a round
 * trip to the engine.
 */
@interface WebScriptObject : NSObject
+ (BOOL)throwException:(NSString *)exceptionMessage;
- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments;
- (id)evaluateWebScript:(NSString *)script;
- (void)removeWebScriptKey:(NSString *)name;
- (NSString *)stringRepresentation;
- (id)webScriptValueAtIndex:(unsigned)index;
- (void)setWebScriptValueAtIndex:(unsigned)index value:(id)value;
- (void)setException:(NSString *)description;
/* There is no JavaScriptCore context in this process: always NULL. */
- (JSObjectRef)JSObject;
@end

/* JavaScript's undefined. */
@interface WebUndefined : NSObject <NSCoding, NSCopying>
+ (WebUndefined *)undefined;
@end

#endif
