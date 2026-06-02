//
//  SJDeviceVolumeAndBrightnessControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/1/5.
//
//  契约层(Swift 6.3): 由原 SJDeviceVolumeAndBrightnessControllerProtocol.h 转换而来。
//

import UIKit

// MARK: - 设备音量/亮度控制协议

/// 对应原 @protocol SJDeviceVolumeAndBrightnessController_Protocol <NSObject>。
@MainActor
@objc(SJDeviceVolumeAndBrightnessController)
public protocol SJDeviceVolumeAndBrightnessController_Protocol: NSObjectProtocol {
    @objc func getObserver() -> SJDeviceVolumeAndBrightnessControllerObserver
    /// device volume
    @objc var volume: Float { get set }
    /// device brightness
    @objc var brightness: Float { get set }

    /// 以下属性由播放器自动维护。
    @objc weak var target: UIView? { get set }
    @objc var targetViewContext: SJDeviceVolumeAndBrightnessTargetViewContext? { get set }

    @objc func onTargetViewMoveToWindow()
    @objc func onTargetViewContextUpdated()
}

// MARK: - TargetView 当前环境

/// 对应原 @protocol SJDeviceVolumeAndBrightnessTargetViewContext_Protocol <NSObject>。
@objc(SJDeviceVolumeAndBrightnessTargetViewContext)
@MainActor public protocol SJDeviceVolumeAndBrightnessTargetViewContext_Protocol: NSObjectProtocol {
    @objc var isFullscreen: Bool { get }
    @objc var isFitOnScreen: Bool { get }
    @objc var isPlayOnScrollView: Bool { get }
    @objc var isScrollAppeared: Bool { get }
    /// 小窗口悬浮模式
    @objc var isFloatingMode: Bool { get }
    /// 画中画模式
    @objc var isPictureInPictureMode: Bool { get }
}

// MARK: - 设备音量/亮度控制观察者

/// 对应原 @protocol SJDeviceVolumeAndBrightnessControllerObserver。
@MainActor
@objc(SJDeviceVolumeAndBrightnessControllerObserver)
public protocol SJDeviceVolumeAndBrightnessControllerObserver: NSObjectProtocol {
    @objc var volumeDidChangeExeBlock: ((_ mgr: SJDeviceVolumeAndBrightnessController, _ volume: Float) -> Void)? { get set }
    @objc var brightnessDidChangeExeBlock: ((_ mgr: SJDeviceVolumeAndBrightnessController, _ brightness: Float) -> Void)? { get set }
}

