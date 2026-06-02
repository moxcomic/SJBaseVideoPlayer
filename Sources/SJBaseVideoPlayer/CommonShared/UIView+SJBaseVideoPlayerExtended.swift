//
//  UIView+SJBaseVideoPlayerExtended.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/22.
//
//  Swift 6.3 转换: 保留全部 ObjC 选择器, 供其它块(SJPlayModel/SJBaseVideoPlayer 等)调用.
//

import UIKit

@objc
public extension UIView {

    ///
    /// 子视图是否显示中
    ///
    @objc(isViewAppeared:insets:)
    func isViewAppeared(_ childView: UIView?, insets: UIEdgeInsets) -> Bool {
        guard let childView = childView else { return false }
        return !intersection(with: childView, insets: insets).isEmpty
    }

    ///
    /// 两者在window上的交叉点
    ///
    @objc(intersectionWithView:insets:)
    func intersection(with view: UIView?, insets: UIEdgeInsets) -> CGRect {
        guard let view = view, view.window != nil, self.window != nil else { return .zero }
        let rect1 = view.convert(view.bounds, to: self.window)
        var rect2 = self.convert(self.bounds, to: self.window)
        rect2 = rect2.inset(by: insets)

        let intersection = rect1.intersection(rect2)
        return (intersection.isEmpty || intersection.isNull) ? .zero : intersection
    }

    ///
    /// 寻找响应者
    ///
    @objc(lookupResponderForClass:)
    func lookupResponder(for cls: AnyClass) -> UIResponder? {
        var next: UIResponder? = self.next
        while let cur = next, !cur.isKind(of: cls) {
            next = cur.next
        }
        return next
    }

    ///
    /// 寻找实现了该协议的视图, 包括自己
    ///
    @objc(viewWithProtocol:tag:)
    func view(with protocol: Protocol, tag: Int) -> UIView? {
        if self.conforms(to: `protocol`) && self.tag == tag {
            return self
        }
        for subview in self.subviews {
            if let target = subview.view(with: `protocol`, tag: tag) {
                return target
            }
        }
        return nil
    }

    ///
    /// 对应视图是否在window中显示
    ///
    @objc(isViewAppearedWithProtocol:tag:insets:)
    func isViewAppeared(with protocol: Protocol, tag: Int, insets: UIEdgeInsets) -> Bool {
        return isViewAppeared(view(with: `protocol`, tag: tag), insets: insets)
    }

    @objc var sj_x: CGFloat {
        get { frame.origin.x }
        set {
            var f = frame
            f.origin.x = newValue
            frame = f
        }
    }

    @objc var sj_y: CGFloat {
        get { frame.origin.y }
        set {
            var f = frame
            f.origin.y = newValue
            frame = f
        }
    }

    @objc var sj_w: CGFloat {
        get { frame.size.width }
        set {
            var f = frame
            f.size.width = newValue
            frame = f
        }
    }

    @objc var sj_h: CGFloat {
        get { frame.size.height }
        set {
            var f = frame
            f.size.height = newValue
            frame = f
        }
    }

    @objc var sj_size: CGSize {
        get { frame.size }
        set {
            var f = frame
            f.size = newValue
            frame = f
        }
    }
}

@objc
public extension NSObject {
    ///
    /// 对 self 执行 selector 并返回其视图结果 (KVC 风格取播放器父视图).
    ///
    @objc(subviewForSelector:)
    func subview(for selector: Selector) -> UIView? {
        if self.responds(to: selector) {
            return self.perform(selector)?.takeUnretainedValue() as? UIView
        }
        return nil
    }
}

