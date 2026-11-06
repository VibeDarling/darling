/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * Portions adapted from the Chameleon UIResponder (BSD-licensed).
 *
 * Copyright (c) 2011, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIResponder.h>

@implementation UIResponder

- (UIResponder *)nextResponder
{
	return _nextResponder;
}

/* Subclasses that own a view chain override this to return their parent. */
- (void)setNextResponder:(UIResponder *)responder
{
	_nextResponder = responder;
}

- (BOOL)canBecomeFirstResponder
{
	return NO;
}

- (BOOL)canResignFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	if (![self canBecomeFirstResponder])
		return NO;
	_firstResponder = YES;
	return YES;
}

- (BOOL)isFirstResponder
{
	return _firstResponder;
}

- (BOOL)resignFirstResponder
{
	_firstResponder = NO;
	return YES;
}

/* Enabled when the class implements the action, otherwise asked of the next responder with the sender unchanged. */
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
	if ([[self class] instancesRespondToSelector:action])
		return YES;
	return [[self nextResponder] canPerformAction:action withSender:sender];
}

@end
