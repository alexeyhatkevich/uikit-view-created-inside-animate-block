import UIKit
import AnimateBlockPitfall

/// Hosts the library's page strips and lets you switch between the naive
/// (indicator rebuilt inside the animation block) and fixed implementations.
final class DemoViewController: UIViewController {
    private enum Variant: Int, CaseIterable {
        case naive, fixed, performWithoutAnimation

        var title: String {
            switch self {
            case .naive: "Naive"
            case .fixed: "Fixed"
            case .performWithoutAnimation: "No-anim"
            }
        }

        var explanation: String {
            switch self {
            case .naive:
                "Naive: the dot indicator is rebuilt INSIDE the UIView.animate block. "
                + "Watch the dots: every new dot slides in from the top-left corner and "
                + "the selected pill grows from a square instead of just appearing."
            case .fixed:
                "Fixed: only the scroll is animated; the indicator is rebuilt after the "
                + "animate call. The pages still slide, the dots simply jump to the new state."
            case .performWithoutAnimation:
                "Alternative fix: the rebuild stays inside the block but is wrapped in "
                + "UIView.performWithoutAnimation. Same result as Fixed."
            }
        }

        func makeStrip(pages: Int, pageSize: CGSize) -> APPageStrip {
            switch self {
            case .naive: APNaivePageStrip(numberOfPages: pages, pageSize: pageSize)
            case .fixed: APFixedPageStrip(numberOfPages: pages, pageSize: pageSize)
            case .performWithoutAnimation:
                APNonAnimatedIndicatorPageStrip(numberOfPages: pages, pageSize: pageSize)
            }
        }
    }

    private let pageCount = 4
    private let pageColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]

    private let segmented = UISegmentedControl(items: Variant.allCases.map(\.title))
    private let explanationLabel = UILabel()
    private let slowMotionSwitch = UISwitch()
    private let stripContainer = UIView()
    private var strip: APPageStrip?

    private var variant: Variant { Variant(rawValue: segmented.selectedSegmentIndex) ?? .naive }
    private var duration: TimeInterval { slowMotionSwitch.isOn ? 1.5 : 0.3 }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Animate-block pitfall"
        view.backgroundColor = .systemBackground

        segmented.selectedSegmentIndex = Variant.naive.rawValue
        switch UserDefaults.standard.string(forKey: "mode")?.lowercased() {
        case "fixed": segmented.selectedSegmentIndex = Variant.fixed.rawValue
        case "noanim", "no-anim": segmented.selectedSegmentIndex = Variant.performWithoutAnimation.rawValue
        default: break
        }
        segmented.accessibilityIdentifier = "variant"
        segmented.addTarget(self, action: #selector(variantChanged), for: .valueChanged)

        explanationLabel.numberOfLines = 0
        explanationLabel.font = .preferredFont(forTextStyle: .callout)
        explanationLabel.textColor = .secondaryLabel

        slowMotionSwitch.isOn = true
        let slowLabel = UILabel()
        slowLabel.text = "Slow motion (1.5 s)"
        let slowRow = UIStackView(arrangedSubviews: [slowLabel, slowMotionSwitch])
        slowRow.spacing = 8

        let previous = UIButton(configuration: .bordered())
        previous.configuration?.title = "Previous"
        previous.addTarget(self, action: #selector(previousPage), for: .touchUpInside)
        let next = UIButton(configuration: .borderedProminent())
        next.configuration?.title = "Next page"
        next.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [previous, next])
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [segmented, explanationLabel, stripContainer, buttons, slowRow])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            stripContainer.heightAnchor.constraint(equalToConstant: 224),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The stack view sizes stripContainer in its own layout pass; run it now.
        stripContainer.superview?.layoutIfNeeded()
        if strip == nil || strip?.bounds.width != stripContainer.bounds.width {
            rebuildStrip()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runScriptIfRequested()
    }

    /// Launch arguments for scripted runs:
    /// `-mode naive|fixed|noanim` picks the variant, `-autorun 1` taps "Next page" once
    /// shortly after launch, and `-freeze <seconds>` pauses every animation in the window
    /// that long after the tap, so a screenshot can show a single mid-animation frame.
    private var didRunScript = false
    private func runScriptIfRequested() {
        let defaults = UserDefaults.standard
        guard !didRunScript, defaults.bool(forKey: "autorun") else { return }
        didRunScript = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.nextPage()
            let freeze = defaults.double(forKey: "freeze")
            guard freeze > 0, let layer = self.view.window?.layer else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + freeze) {
                let now = layer.convertTime(CACurrentMediaTime(), from: nil)
                layer.speed = 0
                layer.timeOffset = now
            }
        }
    }

    @objc private func variantChanged() { rebuildStrip() }

    private func rebuildStrip() {
        explanationLabel.text = variant.explanation
        strip?.removeFromSuperview()
        let width = stripContainer.bounds.width
        guard width > 0 else { return }

        let pageSize = CGSize(width: width, height: 200)
        let newStrip = variant.makeStrip(pages: pageCount, pageSize: pageSize)
        // Pages only change through the buttons, which call -scrollToPage:duration:.
        newStrip.scrollView.isScrollEnabled = false
        for page in 0..<pageCount {
            let card = UILabel(frame: CGRect(x: CGFloat(page) * width + 8, y: 0,
                                             width: width - 16, height: pageSize.height))
            card.text = "Page \(page + 1)"
            card.textAlignment = .center
            card.font = .preferredFont(forTextStyle: .title1)
            card.textColor = .white
            card.backgroundColor = pageColors[page % pageColors.count]
            card.layer.cornerRadius = 16
            card.clipsToBounds = true
            newStrip.scrollView.addSubview(card)
        }
        stripContainer.addSubview(newStrip)
        strip = newStrip
    }

    @objc private func nextPage() { go(by: 1) }
    @objc private func previousPage() { go(by: -1) }

    private func go(by delta: Int) {
        guard let strip else { return }
        let target = (strip.currentPage + delta + pageCount) % pageCount
        strip.scrollToPage(target, duration: duration)
    }
}
