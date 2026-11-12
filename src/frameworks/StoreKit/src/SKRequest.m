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

#import <StoreKit/SKRequest.h>

extern NSString *const SKErrorDomain;

// There is no App Store: a request answers on the main queue once started, and a cancelled
// request answers nothing. Subclasses decide the answer in -_respond.
@implementation SKRequest {
    BOOL _cancelled;
}

@synthesize delegate = _delegate;

- (void)_respond
{
    if ([_delegate respondsToSelector:@selector(requestDidFinish:)])
        [_delegate requestDidFinish:self];
}

- (void)_failWithCode:(NSInteger)code description:(NSString *)description
{
    NSError *error = [NSError errorWithDomain:SKErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: description }];
    if ([_delegate respondsToSelector:@selector(request:didFailWithError:)])
        [_delegate request:self didFailWithError:error];
}

- (void)start
{
    [self retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_cancelled)
            [self _respond];
        [self release];
    });
}

- (void)cancel
{
    _cancelled = YES;
}

@end
