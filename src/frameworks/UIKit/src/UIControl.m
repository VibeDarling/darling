#import <UIKit/UIControl.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <AppKit/NSResponder.h>
#import <objc/message.h>

// One registered target/action pair and the events it responds to.  The target is
// not retained (rung 3: addTarget page, "The control does not retain the object in
// the target parameter"); it is weak, and _chain marks the nil target that stands
// for a responder-chain search, so a target that has gone away is skipped, not
// confused with the chain.
@interface DarlingUIControlAction : NSObject {
@public
	__weak id target;
	BOOL chain;
	SEL action;
	UIControlEvents events;
}
@end

@implementation DarlingUIControlAction
@end

// A registration whose weak target has been released can never be delivered, so
// it must not merge a later registration or keep reporting its events.
static void DarlingUIControlPruneDead(NSMutableArray *actions)
{
	for (NSInteger i = (NSInteger)[actions count] - 1; i >= 0; i--) {
		DarlingUIControlAction *entry = [actions objectAtIndex:i];
		if (!entry->chain && entry->target == nil)
			[actions removeObjectAtIndex:i];
	}
}

@implementation UIControl

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
		_uiActions = [[NSMutableArray alloc] init];
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil)
		_uiActions = [[NSMutableArray alloc] init];
	return self;
}

// Rung 3 (state page): bitmask of UIControlState; enabled NO adds Disabled, and
// likewise Selected and Highlighted for the other two properties.  Enabled
// defaults to YES, selected and highlighted to NO (isenabled, isselected,
// ishighlighted pages), so the ivar for enabled is stored inverted.
- (UIControlState)state
{
	UIControlState state = UIControlStateNormal;
	if (_uiHighlighted) state |= UIControlStateHighlighted;
	if (_uiDisabled) state |= UIControlStateDisabled;
	if (_uiSelected) state |= UIControlStateSelected;
	return state;
}

- (BOOL)isEnabled { return !_uiDisabled; }
- (void)setEnabled:(BOOL)enabled { _uiDisabled = !enabled; }
- (BOOL)isSelected { return _uiSelected; }
- (void)setSelected:(BOOL)selected { _uiSelected = selected; }
- (BOOL)isHighlighted { return _uiHighlighted; }
- (void)setHighlighted:(BOOL)highlighted { _uiHighlighted = highlighted; }

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
	// Rung 6: a NULL action raises, so a registration that could never be
	// delivered is not silently accepted.
	if (action == NULL)
		[NSException raise:NSInvalidArgumentException format:@"UIControl addTarget: action must not be NULL"];
	// Rung 6: registering zero events has nothing to deliver, so no record is made
	// (the page only says that 0 does not stop delivery to an existing registration).
	if (controlEvents == 0)
		return;
	DarlingUIControlPruneDead(_uiActions);
	// Rung 3: calling again with the same target and action is safe; the events accumulate.
	// A nil target is the responder chain and only merges with another chain entry.
	for (DarlingUIControlAction *entry in _uiActions) {
		if (entry->chain == (target == nil) && entry->target == target && entry->action == action) {
			entry->events |= controlEvents;
			return;
		}
	}
	DarlingUIControlAction *entry = [[DarlingUIControlAction alloc] init];
	entry->target = target;
	entry->chain = (target == nil);
	entry->action = action;
	entry->events = controlEvents;
	[_uiActions addObject:entry];
}

// Rung 3 (removetarget page): the action argument is not considered; a nil target
// matches every target.  A registration left with no events is dropped.
- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
	NSMutableArray *kept = [[NSMutableArray alloc] init];
	for (DarlingUIControlAction *entry in _uiActions) {
		if (target == nil || entry->target == target)
			entry->events &= ~controlEvents;
		if (entry->events != 0)
			[kept addObject:entry];
	}
	_uiActions = kept;
}

- (NSSet *)allTargets
{
	DarlingUIControlPruneDead(_uiActions);
	NSMutableSet *targets = [[NSMutableSet alloc] init];
	for (DarlingUIControlAction *entry in _uiActions) {
		id target = entry->target;
		if (entry->chain)
			[targets addObject:[NSNull null]];
		else if (target != nil)
			[targets addObject:target];
	}
	return targets;
}

- (UIControlEvents)allControlEvents
{
	DarlingUIControlPruneDead(_uiActions);
	UIControlEvents all = 0;
	for (DarlingUIControlAction *entry in _uiActions)
		all |= entry->events;
	return all;
}

// Rung 3 (sendactions page): iterates the registered targets and actions and calls
// the action of each one associated with an event in controlEvents.  Rung 3
// (sendaction(_:to:for:) page): a nil target means the responder chain is searched,
// and a nil event is allowed for programmatic calls.  Rung 6: the control is the
// sender; the chain is searched from the control because the pages say nothing about
// the starting point; the iteration is over a snapshot so actions may change
// registrations.
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents
{
	for (DarlingUIControlAction *entry in [_uiActions copy]) {
		if ((entry->events & controlEvents) == 0)
			continue;
		id receiver = entry->target;
		if (entry->chain) {
			NSResponder *responder = self;
			while (responder != nil && ![responder respondsToSelector:entry->action])
				responder = [responder nextResponder];
			receiver = responder;
		}
		if (receiver != nil)
			((void (*)(id, SEL, id, id))objc_msgSend)(receiver, entry->action, self, nil);
	}
}

@end
