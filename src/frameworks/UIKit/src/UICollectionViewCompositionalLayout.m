#import <UIKit/UICollectionViewCompositionalLayout.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#include <math.h>

typedef NS_ENUM(NSUInteger, UILayoutDimensionKind) {
    UILayoutDimensionAbsolute,
    UILayoutDimensionEstimated,
    UILayoutDimensionFractionalWidth,
    UILayoutDimensionFractionalHeight,
};

static void UIRequireFinite(CGFloat value)
{
    if (!isfinite(value))
        [NSException raise:NSInvalidArgumentException format:@"Layout values must be finite"];
}

@implementation NSCollectionLayoutDimension

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a layout factory to create %@", [self class]];
    return nil;
}
- (instancetype)initWithDimension:(CGFloat)value kind:(UILayoutDimensionKind)kind
{
    UIRequireFinite(value);
    if (value < 0)
        [NSException raise:NSInvalidArgumentException format:@"Layout dimensions must be nonnegative"];
    if ((self = [super init])) {
        _dimension = value;
        _kind = kind;
    }
    return self;
}
+ (instancetype)absoluteDimension:(CGFloat)value
{
    return [[self alloc] initWithDimension:value kind:UILayoutDimensionAbsolute];
}
+ (instancetype)estimatedDimension:(CGFloat)value
{
    return [[self alloc] initWithDimension:value kind:UILayoutDimensionEstimated];
}
+ (instancetype)fractionalWidthDimension:(CGFloat)value
{
    return [[self alloc] initWithDimension:value kind:UILayoutDimensionFractionalWidth];
}
+ (instancetype)fractionalHeightDimension:(CGFloat)value
{
    return [[self alloc] initWithDimension:value kind:UILayoutDimensionFractionalHeight];
}
- (CGFloat)dimension { return _dimension; }
- (BOOL)isAbsolute { return _kind == UILayoutDimensionAbsolute; }
- (BOOL)isEstimated { return _kind == UILayoutDimensionEstimated; }
- (BOOL)isFractionalWidth { return _kind == UILayoutDimensionFractionalWidth; }
- (BOOL)isFractionalHeight { return _kind == UILayoutDimensionFractionalHeight; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation NSCollectionLayoutSize

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a layout factory to create %@", [self class]];
    return nil;
}
- (instancetype)initWithWidthDimension:(NSCollectionLayoutDimension *)width
                      heightDimension:(NSCollectionLayoutDimension *)height
{
    if (![width isKindOfClass:[NSCollectionLayoutDimension class]] ||
        ![height isKindOfClass:[NSCollectionLayoutDimension class]])
        [NSException raise:NSInvalidArgumentException format:@"Layout size requires two dimensions"];
    if ((self = [super init])) {
        _widthDimension = [width copy];
        _heightDimension = [height copy];
    }
    return self;
}
+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)width
                      heightDimension:(NSCollectionLayoutDimension *)height
{
    return [[self alloc] initWithWidthDimension:width heightDimension:height];
}
- (NSCollectionLayoutDimension *)widthDimension { return _widthDimension; }
- (NSCollectionLayoutDimension *)heightDimension { return _heightDimension; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation NSCollectionLayoutSpacing

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a layout factory to create %@", [self class]];
    return nil;
}
- (instancetype)initWithSpacing:(CGFloat)value fixed:(BOOL)fixed
{
    UIRequireFinite(value);
    if ((self = [super init])) {
        _spacing = value;
        _fixed = fixed;
    }
    return self;
}
+ (instancetype)fixedSpacing:(CGFloat)value
{
    return [[self alloc] initWithSpacing:value fixed:YES];
}
+ (instancetype)flexibleSpacing:(CGFloat)value
{
    return [[self alloc] initWithSpacing:value fixed:NO];
}
- (CGFloat)spacing { return _spacing; }
- (BOOL)isFixedSpacing { return _fixed; }
- (BOOL)isFlexibleSpacing { return !_fixed; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation NSCollectionLayoutEdgeSpacing

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a layout factory to create %@", [self class]];
    return nil;
}
- (instancetype)initWithLeading:(NSCollectionLayoutSpacing *)leading
                           top:(NSCollectionLayoutSpacing *)top
                      trailing:(NSCollectionLayoutSpacing *)trailing
                        bottom:(NSCollectionLayoutSpacing *)bottom
{
    for (id edge in @[leading ?: [NSNull null], top ?: [NSNull null],
                      trailing ?: [NSNull null], bottom ?: [NSNull null]]) {
        if (edge != [NSNull null] && ![edge isKindOfClass:[NSCollectionLayoutSpacing class]])
            [NSException raise:NSInvalidArgumentException format:@"Edges require layout spacing or nil"];
    }
    if ((self = [super init])) {
        _leading = [leading copy];
        _top = [top copy];
        _trailing = [trailing copy];
        _bottom = [bottom copy];
    }
    return self;
}
+ (instancetype)spacingForLeading:(NSCollectionLayoutSpacing *)leading
                             top:(NSCollectionLayoutSpacing *)top
                        trailing:(NSCollectionLayoutSpacing *)trailing
                          bottom:(NSCollectionLayoutSpacing *)bottom
{
    return [[self alloc] initWithLeading:leading top:top trailing:trailing bottom:bottom];
}
- (NSCollectionLayoutSpacing *)leading { return _leading; }
- (NSCollectionLayoutSpacing *)top { return _top; }
- (NSCollectionLayoutSpacing *)trailing { return _trailing; }
- (NSCollectionLayoutSpacing *)bottom { return _bottom; }
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

@implementation NSCollectionLayoutItem {
    NSCollectionLayoutSize *_layoutSize;
    NSCollectionLayoutEdgeSpacing *_edgeSpacing;
    NSDirectionalEdgeInsets _contentInsets;
}
- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Use a layout factory to create %@", [self class]];
    return nil;
}
- (instancetype)initWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
{
    if (![layoutSize isKindOfClass:[NSCollectionLayoutSize class]])
        [NSException raise:NSInvalidArgumentException format:@"Layout item requires a layout size"];
    if ((self = [super init]))
        _layoutSize = [layoutSize copy];
    return self;
}
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
{
    return [[self alloc] initWithLayoutSize:layoutSize];
}
- (NSCollectionLayoutSize *)layoutSize { return _layoutSize; }
- (NSCollectionLayoutEdgeSpacing *)edgeSpacing { return _edgeSpacing; }
- (void)setEdgeSpacing:(NSCollectionLayoutEdgeSpacing *)edgeSpacing
{
    if (edgeSpacing != nil && ![edgeSpacing isKindOfClass:[NSCollectionLayoutEdgeSpacing class]])
        [NSException raise:NSInvalidArgumentException format:@"Layout item requires edge spacing or nil"];
    _edgeSpacing = [edgeSpacing copy];
}
- (NSDirectionalEdgeInsets)contentInsets { return _contentInsets; }
- (void)setContentInsets:(NSDirectionalEdgeInsets)insets
{
    UIRequireFinite(insets.top);
    UIRequireFinite(insets.leading);
    UIRequireFinite(insets.bottom);
    UIRequireFinite(insets.trailing);
    _contentInsets = insets;
}
- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutItem *copy = [[[self class] allocWithZone:zone] initWithLayoutSize:_layoutSize];
    copy.edgeSpacing = _edgeSpacing;
    copy.contentInsets = _contentInsets;
    return copy;
}
@end
