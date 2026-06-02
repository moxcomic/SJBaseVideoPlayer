//
//  SJFlipTransitionManagerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2018/12/31.
//
//  契约层(Swift 6.3): 由原 SJFlipTransitionManagerDefines.h 转换而来。
//

import UIKit

// MARK: - 翻转类型

/// 对应原 NS_ENUM(NSUInteger, SJViewFlipTransition)。
@objc(SJViewFlipTransition)
public enum SJViewFlipTransition: UInt, Sendable {
    case identity
    /// 水平翻转
    case horizontally
}

// MARK: - 翻转转场管理协议

/// 对应原 @protocol SJFlipTransitionManager_Protocol <NSObject>。
@MainActor
@objc(SJFlipTransitionManager)
public protocol SJFlipTransitionManager_Protocol: NSObjectProtocol {
    @objc init(target: UIView)
    @objc func getObserver() -> SJFlipTransitionManagerObserver

    @objc(isTransitioning) var transitioning: Bool { get }
    @objc var duration: TimeInterval { get set }

    @objc var flipTransition: SJViewFlipTransition { get set }
    @objc func setFlipTransition(_ t: SJViewFlipTransition, animated: Bool)
    @objc func setFlipTransition(_ t: SJViewFlipTransition, animated: Bool, completionHandler: ((_ mgr: SJFlipTransitionManager) -> Void)?)

    @objc weak var target: UIView? { get set }
}

// MARK: - 翻转转场管理观察者

/// 对应原 @protocol SJFlipTransitionManagerObserver_Protocol <NSObject>。
@MainActor
@objc(SJFlipTransitionManagerObserver)
public protocol SJFlipTransitionManagerObserver_Protocol: NSObjectProtocol {
    @objc var flipTransitionDidStartExeBlock: ((_ mgr: SJFlipTransitionManager) -> Void)? { get set }
    @objc var flipTransitionDidStopExeBlock: ((_ mgr: SJFlipTransitionManager) -> Void)? { get set }
}

