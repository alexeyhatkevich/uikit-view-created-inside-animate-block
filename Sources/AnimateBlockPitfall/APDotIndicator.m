#import "AnimateBlockPitfall.h"

const CGFloat APDotSize = 8;
const CGFloat APSelectedDotWidth = 20;
const CGFloat APDotSpacing = 6;

@interface APDotIndicator ()
@property (nonatomic, readwrite) NSInteger numberOfPages;
@property (nonatomic, readwrite) NSInteger selectedIndex;
@property (nonatomic, readwrite, nullable) UIView *selectedDot;
@property (nonatomic, readwrite) NSArray<UIView *> *dots;
@end

@implementation APDotIndicator

- (void)configureWithNumberOfPages:(NSInteger)numberOfPages {
    self.numberOfPages = numberOfPages;
    [self selectPage:0];
}

- (void)selectPage:(NSInteger)index {
    self.selectedIndex = index;
    [self.dots makeObjectsPerformSelector:@selector(removeFromSuperview)];

    NSMutableArray<UIView *> *dots = [NSMutableArray array];
    CGFloat x = 0;
    for (NSInteger page = 0; page < self.numberOfPages; page++) {
        BOOL isSelected = page == index;
        CGFloat width = isSelected ? APSelectedDotWidth : APDotSize;

        UIView *dot = [[UIView alloc] init];   // frame == CGRectZero, cornerRadius == 0
        dot.backgroundColor = isSelected ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        [self addSubview:dot];

        dot.frame = CGRectMake(x, 0, width, APDotSize);
        dot.layer.cornerRadius = APDotSize / 2;

        [dots addObject:dot];
        if (isSelected) { self.selectedDot = dot; }
        x += width + APDotSpacing;
    }
    self.dots = dots;
}

@end
