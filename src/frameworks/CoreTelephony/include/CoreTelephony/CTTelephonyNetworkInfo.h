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

@class CTCarrier;

extern NSString *const CTRadioAccessTechnologyDidChangeNotification;
extern NSString *const CTServiceRadioAccessTechnologyDidChangeNotification;
extern NSString *const CTRadioAccessTechnologyGPRS;
extern NSString *const CTRadioAccessTechnologyEdge;
extern NSString *const CTRadioAccessTechnologyWCDMA;
extern NSString *const CTRadioAccessTechnologyHSDPA;
extern NSString *const CTRadioAccessTechnologyHSUPA;
extern NSString *const CTRadioAccessTechnologyCDMA1x;
extern NSString *const CTRadioAccessTechnologyCDMAEVDORev0;
extern NSString *const CTRadioAccessTechnologyCDMAEVDORevA;
extern NSString *const CTRadioAccessTechnologyCDMAEVDORevB;
extern NSString *const CTRadioAccessTechnologyeHRPD;
extern NSString *const CTRadioAccessTechnologyLTE;
extern NSString *const CTRadioAccessTechnologyNRNSA;
extern NSString *const CTRadioAccessTechnologyNR;

/* There is no cellular radio: no technology, no carrier. */
@interface CTTelephonyNetworkInfo : NSObject
@property (nonatomic, readonly) NSString *currentRadioAccessTechnology;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *serviceCurrentRadioAccessTechnology;
@property (nonatomic, readonly) CTCarrier *subscriberCellularProvider;
@property (nonatomic, readonly) NSDictionary<NSString *, CTCarrier *> *serviceSubscriberCellularProviders;
@property (nonatomic, readonly) NSString *dataServiceIdentifier;
@property (nonatomic, assign) id delegate;
@property (nonatomic, copy) void (^subscriberCellularProviderDidUpdateNotifier)(CTCarrier *carrier);
@property (nonatomic, copy) void (^serviceSubscriberCellularProvidersDidUpdateNotifier)(NSString *identifier);
@end
