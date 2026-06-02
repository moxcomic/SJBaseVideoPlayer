//
//  SJPictureInPictureControllerDefines.swift
//  Pods
//
//  Created by BlueDancer on 2020/9/26.
//
//  契约层(Swift 6.3): 由原 SJPictureInPictureControllerDefines.h 转换而来。
//

import Foundation

// MARK: - 画中画状态

/// 对应原 NS_ENUM(NSUInteger, SJPictureInPictureStatus) API_AVAILABLE(ios(14.0))。
@objc(SJPictureInPictureStatus)
public enum SJPictureInPictureStatus: UInt, Sendable {
    case unknown
    /// 启动中
    case starting
    /// 启动完毕, 运行中
    case running
    /// 正在停止
    case stopping
    /// 停止画中画
    case stopped
}

// MARK: - 画中画控制协议

/// 对应原 @protocol SJPictureInPictureController <NSObject> API_AVAILABLE(ios(14.0))。
@available(iOS 14.0, *)
@MainActor
@objc(SJPictureInPictureController)
public protocol SJPictureInPictureController: NSObjectProtocol {
    @objc static func isPictureInPictureSupported() -> Bool

    @objc var requiresLinearPlayback: Bool { get set }
    @available(iOS 14.2, *)
    @objc var canStartPictureInPictureAutomaticallyFromInline: Bool { get set }
    @objc weak var delegate: SJPictureInPictureControllerDelegate? { get set }
    @objc var status: SJPictureInPictureStatus { get }
    @objc func startPictureInPicture()
    @objc func stopPictureInPicture()
}

// MARK: - 画中画控制代理

/// 对应原 @protocol SJPictureInPictureControllerDelegate <NSObject> API_AVAILABLE(ios(14.0))。
@available(iOS 14.0, *)
@MainActor
@objc(SJPictureInPictureControllerDelegate)
public protocol SJPictureInPictureControllerDelegate: NSObjectProtocol {
    @objc func pictureInPictureController(_ controller: SJPictureInPictureController, statusDidChange status: SJPictureInPictureStatus)

    @objc func pictureInPictureController(_ controller: SJPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (_ restored: Bool) -> Void)
}

