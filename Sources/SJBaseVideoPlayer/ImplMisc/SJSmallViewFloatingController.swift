//
//  SJSmallViewFloatingController.swift
//  Pods
//
//  Created by 畅三江 on 2019/6/6.
//  Swift 6.3 迁移: 保留原 ObjC 类/枚举/协议/选择器名.
//

import Foundation
import UIKit
import SJUIKit

/// 小浮窗布局位置 (与 ObjC 版枚举值严格一致)
@objc(SJSmallViewLayoutPosition)
public enum SJSmallViewLayoutPosition: Int {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

// MARK: - 浮动视图

@MainActor
@objc(SJSmallFloatingView)
final class SJSmallFloatingView: UIView {
    var x: CGFloat {
        get { frame.origin.x }
        set { var f = frame; f.origin.x = newValue; frame = f }
    }
    var y: CGFloat {
        get { frame.origin.y }
        set { var f = frame; f.origin.y = newValue; frame = f }
    }
    var w: CGFloat { frame.size.width }
    var h: CGFloat { frame.size.height }
}

// MARK: - Observer

@objc(SJSmallViewFloatingControllerObserver)
public final class SJSmallViewFloatingControllerObserver: NSObject, SJSmallViewFloatingControllerObserverProtocol {
    @objc public weak var controller: SJSmallViewFloatingController?
    @objc public var onAppearChanged: ((SJSmallViewFloatingController) -> Void)?
    @objc public var onEnabled: ((SJSmallViewFloatingController) -> Void)?

    @objc public init(controller: SJSmallViewFloatingController) {
        super.init()
        self.controller = controller

        sjkvo_observe(controller, "isAppeared") { [weak self] target, _ in
            DispatchQueue.main.async {
                guard let self = self, let target = target as? SJSmallViewFloatingController else { return }
                self.onAppearChanged?(target)
            }
        }

        sjkvo_observe(controller, "enabled") { [weak self] target, _ in
            DispatchQueue.main.async {
                guard let self = self, let target = target as? SJSmallViewFloatingController else { return }
                self.onEnabled?(target)
            }
        }
    }
}

// MARK: - Controller

@MainActor
@objc(SJSmallViewFloatingController)
public final class SJSmallViewFloatingController: NSObject, SJSmallViewFloatingController_Protocol, UIGestureRecognizerDelegate {

    // 由于 tap 手势会阻断事件响应链, 为了避免此种情况, 此处无需添加单击和双击手势,
    // 已改为由播放器主动调用这两个 block.
    // 这两个 block 将来可能会直接移动到播放器中.
    @objc public var onSingleTapped: ((SJSmallViewFloatingController) -> Void)?
    @objc public var onDoubleTapped: ((SJSmallViewFloatingController) -> Void)?
    @objc public var floatingViewShouldAppear: ((SJSmallViewFloatingController) -> Bool)?

    @objc public weak var targetSuperview: UIView?
    @objc public weak var target: UIView?

    // KVO 观察的属性: isAppeared / enabled, 需为 @objc dynamic
    @objc public dynamic var isAppeared: Bool = false
    @objc(isEnabled) public dynamic var enabled: Bool = false

    /// default value is SJSmallViewLayoutPositionBottomRight.
    @objc public var layoutPosition: SJSmallViewLayoutPosition = .bottomRight
    /// default value is UIEdgeInsetsMake(20, 12, 20, 12).
    @objc public var layoutInsets: UIEdgeInsets = UIEdgeInsets(top: 20, left: 12, bottom: 20, right: 12)
    @objc public var layoutSize: CGSize = .zero
    @objc public var ignoreSafeAreaInsets: Bool = false
    @objc public var addFloatViewToKeyWindow: Bool = false

    private var _floatingView: SJSmallFloatingView?

    public override init() {
        super.init()
        layoutInsets = UIEdgeInsets(top: 20, left: 12, bottom: 20, right: 12)
        layoutPosition = .bottomRight
    }

    deinit {
        // 与 ObjC 版一致: 销毁时在主线程移除浮动视图.
        if let floatingView = _floatingView {
            let nonisolatedView = floatingView
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    nonisolatedView.removeFromSuperview()
                }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        nonisolatedView.removeFromSuperview()
                    }
                }
            }
        }
    }

    @objc public var floatingView: UIView {
        if _floatingView == nil {
            let view = SJSmallFloatingView(frame: .zero)
            _addGestures(to: view)
            _floatingView = view
        }
        return _floatingView!
    }

    @objc public func show() {
        if !enabled { return }

        guard let floatingViewShouldAppear = floatingViewShouldAppear, floatingViewShouldAppear(self) else { return }

        var superview: UIView?
        if addFloatViewToKeyWindow == false {
            let currentViewController = targetSuperview?.lookupResponder(for: UIViewController.self) as? UIViewController
            superview = currentViewController?.view
        } else {
            superview = UIApplication.shared.keyWindow
        }

        let floatingView = self.floatingView as! SJSmallFloatingView

        if floatingView.superview !== superview {
            superview?.addSubview(floatingView)
            let superViewBounds = superview?.bounds ?? .zero
            let superViewWidth = superViewBounds.size.width
            let superViewHeight = superViewBounds.size.height

            var safeAreaInsets = UIEdgeInsets.zero
            if !ignoreSafeAreaInsets {
                safeAreaInsets = superview?.safeAreaInsets ?? .zero
            }

            let size = layoutSize
            var w = size.width
            var h = size.height
            var x: CGFloat = 0
            var y: CGFloat = 0

            if size.equalTo(.zero) {
                let maxW = ceil(superViewWidth * 0.48)
                w = maxW > 300.0 ? 300.0 : maxW
                h = w * 9.0 / 16.0
            }

            switch layoutPosition {
            case .topLeft, .bottomLeft:
                x = safeAreaInsets.left + layoutInsets.left
            case .topRight, .bottomRight:
                x = superViewWidth - w - layoutInsets.right - safeAreaInsets.right
            }

            switch layoutPosition {
            case .topLeft, .topRight:
                y = safeAreaInsets.top + layoutInsets.top
            case .bottomLeft, .bottomRight:
                y = superViewHeight - h - layoutInsets.bottom - safeAreaInsets.bottom
            }

            floatingView.frame = CGRect(x: x, y: y, width: w, height: h)
        }

        target?.frame = floatingView.bounds
        if let target = target {
            floatingView.addSubview(target)
            target.layoutIfNeeded()
        }

        UIView.animate(withDuration: 0.3) {
            floatingView.alpha = 1
        }

        isAppeared = true
    }

    @objc public func dismiss() {
        if !enabled { return }

        target?.frame = targetSuperview?.bounds ?? .zero
        if let target = target {
            targetSuperview?.addSubview(target)
            target.layoutIfNeeded()
        }

        UIView.animate(withDuration: 0.3) {
            self._floatingView?.alpha = 0.001
        }

        isAppeared = false
    }

    @objc public func getObserver() -> SJSmallViewFloatingControllerObserverProtocol {
        return SJSmallViewFloatingControllerObserver(controller: self)
    }

    // MARK: gestures

    private func _addGestures(to floatingView: SJSmallFloatingView) {
        floatingView.addGestureRecognizer(panGesture)
    }

    @objc(isSlidable) public var slidable: Bool {
        get { panGesture.isEnabled }
        set { panGesture.isEnabled = newValue }
    }

    private lazy var panGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(_handlePanGesture(_:)))
        pan.delegate = self
        return pan
    }()

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            otherGestureRecognizer.state = .cancelled
            return true
        }
        return false
    }

    @objc private func _handlePanGesture(_ panGesture: UIPanGestureRecognizer) {
        guard let view = _floatingView, let superview = view.superview else { return }
        let offset = panGesture.translation(in: superview)
        let center = view.center
        view.center = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
        panGesture.setTranslation(.zero, in: superview)

        switch panGesture.state {
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
                var safeAreaInsets = UIEdgeInsets.zero
                if !self.ignoreSafeAreaInsets {
                    safeAreaInsets = superview.safeAreaInsets
                }

                let left = safeAreaInsets.left + self.layoutInsets.left
                let right = superview.bounds.size.width - view.w - self.layoutInsets.right - safeAreaInsets.right
                if view.x <= left {
                    view.x = left
                } else if view.x >= right {
                    view.x = right
                }

                let top = safeAreaInsets.top + self.layoutInsets.top
                let bottom = superview.bounds.size.height - view.h - self.layoutInsets.bottom - safeAreaInsets.bottom
                if view.y <= top {
                    view.y = top
                } else if view.y >= bottom {
                    view.y = bottom
                }
            }, completion: nil)
        default:
            break
        }
    }
}

