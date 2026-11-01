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

#import <StoreKit/SKProductsResponse.h>

@implementation SKProductsResponse

@synthesize products = _products;
@synthesize invalidProductIdentifiers = _invalidProductIdentifiers;

- (instancetype)_initWithProducts:(NSArray *)products invalidProductIdentifiers:(NSArray *)invalid
{
    if ((self = [super init]) != nil)
    {
        _products = [products copy];
        _invalidProductIdentifiers = [invalid copy];
    }
    return self;
}

- (void)dealloc
{
    [_products release];
    [_invalidProductIdentifiers release];
    [super dealloc];
}

@end
