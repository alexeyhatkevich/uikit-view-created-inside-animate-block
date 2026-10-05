# Views created inside a UIView animation block animate from their initial state

A minimal Objective-C reproduction (with Swift XCTest tests) of a UIKit gotcha:
any view you **create and lay out synchronously inside**
`+[UIView animateWithDuration:animations:]` does not just appear - it animates
from its initial state (`frame == CGRectZero`, `cornerRadius == 0`) to the values
you set a line later.

## The problem

A horizontal pager with a dot indicator. On every page snap the "selected" pill
slides in from the left edge and morphs from a square into a rounded pill
instead of simply appearing in its slot.

```objc
// APNaivePageStrip
[UIView animateWithDuration:duration animations:^{
    self.scrollView.contentOffset = target;
    [self setIndicatorIndex:page];          // rebuilds the dot views
}];
```

`-setIndicatorIndex:` rebuilds the indicator: `[[UIView alloc] init]` (frame
`CGRectZero`, corner radius 0), then sets the final `frame` and
`layer.cornerRadius`. Because that runs inside the animation transaction, UIKit
turns those property changes into animations of the brand-new view
(`position`, `bounds.size`, `cornerRadius` - corner radius is animatable in
UIView blocks since iOS 11).

## The fix

Animate only what should animate and update the indicator after the call:

```objc
// APFixedPageStrip
[UIView animateWithDuration:duration animations:^{
    self.scrollView.contentOffset = target;
}];
[self setIndicatorIndex:page];
```

or, if the call must stay inside the block, opt out explicitly:

```objc
// APNonAnimatedIndicatorPageStrip
[UIView performWithoutAnimation:^{
    [self setIndicatorIndex:page];
}];
```

## Layout

- `Sources/AnimateBlockPitfall/` - Objective-C target: `APDotIndicator`,
  `APPageStrip` and the `APNaivePageStrip` / `APFixedPageStrip` /
  `APNonAnimatedIndicatorPageStrip` variants. Public header in `include/`.
- `Tests/AnimateBlockPitfallTests/` - Swift XCTest. Test subclasses record
  `UIView.inheritedAnimationDuration` inside `setIndicatorIndex(_:)` (0.3 for the
  naive version, 0 for the fixed ones) and inspect `layer.animationKeys()` on the
  newly created dot.

## Run the tests

UIKit animations need a simulator:

```bash
xcodebuild test -scheme AnimateBlockPitfall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Requires iOS 17+. Verified with Xcode 27 on iOS 26.5 and iOS 27 simulators.

## License

MIT

Write-up: https://alexeyhatkevich.blogspot.com
