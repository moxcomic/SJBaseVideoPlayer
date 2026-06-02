//
//  SJTextPopupControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/9/15.
//
//  契约层(Swift 6.3): 由原 SJTextPopupControllerDefines.h 转换而来。
//

import UIKit
import CoreGraphics

// MARK: - 中心文本提示弹出控制协议

/// 对应原 @protocol SJTextPopupController_Protocol <NSObject>。
@MainActor
@objc(SJTextPopupController)
public protocol SJTextPopupController_Protocol: NSObjectProtocol {
    @objc func show(_ title: NSAttributedString)
    @objc func show(_ title: NSAttributedString, duration: TimeInterval)
    @objc func show(_ title: NSAttributedString, duration: TimeInterval, completionHandler: (() -> Void)?)
    @objc func hidden()

    /// default value is UIEdgeInsetsMake(12, 22, 12, 22)
    @objc var contentInset: UIEdgeInsets { get set }
    /// default value is 8.0
    @objc var cornerRadius: CGFloat { get set }
    /// default value is blackColor
    @objc var backgroundColor: UIColor? { get set }
    /// default value is ( target.width * 0.6 )
    @objc var maxLayoutWidth: CGFloat { get set }

    /// 以下属性由播放器维护。
    @objc weak var target: UIView? { get set }
}

