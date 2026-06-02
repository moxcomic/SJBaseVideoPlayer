//
//  SJFitOnScreenManagerDefines.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/12/31.
//
//  契约层(Swift 6.3): 由原 SJFitOnScreenManagerDefines.h 转换而来。
//

import UIKit

// MARK: - 全屏(不旋转)管理协议

/// 对应原 @protocol SJFitOnScreenManager_Protocol <NSObject>。
@MainActor
@objc(SJFitOnScreenManager)
public protocol SJFitOnScreenManager_Protocol: NSObjectProtocol {
    @objc init(target: UIView, targetSuperview superview: UIView)
    @objc func getObserver() -> SJFitOnScreenManagerObserver

    @objc(isTransitioning) var transitioning: Bool { get }
    @objc var duration: TimeInterval { get set }

    /// 是否已充满屏幕。
    @objc(isFitOnScreen) var fitOnScreen: Bool { get set }
    @objc func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool)
    @objc func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool, completionHandler: ((_ mgr: SJFitOnScreenManager) -> Void)?)

    @objc var superviewInFitOnScreen: UIView { get }
}

// MARK: - 全屏(不旋转)管理观察者

/// 对应原 @protocol SJFitOnScreenManagerObserver_Protocol <NSObject>。
@MainActor
@objc(SJFitOnScreenManagerObserver)
public protocol SJFitOnScreenManagerObserver_Protocol: NSObjectProtocol {
    @objc var fitOnScreenWillBeginExeBlock: ((_ mgr: SJFitOnScreenManager) -> Void)? { get set }
    @objc var fitOnScreenDidEndExeBlock: ((_ mgr: SJFitOnScreenManager) -> Void)? { get set }
}

