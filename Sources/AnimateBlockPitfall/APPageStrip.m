#import "AnimateBlockPitfall.h"

@interface APPageStrip ()
@property (nonatomic, readwrite) NSInteger currentPage;
@end

@implementation APPageStrip

- (instancetype)initWithNumberOfPages:(NSInteger)numberOfPages pageSize:(CGSize)pageSize {
    self = [super initWithFrame:CGRectMake(0, 0, pageSize.width, pageSize.height + 24)];
    if (self) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, pageSize.width, pageSize.height)];
        _scrollView.contentSize = CGSizeMake(pageSize.width * numberOfPages, pageSize.height);
        _scrollView.pagingEnabled = YES;
        [self addSubview:_scrollView];

        _indicator = [[APDotIndicator alloc] initWithFrame:CGRectMake(16, pageSize.height + 8,
                                                                      pageSize.width - 32, APDotSize)];
        [self addSubview:_indicator];
        [_indicator configureWithNumberOfPages:numberOfPages];
    }
    return self;
}

- (CGPoint)targetOffsetForPage:(NSInteger)page {
    return CGPointMake(page * CGRectGetWidth(self.scrollView.bounds), 0);
}

- (void)setIndicatorIndex:(NSInteger)page {
    self.currentPage = page;
    [self.indicator selectPage:page];
}

- (void)scrollToPage:(NSInteger)page duration:(NSTimeInterval)duration {
    [self doesNotRecognizeSelector:_cmd];
}

@end

@implementation APNaivePageStrip

- (void)scrollToPage:(NSInteger)page duration:(NSTimeInterval)duration {
    CGPoint target = [self targetOffsetForPage:page];
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentOffset = target;
        [self setIndicatorIndex:page];          // <- runs inside the animation transaction
    }];
}

@end

@implementation APFixedPageStrip

- (void)scrollToPage:(NSInteger)page duration:(NSTimeInterval)duration {
    CGPoint target = [self targetOffsetForPage:page];
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentOffset = target;
    }];
    [self setIndicatorIndex:page];              // <- outside: no animation context
}

@end

@implementation APNonAnimatedIndicatorPageStrip

- (void)scrollToPage:(NSInteger)page duration:(NSTimeInterval)duration {
    CGPoint target = [self targetOffsetForPage:page];
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentOffset = target;
        [UIView performWithoutAnimation:^{
            [self setIndicatorIndex:page];
        }];
    }];
}

@end
