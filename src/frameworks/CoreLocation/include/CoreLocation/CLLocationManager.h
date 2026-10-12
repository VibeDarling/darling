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

@interface CLLocationManager : NSObject
{
	id _delegate;
}

/* A real property, so callers get a proper accessor instead of falling
 * through to the stub forwardInvocation, whose 0-arg signature raises
 * `NSForwardSignatureError: invoked with 3 args, but 2 expected`. */
@property (nonatomic, assign) id delegate;

@end
