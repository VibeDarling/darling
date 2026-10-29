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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <objc/runtime.h>

NSString *const CTRadioAccessTechnologyDidChangeNotification = @"kCTRadioAccessTechnologyDidChangeNotification";
NSString *const CTServiceRadioAccessTechnologyDidChangeNotification = @"kCTServiceRadioAccessTechnologyDidChangeNotification";
NSString *const CTRadioAccessTechnologyGPRS = @"CTRadioAccessTechnologyGPRS";
NSString *const CTRadioAccessTechnologyEdge = @"CTRadioAccessTechnologyEdge";
NSString *const CTRadioAccessTechnologyWCDMA = @"CTRadioAccessTechnologyWCDMA";
NSString *const CTRadioAccessTechnologyHSDPA = @"CTRadioAccessTechnologyHSDPA";
NSString *const CTRadioAccessTechnologyHSUPA = @"CTRadioAccessTechnologyHSUPA";
NSString *const CTRadioAccessTechnologyCDMA1x = @"CTRadioAccessTechnologyCDMA1x";
NSString *const CTRadioAccessTechnologyCDMAEVDORev0 = @"CTRadioAccessTechnologyCDMAEVDORev0";
NSString *const CTRadioAccessTechnologyCDMAEVDORevA = @"CTRadioAccessTechnologyCDMAEVDORevA";
NSString *const CTRadioAccessTechnologyCDMAEVDORevB = @"CTRadioAccessTechnologyCDMAEVDORevB";
NSString *const CTRadioAccessTechnologyeHRPD = @"CTRadioAccessTechnologyeHRPD";
NSString *const CTRadioAccessTechnologyLTE = @"CTRadioAccessTechnologyLTE";
NSString *const CTRadioAccessTechnologyNRNSA = @"CTRadioAccessTechnologyNRNSA";
NSString *const CTRadioAccessTechnologyNR = @"CTRadioAccessTechnologyNR";

@implementation CTTelephonyNetworkInfo

@synthesize delegate = _delegate;
@synthesize subscriberCellularProviderDidUpdateNotifier = _subscriberCellularProviderDidUpdateNotifier;
@synthesize serviceSubscriberCellularProvidersDidUpdateNotifier = _serviceSubscriberCellularProvidersDidUpdateNotifier;

- (NSString *)currentRadioAccessTechnology { return nil; }
- (NSDictionary *)serviceCurrentRadioAccessTechnology { return nil; }
- (CTCarrier *)subscriberCellularProvider { return nil; }
- (NSDictionary *)serviceSubscriberCellularProviders { return nil; }
- (NSString *)dataServiceIdentifier { return nil; }

/* Anything else answers nil, whatever it returns. */
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
