//
//  SJRotationFullscreenWindow.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationFullscreenWindow.h/.m
//  - 全屏旋转专用 UIWindow。
//  - pointInside 转发给 delegate; layoutSubviews 时清理多余子视图背景色。
//  - rotationManager 弱引用回旋转管理器 (供 supportedInterfaceOrientationsForWindow 反查)。
//

import UIKit

@MainActor
@objc(SJRotationFullscreenWindow)
public class SJRotationFullscreenWindow: UIWindow {

    private weak var sj_delegate: SJRotationFullscreenWindowDelegate?
    private var sj_old_bounds: CGRect = .zero

    @objc public weak var rotationManager: SJRotationManager?

    @objc(initWithFrame:delegate:)
    public init(frame: CGRect, delegate: SJRotationFullscreenWindowDelegate?) {
        super.init(frame: frame)
        self.sj_delegate = delegate
        _setup()
    }

    @available(iOS 13.0, *)
    @objc(initWithWindowScene:delegate:)
    public init(windowScene: UIWindowScene, delegate: SJRotationFullscreenWindowDelegate?) {
        super.init(windowScene: windowScene)
        self.sj_delegate = delegate
        _setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if DEBUG
    deinit {
        // 原 ObjC 版 dealloc 打印日志
    }
#endif

    public override var rootViewController: UIViewController? {
        get { super.rootViewController }
        set {
            super.rootViewController = newValue
            newValue?.view.frame = bounds
            newValue?.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    private func _setup() {
        self.frame = UIScreen.main.bounds
    }

    public override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { /* no-op: 与 ObjC 版本一致, 屏蔽外部设置背景色 */ }
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        sj_delegate?.window(self, point: point, with: event) ?? false
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // 如果是大屏转大屏 就不需要修改了
        if !sj_old_bounds.equalTo(bounds) {
            sj_old_bounds = bounds

            var superview: UIView = self
            if #available(iOS 13.0, *) {
                if let first = subviews.first { superview = first }
            }

            UIView.performWithoutAnimation {
                for view in superview.subviews {
                    if view != self.rootViewController?.view, view.isMember(of: UIView.self) {
                        view.backgroundColor = .clear
                        for subview in view.subviews {
                            subview.backgroundColor = .clear
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Delegate

@MainActor
@objc(SJRotationFullscreenWindowDelegate)
public protocol SJRotationFullscreenWindowDelegate: NSObjectProtocol {
    @objc(window:pointInside:withEvent:)
    func window(_ window: SJRotationFullscreenWindow, point: CGPoint, with event: UIEvent?) -> Bool
}

