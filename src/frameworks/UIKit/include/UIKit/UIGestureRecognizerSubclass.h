/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UIGESTURERECOGNIZERSUBCLASS_H
#define UIKIT_UIGESTURERECOGNIZERSUBCLASS_H

#import <UIKit/UIGestureRecognizer.h>

/* What gesture recognizer subclasses implement and call. */
@interface UIGestureRecognizer (UIGestureRecognizerProtected)
@property (nonatomic, readwrite) UIGestureRecognizerState state;
- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event;
- (void)reset;
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer;
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer;
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
@end

#endif /* UIKIT_UIGESTURERECOGNIZERSUBCLASS_H */
