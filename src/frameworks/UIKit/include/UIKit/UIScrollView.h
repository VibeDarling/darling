/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#ifndef UIKIT_UISCROLLVIEW_H
#define UIKIT_UISCROLLVIEW_H

#import <UIKit/UIView.h>
#import <UIKit/UIGeometry.h>

@class UIScrollView;

typedef NS_ENUM(NSInteger, UIScrollViewIndicatorStyle) {
	UIScrollViewIndicatorStyleDefault,
	UIScrollViewIndicatorStyleBlack,
	UIScrollViewIndicatorStyleWhite,
};

extern const CGFloat UIScrollViewDecelerationRateNormal;
extern const CGFloat UIScrollViewDecelerationRateFast;

@protocol UIScrollViewDelegate <NSObject>
@optional
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView;
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView;
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView;
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView;
@end

/*
 * The content offset is the view's bounds origin, so subviews placed in
 * content coordinates scroll with it.  The pointer drags the content and
 * the wheel scrolls it; there is no momentum or bounce.
 */
@interface UIScrollView : UIView
@property (nonatomic) CGPoint contentOffset;
@property (nonatomic) CGSize contentSize;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) UIEdgeInsets scrollIndicatorInsets;
@property (nonatomic, weak) id<UIScrollViewDelegate> delegate;
@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@property (nonatomic, getter=isPagingEnabled) BOOL pagingEnabled;
@property (nonatomic, getter=isDirectionalLockEnabled) BOOL directionalLockEnabled;
@property (nonatomic) BOOL bounces;
@property (nonatomic) BOOL alwaysBounceVertical;
@property (nonatomic) BOOL alwaysBounceHorizontal;
@property (nonatomic) BOOL showsVerticalScrollIndicator;
@property (nonatomic) BOOL showsHorizontalScrollIndicator;
@property (nonatomic) UIScrollViewIndicatorStyle indicatorStyle;
@property (nonatomic) CGFloat decelerationRate;
@property (nonatomic) BOOL scrollsToTop;
@property (nonatomic) BOOL delaysContentTouches;
@property (nonatomic) BOOL canCancelContentTouches;
@property (nonatomic) CGFloat zoomScale;
@property (nonatomic) CGFloat minimumZoomScale;
@property (nonatomic) CGFloat maximumZoomScale;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic, readonly, getter=isDragging) BOOL dragging;
@property (nonatomic, readonly, getter=isDecelerating) BOOL decelerating;
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated;
- (void)flashScrollIndicators;
- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated;
/* Old private UIScroller API, still called by apps. */
- (void)setScrollingEnabled:(BOOL)enabled;
- (void)setShowBackgroundShadow:(BOOL)show;
- (void)setOffset:(CGPoint)offset;
@end

#endif /* UIKIT_UISCROLLVIEW_H */
