/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * The part of iOS's WebCore.framework that apps call directly: script
 * objects, WebUndefined and the web thread lock.  Script objects are
 * handles into darling-webhost's web processes; DWKBridge carries the calls.
 */

#import <WebKitLegacy/WebScriptObject.h>
#import <WebKitLegacy/WebThread.h>
#import <WebKitLegacy/DWKBridge.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

#pragma mark - Web thread

static pthread_mutex_t sWebThreadMutex;
static __thread int sWebThreadDepth;

static void WebThreadInitMutex(void)
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		pthread_mutexattr_t attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&sWebThreadMutex, &attr);
		pthread_mutexattr_destroy(&attr);
	});
}

void WebThreadLock(void)
{
	WebThreadInitMutex();
	pthread_mutex_lock(&sWebThreadMutex);
	sWebThreadDepth++;
}

void WebThreadUnlock(void)
{
	if (sWebThreadDepth == 0)
		return;
	sWebThreadDepth--;
	pthread_mutex_unlock(&sWebThreadMutex);
}

void WebThreadUnlockFromAnyThread(void)
{
	WebThreadUnlock();
}

bool WebThreadIsLocked(void)
{
	return sWebThreadDepth > 0;
}

bool WebThreadIsCurrent(void)
{
	return false;
}

bool WebThreadNotCurrent(void)
{
	return true;
}

bool WebThreadIsEnabled(void)
{
	return true;
}

void WebThreadEnable(void)
{
}

void WebThreadRun(void (^block)(void))
{
	if (pthread_main_np())
		block();
	else
		dispatch_sync(dispatch_get_main_queue(), block);
}

NSInvocation *WebThreadCreateNSInvocation(id target, SEL selector)
{
	NSMethodSignature *signature = [target methodSignatureForSelector:selector];
	if (signature == nil)
		return nil;
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setTarget:target];
	[invocation setSelector:selector];
	[invocation retainArguments];
	return invocation;
}

void WebThreadCallAPI(NSInvocation *invocation)
{
	WebThreadRun(^{
		[invocation invoke];
	});
}

#pragma mark - WebScripting defaults

@implementation NSObject (WebScripting)

+ (NSString *)webScriptNameForSelector:(SEL)selector
{
	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
	return YES;
}

+ (NSString *)webScriptNameForKey:(const char *)name
{
	return nil;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return YES;
}

@end

#pragma mark - WebUndefined

@implementation WebUndefined

+ (WebUndefined *)undefined
{
	static WebUndefined *undefined;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		undefined = [[WebUndefined alloc] init];
	});
	return undefined;
}

- (id)initWithCoder:(NSCoder *)coder
{
	return [WebUndefined undefined];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (NSString *)description
{
	return @"undefined";
}

@end

#pragma mark - Exposing Objective-C objects

/* The JS name lookup WebKit's Objective-C bindings do (objc_class.mm). */

static NSString *const DWKMethodMarker = @"$m";

/* "foo_bar_" -> "foo:bar:", "$_" -> "_". */
static NSString *DWKSelectorNameForScriptName(NSString *name)
{
	NSMutableString *selector = [NSMutableString string];
	NSUInteger length = [name length];
	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [name characterAtIndex:i];
		if (c == '$' && i + 1 < length) {
			c = [name characterAtIndex:++i];
			[selector appendFormat:@"%C", c];
		} else if (c == '_') {
			[selector appendString:@":"];
		} else {
			[selector appendFormat:@"%C", c];
		}
	}
	return selector;
}

static SEL DWKFindMethod(id object, NSString *name)
{
	NSString *selectorName = DWKSelectorNameForScriptName(name);
	for (Class cls = object_getClass(object); cls != Nil; cls = class_getSuperclass(cls)) {
		unsigned count = 0;
		Method *methods = class_copyMethodList(cls, &count);
		SEL found = NULL;
		for (unsigned i = 0; i < count && found == NULL; i++) {
			SEL selector = method_getName(methods[i]);
			if ([cls isSelectorExcludedFromWebScript:selector])
				continue;
			NSString *mapped = [cls webScriptNameForSelector:selector];
			if ((mapped != nil && [mapped isEqualToString:name]) ||
			    strcmp(sel_getName(selector), [selectorName UTF8String]) == 0)
				found = selector;
		}
		free(methods);
		if (found != NULL)
			return found;
	}
	return NULL;
}

/* A key the object exposes as a property: from -attributeKeys if it has
 * them, else its instance variables. */
static NSString *DWKFindKey(id object, NSString *name)
{
	Class cls = object_getClass(object);
	if ([object respondsToSelector:@selector(attributeKeys)]) {
		for (NSString *key in [object performSelector:@selector(attributeKeys)]) {
			const char *utf8 = [key UTF8String];
			if ([cls isKeyExcludedFromWebScript:utf8])
				continue;
			NSString *mapped = [cls webScriptNameForKey:utf8];
			if ([mapped isEqualToString:name] || [key isEqualToString:name])
				return key;
		}
		return nil;
	}
	for (Class c = cls; c != Nil; c = class_getSuperclass(c)) {
		unsigned count = 0;
		Ivar *ivars = class_copyIvarList(c, &count);
		NSString *found = nil;
		for (unsigned i = 0; i < count && found == nil; i++) {
			const char *ivarName = ivar_getName(ivars[i]);
			if (ivarName == NULL || [c isKeyExcludedFromWebScript:ivarName])
				continue;
			NSString *mapped = [c webScriptNameForKey:ivarName];
			if ([mapped isEqualToString:name] || strcmp(ivarName, [name UTF8String]) == 0)
				found = [NSString stringWithUTF8String:ivarName];
		}
		free(ivars);
		if (found != nil)
			return found;
	}
	return nil;
}

/* Skips type qualifiers (const, in, out, ...). */
static const char *DWKSkipQualifiers(const char *type)
{
	while (*type && strchr("rnNoORV", *type))
		type++;
	return type;
}

static void DWKSetArgument(NSInvocation *invocation, NSUInteger index, id value)
{
	const char *type = DWKSkipQualifiers([[invocation methodSignature] getArgumentTypeAtIndex:index]);
	NSNumber *number = [value isKindOfClass:[NSNumber class]] ? value : nil;
	if ([value isKindOfClass:[NSString class]])
		number = @([value doubleValue]);
	switch (*type) {
	case '@':
	case '#': {
		__unsafe_unretained id object = value;
		[invocation setArgument:&object atIndex:index];
		break;
	}
	case 'c': { char v = [number charValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'C': { unsigned char v = [number unsignedCharValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'B': { bool v = [number boolValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 's': { short v = [number shortValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'S': { unsigned short v = [number unsignedShortValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'i': { int v = [number intValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'I': { unsigned v = [number unsignedIntValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'l': { long v = [number longValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'L': { unsigned long v = [number unsignedLongValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'q': { long long v = [number longLongValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'Q': { unsigned long long v = [number unsignedLongLongValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'f': { float v = [number floatValue]; [invocation setArgument:&v atIndex:index]; break; }
	case 'd': { double v = [number doubleValue]; [invocation setArgument:&v atIndex:index]; break; }
	case '*': {
		const char *v = [value isKindOfClass:[NSString class]] ? [value UTF8String] : NULL;
		[invocation setArgument:&v atIndex:index];
		break;
	}
	case ':': {
		SEL v = [value isKindOfClass:[NSString class]] ? NSSelectorFromString(value) : NULL;
		[invocation setArgument:&v atIndex:index];
		break;
	}
	default:
		/* Structs and pointers have no script value; leave them zeroed. */
		break;
	}
}

static id DWKReturnValue(NSInvocation *invocation)
{
	NSMethodSignature *signature = [invocation methodSignature];
	const char *type = DWKSkipQualifiers([signature methodReturnType]);
	if ([signature methodReturnLength] == 0)
		return nil;
	switch (*type) {
	case '@':
	case '#': { __unsafe_unretained id v; [invocation getReturnValue:&v]; return v; }
	case 'c': { char v; [invocation getReturnValue:&v]; return @(v); }
	case 'C': { unsigned char v; [invocation getReturnValue:&v]; return @(v); }
	case 'B': { bool v; [invocation getReturnValue:&v]; return v ? (id)kCFBooleanTrue : (id)kCFBooleanFalse; }
	case 's': { short v; [invocation getReturnValue:&v]; return @(v); }
	case 'S': { unsigned short v; [invocation getReturnValue:&v]; return @(v); }
	case 'i': { int v; [invocation getReturnValue:&v]; return @(v); }
	case 'I': { unsigned v; [invocation getReturnValue:&v]; return @(v); }
	case 'l': { long v; [invocation getReturnValue:&v]; return @(v); }
	case 'L': { unsigned long v; [invocation getReturnValue:&v]; return @(v); }
	case 'q': { long long v; [invocation getReturnValue:&v]; return @(v); }
	case 'Q': { unsigned long long v; [invocation getReturnValue:&v]; return @(v); }
	case 'f': { float v; [invocation getReturnValue:&v]; return @(v); }
	case 'd': { double v; [invocation getReturnValue:&v]; return @(v); }
	case '*': { const char *v; [invocation getReturnValue:&v]; return v ? [NSString stringWithUTF8String:v] : nil; }
	default: return nil;
	}
}

static id DWKInvoke(id object, SEL selector, NSArray *arguments)
{
	NSMethodSignature *signature = [object methodSignatureForSelector:selector];
	if (signature == nil)
		return nil;
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setTarget:object];
	[invocation setSelector:selector];
	NSUInteger count = [signature numberOfArguments];
	for (NSUInteger i = 2; i < count; i++) {
		id value = i - 2 < [arguments count] ? [arguments objectAtIndex:i - 2] : nil;
		if (value == (id)[NSNull null])
			value = nil;
		DWKSetArgument(invocation, i, value);
	}
	[invocation retainArguments];
	[invocation invoke];
	return DWKReturnValue(invocation);
}

#pragma mark - Bridge connection

@interface DWKBridge ()
- (void)noteConnection:(DWKBridgeConnection *)connection forPage:(unsigned long long)page;
- (void)connectionDidClose:(DWKBridgeConnection *)connection;
@end

@implementation DWKBridgeConnection {
	int _fd;
	NSMutableData *_buffer;
	dispatch_source_t _source;
	long long _nextID;
	NSMutableDictionary<NSNumber *, NSDictionary *> *_stashedReplies;
	NSMapTable<NSNumber *, WebScriptObject *> *_scriptObjects;
	BOOL _closed;
	BOOL _drainScheduled;
}

/* Objects handed to scripts.  Kept for the life of the process: the web
 * process has no way to say when a page lets go of one. */
static NSMutableArray *sExportedObjects;
static NSMapTable *sExportedHandles;

- (instancetype)initWithSocket:(int)fd
{
	if ((self = [super init]) == nil)
		return nil;
	_fd = fd;
	_buffer = [NSMutableData data];
	_stashedReplies = [NSMutableDictionary dictionary];
	_scriptObjects = [NSMapTable strongToWeakObjectsMapTable];
	int one = 1;
	setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));

	__weak DWKBridgeConnection *weakSelf = self;
	_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(_source, ^{
		[weakSelf readAvailable];
	});
	dispatch_resume(_source);
	return self;
}

- (void)close
{
	if (_closed)
		return;
	_closed = YES;
	dispatch_source_cancel(_source);
	close(_fd);
	[[DWKBridge sharedBridge] connectionDidClose:self];
}

- (BOOL)writeMessage:(NSDictionary *)message
{
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
	if (data == nil) {
		NSLog(@"DWKBridge: cannot encode %@: %@", message, error);
		return NO;
	}
	NSMutableData *line = [data mutableCopy];
	[line appendBytes:"\n" length:1];
	const char *bytes = [line bytes];
	size_t left = [line length];
	while (left > 0) {
		ssize_t n = write(_fd, bytes, left);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0) {
			[self close];
			return NO;
		}
		bytes += n;
		left -= n;
	}
	return YES;
}

/* The next complete message in the buffer, or nil. */
- (NSDictionary *)takeBufferedMessage
{
	const char *bytes = [_buffer bytes];
	const char *newline = memchr(bytes, '\n', [_buffer length]);
	if (newline == NULL)
		return nil;
	NSUInteger length = newline - bytes;
	NSData *line = [_buffer subdataWithRange:NSMakeRange(0, length)];
	[_buffer replaceBytesInRange:NSMakeRange(0, length + 1) withBytes:NULL length:0];
	id message = [NSJSONSerialization JSONObjectWithData:line options:0 error:NULL];
	if (![message isKindOfClass:[NSDictionary class]]) {
		NSLog(@"DWKBridge: ignoring a malformed message");
		return @{};
	}
	return message;
}

- (BOOL)readBlocking
{
	char chunk[16384];
	for (;;) {
		ssize_t n = read(_fd, chunk, sizeof(chunk));
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0) {
			[self close];
			return NO;
		}
		[_buffer appendBytes:chunk length:n];
		return YES;
	}
}

- (void)readAvailable
{
	if (_closed)
		return;
	char chunk[16384];
	ssize_t n = recv(_fd, chunk, sizeof(chunk), MSG_DONTWAIT);
	if (n == 0 || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) {
		[self close];
		return;
	}
	if (n > 0)
		[_buffer appendBytes:chunk length:n];
	[self drain];
}

/* Serves whatever complete messages are buffered. */
- (void)drain
{
	_drainScheduled = NO;
	NSDictionary *message;
	while (!_closed && (message = [self takeBufferedMessage]) != nil)
		[self dispatchMessage:message];
}

- (void)scheduleDrain
{
	if (_drainScheduled || [_buffer length] == 0)
		return;
	_drainScheduled = YES;
	__weak DWKBridgeConnection *weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf drain];
	});
}

- (void)dispatchMessage:(NSDictionary *)message
{
	id re = [message objectForKey:@"re"];
	if (re != nil) {
		[_stashedReplies setObject:message forKey:re];
		return;
	}
	id requestID = [message objectForKey:@"id"];
	if (requestID == nil)
		return;
	id result = nil;
	NSString *error = nil;
	@try {
		result = [self serveRequest:message];
	} @catch (NSException *exception) {
		error = [NSString stringWithFormat:@"%@: %@", [exception name], [exception reason]];
	}
	if (error != nil)
		[self writeMessage:@{ @"re": requestID, @"err": error }];
	else
		[self writeMessage:@{ @"re": requestID, @"ok": [self encode:result] }];
}

- (id)sendRequest:(NSDictionary *)request
{
	if (_closed)
		return nil;
	NSNumber *requestID = @(++_nextID);
	NSMutableDictionary *message = [request mutableCopy];
	[message setObject:requestID forKey:@"id"];
	if (![self writeMessage:message])
		return nil;
	for (;;) {
		NSDictionary *reply = [_stashedReplies objectForKey:requestID];
		if (reply != nil) {
			[_stashedReplies removeObjectForKey:requestID];
			[self scheduleDrain];
			NSString *error = [reply objectForKey:@"err"];
			if (error != nil) {
				NSLog(@"DWKBridge: %@ failed: %@", [request objectForKey:@"op"], error);
				return nil;
			}
			return [self decode:[reply objectForKey:@"ok"]];
		}
		NSDictionary *next = [self takeBufferedMessage];
		if (next != nil) {
			[self dispatchMessage:next];
			continue;
		}
		if (_closed || ![self readBlocking])
			return nil;
	}
}

#pragma mark Requests from the page

- (id)objectForHandle:(id)handle
{
	if (![handle isKindOfClass:[NSNumber class]])
		return nil;
	NSUInteger index = [handle unsignedIntegerValue];
	return index < [sExportedObjects count] ? [sExportedObjects objectAtIndex:index] : nil;
}

- (id)serveRequest:(NSDictionary *)request
{
	NSString *op = [request objectForKey:@"op"];
	if ([op isEqualToString:@"clear"]) {
		unsigned long long page = [[request objectForKey:@"page"] unsignedLongLongValue];
		[[DWKBridge sharedBridge] noteConnection:self forPage:page];
		DWKBridgeRequestHandler handler = [[DWKBridge sharedBridge] clearHandler];
		return handler != nil ? handler(self, request) : nil;
	}
	if ([op isEqualToString:@"hello"]) {
		return nil;
	}

	id object = [self objectForHandle:[request objectForKey:@"obj"]];
	NSString *name = [request objectForKey:@"key"] ?: [request objectForKey:@"name"];
	if (object == nil || ![name isKindOfClass:[NSString class]])
		return [WebUndefined undefined];

	if ([op isEqualToString:@"get"]) {
		NSString *key = DWKFindKey(object, name);
		if (key != nil)
			return [object valueForKey:key];
		if (DWKFindMethod(object, name) != NULL ||
		    [object respondsToSelector:@selector(invokeUndefinedMethodFromWebScript:withArguments:)])
			return DWKMethodMarker;
		return [WebUndefined undefined];
	}
	if ([op isEqualToString:@"set"]) {
		NSString *key = DWKFindKey(object, name);
		if (key != nil)
			[object setValue:[self decode:[request objectForKey:@"value"]] forKey:key];
		return nil;
	}
	if ([op isEqualToString:@"call"]) {
		NSMutableArray *arguments = [NSMutableArray array];
		for (id json in [request objectForKey:@"args"])
			[arguments addObject:[self decode:json] ?: [NSNull null]];
		SEL selector = DWKFindMethod(object, name);
		if (selector != NULL)
			return DWKInvoke(object, selector, arguments);
		if ([object respondsToSelector:@selector(invokeUndefinedMethodFromWebScript:withArguments:)]) {
			for (NSUInteger i = 0; i < [arguments count]; i++)
				if ([arguments objectAtIndex:i] == (id)[NSNull null])
					[arguments replaceObjectAtIndex:i withObject:[WebUndefined undefined]];
			return [object invokeUndefinedMethodFromWebScript:name withArguments:arguments];
		}
		return [WebUndefined undefined];
	}
	return [WebUndefined undefined];
}

#pragma mark Values

- (id)encode:(id)value
{
	if (value == nil || [value isKindOfClass:[WebUndefined class]])
		return @{ @"$u": @1 };
	if (value == DWKMethodMarker)
		return @{ @"$m": @1 };
	if (value == (id)[NSNull null])
		return [NSNull null];
	if ((__bridge CFBooleanRef)value == kCFBooleanTrue || (__bridge CFBooleanRef)value == kCFBooleanFalse)
		return value;
	if ([value isKindOfClass:[NSNumber class]]) {
		double d = [value doubleValue];
		/* JSON has no NaN or infinities. */
		if (d != d || d - d != 0)
			return @{ @"$n": [value description] };
		return value;
	}
	if ([value isKindOfClass:[NSString class]])
		return value;
	if ([value isKindOfClass:[WebScriptObject class]] && [value dwkConnection] == self)
		return @{ @"$js": @([value dwkHandle]) };
	if ([value isKindOfClass:[NSArray class]]) {
		NSMutableArray *array = [NSMutableArray array];
		for (id element in value)
			[array addObject:[self encode:element]];
		return @{ @"$a": array };
	}
	if (sExportedObjects == nil) {
		sExportedObjects = [NSMutableArray array];
		sExportedHandles = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory
		                                         valueOptions:NSPointerFunctionsStrongMemory];
	}
	NSNumber *handle = [sExportedHandles objectForKey:value];
	if (handle == nil) {
		handle = @([sExportedObjects count]);
		[sExportedObjects addObject:value];
		[sExportedHandles setObject:handle forKey:value];
	}
	return @{ @"$oc": handle };
}

- (id)decode:(id)json
{
	if (json == nil || json == (id)[NSNull null])
		return nil;
	if (![json isKindOfClass:[NSDictionary class]]) {
		if ([json isKindOfClass:[NSArray class]]) {
			NSMutableArray *array = [NSMutableArray array];
			for (id element in json)
				[array addObject:[self decode:element] ?: [NSNull null]];
			return array;
		}
		return json;
	}
	if ([json objectForKey:@"$u"] != nil)
		return [WebUndefined undefined];
	if ([json objectForKey:@"$m"] != nil)
		return DWKMethodMarker;
	NSString *special = [json objectForKey:@"$n"];
	if (special != nil)
		return @([special doubleValue]);
	id oc = [json objectForKey:@"$oc"];
	if (oc != nil)
		return [self objectForHandle:oc];
	id js = [json objectForKey:@"$js"];
	if (js != nil) {
		WebScriptObject *object = [_scriptObjects objectForKey:js];
		if (object == nil) {
			object = [[WebScriptObject alloc] initWithConnection:self handle:[js longLongValue]];
			[_scriptObjects setObject:object forKey:js];
		}
		return object;
	}
	NSArray *array = [json objectForKey:@"$a"];
	if (array != nil)
		return [self decode:array];
	return nil;
}

- (WebScriptObject *)windowObjectForPage:(unsigned long long)page
{
	id window = [self sendRequest:@{ @"op": @"window", @"page": @(page) }];
	return [window isKindOfClass:[WebScriptObject class]] ? window : nil;
}

@end

#pragma mark - Bridge listener

@implementation DWKBridge {
	int _listener;
	unsigned short _port;
	dispatch_source_t _acceptSource;
	NSMutableArray<DWKBridgeConnection *> *_connections;
	NSMutableDictionary<NSNumber *, DWKBridgeConnection *> *_pages;
}

+ (DWKBridge *)sharedBridge
{
	static DWKBridge *bridge;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		bridge = [[DWKBridge alloc] init];
	});
	return bridge;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_listener = -1;
		_connections = [NSMutableArray array];
		_pages = [NSMutableDictionary dictionary];
	}
	return self;
}

- (unsigned short)port
{
	if (_listener >= 0)
		return _port;
	int fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd < 0)
		return 0;
	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	socklen_t length = sizeof(address);
	if (bind(fd, (struct sockaddr *)&address, sizeof(address)) < 0 || listen(fd, 8) < 0 ||
	    getsockname(fd, (struct sockaddr *)&address, &length) < 0) {
		NSLog(@"DWKBridge: cannot listen: %s", strerror(errno));
		close(fd);
		return 0;
	}
	_listener = fd;
	_port = ntohs(address.sin_port);
	_acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
	__weak DWKBridge *weakSelf = self;
	dispatch_source_set_event_handler(_acceptSource, ^{
		[weakSelf acceptConnection];
	});
	dispatch_resume(_acceptSource);
	return _port;
}

- (void)acceptConnection
{
	int fd = accept(_listener, NULL, NULL);
	if (fd < 0)
		return;
	[_connections addObject:[[DWKBridgeConnection alloc] initWithSocket:fd]];
}

- (void)noteConnection:(DWKBridgeConnection *)connection forPage:(unsigned long long)page
{
	[_pages setObject:connection forKey:@(page)];
}

- (DWKBridgeConnection *)connectionForPage:(unsigned long long)page
{
	return [_pages objectForKey:@(page)];
}

- (void)connectionDidClose:(DWKBridgeConnection *)connection
{
	for (NSNumber *page in [_pages allKeysForObject:connection])
		[_pages removeObjectForKey:page];
	[_connections removeObject:connection];
}

@end

#pragma mark - WebScriptObject

@implementation WebScriptObject {
	DWKBridgeConnection *_connection;
	long long _handle;
}

- (instancetype)initWithConnection:(DWKBridgeConnection *)connection handle:(long long)handle
{
	if ((self = [super init])) {
		_connection = connection;
		_handle = handle;
	}
	return self;
}

- (DWKBridgeConnection *)dwkConnection
{
	return _connection;
}

- (long long)dwkHandle
{
	return _handle;
}

+ (BOOL)throwException:(NSString *)exceptionMessage
{
	NSLog(@"WebScriptObject: exception from Objective-C: %@", exceptionMessage);
	return NO;
}

- (void)setException:(NSString *)description
{
	[WebScriptObject throwException:description];
}

- (NSArray *)encodeArguments:(NSArray *)arguments
{
	NSMutableArray *encoded = [NSMutableArray array];
	for (id argument in arguments)
		[encoded addObject:[_connection encode:argument == (id)[NSNull null] ? nil : argument]];
	return encoded;
}

- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments
{
	return [_connection sendRequest:@{ @"op": @"call", @"obj": @(_handle), @"name": name ?: @"",
	                                   @"args": [self encodeArguments:arguments] }];
}

- (id)evaluateWebScript:(NSString *)script
{
	return [_connection sendRequest:@{ @"op": @"eval", @"obj": @(_handle), @"script": script ?: @"" }];
}

- (id)valueForKey:(NSString *)key
{
	return [_connection sendRequest:@{ @"op": @"get", @"obj": @(_handle), @"key": key ?: @"" }];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	[_connection sendRequest:@{ @"op": @"set", @"obj": @(_handle), @"key": key ?: @"",
	                            @"value": [_connection encode:value] }];
}

- (void)removeWebScriptKey:(NSString *)name
{
	[_connection sendRequest:@{ @"op": @"remove", @"obj": @(_handle), @"key": name ?: @"" }];
}

- (NSString *)stringRepresentation
{
	id value = [_connection sendRequest:@{ @"op": @"string", @"obj": @(_handle) }];
	return [value isKindOfClass:[NSString class]] ? value : [value description];
}

- (id)webScriptValueAtIndex:(unsigned)index
{
	return [_connection sendRequest:@{ @"op": @"index", @"obj": @(_handle), @"i": @(index) }];
}

- (void)setWebScriptValueAtIndex:(unsigned)index value:(id)value
{
	[_connection sendRequest:@{ @"op": @"setindex", @"obj": @(_handle), @"i": @(index),
	                            @"value": [_connection encode:value] }];
}

- (JSObjectRef)JSObject
{
	return NULL;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<WebScriptObject %p: handle %lld>", self, _handle];
}

@end
