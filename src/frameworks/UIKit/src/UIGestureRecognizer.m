/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <UIKit/UIControl.h>
#import <UIKit/UITouch.h>
#import <UIKit/UIEvent.h>
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <dispatch/dispatch.h>
#include <math.h>

/*
 * Gesture recognizers see a touch before its view does. One recognizer
 * recognizing makes the others fail (unless a delegate lets them run
 * together) and, by default, cancels the view's touches. Recognizers stay
 * in play after the pointer goes up while one waits for another tap or for
 * one it depends on to fail, and are reset once all have finished.
 */

@interface UIKitGestureTarget : NSObject {
@public
	__weak id target;
	SEL action;
}
@end

@implementation UIKitGestureTarget
@end

@interface UIGestureRecognizer ()
- (void)uikitSetView:(UIView *)view;
- (void)uikitAddTouch:(UITouch *)touch;
- (void)uikitRemoveTouch:(UITouch *)touch;
- (BOOL)uikitWantsMoreTouches;
- (BOOL)uikitIsPending;
- (void)uikitResolvePending;
- (void)uikitReset;
- (BOOL)uikitRequires:(UIGestureRecognizer *)other;
/* After a finger joins or leaves: the centroid jumps, which pans must not see. */
- (void)uikitTouchesChanged;
@end

static NSMutableArray<UIGestureRecognizer *> *sRecognizers;
/* The fingers down, first first. */
static NSMutableArray<UITouch *> *sTouches;

static BOOL UIKitGestureIsActive(UIGestureRecognizerState state)
{
	return state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded;
}

static BOOL UIKitGestureIsFinished(UIGestureRecognizerState state)
{
	return state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateFailed;
}

static void UIKitCancelViewTouch(UITouch *touch)
{
	if ([touch uikitViewCancelled])
		return;
	[touch setUikitViewCancelled:YES];
	if ([touch uikitViewBegan])
		[[touch view] touchesCancelled:[NSSet setWithObject:touch] withEvent:[UIEvent uikitTouchesEvent]];
}

static BOOL UIKitGesturesSimultaneous(UIGestureRecognizer *a, UIGestureRecognizer *b)
{
	SEL selector = @selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:);
	id<UIGestureRecognizerDelegate> da = [a delegate], db = [b delegate];
	return ([da respondsToSelector:selector] && [da gestureRecognizer:a shouldRecognizeSimultaneouslyWithGestureRecognizer:b])
		|| ([db respondsToSelector:selector] && [db gestureRecognizer:b shouldRecognizeSimultaneouslyWithGestureRecognizer:a]);
}

/* Once every finger is up and no recognizer is still deciding, all start over. */
static void UIKitGesturesCleanUp(void)
{
	if ([sTouches count] > 0)
		return;
	for (UIGestureRecognizer *recognizer in sRecognizers) {
		UIGestureRecognizerState state = [recognizer state];
		if ([recognizer uikitIsPending] || (state == UIGestureRecognizerStatePossible && [recognizer uikitWantsMoreTouches])
		    || state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
			return;
	}
	NSArray *finished = [sRecognizers copy];
	[sRecognizers removeAllObjects];
	for (UIGestureRecognizer *recognizer in finished)
		[recognizer uikitReset];
}

static void UIKitGesturesResolvePending(void)
{
	for (UIGestureRecognizer *recognizer in [sRecognizers copy])
		if ([recognizer uikitIsPending])
			[recognizer uikitResolvePending];
}

static void UIKitGestureRecognized(UIGestureRecognizer *recognizer)
{
	for (UIGestureRecognizer *other in [sRecognizers copy]) {
		if (other == recognizer || UIKitGesturesSimultaneous(recognizer, other) || [other uikitRequires:recognizer])
			continue;
		UIGestureRecognizerState state = [other state];
		if (state == UIGestureRecognizerStatePossible)
			[other setState:UIGestureRecognizerStateFailed];
		else if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
			[other setState:UIGestureRecognizerStateCancelled];
	}
	if ([recognizer cancelsTouchesInView])
		for (UITouch *touch in [sTouches copy])
			if ([[touch uikitRecognizers] containsObject:recognizer])
				UIKitCancelViewTouch(touch);
}

/* Recognizers on the touched view and the views it is in, nearest first. */
static NSArray<UIGestureRecognizer *> *UIKitGesturesForTouch(UITouch *touch, UIView *hitView)
{
	NSMutableArray *found = [NSMutableArray array];
	/* Since iOS 6 a control's own tap wins over a single-tap recognizer above it. */
	UIView *control = nil;
	for (NSView *view = hitView; [view isKindOfClass:[UIView class]]; view = [view superview])
		if ([view isKindOfClass:[UIControl class]]) {
			control = (UIView *)view;
			break;
		}
	BOOL aboveControl = NO;
	for (NSView *view = hitView; [view isKindOfClass:[UIView class]]; view = [view superview]) {
		for (UIGestureRecognizer *recognizer in [(UIView *)view gestureRecognizers]) {
			if (![recognizer isEnabled])
				continue;
			if (aboveControl && [recognizer isKindOfClass:[UITapGestureRecognizer class]]
			    && [(UITapGestureRecognizer *)recognizer numberOfTapsRequired] == 1
			    && [(UITapGestureRecognizer *)recognizer numberOfTouchesRequired] == 1)
				continue;
			id<UIGestureRecognizerDelegate> delegate = [recognizer delegate];
			if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)]
			    && ![delegate gestureRecognizer:recognizer shouldReceiveTouch:touch])
				continue;
			[found addObject:recognizer];
		}
		if (view == control)
			aboveControl = YES;
	}
	return found;
}

/* Whether the view under a new finger gets it, given the fingers already down. */
static BOOL UIKitTouchReachesView(UITouch *touch)
{
	UIView *view = [touch view];
	for (UITouch *other in sTouches) {
		if (other == touch || ![other uikitToView])
			continue;
		UIView *otherView = [other view];
		if (otherView != view && ([otherView isExclusiveTouch] || [view isExclusiveTouch]))
			return NO;
		if (otherView == view && ![view isMultipleTouchEnabled])
			return NO;
	}
	return YES;
}

static BOOL UIKitTouchIsShutOut(UITouch *touch)
{
	/* An exclusive view's finger shuts the others out entirely. */
	for (UITouch *other in sTouches)
		if (other != touch && [other uikitToView] && [other view] != [touch view]
		    && ([[other view] isExclusiveTouch] || [[touch view] isExclusiveTouch]))
			return YES;
	return NO;
}

void UIKitDispatchTouch(UITouch *touch, UITouchPhase phase)
{
	if (sRecognizers == nil) {
		sRecognizers = [NSMutableArray array];
		sTouches = [NSMutableArray array];
	}
	UIEvent *event = [UIEvent uikitTouchesEvent];
	NSSet *touches = [NSSet setWithObject:touch];
	[event uikitSetTimestamp:[touch timestamp]];
	for (UITouch *other in sTouches)
		if (other != touch)
			[other setPhase:UITouchPhaseStationary];

	if (phase == UITouchPhaseBegan) {
		if (UIKitTouchIsShutOut(touch))
			return;
		BOOL first = [sTouches count] == 0;
		[sTouches addObject:touch];
		[event uikitAddTouch:touch];
		[touch setUikitToView:UIKitTouchReachesView(touch)];
		NSArray *receivers = UIKitGesturesForTouch(touch, [touch view]);
		/* Those left from the last fingers that are not waiting for this one are done. */
		if (first)
			for (UIGestureRecognizer *recognizer in [sRecognizers copy]) {
				BOOL waiting = [recognizer state] == UIGestureRecognizerStatePossible && [recognizer uikitWantsMoreTouches];
				if (!waiting || ![receivers containsObject:recognizer]) {
					if ([recognizer state] == UIGestureRecognizerStatePossible)
						[recognizer setState:UIGestureRecognizerStateFailed];
					[sRecognizers removeObject:recognizer];
					[recognizer uikitReset];
				}
			}
		NSMutableArray *live = [NSMutableArray array];
		for (UIGestureRecognizer *recognizer in receivers) {
			if (![sRecognizers containsObject:recognizer]) {
				if ([recognizer state] != UIGestureRecognizerStatePossible)
					[recognizer uikitReset];
				[sRecognizers addObject:recognizer];
			}
			if (!UIKitGestureIsFinished([recognizer state]))
				[live addObject:recognizer];
		}
		[touch setUikitRecognizers:live];
		for (UIGestureRecognizer *recognizer in live) {
			if (UIKitGestureIsFinished([recognizer state]))
				continue;
			[recognizer uikitAddTouch:touch];
			[recognizer touchesBegan:touches withEvent:event];
			[recognizer uikitTouchesChanged];
		}
		/* A recognizer that already has its gesture takes the new finger too. */
		for (UIGestureRecognizer *recognizer in live)
			if ([recognizer cancelsTouchesInView] && UIKitGestureIsActive([recognizer state]))
				[touch setUikitViewCancelled:YES];
		if ([touch uikitToView] && ![touch uikitViewCancelled]) {
			[touch setUikitViewBegan:YES];
			[[touch view] touchesBegan:touches withEvent:event];
		}
		return;
	}

	if (![sTouches containsObject:touch])
		return;
	NSArray *recognizers = [touch uikitRecognizers];
	for (UIGestureRecognizer *recognizer in recognizers) {
		if (![sRecognizers containsObject:recognizer] || UIKitGestureIsFinished([recognizer state]))
			continue;
		if (phase == UITouchPhaseMoved)
			[recognizer touchesMoved:touches withEvent:event];
		else if (phase == UITouchPhaseCancelled)
			[recognizer touchesCancelled:touches withEvent:event];
		else
			[recognizer touchesEnded:touches withEvent:event];
	}
	BOOL toView = [touch uikitViewBegan] && ![touch uikitViewCancelled];
	if (phase == UITouchPhaseMoved) {
		if (toView)
			[[touch view] touchesMoved:touches withEvent:event];
		return;
	}

	for (UIGestureRecognizer *recognizer in recognizers) {
		[recognizer uikitRemoveTouch:touch];
		[recognizer uikitTouchesChanged];
		if ([recognizer numberOfTouches] > 0)
			continue;
		if ([recognizer state] == UIGestureRecognizerStatePossible && ![recognizer uikitIsPending] && ![recognizer uikitWantsMoreTouches])
			[recognizer setState:UIGestureRecognizerStateFailed];
		else if (phase == UITouchPhaseCancelled
		         && ([recognizer state] == UIGestureRecognizerStateBegan || [recognizer state] == UIGestureRecognizerStateChanged))
			[recognizer setState:UIGestureRecognizerStateCancelled];
	}
	toView = [touch uikitViewBegan] && ![touch uikitViewCancelled];
	if (toView) {
		if (phase == UITouchPhaseCancelled)
			[[touch view] touchesCancelled:touches withEvent:event];
		else
			[[touch view] touchesEnded:touches withEvent:event];
	}
	[sTouches removeObject:touch];
	[event uikitRemoveTouch:touch];
	UIKitGesturesCleanUp();
}

@implementation UIGestureRecognizer {
	NSMutableArray<UIKitGestureTarget *> *_targets;
	NSHashTable<UIGestureRecognizer *> *_requiredToFail;
	NSMutableArray<UITouch *> *_touches;
	UITouch *_lastTouch;
	__weak UIView *_view;
	UIGestureRecognizerState _state;
	UIGestureRecognizerState _pendingState;
	BOOL _disabled;
}

@synthesize delegate = _delegate;
@synthesize cancelsTouchesInView = _cancelsTouchesInView;
@synthesize delaysTouchesBegan = _delaysTouchesBegan;
@synthesize delaysTouchesEnded = _delaysTouchesEnded;
@synthesize name = _name;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super init]) == nil)
		return nil;
	_targets = [NSMutableArray array];
	_requiredToFail = [NSHashTable weakObjectsHashTable];
	_touches = [NSMutableArray array];
	_cancelsTouchesInView = YES;
	_delaysTouchesEnded = YES;
	[self addTarget:target action:action];
	return self;
}

- (instancetype)init
{
	return [self initWithTarget:nil action:NULL];
}

- (void)addTarget:(id)target action:(SEL)action
{
	if (action == NULL)
		return;
	UIKitGestureTarget *entry = [[UIKitGestureTarget alloc] init];
	entry->target = target;
	entry->action = action;
	[_targets addObject:entry];
}

- (void)removeTarget:(id)target action:(SEL)action
{
	for (UIKitGestureTarget *entry in [_targets copy])
		if ((target == nil || entry->target == target) && (action == NULL || entry->action == action))
			[_targets removeObject:entry];
}

- (UIView *)view { return _view; }
- (void)uikitSetView:(UIView *)view { _view = view; }
- (BOOL)isEnabled { return !_disabled; }

- (void)setEnabled:(BOOL)enabled
{
	_disabled = !enabled;
	if (_disabled && (_state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateChanged))
		[self setState:UIGestureRecognizerStateCancelled];
}

- (UIGestureRecognizerState)state { return _state; }

- (BOOL)uikitShouldBegin
{
	id<UIGestureRecognizerDelegate> delegate = _delegate;
	if ([delegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![delegate gestureRecognizerShouldBegin:self])
		return NO;
	UIView *view = _view;
	return view == nil || [view gestureRecognizerShouldBegin:self];
}

- (BOOL)uikitRequires:(UIGestureRecognizer *)other
{
	if ([_requiredToFail containsObject:other] || [self shouldRequireFailureOfGestureRecognizer:other]
	    || [other shouldBeRequiredToFailByGestureRecognizer:self])
		return YES;
	id<UIGestureRecognizerDelegate> delegate = _delegate, otherDelegate = [other delegate];
	return ([delegate respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)]
	        && [delegate gestureRecognizer:self shouldRequireFailureOfGestureRecognizer:other])
		|| ([otherDelegate respondsToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)]
		    && [otherDelegate gestureRecognizer:other shouldBeRequiredToFailByGestureRecognizer:self]);
}

/* A required recognizer still deciding, among those seeing this touch. */
- (BOOL)uikitWaitsForFailure
{
	for (UIGestureRecognizer *other in sRecognizers)
		if (other != self && [other state] == UIGestureRecognizerStatePossible && [self uikitRequires:other])
			return YES;
	return NO;
}

/* A required recognizer that has recognized, so this one cannot. */
- (BOOL)uikitPrevented
{
	for (UIGestureRecognizer *other in sRecognizers)
		if (other != self && UIKitGestureIsActive([other state]) && [self uikitRequires:other])
			return YES;
	return NO;
}

- (BOOL)uikitIsPending { return _pendingState != UIGestureRecognizerStatePossible; }

- (void)uikitResolvePending
{
	if ([self uikitPrevented]) {
		_pendingState = UIGestureRecognizerStatePossible;
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	if ([self uikitWaitsForFailure])
		return;
	UIGestureRecognizerState state = _pendingState;
	_pendingState = UIGestureRecognizerStatePossible;
	[self setState:state];
}

- (void)setState:(UIGestureRecognizerState)state
{
	if (_state == UIGestureRecognizerStatePossible
	    && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateEnded)) {
		if ([self uikitPrevented] || ![self uikitShouldBegin]) {
			state = UIGestureRecognizerStateFailed;
		} else if ([self uikitWaitsForFailure]) {
			_pendingState = state;
			return;
		}
	}
	UIGestureRecognizerState old = _state;
	_state = state;
	if (old == UIGestureRecognizerStatePossible && UIKitGestureIsActive(state))
		UIKitGestureRecognized(self);
	if (state != UIGestureRecognizerStateFailed && state != UIGestureRecognizerStatePossible)
		[self uikitSendActions];
	if (state != old)
		UIKitGesturesResolvePending();
	UIKitGesturesCleanUp();
}

- (void)uikitSendActions
{
	for (UIKitGestureTarget *entry in [_targets copy]) {
		id target = entry->target;
		if (target == nil || ![target respondsToSelector:entry->action])
			continue;
		if ([[target methodSignatureForSelector:entry->action] numberOfArguments] <= 2)
			((void (*)(id, SEL))objc_msgSend)(target, entry->action);
		else
			((void (*)(id, SEL, id))objc_msgSend)(target, entry->action, self);
	}
}

- (void)uikitReset
{
	_state = UIGestureRecognizerStatePossible;
	_pendingState = UIGestureRecognizerStatePossible;
	[_touches removeAllObjects];
	[self reset];
}

- (void)uikitAddTouch:(UITouch *)touch
{
	if (![_touches containsObject:touch])
		[_touches addObject:touch];
	_lastTouch = touch;
}

- (void)uikitRemoveTouch:(UITouch *)touch { [_touches removeObject:touch]; }
- (BOOL)uikitWantsMoreTouches { return NO; }
- (void)uikitTouchesChanged { }

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other
{
	if (other != nil)
		[_requiredToFail addObject:other];
}

- (CGPoint)locationInView:(UIView *)view
{
	if ([_touches count] == 0)
		return _lastTouch != nil ? [_lastTouch locationInView:view] : CGPointZero;
	CGFloat x = 0, y = 0;
	for (UITouch *touch in _touches) {
		CGPoint point = [touch locationInView:view];
		x += point.x;
		y += point.y;
	}
	return CGPointMake(x / [_touches count], y / [_touches count]);
}

- (NSUInteger)numberOfTouches { return [_touches count]; }

- (CGPoint)locationOfTouch:(NSUInteger)index inView:(UIView *)view
{
	if (index >= [_touches count])
		return [self locationInView:view];
	return [[_touches objectAtIndex:index] locationInView:view];
}

- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event { }
- (void)reset { }
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { }

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if (_state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateChanged)
		[self setState:UIGestureRecognizerStateCancelled];
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)prevented { return YES; }
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventing { return YES; }
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other { return NO; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p; state = %ld; view = <%@ %p>>", [self class], self, (long)_state, [_view class], _view];
}

@end

#pragma mark - UIView

static char UIKitGestureRecognizersKey;

@implementation UIView (UIGestureRecognizers)

- (NSArray<UIGestureRecognizer *> *)gestureRecognizers
{
	NSArray *recognizers = objc_getAssociatedObject(self, &UIKitGestureRecognizersKey);
	return [recognizers count] > 0 ? [recognizers copy] : nil;
}

- (void)setGestureRecognizers:(NSArray<UIGestureRecognizer *> *)recognizers
{
	for (UIGestureRecognizer *recognizer in [self gestureRecognizers])
		[self removeGestureRecognizer:recognizer];
	for (UIGestureRecognizer *recognizer in recognizers)
		[self addGestureRecognizer:recognizer];
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)recognizer
{
	if (recognizer == nil)
		return;
	[[recognizer view] removeGestureRecognizer:recognizer];
	NSMutableArray *recognizers = objc_getAssociatedObject(self, &UIKitGestureRecognizersKey);
	if (recognizers == nil) {
		recognizers = [NSMutableArray array];
		objc_setAssociatedObject(self, &UIKitGestureRecognizersKey, recognizers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[recognizers addObject:recognizer];
	[recognizer uikitSetView:self];
}

- (void)removeGestureRecognizer:(UIGestureRecognizer *)recognizer
{
	NSMutableArray *recognizers = objc_getAssociatedObject(self, &UIKitGestureRecognizersKey);
	if (![recognizers containsObject:recognizer])
		return;
	[recognizers removeObject:recognizer];
	[recognizer uikitSetView:nil];
	[sRecognizers removeObject:recognizer];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
	return YES;
}

@end

/* UIKit's scroll views pan and pinch with recognizers apps can depend on.
 * Darling's scroll by themselves, so these only stand in for those. */
static char UIKitPanRecognizerKey;

@implementation UIScrollView (UIGestureRecognizers)

- (UIPanGestureRecognizer *)panGestureRecognizer
{
	UIPanGestureRecognizer *recognizer = objc_getAssociatedObject(self, &UIKitPanRecognizerKey);
	if (recognizer == nil) {
		recognizer = [[UIPanGestureRecognizer alloc] init];
		[recognizer uikitSetView:self];
		objc_setAssociatedObject(self, &UIKitPanRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return recognizer;
}

- (UIPinchGestureRecognizer *)pinchGestureRecognizer
{
	return nil;
}

@end

#pragma mark - Concrete recognizers

static CGFloat UIKitDistance(CGPoint a, CGPoint b)
{
	return hypot(a.x - b.x, a.y - b.y);
}

/* How far a finger may drift and still tap, and how long between taps. */
#define UIKitTapSlop 10.0
#define UIKitMultipleTapInterval 0.35

/* Whether any of the fingers has gone further than slop from where it came down. */
static BOOL UIKitTouchesStrayed(NSSet *touches, CGFloat slop)
{
	for (UITouch *touch in touches)
		if (UIKitDistance([touch locationInView:nil], [touch uikitStartLocationInView:nil]) > slop)
			return YES;
	return NO;
}

/* The fingers still down once these go up. */
static NSUInteger UIKitTouchesLeft(UIGestureRecognizer *recognizer, NSSet *ending)
{
	NSUInteger count = [recognizer numberOfTouches];
	return count > [ending count] ? count - [ending count] : 0;
}

@implementation UITapGestureRecognizer {
	NSUInteger _taps;
	NSUInteger _generation;
	NSUInteger _fingers;
	CGPoint _start;
	BOOL _waiting;
}

@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		_numberOfTapsRequired = 1;
		_numberOfTouchesRequired = 1;
	}
	return self;
}

- (BOOL)uikitWantsMoreTouches { return _waiting; }

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_generation++;
	_waiting = NO;
	if ([self numberOfTouches] == 1) {
		/* The first finger of a tap. */
		_fingers = 0;
		CGPoint point = [[touches anyObject] locationInView:nil];
		if (_taps > 0 && UIKitDistance(point, _start) > UIKitTapSlop * 3) {
			[self setState:UIGestureRecognizerStateFailed];
			return;
		}
		_start = point;
	}
	_fingers = MAX(_fingers, [self numberOfTouches]);
	if (_fingers > MAX(_numberOfTouchesRequired, 1))
		[self setState:UIGestureRecognizerStateFailed];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self state] == UIGestureRecognizerStatePossible && UIKitTouchesStrayed(touches, UIKitTapSlop))
		[self setState:UIGestureRecognizerStateFailed];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self state] != UIGestureRecognizerStatePossible || UIKitTouchesLeft(self, touches) > 0)
		return;
	if (_fingers < MAX(_numberOfTouchesRequired, 1)) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	if (++_taps >= MAX(_numberOfTapsRequired, 1)) {
		[self setState:UIGestureRecognizerStateEnded];
		return;
	}
	_waiting = YES;
	NSUInteger generation = ++_generation;
	__weak UITapGestureRecognizer *weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(UIKitMultipleTapInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		UITapGestureRecognizer *recognizer = weakSelf;
		if (recognizer == nil || recognizer->_generation != generation || [recognizer state] != UIGestureRecognizerStatePossible)
			return;
		recognizer->_waiting = NO;
		[recognizer setState:UIGestureRecognizerStateFailed];
	});
}

- (void)reset
{
	_taps = 0;
	_fingers = 0;
	_waiting = NO;
	_generation++;
}

@end

@implementation UILongPressGestureRecognizer {
	NSUInteger _generation;
}

@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;
@synthesize minimumPressDuration = _minimumPressDuration;
@synthesize allowableMovement = _allowableMovement;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		_numberOfTouchesRequired = 1;
		_minimumPressDuration = 0.5;
		_allowableMovement = 10;
	}
	return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSUInteger required = MAX(_numberOfTouchesRequired, 1);
	if ([self state] != UIGestureRecognizerStatePossible)
		return;
	if ([self numberOfTouches] > required) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	if ([self numberOfTouches] < required)
		return;
	/* The press is timed from when the last finger it needs comes down. */
	NSUInteger generation = ++_generation;
	__weak UILongPressGestureRecognizer *weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_minimumPressDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		UILongPressGestureRecognizer *recognizer = weakSelf;
		if (recognizer != nil && recognizer->_generation == generation && [recognizer numberOfTouches] == required
		    && [recognizer state] == UIGestureRecognizerStatePossible)
			[recognizer setState:UIGestureRecognizerStateBegan];
	});
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIGestureRecognizerState state = [self state];
	if (state == UIGestureRecognizerStatePossible) {
		if (UIKitTouchesStrayed(touches, _allowableMovement))
			[self setState:UIGestureRecognizerStateFailed];
	} else if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
		[self setState:UIGestureRecognizerStateChanged];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	_generation++;
	UIGestureRecognizerState state = [self state];
	if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
		[self setState:UIGestureRecognizerStateEnded];
	else if (state == UIGestureRecognizerStatePossible)
		[self setState:UIGestureRecognizerStateFailed];
}

- (void)reset
{
	_generation++;
}

@end

@implementation UIPanGestureRecognizer {
	CGPoint _start;
	CGPoint _last;
	NSTimeInterval _lastTime;
	CGPoint _velocity;
}

@synthesize minimumNumberOfTouches = _minimumNumberOfTouches;
@synthesize maximumNumberOfTouches = _maximumNumberOfTouches;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		_minimumNumberOfTouches = 1;
		_maximumNumberOfTouches = NSUIntegerMax;
	}
	return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self numberOfTouches] == 1) {
		_start = _last = [self locationInView:nil];
		_lastTime = [[touches anyObject] timestamp];
		_velocity = CGPointZero;
	}
	if ([self numberOfTouches] > _maximumNumberOfTouches && [self state] == UIGestureRecognizerStatePossible)
		[self setState:UIGestureRecognizerStateFailed];
}

/* The centroid jumps when a finger comes or goes; the translation must not. */
- (void)uikitTouchesChanged
{
	if ([self numberOfTouches] == 0)
		return;
	CGPoint point = [self locationInView:nil];
	_start = CGPointMake(_start.x + point.x - _last.x, _start.y + point.y - _last.y);
	_last = point;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint point = [self locationInView:nil];
	NSTimeInterval time = [[touches anyObject] timestamp];
	if (time > _lastTime)
		_velocity = CGPointMake((point.x - _last.x) / (time - _lastTime), (point.y - _last.y) / (time - _lastTime));
	_last = point;
	_lastTime = time;
	UIGestureRecognizerState state = [self state];
	NSUInteger count = [self numberOfTouches];
	if (state == UIGestureRecognizerStatePossible) {
		if (count >= MAX(_minimumNumberOfTouches, 1) && count <= _maximumNumberOfTouches
		    && UIKitDistance(point, _start) > UIKitTapSlop)
			[self setState:UIGestureRecognizerStateBegan];
	} else if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
		[self setState:UIGestureRecognizerStateChanged];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIGestureRecognizerState state = [self state];
	NSUInteger left = UIKitTouchesLeft(self, touches);
	BOOL active = state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged;
	if (active && left < MAX(_minimumNumberOfTouches, 1))
		[self setState:UIGestureRecognizerStateEnded];
	else if (state == UIGestureRecognizerStatePossible && left == 0)
		[self setState:UIGestureRecognizerStateFailed];
}

/* Views are not scaled, so a distance is the same in every view. */
- (CGPoint)translationInView:(UIView *)view
{
	return CGPointMake(_last.x - _start.x, _last.y - _start.y);
}

- (void)setTranslation:(CGPoint)translation inView:(UIView *)view
{
	_start = CGPointMake(_last.x - translation.x, _last.y - translation.y);
}

- (CGPoint)velocityInView:(UIView *)view
{
	return _velocity;
}

- (CGPoint)uikitStart { return _start; }

@end

@implementation UIScreenEdgePanGestureRecognizer

@synthesize edges = _edges;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	UITouch *touch = [touches anyObject];
	NSView *content = [[[touch view] window] contentView];
	CGPoint point = [self locationInView:nil];
	NSSize size = [content bounds].size;
	/* Window coordinates are AppKit's, from the bottom left. */
	BOOL near = ((_edges & UIRectEdgeLeft) && point.x < 20) || ((_edges & UIRectEdgeRight) && point.x > size.width - 20)
		|| ((_edges & UIRectEdgeBottom) && point.y < 20) || ((_edges & UIRectEdgeTop) && point.y > size.height - 20);
	if (!near)
		[self setState:UIGestureRecognizerStateFailed];
}

@end

@implementation UISwipeGestureRecognizer {
	CGPoint _start;
	NSTimeInterval _startTime;
}

@synthesize direction = _direction;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action])) {
		_direction = UISwipeGestureRecognizerDirectionRight;
		_numberOfTouchesRequired = 1;
	}
	return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self numberOfTouches] > MAX(_numberOfTouchesRequired, 1)) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	/* Measured from where all the fingers it needs are down. */
	_start = [self locationInView:nil];
	if ([self numberOfTouches] == 1)
		_startTime = [[touches anyObject] timestamp];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self state] != UIGestureRecognizerStatePossible || [self numberOfTouches] != MAX(_numberOfTouchesRequired, 1))
		return;
	if ([[touches anyObject] timestamp] - _startTime > 0.6) {
		[self setState:UIGestureRecognizerStateFailed];
		return;
	}
	CGPoint point = [self locationInView:nil];
	/* Window coordinates grow upwards. */
	CGFloat dx = point.x - _start.x, dy = _start.y - point.y;
	BOOL swiped = ((_direction & UISwipeGestureRecognizerDirectionRight) && dx > 50 && fabs(dy) < dx / 2)
		|| ((_direction & UISwipeGestureRecognizerDirectionLeft) && -dx > 50 && fabs(dy) < -dx / 2)
		|| ((_direction & UISwipeGestureRecognizerDirectionDown) && dy > 50 && fabs(dx) < dy / 2)
		|| ((_direction & UISwipeGestureRecognizerDirectionUp) && -dy > 50 && fabs(dx) < -dy / 2);
	if (swiped)
		[self setState:UIGestureRecognizerStateEnded];
}

@end

/* Two-finger gestures track the first two fingers down. */
static BOOL UIKitTwoFingers(UIGestureRecognizer *recognizer, CGPoint *a, CGPoint *b)
{
	if ([recognizer numberOfTouches] < 2)
		return NO;
	*a = [recognizer locationOfTouch:0 inView:[recognizer view]];
	*b = [recognizer locationOfTouch:1 inView:[recognizer view]];
	return YES;
}

/* How far apart the fingers must move, or turn, before the gesture begins. */
#define UIKitPinchSlop 8.0
#define UIKitRotationSlop 0.1

@implementation UIPinchGestureRecognizer {
	CGFloat _startSpan;
	CGFloat _lastSpan;
	NSTimeInterval _lastTime;
	CGFloat _velocity;
}

@synthesize scale = _scale;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
	if ((self = [super initWithTarget:target action:action]))
		_scale = 1;
	return self;
}

- (CGFloat)uikitSpan
{
	CGPoint a, b;
	return UIKitTwoFingers(self, &a, &b) ? UIKitDistance(a, b) : 0;
}

- (void)uikitTouchesChanged
{
	CGFloat span = [self uikitSpan];
	if (span <= 0)
		return;
	_lastSpan = span;
	if ([self state] == UIGestureRecognizerStatePossible)
		_startSpan = span;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_lastTime = [[touches anyObject] timestamp];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGFloat span = [self uikitSpan];
	if (span <= 0 || _lastSpan <= 0)
		return;
	NSTimeInterval time = [[touches anyObject] timestamp];
	UIGestureRecognizerState state = [self state];
	if (state == UIGestureRecognizerStatePossible) {
		if (fabs(span - _startSpan) <= UIKitPinchSlop)
			return;
		_scale *= span / _startSpan;
		_velocity = 0;
		_lastSpan = span;
		_lastTime = time;
		[self setState:UIGestureRecognizerStateBegan];
		return;
	}
	if (state != UIGestureRecognizerStateBegan && state != UIGestureRecognizerStateChanged)
		return;
	CGFloat factor = span / _lastSpan;
	if (time > _lastTime)
		_velocity = (_scale * factor - _scale) / (time - _lastTime);
	_scale *= factor;
	_lastSpan = span;
	_lastTime = time;
	[self setState:UIGestureRecognizerStateChanged];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIGestureRecognizerState state = [self state];
	if ((state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) && UIKitTouchesLeft(self, touches) < 2)
		[self setState:UIGestureRecognizerStateEnded];
}

- (CGFloat)velocity { return _velocity; }

- (void)reset
{
	_scale = 1;
	_velocity = 0;
	_startSpan = _lastSpan = 0;
}

@end

/* An angle step between -pi and pi. */
static CGFloat UIKitAngleStep(CGFloat from, CGFloat to)
{
	CGFloat step = to - from;
	while (step > M_PI)
		step -= 2 * M_PI;
	while (step < -M_PI)
		step += 2 * M_PI;
	return step;
}

@implementation UIRotationGestureRecognizer {
	CGFloat _startAngle;
	CGFloat _lastAngle;
	NSTimeInterval _lastTime;
	CGFloat _velocity;
	BOOL _tracking;
}

@synthesize rotation = _rotation;

/* Views are flipped, so the angle grows clockwise on screen, as on iOS. */
- (BOOL)uikitAngle:(CGFloat *)angle
{
	CGPoint a, b;
	if (!UIKitTwoFingers(self, &a, &b))
		return NO;
	*angle = atan2(b.y - a.y, b.x - a.x);
	return YES;
}

- (void)uikitTouchesChanged
{
	CGFloat angle;
	_tracking = [self uikitAngle:&angle];
	if (!_tracking)
		return;
	_lastAngle = angle;
	if ([self state] == UIGestureRecognizerStatePossible)
		_startAngle = angle;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	_lastTime = [[touches anyObject] timestamp];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGFloat angle;
	if (!_tracking || ![self uikitAngle:&angle])
		return;
	NSTimeInterval time = [[touches anyObject] timestamp];
	UIGestureRecognizerState state = [self state];
	if (state == UIGestureRecognizerStatePossible) {
		CGFloat turned = UIKitAngleStep(_startAngle, angle);
		if (fabs(turned) <= UIKitRotationSlop)
			return;
		_rotation += turned;
		_velocity = 0;
		_lastAngle = angle;
		_lastTime = time;
		[self setState:UIGestureRecognizerStateBegan];
		return;
	}
	if (state != UIGestureRecognizerStateBegan && state != UIGestureRecognizerStateChanged)
		return;
	CGFloat step = UIKitAngleStep(_lastAngle, angle);
	if (time > _lastTime)
		_velocity = step / (time - _lastTime);
	_rotation += step;
	_lastAngle = angle;
	_lastTime = time;
	[self setState:UIGestureRecognizerStateChanged];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIGestureRecognizerState state = [self state];
	if ((state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) && UIKitTouchesLeft(self, touches) < 2)
		[self setState:UIGestureRecognizerStateEnded];
}

- (CGFloat)velocity { return _velocity; }

- (void)reset
{
	_rotation = 0;
	_velocity = 0;
	_tracking = NO;
}

@end
