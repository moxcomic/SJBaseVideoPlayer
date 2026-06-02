//
//  SJPromptingPopupController.swift
//  Pods
//
//  Created by 畅三江 on 2019/7/12.
//
//  由 ObjC 版 SJPromptingPopupController.h/.m 转换而来 (Swift 6.3)。
//  Masonry -> SnapKit。
//

import Foundation
import UIKit
import SnapKit

private let _AnimDuration: TimeInterval = 0.4

///
/// 左下角提示项容器视图(私有)。
///
@MainActor
private final class _SJItemPopupContainerView: UIView {
    private(set) var titleLabel: UILabel?
    private(set) var customView: UIView?

    convenience init(frame: CGRect, contentInset: UIEdgeInsets) {
        self.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.8)
        layer.cornerRadius = 5

        let label = UILabel(frame: .zero)
        label.numberOfLines = 0
        addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(contentInset.top)
            make.left.equalToSuperview().offset(contentInset.left)
            make.bottom.equalToSuperview().offset(-contentInset.bottom)
            make.right.equalToSuperview().offset(-contentInset.right)
        }
        titleLabel = label
    }

    convenience init(frame: CGRect, customView: UIView) {
        self.init(frame: frame)
        self.customView = customView
        addSubview(customView)
        customView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        // SJPlayerZIndexes 由 Const 块提供 (同 module)
        layer.zPosition = CGFloat(SJPlayerZIndexes.shared.promptingPopupViewZIndex)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

///
/// 左下角提示弹层控制器。
///
/// 遵循 `SJPromptingPopupController` 协议(定义在接口块)。UIKit 操作, @MainActor。
///
@MainActor
public final class SJPromptingPopupController: NSObject, SJPromptingPopupController_Protocol {

    // 注意: 原 ObjC 私有属性名为 `subviews`(覆盖 UIView 概念), 这里用 _items 存储已显示容器视图。
    private var items: [_SJItemPopupContainerView] = []

    // MARK: 协议属性

    /// 内边距 (default value is UIEdgeInsetsMake(12, 22, 12, 22))
    public var contentInset: UIEdgeInsets = UIEdgeInsets(top: 12, left: 22, bottom: 12, right: 22)

    /// 左间距 (default value is 16)
    public var leftMargin: CGFloat = 16

    /// 下间距 (default value is 16)
    public var bottomMargin: CGFloat = 16 {
        didSet {
            if bottomMargin != oldValue {
                if !items.isEmpty {
                    remakeConstraints(at: items.count - 1)
                    UIView.animate(withDuration: _AnimDuration) {
                        self.target?.layoutIfNeeded()
                    }
                }
            }
        }
    }

    /// 项目间距 (default value is 12)
    public var itemSpacing: CGFloat = 12

    /// 自动调整左 Inset
    public var automaticallyAdjustsLeftInset: Bool = true

    /// 自动调整底部 Inset
    public var automaticallyAdjustsBottomInset: Bool = true

    /// 目标视图 (由播放器维护)
    public weak var target: UIView?

    /// 正显示的视图
    public var displayingViews: [UIView]? {
        guard !items.isEmpty else { return nil }
        var m: [UIView] = []
        m.reserveCapacity(items.count)
        for container in items {
            if let custom = container.customView {
                m.append(custom)
            } else if let label = container.titleLabel {
                m.append(label)
            }
        }
        return m
    }

    // MARK: 初始化

    public override init() {
        super.init()
    }

    // MARK: 协议方法

    public func show(_ title: NSAttributedString) {
        show(title, duration: 3)
    }

    public func show(_ title: NSAttributedString, duration: TimeInterval) {
        let view = _SJItemPopupContainerView(frame: .zero, contentInset: contentInset)
        view.titleLabel?.attributedText = title
        _show(view, duration: duration)
    }

    public func showCustomView(_ view: UIView) {
        showCustomView(view, duration: 3)
    }

    public func showCustomView(_ customView: UIView, duration: TimeInterval) {
        let view = _SJItemPopupContainerView(frame: .zero, customView: customView)
        _show(view, duration: duration)
    }

    public func isShowing(withCustomView view: UIView) -> Bool {
        for container in items where container.customView == view {
            return true
        }
        return false
    }

    public func clear() {
        removeAllSubviews()
    }

    public func remove(_ view: UIView) {
        for container in items {
            if container.customView == view || container.titleLabel == view {
                removeSubview(container)
                break
            }
        }
    }

    // MARK: 私有

    private func _show(_ view: _SJItemPopupContainerView, duration: TimeInterval) {
        addSubview(view)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak view] in
            guard let self = self else { return }
            guard let view = view else { return }
            self.removeSubview(view)
        }
    }

    private func addSubview(_ view: _SJItemPopupContainerView) {
        guard let target = target else { return }
        let bounds = target.bounds
        view.frame = CGRect(x: -bounds.size.width, y: bounds.size.height - bottomMargin, width: 0, height: 0)
        target.addSubview(view)
        items.append(view)

        for idx in items.indices {
            remakeConstraints(at: idx)
        }

        UIView.animate(withDuration: _AnimDuration, delay: 0, options: .curveEaseOut, animations: {
            target.layoutIfNeeded()
        }, completion: nil)
    }

    private func removeSubview(_ view: _SJItemPopupContainerView) {
        guard let idx = items.firstIndex(of: view) else { return }

        items.remove(at: idx)

        remakeConstraints(at: idx - 1)
        remakeConstraints(at: idx)

        UIView.animate(withDuration: _AnimDuration, animations: {
            view.alpha = 0.01
            self.target?.layoutIfNeeded()
        }, completion: { _ in
            view.removeFromSuperview()
        })
    }

    private func removeAllSubviews() {
        guard !items.isEmpty else { return }
        let subviews = items
        items.removeAll()
        UIView.animate(withDuration: _AnimDuration, animations: {
            for subview in subviews {
                subview.alpha = 0.001
            }
        }, completion: { _ in
            for subview in subviews.reversed() {
                subview.removeFromSuperview()
            }
        })
    }

    private func remakeConstraints(at idx: Int) {
        guard idx >= 0, idx < items.count else { return }

        let count = items.count
        let view = items[idx]
        guard let target = target else { return }
        view.snp.remakeConstraints { make in
            if automaticallyAdjustsLeftInset {
                make.left.equalTo(target.safeAreaLayoutGuide.snp.left).offset(leftMargin)
            } else {
                make.left.equalToSuperview().offset(leftMargin)
            }

            if idx != count - 1 {
                make.bottom.equalTo(items[idx + 1].snp.top).offset(-itemSpacing)
            } else {
                if automaticallyAdjustsBottomInset {
                    make.bottom.equalTo(target.safeAreaLayoutGuide.snp.bottom).offset(-bottomMargin)
                } else {
                    make.bottom.equalToSuperview().offset(-bottomMargin)
                }
            }
        }
    }
}

