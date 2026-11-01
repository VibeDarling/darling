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

#import <StoreKit/SKReceiptRefreshRequest.h>

@interface SKRequest (Private)
- (void)_failWithCode:(NSInteger)code description:(NSString *)description;
@end

// No App Store to fetch a receipt from: the request fails as it does offline (SKErrorUnknown).
@implementation SKReceiptRefreshRequest

@synthesize receiptProperties = _receiptProperties;

- (instancetype)initWithReceiptProperties:(NSDictionary *)properties
{
    if ((self = [super init]) != nil)
        _receiptProperties = [properties copy];
    return self;
}

- (void)dealloc
{
    [_receiptProperties release];
    [super dealloc];
}

- (void)_respond
{
    [self _failWithCode:0 description:@"Cannot connect to the App Store."];
}

@end
