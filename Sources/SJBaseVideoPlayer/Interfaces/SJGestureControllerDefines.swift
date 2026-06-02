//
//  SJGestureControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/1/3.
//
//  契约层(Swift 6.3): 由原 SJGestureControllerDefines.h 转换而来。
//

import UIKit
import CoreGraphics

// MARK: - 手势类型

/// 对应原 NS_ENUM(NSUInteger, SJPlayerGestureType)。
@objc(SJPlayerGestureType)
public enum SJPlayerGestureType: UInt, Sendable {
    /// 单击手势
    case singleTap
    /// 双击手势
    case doubleTap
    /// 移动手势
    case pan
    /// 捏合手势
    case pinch
    /// 长按手势
    case longPress
}

// MARK: - 手势类型集合

/// 对应原 NS_OPTIONS(NSUInteger, SJPlayerGestureTypeMask)。
/// 说明(notes): OptionSet 不可 @objc, Swift 侧原生使用; 协议属性以 UInt rawValue 暴露给 ObjC,
/// 与上层 SJPlayerGestureTypeMask_None / _SingleTap 等常量(由实现块导出)位运算等价。
public struct SJPlayerGestureTypeMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let none      = SJPlayerGestureTypeMask([])
    public static let singleTap = SJPlayerGestureTypeMask(rawValue: 1 << SJPlayerGestureType.singleTap.rawValue)
    public static let doubleTap = SJPlayerGestureTypeMask(rawValue: 1 << SJPlayerGestureType.doubleTap.rawValue)
    public static let pan_H     = SJPlayerGestureTypeMask(rawValue: 0x100) // 水平方向
    public static let pan_V     = SJPlayerGestureTypeMask(rawValue: 0x200) // 垂直方向
    public static let pan: SJPlayerGestureTypeMask = [.pan_H, .pan_V]
    public static let pinch     = SJPlayerGestureTypeMask(rawValue: 1 << SJPlayerGestureType.pinch.rawValue)
    public static let longPress = SJPlayerGestureTypeMask(rawValue: 1 << SJPlayerGestureType.longPress.rawValue)

    public static let `default`: SJPlayerGestureTypeMask = [.singleTap, .doubleTap, .pan, .pinch]
    public static let all: SJPlayerGestureTypeMask = [.default, .longPress]
}

// MARK: - 移动方向

/// 对应原 NS_ENUM(NSUInteger, SJPanGestureMovingDirection)。
@objc(SJPanGestureMovingDirection)
public enum SJPanGestureMovingDirection: UInt, Sendable {
    case H
    case V
}

// MARK: - 移动手势触发位置

/// 对应原 NS_ENUM(NSUInteger, SJPanGestureTriggeredPosition)。
@objc(SJPanGestureTriggeredPosition)
public enum SJPanGestureTriggeredPosition: UInt, Sendable {
    case left
    case right
}

// MARK: - 移动手势状态

/// 对应原 NS_ENUM(NSUInteger, SJPanGestureRecognizerState)。
@objc(SJPanGestureRecognizerState)
public enum SJPanGestureRecognizerState: UInt, Sendable {
    case began
    case changed
    case ended
}

// MARK: - 长按手势状态

/// 对应原 NS_ENUM(NSUInteger, SJLongPressGestureRecognizerState)。
@objc(SJLongPressGestureRecognizerState)
public enum SJLongPressGestureRecognizerState: UInt, Sendable {
    case began
    case changed
    case ended
}

// MARK: - 手势控制协议

/// 对应原 @protocol SJGestureController <NSObject>。
@MainActor
@objc(SJGestureController)
public protocol SJGestureController: NSObjectProtocol {
    /// 支持的手势类型(rawValue), 默认 .Default。
    /// 说明(notes): SJPlayerGestureTypeMask 为 OptionSet 不可 @objc, 以 UInt rawValue 暴露给 ObjC。
    @objc var supportedGestureTypes: UInt { get set }

    @objc var gestureRecognizerShouldTrigger: ((_ control: SJGestureController, _ type: SJPlayerGestureType, _ location: CGPoint) -> Bool)? { get set }
    @objc var singleTapHandler: ((_ control: SJGestureController, _ location: CGPoint) -> Void)? { get set }
    @objc var doubleTapHandler: ((_ control: SJGestureController, _ location: CGPoint) -> Void)? { get set }
    @objc var panHandler: ((_ control: SJGestureController, _ position: SJPanGestureTriggeredPosition, _ direction: SJPanGestureMovingDirection, _ state: SJPanGestureRecognizerState, _ translate: CGPoint) -> Void)? { get set }
    @objc var pinchHandler: ((_ control: SJGestureController, _ scale: CGFloat) -> Void)? { get set }
    @objc var longPressHandler: ((_ control: SJGestureController, _ state: SJLongPressGestureRecognizerState) -> Void)? { get set }

    @objc func cancelGesture(_ type: SJPlayerGestureType)
    @objc func stateOfGesture(_ type: SJPlayerGestureType) -> UIGestureRecognizer.State

    @objc var movingDirection: SJPanGestureMovingDirection { get }
    @objc var triggeredPosition: SJPanGestureTriggeredPosition { get }
}

