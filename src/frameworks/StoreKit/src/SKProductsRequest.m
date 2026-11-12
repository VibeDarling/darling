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

#import <StoreKit/SKProductsRequest.h>
#import <StoreKit/SKProductsResponse.h>

@interface SKRequest (Private)
- (void)_respond;
@end

// The App Store knows no products here, so every identifier comes back invalid; apps treat
// that like products that are not (yet) on sale.
@implementation SKProductsRequest {
    NSSet *_productIdentifiers;
}

@dynamic delegate;

- (instancetype)initWithProductIdentifiers:(NSSet *)productIdentifiers
{
    if ((self = [super init]) != nil)
        _productIdentifiers = [productIdentifiers copy];
    return self;
}

- (void)dealloc
{
    [_productIdentifiers release];
    [super dealloc];
}

- (void)_respond
{
    SKProductsResponse *response = [[SKProductsResponse alloc] _initWithProducts:@[] invalidProductIdentifiers:[_productIdentifiers allObjects] ?: @[]];
    [[self delegate] productsRequest:self didReceiveResponse:response];
    [response release];
    [super _respond];
}

@end
