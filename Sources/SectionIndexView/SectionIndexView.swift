//
// https://github.com/0xcj/SectionIndexView
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

///  ┌─────────────────┐
///  │                                                             │
///  │                                                  ┌─┐│              ┌─┐
///  │                                                  │A ││              │A │        ┌─┐
///  │                                                  ├─┤│              ├─┤       │ A │-------> Item (SectionIndexViewItem)
///  │                                                  │B ││              │B │       └─┘
///  │                                                  ├─┤│              ├─┤
///  │                                                  │C ││              │C │
///  │                                                  ├─┤│              ├─┤
///  │                                                  │D ││              │D │
///  │                                                  ├─┤│              ├─┤
///  │                                                  │E ││              │E │--------------------------->  SectionIndexView
///  │                  ┌─┐                     ├─┤│              ├─┤
///  │                  │G │                     │F ││              │F │
///  │                  └─┘                     ├─┤│              ├─┤
///  │                     │                         │G ││              │G │
///  │                     │                         ├─┤│              ├─┤
///  │                     ⇩                         │H ││              │H │
///  │           Indicator (UIView)          ├─┤│              ├─┤
///  │                                                  │ I  ││             │ I  │
///  │                                                  ├─┤│             ├─┤
///  │                                                  │J  ││             │J  │
///  │                                                  ├─┤│             ├─┤
///  │                                                  │K ││             │K │
///  │                                                  └─┘│             └─┘
///  │                                                             │
///  │                                                             │
///  │                                                             │
///  └─────────────────┘

#if canImport(UIKit)

import UIKit

#endif

//MARK: - SectionIndexViewDataSource
@objc public protocol SectionIndexViewDataSource: NSObjectProtocol {
    @objc func numberOfSections(in sectionIndexView: SectionIndexView) -> Int
    @objc func sectionIndexView(_ sectionIndexView: SectionIndexView, itemAt section: Int) -> SectionIndexViewItem
}

//MARK: - SectionIndexViewDelegate
@objc public protocol SectionIndexViewDelegate: NSObjectProtocol {
    @objc func sectionIndexView(_ sectionIndexView: SectionIndexView, didSelect section: Int)
    @objc func sectionIndexViewTouchBegan(_ sectionIndexView: SectionIndexView)
    @objc func sectionIndexViewTouchEnded(_ sectionIndexView: SectionIndexView)
}

//MARK: - SectionIndexView
public class SectionIndexView: UIView {

    @objc public weak var dataSource: SectionIndexViewDataSource? { didSet { reloadData() } }
    @objc public weak var delegate: SectionIndexViewDelegate?

    @objc public var isItemIndicatorAlwaysInCenterY = false
    @objc public var itemIndicatorHorizontalOffset: CGFloat = -20

    @objc public private(set) var selectedItem: SectionIndexViewItem?
    @objc public private(set) var isTouching = false

    @available(iOS 10.0, *)
    private lazy var generator: UIImpactFeedbackGenerator = {
        return UIImpactFeedbackGenerator.init(style: .light)
    }()

    private var items = [SectionIndexViewItem]()

    override public init(frame: CGRect) {
        super.init(frame: frame)

        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupGestures()
    }

    // MARK: - Func

    @objc public func reloadData() {
        for item in items {
            item.removeFromSuperview()
            item.indicator?.removeFromSuperview()
        }
        items.removeAll()
        loadView()
    }

    @objc public func item(at section: Int) -> SectionIndexViewItem? {
        guard section >= 0, section < items.count else { return nil }
        return items[section]
    }

    @objc public func impact() {
        guard #available(iOS 10.0, *) else { return }
        generator.prepare()
        generator.impactOccurred()
    }

    @objc public func selectItem(at section: Int) {
        guard let item = item(at: section) else { return }
        item.isSelected = true
        selectedItem = item
    }

    @objc public func deselectCurrentItem() {
        selectedItem?.isSelected = false
        selectedItem = nil
    }

    @objc public func showCurrentItemIndicator() {
        guard let selectedItem = selectedItem, let indicator = selectedItem.indicator else { return }
        guard indicator.superview != nil else {
            let x = -(indicator.bounds.width * 0.5) + itemIndicatorHorizontalOffset
            let y = isItemIndicatorAlwaysInCenterY ? (bounds.height - selectedItem.bounds.height) * 0.5 : selectedItem.center.y
            indicator.center = CGPoint.init(x: x, y: y)
            addSubview(indicator)
            return
        }
        indicator.alpha = 1
    }

    @objc public func hideCurrentItemIndicator() {
        guard let indicator = self.selectedItem?.indicator else { return }
        indicator.alpha = 0
    }

    @objc private func onTapRecognized(_ gesture: UIPanGestureRecognizer) {
        processBeginGesture(gesture)

        processGesture(gesture)

        processFinishGesture(gesture)
    }

    @objc private func onPanRecognized(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
            case .began:
                processBeginGesture(gesture)

            case .changed:
                processGesture(gesture)

            case .ended:
                processFinishGesture(gesture)

            default:
                break
        }
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapRecognized(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPanRecognized(_:)))

        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(tapGesture)
        self.addGestureRecognizer(panGesture)
    }

    private func processBeginGesture(_ gesture: UIGestureRecognizer) {
        isTouching = true
        delegate?.sectionIndexViewTouchBegan(self)
    }

    private func processGesture(_ gesture: UIGestureRecognizer) {
        let location = gesture.location(in: self)

        guard let section = getSectionBy(location),
              let item = item(at: section), !(self.selectedItem?.isEqual(item) ?? false) else { return }
        delegate?.sectionIndexView(self, didSelect: section)
        NotificationCenter.default.post(name: SectionIndexView.touchesEndedNotification, object: self, userInfo: ["section": section])
    }

    private func processFinishGesture(_ gesture: UIGestureRecognizer) {
        isTouching = false
        delegate?.sectionIndexViewTouchEnded(self)
        NotificationCenter.default.post(name: SectionIndexView.touchesEndedNotification, object: self)
    }

    private func loadView() {
        guard let dataSource = self.dataSource  else { return }
        let numberOfItems = dataSource.numberOfSections(in: self)
        items = Array(0..<numberOfItems).compactMap { dataSource.sectionIndexView(self, itemAt: $0) }
        setItemsLayoutConstraint()
    }

    private func setItemsLayoutConstraint() {
        guard !items.isEmpty else { return }
        let heightMultiplier = CGFloat(1) / CGFloat(items.count)
        for (i, item) in items.enumerated() {
            item.translatesAutoresizingMaskIntoConstraints = false
            addSubview(item)
            let constraints = [
                item.leadingAnchor.constraint(equalTo: leadingAnchor),
                item.trailingAnchor.constraint(equalTo: trailingAnchor),
                item.heightAnchor.constraint(equalTo: heightAnchor, multiplier: heightMultiplier),
                item.topAnchor.constraint(equalTo: i == 0 ? topAnchor : items[i - 1].bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
        }
    }

    // MARK: -  Touches handle
    private func point(_ point: CGPoint, isIn view: UIView) -> Bool {
        return point.y <= (view.frame.origin.y + view.frame.size.height) && point.y >= view.frame.origin.y
    }

    private func getSectionBy(_ touches: Set<UITouch>) -> Int? {
        guard let touch = touches.first else { return nil }
        let p = touch.location(in: self)
        return self.getSectionBy(p)
    }

    private func getSectionBy(_ location: CGPoint) -> Int? {
        items.enumerated().filter { point(location, isIn: $0.element) }.compactMap { $0.offset }.first
    }
}

extension SectionIndexView {
    public static let touchesOccurredNotification = Notification.Name.init("SectionIndexViewTouchesOccurredNotification")
    public static let touchesEndedNotification = Notification.Name.init("SectionIndexViewTouchesEndedNotification")
}
