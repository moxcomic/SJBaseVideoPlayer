//
//  SJDeviceVolumeAndBrightnessTargetViewContext.swift
//  SJBaseVideoPlayer
//
//  Created by 蓝舞者 on 2022/11/2.
//
//  Swift 6.3 移植 (等价于原 ObjC 版 SJDeviceVolumeAndBrightnessTargetViewContext.h/.m)
//

import UIKit

/// TargetView 当前环境的具体载体 (可读写 struct-like 类)。
///
/// 实现 `SJDeviceVolumeAndBrightnessTargetViewContext` 协议 (协议在 Interfaces 块定义,
/// 其属性为 readonly; 本类对外提供可写存储, 由播放器自动维护)。
@MainActor
@objc(SJDeviceVolumeAndBrightnessTargetViewContext)
public final class SJDeviceVolumeAndBrightnessTargetViewContext: NSObject, SJDeviceVolumeAndBrightnessTargetViewContext_Protocol {
    @objc public var isFullscreen: Bool = false
    @objc public var isFitOnScreen: Bool = false
    @objc public var isPlayOnScrollView: Bool = false
    @objc public var isScrollAppeared: Bool = false
    /// 是否进入了小浮窗模式
    @objc public var isFloatingMode: Bool = false
    /// 画中画模式
    @objc public var isPictureInPictureMode: Bool = false

    @objc public override init() {
        super.init()
    }
}

