#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat APDotSize;          // 8
extern const CGFloat APSelectedDotWidth; // 20
extern const CGFloat APDotSpacing;       // 6

/// A row of page dots. The selected page is drawn as a wider, fully rounded pill.
///
/// -selectPage: rebuilds the strip from scratch: it throws the old dot views
/// away and creates new ones. A freshly created UIView starts with frame == CGRectZero
/// and layer.cornerRadius == 0 and only *then* receives its final frame and corner
/// radius. That is fine - unless the rebuild runs inside a UIView animation block.
@interface APDotIndicator : UIView
@property (nonatomic, readonly) NSInteger numberOfPages;
@property (nonatomic, readonly) NSInteger selectedIndex;
/// The pill view for the current page (recreated on every update).
@property (nonatomic, readonly, nullable) UIView *selectedDot;
@property (nonatomic, readonly) NSArray<UIView *> *dots;

- (void)configureWithNumberOfPages:(NSInteger)numberOfPages;
- (void)selectPage:(NSInteger)index;
@end

/// A minimal horizontal pager with a dot indicator underneath. The subclasses
/// differ only in *where* they update the indicator relative to the page-snap
/// animation in -scrollToPage:duration:.
@interface APPageStrip : UIView
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) APDotIndicator *indicator;
@property (nonatomic, readonly) NSInteger currentPage;

- (instancetype)initWithNumberOfPages:(NSInteger)numberOfPages
                             pageSize:(CGSize)pageSize NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Moves the indicator to `page`. Overridable so tests can observe the
/// animation context it runs in.
- (void)setIndicatorIndex:(NSInteger)page;

/// Snaps to `page` with an animation. Implemented by the subclasses.
- (void)scrollToPage:(NSInteger)page duration:(NSTimeInterval)duration
    NS_SWIFT_NAME(scrollToPage(_:duration:));
@end

/// The buggy version: the indicator is rebuilt *inside* the animation block, so
/// every freshly created dot animates from CGRectZero and square corners.
@interface APNaivePageStrip : APPageStrip
@end

/// Fix #1: animate only the scroll; update the indicator after the animate call.
@interface APFixedPageStrip : APPageStrip
@end

/// Fix #2: keep the call inside the block but opt the rebuild out of animation
/// with +[UIView performWithoutAnimation:].
@interface APNonAnimatedIndicatorPageStrip : APPageStrip
@end

NS_ASSUME_NONNULL_END
