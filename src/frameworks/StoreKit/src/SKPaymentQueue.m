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

#import <StoreKit/SKPaymentQueue.h>
#import <objc/runtime.h>

extern NSString *const SKErrorDomain;

@implementation SKPaymentQueue {
    NSMutableArray *_observers;
}

+ (instancetype)defaultQueue
{
    static SKPaymentQueue *queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [[SKPaymentQueue alloc] init];
    });
    return queue;
}

+ (BOOL)canMakePayments
{
    return NO;
}

- (instancetype)init
{
    if ((self = [super init]) != nil)
        _observers = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [_observers release];
    [super dealloc];
}

- (NSArray *)transactions
{
    return @[];
}

// Observers are not retained, as on iOS.
- (void)addTransactionObserver:(id)observer
{
    if (observer != nil && [_observers indexOfObjectIdenticalTo:observer] == NSNotFound)
        [_observers addObject:[NSValue valueWithNonretainedObject:observer]];
}

- (void)removeTransactionObserver:(id)observer
{
    for (NSValue *value in [[_observers copy] autorelease])
        if ([value nonretainedObjectValue] == observer)
            [_observers removeObject:value];
}

- (void)addPayment:(SKPayment *)payment
{
    NSLog(@"SKPaymentQueue: there is no App Store to buy %@ from", payment);
}

- (void)restoreCompletedTransactions
{
    NSError *error = [NSError errorWithDomain:SKErrorDomain code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Cannot connect to the App Store." }];
    NSArray *observers = [[_observers copy] autorelease];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSValue *value in observers) {
            id observer = [value nonretainedObjectValue];
            if ([observer respondsToSelector:@selector(paymentQueue:restoreCompletedTransactionsFailedWithError:)])
                [observer paymentQueue:self restoreCompletedTransactionsFailedWithError:error];
        }
    });
}

- (void)restoreCompletedTransactionsWithApplicationUsername:(NSString *)username
{
    [self restoreCompletedTransactions];
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction
{
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    if (signature != nil)
        return signature;
    NSMutableString *types = [NSMutableString stringWithString:@"@@:"];
    for (const char *c = sel_getName(aSelector); *c != '\0'; c++)
        if (*c == ':')
            [types appendString:@"@"];
    return [NSMethodSignature signatureWithObjCTypes:[types UTF8String]];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
    id nothing = nil;
    [anInvocation setReturnValue:&nothing];
}

@end
