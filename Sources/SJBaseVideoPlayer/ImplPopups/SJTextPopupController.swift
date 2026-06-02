//
//  SJTextPopupController.swift
//  SJTextPopupControllerProject
//
//  Created by 畅三江 on 2017/9/26.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  由 ObjC 版 SJTextPopupController.h/.m 转换而来 (Swift 6.3)。
//  Masonry -> SnapKit。
//

import Foundation
import UIKit
import SnapKit

///
/// 居中文本提示弹层控制器。
///
/// 遵循 `SJTextPopupController` 协议(定义在接口块)。UIKit 操作, @MainActor。
///
@MainActor
public final class SJTextPopupController: NSObject, SJTextPopupController_Protocol {

    // MARK: 私有视图
    private lazy var contentView: UIView = {
        let v = UIView(frame: .zero)
        // SJPlayerZIndexes 由 Const 块提供 (同 module)
        v.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.textPopupViewZIndex)
        return v
    }()

    private lazy var label: UILabel = {
        let l = UILabel(frame: .zero)
        l.numberOfLines = 0
        return l
    }()

    private var completionHandler: (() -> Void)?

    // MARK: 协议属性

    /// 内边距 (default value is UIEdgeInsetsMake(12, 22, 12, 22))
    public var contentInset: UIEdgeInsets = UIEdgeInsets(top: 12, left: 22, bottom: 12, right: 22)

    /// 圆角半径 (default value is 8.0)
    public var cornerRadius: CGFloat {
        get { contentView.layer.cornerRadius }
        set { contentView.layer.cornerRadius = newValue }
    }

    /// 背景色 (default value is blackColor)
    public var backgroundColor: UIColor? {
        get { contentView.backgroundColor }
        set { contentView.backgroundColor = newValue }
    }

    /// 最大布局宽度 (default value is target.width * 0.6)
    public var maxLayoutWidth: CGFloat = 0

    /// 目标视图 (由播放器维护)
    public weak var target: UIView?

    // MARK: 初始化

    public override init() {
        super.init()
        self.contentInset = UIEdgeInsets(top: 12, left: 22, bottom: 12, right: 22)
        self.backgroundColor = UIColor.black
        self.cornerRadius = 8
    }

    // MARK: 协议方法

    public func show(_ title: NSAttributedString) {
        show(title, duration: 1)
    }

    public func show(_ title: NSAttributedString, duration: TimeInterval) {
        show(title, duration: duration, completionHandler: nil)
    }

    public func show(_ title: NSAttributedString, duration: TimeInterval, completionHandler: (() -> Void)?) {
        if title.length == 0 { return }
        DispatchQueue.main.async {
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            self.contentView.backgroundColor = self.backgroundColor
            self.contentView.layer.cornerRadius = self.cornerRadius
            self.label.attributedText = title
            self.completionHandler = completionHandler

            guard let target = self.target else { return }
            let bounds = target.bounds
            if self.contentView.superview != target {
                target.addSubview(self.contentView)
                self.contentView.center = CGPoint(x: bounds.width * 0.5, y: bounds.height * 0.5)
                self.contentView.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                }
            }

            if self.label.superview == nil {
                self.contentView.addSubview(self.label)
            }

            self.label.preferredMaxLayoutWidth = self.maxLayoutWidth != 0 ? self.maxLayoutWidth : bounds.width * 0.6
            self.label.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(self.contentInset.top)
                make.left.equalToSuperview().offset(self.contentInset.left)
                make.bottom.equalToSuperview().offset(-self.contentInset.bottom)
                make.right.equalToSuperview().offset(-self.contentInset.right)
            }

            UIView.animate(withDuration: 0.25) {
                self.contentView.alpha = 1
            }

            if duration != -1 {
                self.perform(#selector(self.hidden), with: nil, afterDelay: duration)
            }
        }
    }

    @objc public func hidden() {
        DispatchQueue.main.async {
            NSObject.cancelPreviousPerformRequests(withTarget: self)
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.alpha = 0.001
            }, completion: { _ in
                if let handler = self.completionHandler {
                    handler()
                    self.completionHandler = nil
                }
            })
        }
    }
}

