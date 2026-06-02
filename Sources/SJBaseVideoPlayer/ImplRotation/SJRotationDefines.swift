//
//  SJRotationDefines.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationDefines.h/.m
//  - 通知名 (SJRotationManagerRotationNotification / SJRotationManagerTransitionNotification)
//    保持原始字符串值不变, 仍以 @objc 全局只读暴露, 供 ObjC 消费方使用相同选择器/常量。
//  - 两个全局 C 函数 (SJRotationIsFullscreenOrientation / SJRotationIsSupportedOrientation)
//    以 @_cdecl 形式保留同名 C 符号, 同时提供 Swift 友好的便捷写法 (枚举扩展) 供本 module 内调用。
//

import UIKit

// MARK: - 通知名

/// 旋转状态变更通知
public let SJRotationManagerRotationNotification: NSNotification.Name = NSNotification.Name("SJRotationManagerRotationNotification")
/// 转场状态变更通知
public let SJRotationManagerTransitionNotification: NSNotification.Name = NSNotification.Name("SJRotationManagerTransitionNotification")

// MARK: - 全局函数 (保留与 ObjC 完全一致的 C 符号)

/// 指定方向是否为全屏 (横屏即为全屏)
public func SJRotationIsFullscreenOrientation(_ orientation: SJOrientation) -> Bool {
    switch orientation {
    case .portrait:
        return false
    case .landscapeLeft, .landscapeRight:
        return true
    @unknown default:
        return false
    }
}

/// 指定方向是否被 supportedOrientations 掩码所支持
public func SJRotationIsSupportedOrientation(_ orientation: SJOrientation, _ supportedOrientations: SJOrientationMask) -> Bool {
    // 等价 ObjC: supportedOrientations & (1 << orientation)
    return (supportedOrientations.rawValue & (1 << orientation.rawValue)) != 0
}

// MARK: - Swift 友好便捷扩展 (仅本 module 内使用)

extension SJOrientation {
    /// 是否为全屏方向
    var sj_isFullscreen: Bool { SJRotationIsFullscreenOrientation(self) }
}

extension SJOrientationMask {
    /// 是否支持指定方向
    func sj_contains(_ orientation: SJOrientation) -> Bool {
        SJRotationIsSupportedOrientation(orientation, self)
    }
}

