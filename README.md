# Views created inside a UIView animation block animate from their initial state

A minimal Objective-C reproduction (with Swift XCTest tests) of a UIKit gotcha:
any view you **create and lay out synchronously inside**
`+[UIView animateWithDuration:animations:]` does not just appear - it animates
from its initial state (`frame == CGRectZero`, `cornerRadius == 0`) to the values
you set a line later.

## How to run

1. Open `Demo/Demo.xcodeproj` in Xcode (it references this package locally).
2. Pick any iPhone simulator (iOS 17+) and press **⌘R**.
3. Use the **Naive / Fixed / No-anim** switch, then tap **Next page**. Slow motion
   (1.5 s) is on by default.
   - **Naive**: watch the dots under the pages. Every dot is rebuilt inside the
     animation block, so each new dot flies in from the top-left corner and the
     selected pill grows out of a square.
   - **Fixed** / **No-anim**: the pages still slide, but the dots just switch to
     the new state in place.
   - **Scripted run**: launch arguments `-mode naive|fixed|noanim`, `-autorun 1` (taps
     **Next page** once, a second after launch) and `-freeze <seconds>` (pauses all
     animations that long after the tap, to inspect one mid-animation frame), e.g.
     `xcrun simctl launch booted com.alexeyhatkevich.uikit-view-created-inside-animate-block.demo -mode naive -autorun 1 -freeze 0.5`.
     In Xcode, add them under *Edit Scheme > Run > Arguments*.
4. **⌘U** runs the package's XCTest suite (`AnimateBlockPitfallTests`) on the
   simulator. The tests that assert the naive bug exists are expected to pass.

`swift test` on macOS does not apply: the library is UIKit-only, so the tests
need an iOS simulator (use Xcode or the `xcodebuild` command below).

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `Demo/project.yml` (`cd Demo && xcodegen generate`); the generated project is
committed, so you don't need XcodeGen to run it.

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
