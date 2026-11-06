#import <UIKit/UIButton.h>
#import <Foundation/NSValue.h>

@implementation UIButton

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		_uiTitles = [[NSMutableDictionary alloc] init];
		_uiTitleColors = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self != nil) {
		_uiTitles = [[NSMutableDictionary alloc] init];
		_uiTitleColors = [[NSMutableDictionary alloc] init];
	}
	return self;
}

// Rung 3 (init(type:) page): the custom button frame is (0, 0, 0, 0). Rung 6: the other
// types are created with the same empty frame, and any buttonType value is stored as given.
+ (instancetype)buttonWithType:(UIButtonType)buttonType
{
	UIButton *button = [[self alloc] initWithFrame:CGRectZero];
	button->_uiButtonType = buttonType;
	return button;
}

- (UIButtonType)buttonType { return _uiButtonType; }

// Rung 3 (settitle, title(for:), settitlecolor pages): a value is kept per state, and a
// state without its own value uses the one for UIControlStateNormal.  Rung 6: states are
// matched by exact value (a combination such as Highlighted|Selected is its own state), nil
// removes a value, and when Normal is unset the result is nil because the pages only say
// "a system value".
- (void)setTitle:(NSString *)title forState:(UIControlState)state
{
	NSNumber *key = @(state);
	if (title != nil)
		_uiTitles[key] = [title copy];
	else
		[_uiTitles removeObjectForKey:key];
}

- (NSString *)titleForState:(UIControlState)state
{
	return _uiTitles[@(state)] ?: _uiTitles[@(UIControlStateNormal)];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
	NSNumber *key = @(state);
	if (color != nil)
		_uiTitleColors[key] = color;
	else
		[_uiTitleColors removeObjectForKey:key];
}

- (UIColor *)titleColorForState:(UIControlState)state
{
	return _uiTitleColors[@(state)] ?: _uiTitleColors[@(UIControlStateNormal)];
}

@end
