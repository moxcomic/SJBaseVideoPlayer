//
//  SJPromptingPopupControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/7/12.
//
//  契约层(Swift 6.3): 由原 SJPromptingPopupControllerProtocol.h 转换而来。
//

import UIKit
import CoreGraphics

// MARK: - 左下角提示弹出控制协议

/// 对应原 @protocol SJPromptingPopupController_Protocol <NSObject>。
@MainActor
@objc(SJPromptingPopupController)
public protocol SJPromptingPopupController_Protocol: NSObjectProtocol {
    /// default value is UIEdgeInsetsMake(12, 22, 12, 22)
    @objc var contentInset: UIEdgeInsets { get set }
    @objc func show(_ title: NSAttributedString)
    @objc func show(_ title: NSAttributedString, duration: TimeInterval)

    @objc func showCustomView(_ view: UIView)
    @objc func showCustomView(_ view: UIView, duration: TimeInterval)
    @objc func isShowing(withCustomView view: UIView) -> Bool

    @objc func remove(_ view: UIView)
    @objc func clear()
    /// default value is 16
    @objc var leftMargin: CGFloat { get set }
    /// default value is 16
    @objc var bottomMargin: CGFloat { get set }
    /// default value is 12
    @objc var itemSpacing: CGFloat { get set }

    @objc var displayingViews: [UIView]? { get }

    @objc var automaticallyAdjustsLeftInset: Bool { get set }
    @objc var automaticallyAdjustsBottomInset: Bool { get set }

    /// 以下属性由播放器维护。
    @objc weak var target: UIView? { get set }
}

