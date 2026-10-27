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

#import <RunningBoardServices/RunningBoardServices.h>

@implementation RBSTarget

+ (instancetype)currentProcess
{
	return [self targetWithProcessIdentifier:[RBSProcessIdentifier identifierForCurrentProcess]];
}

+ (instancetype)targetWithPid:(pid_t)pid
{
	return [self targetWithProcessIdentifier:[RBSProcessIdentifier identifierWithPid:pid]];
}

+ (instancetype)targetWithProcessIdentifier:(RBSProcessIdentifier *)identifier
{
	RBSTarget *target = [[self alloc] init];
	target->_processIdentifier = identifier;
	return target;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[RBSTarget class]] && [((RBSTarget *)other).processIdentifier isEqual:_processIdentifier];
}

- (NSUInteger)hash
{
	return [_processIdentifier hash];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@>", [self class], _processIdentifier];
}

@end

@implementation RBSAttribute

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end

@implementation RBSDomainAttribute

+ (instancetype)attributeWithDomain:(NSString *)domain name:(NSString *)name
{
	RBSDomainAttribute *attribute = [[self alloc] init];
	attribute->_domain = [domain copy];
	attribute->_name = [name copy];
	return attribute;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@:%@>", [self class], _domain, _name];
}

@end

/* Without runningboardd nothing enforces an assertion (no process is ever
   suspended or jetsammed for lack of one), so acquiring one only records it. */
static NSMutableArray<RBSAssertion *> *RBSAcquired(void)
{
	static NSMutableArray<RBSAssertion *> *acquired;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		acquired = [NSMutableArray array];
	});
	return acquired;
}

@implementation RBSAssertion {
	void (^_invalidationHandler)(RBSAssertion *, NSError *);
}

- (instancetype)initWithExplanation:(NSString *)explanation target:(RBSTarget *)target attributes:(NSArray<RBSAttribute *> *)attributes
{
	if ((self = [super init])) {
		_explanation = [explanation copy];
		_target = target;
		_attributes = [attributes copy] ?: @[];
	}
	return self;
}

- (BOOL)acquireWithError:(NSError **)error
{
	RBSProcessIdentifier *identifier = [_target processIdentifier];
	if (identifier != nil && [RBSProcessHandle handleForIdentifier:identifier error:error] == nil)
		return NO;

	NSMutableArray *acquired = RBSAcquired();
	@synchronized (acquired) {
		if (!_valid) {
			_valid = YES;
			[acquired addObject:self];
		}
	}
	return YES;
}

- (void)acquireWithInvalidationHandler:(void (^)(RBSAssertion *, NSError *))handler
{
	_invalidationHandler = [handler copy];
	NSError *error = nil;
	if (![self acquireWithError:&error] && handler != nil)
		handler(self, error);
}

- (void)invalidate
{
	NSMutableArray *acquired = RBSAcquired();
	@synchronized (acquired) {
		_valid = NO;
		[acquired removeObjectIdenticalTo:self];
	}
	_invalidationHandler = nil;
}

- (BOOL)invalidateSyncWithError:(NSError **)error
{
	[self invalidate];
	return YES;
}

+ (NSArray<RBSAssertion *> *)acquiredAssertionsForTarget:(RBSTarget *)target
{
	NSMutableArray *acquired = RBSAcquired();
	@synchronized (acquired) {
		return [acquired filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RBSAssertion *assertion, NSDictionary *bindings) {
			return [[assertion target] isEqual:target];
		}]];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ \"%@\" target=%@ valid=%d>", [self class], _explanation, _target, _valid];
}

@end
