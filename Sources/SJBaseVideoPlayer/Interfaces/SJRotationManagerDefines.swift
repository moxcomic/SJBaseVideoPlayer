//
//  SJRotationManagerDefines.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/9/19.
//
//  契约层(Swift 6.3): 由原 SJRotationManagerDefines.h 转换而来。
//

import UIKit

// MARK: - 视图方向

/// 对应原 NS_ENUM(NSUInteger, SJOrientation)。
/// - portrait:       竖屏
/// - landscapeLeft:  全屏, Home键在右侧
/// - landscapeRight: 全屏, Home键在左侧
@objc(SJOrientation)
public enum SJOrientation: UInt, Sendable {
    case portrait = 1       // UIDeviceOrientationPortrait
    case landscapeLeft = 3  // UIDeviceOrientationLandscapeLeft
    case landscapeRight = 4 // UIDeviceOrientationLandscapeRight
}

// MARK: - 旋转方向集合

/// 对应原 NS_OPTIONS(NSUInteger, SJOrientationMask)。
/// 说明(notes): NS_OPTIONS 在 Swift 中表达为 OptionSet, 无法直接 @objc。
/// 这里以 OptionSet 提供 Swift 原生位运算; 协议属性以 NSUInteger(rawValue) @objc 暴露,
/// 上层 ObjC 用 SJOrientationMaskPortrait 等常量(由实现块导出)进行 == / | 运算时保持等价。
public struct SJOrientationMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let portrait       = SJOrientationMask(rawValue: 1 << SJOrientation.portrait.rawValue)
    public static let landscapeLeft  = SJOrientationMask(rawValue: 1 << SJOrientation.landscapeLeft.rawValue)
    public static let landscapeRight = SJOrientationMask(rawValue: 1 << SJOrientation.landscapeRight.rawValue)
    public static let all: SJOrientationMask = [.portrait, .landscapeLeft, .landscapeRight]
}

// MARK: - 旋转管理协议

/// 对应原 @protocol SJRotationManager_Protocol<NSObject>。
/// 旋转涉及设备方向与视图转场, 实现类应在 @MainActor。
@MainActor
@objc(SJRotationManager)
public protocol SJRotationManager_Protocol: NSObjectProtocol {
    @objc func getObserver() -> SJRotationManagerObserver

    @objc var shouldTriggerRotation: ((_ mgr: SJRotationManager) -> Bool)? { get set }

    /// 是否禁止自动旋转(只禁止自动旋转, 调用 rotate 等方法仍可旋转), 默认 false。
    @objc(isDisabledAutorotation) var disabledAutorotation: Bool { get set }

    /// 自动旋转时所支持的方向(rawValue), 默认 .all。
    /// 说明(notes): SJOrientationMask 为 OptionSet 不可 @objc, 故以 UInt rawValue 暴露给 ObjC。
    @objc var autorotationSupportedOrientations: UInt { get set }

    /// 旋转(带动画)。
    @objc func rotate()

    /// 旋转到指定方向。
    @objc func rotate(_ orientation: SJOrientation, animated: Bool)

    /// 旋转到指定方向(带完成回调)。
    @objc func rotate(_ orientation: SJOrientation, animated: Bool, completionHandler: ((_ mgr: SJRotationManager) -> Void)?)

    /// 当前的方向。
    @objc var currentOrientation: SJOrientation { get }

    /// 是否全屏(landscapeRight 或 landscapeLeft 即为全屏)。
    @objc var isFullscreen: Bool { get }
    /// 是否正在旋转。
    @objc(isRotating) var rotating: Bool { get }
    /// 是否正在进行转场。
    @objc(isTransitioning) var transitioning: Bool { get }

    /// 以下属性由播放器维护。
    @objc weak var superview: UIView? { get set }
    @objc weak var target: UIView? { get set }
}

/// 对应原 @protocol SJRotationManagerProtocol <SJRotationManager>。
@MainActor
@objc(SJRotationManagerProtocol)
public protocol SJRotationManagerProtocol: SJRotationManager_Protocol {}

// MARK: - 旋转观察者

/// 对应原 @protocol SJRotationManagerObserver <NSObject>。
@objc(SJRotationManagerObserver)
@MainActor public protocol SJRotationManagerObserver: NSObjectProtocol {
    @objc var onRotatingChanged: ((_ mgr: SJRotationManager, _ isRotating: Bool) -> Void)? { get set }
    @objc var onTransitioningChanged: ((_ mgr: SJRotationManager, _ isTransitioning: Bool) -> Void)? { get set }
}

