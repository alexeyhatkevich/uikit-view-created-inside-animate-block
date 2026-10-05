import XCTest
import UIKit
import AnimateBlockPitfall

// Test subclasses record the animation context -setIndicatorIndex: runs in.
// `UIView.inheritedAnimationDuration` is the duration of the enclosing
// UIView animation block, or 0 when no animation block is active.

private final class ProbeNaive: APNaivePageStrip {
    var observedDuration: TimeInterval?
    override func setIndicatorIndex(_ page: Int) {
        observedDuration = UIView.inheritedAnimationDuration
        super.setIndicatorIndex(page)
    }
}

private final class ProbeFixed: APFixedPageStrip {
    var observedDuration: TimeInterval?
    override func setIndicatorIndex(_ page: Int) {
        observedDuration = UIView.inheritedAnimationDuration
        super.setIndicatorIndex(page)
    }
}

private final class ProbeNonAnimated: APNonAnimatedIndicatorPageStrip {
    var observedDuration: TimeInterval?
    override func setIndicatorIndex(_ page: Int) {
        observedDuration = UIView.inheritedAnimationDuration
        super.setIndicatorIndex(page)
    }
}

@MainActor
final class AnimateBlockPitfallTests: XCTestCase {
    private let duration: TimeInterval = 0.3
    private let pageSize = CGSize(width: 390, height: 200)
    private var window: UIWindow!

    override func setUp() async throws {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
    }

    override func tearDown() async throws {
        window.isHidden = true
        window = nil
    }

    /// Hosts the view in a visible window so UIKit attaches real CAAnimations.
    private func host<T: UIView>(_ view: T) -> T {
        window.addSubview(view)
        window.layoutIfNeeded()
        return view
    }

    private func animationKeys(of view: UIView?) -> Set<String> {
        Set(view?.layer.animationKeys() ?? [])
    }

    // MARK: - Naive: the bug

    // Proves the indicator rebuild runs inside the scroll animation's transaction.
    func test_naive_indicatorUpdateRunsInsideTheAnimationBlock() {
        let strip = host(ProbeNaive(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        XCTAssertEqual(strip.observedDuration ?? -1, duration, accuracy: 0.0001)
    }

    // Proves the brand-new selected dot animates position, size and corners
    // from its initial state instead of appearing in place.
    func test_naive_newSelectedDotAnimatesFromItsInitialState() {
        let strip = host(ProbeNaive(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        let keys = animationKeys(of: strip.indicator.selectedDot)
        XCTAssertTrue(keys.contains("position"), "keys: \(keys)")
        XCTAssertTrue(keys.contains("bounds.size"), "keys: \(keys)")
        XCTAssertTrue(keys.contains("cornerRadius"), "keys: \(keys)")
    }

    // Proves the corner animation starts from a square: UIKit adds an *additive*
    // animation whose fromValue is (initial - final) = 0 - 4 = -4.
    func test_naive_selectedDotCornerRadiusAnimationStartsSquare() throws {
        let strip = host(ProbeNaive(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        let layer = try XCTUnwrap(strip.indicator.selectedDot?.layer)
        let animation = try XCTUnwrap(layer.animation(forKey: "cornerRadius") as? CABasicAnimation)
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.fromValue as? CGFloat, -layer.cornerRadius)
        XCTAssertEqual(animation.duration, duration, accuracy: 0.0001)
    }

    // MARK: - Fixed: update after the animate call

    // Proves the indicator rebuild runs with no animation context.
    func test_fixed_indicatorUpdateRunsOutsideTheAnimationBlock() {
        let strip = host(ProbeFixed(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        XCTAssertEqual(strip.observedDuration, 0)
    }

    // Proves the new selected dot simply appears at its final frame.
    func test_fixed_newSelectedDotHasNoAnimations() {
        let strip = host(ProbeFixed(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        XCTAssertEqual(animationKeys(of: strip.indicator.selectedDot), [])
        XCTAssertEqual(strip.indicator.selectedDot?.frame,
                       CGRect(x: APDotSize + APDotSpacing, y: 0,
                              width: APSelectedDotWidth, height: APDotSize))
    }

    // Proves the fix keeps the page snap itself animated.
    func test_fixed_scrollIsStillAnimated() {
        let strip = host(ProbeFixed(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        XCTAssertFalse(animationKeys(of: strip.scrollView).isEmpty)
        XCTAssertEqual(strip.scrollView.contentOffset.x, pageSize.width)
    }

    // MARK: - Alternative fix: performWithoutAnimation inside the block

    // Proves performWithoutAnimation: suppresses the inherited animation for the rebuild.
    func test_performWithoutAnimation_newSelectedDotHasNoAnimations() {
        let strip = host(ProbeNonAnimated(numberOfPages: 4, pageSize: pageSize))
        strip.scrollToPage(1, duration: duration)
        XCTAssertEqual(strip.observedDuration, 0)
        XCTAssertEqual(animationKeys(of: strip.indicator.selectedDot), [])
        XCTAssertFalse(animationKeys(of: strip.scrollView).isEmpty)
    }

    // MARK: - Edge cases

    // Proves a nested animate block inherits the OUTER duration by default.
    func test_nestedAnimate_inheritsOuterDurationByDefault() {
        var inner: TimeInterval = -1
        UIView.animate(withDuration: duration) {
            UIView.animate(withDuration: 2.0) {
                inner = UIView.inheritedAnimationDuration
            }
        }
        XCTAssertEqual(inner, duration, accuracy: 0.0001)
    }

    // Proves .overrideInheritedDuration lets the nested block use its own duration.
    func test_nestedAnimate_overrideInheritedDurationUsesOwnDuration() {
        var inner: TimeInterval = -1
        UIView.animate(withDuration: duration) {
            UIView.animate(withDuration: 2.0, delay: 0, options: [.overrideInheritedDuration]) {
                inner = UIView.inheritedAnimationDuration
            }
        }
        XCTAssertEqual(inner, 2.0, accuracy: 0.0001)
    }

    // Proves indirection does not matter: a helper two calls deep still creates
    // its view inside the transaction, so the view animates in.
    func test_indirectHelper_viewCreatedDeepInsideBlockIsAnimated() {
        let container = host(UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200)))
        func buildBadge() -> UIView {
            let badge = UIView()
            container.addSubview(badge)
            badge.frame = CGRect(x: 100, y: 100, width: 20, height: 20)
            return badge
        }
        func refresh() -> UIView { buildBadge() }

        var badge: UIView?
        UIView.animate(withDuration: duration) { badge = refresh() }
        XCTAssertTrue(animationKeys(of: badge).contains("position"))
    }
}
