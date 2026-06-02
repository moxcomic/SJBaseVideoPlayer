//
//  SJFlipTransitionManager.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名.
//

import Foundation
import UIKit
import QuartzCore

/// 翻转转场状态改变通知 (内部使用, 名称与 ObjC 版严格一致)
private let SJFlipTransitionManagerTransitioningValueDidChangeNotification = Notification.Name("SJFlipTransitionManagerTransitioningValueDidChange")

// MARK: - Observer

@objc(SJFlipTransitionManagerObserver)
public final class SJFlipTransitionManagerObserver: NSObject, SJFlipTransitionManagerObserver_Protocol {
    @objc public var flipTransitionDidStartExeBlock: ((SJFlipTransitionManager) -> Void)?
    @objc public var flipTransitionDidStopExeBlock: ((SJFlipTransitionManager) -> Void)?

    @objc public init(manager mgr: SJFlipTransitionManager) {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(transitioningValueDidChange(_:)), name: SJFlipTransitionManagerTransitioningValueDidChangeNotification, object: mgr)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func transitioningValueDidChange(_ note: Notification) {
        guard let mgr = note.object as? SJFlipTransitionManager else { return }
        if mgr.transitioning {
            flipTransitionDidStartExeBlock?(mgr)
        } else {
            flipTransitionDidStopExeBlock?(mgr)
        }
    }
}

// MARK: - Manager

@MainActor
@objc(SJFlipTransitionManager)
public final class SJFlipTransitionManager: NSObject, SJFlipTransitionManager_Protocol, CAAnimationDelegate {

    private var innerFlipTransition: SJViewFlipTransition = .identity
    private var _transitioning: Bool = false
    private var _completionHandler: ((SJFlipTransitionManager) -> Void)?

    @objc public var target: UIView?
    @objc public var duration: TimeInterval = 1.0

    @objc public init(target: UIView) {
        self.target = target
        super.init()
    }

    @objc public func getObserver() -> SJFlipTransitionManagerObserver {
        return SJFlipTransitionManagerObserver(manager: self)
    }

    @objc(isTransitioning) public private(set) var transitioning: Bool {
        get { _transitioning }
        set {
            _transitioning = newValue
            NotificationCenter.default.post(name: SJFlipTransitionManagerTransitioningValueDidChangeNotification, object: self)
        }
    }

    @objc public var flipTransition: SJViewFlipTransition {
        get { innerFlipTransition }
        set { setFlipTransition(newValue, animated: true) }
    }

    @objc public func setFlipTransition(_ t: SJViewFlipTransition, animated: Bool) {
        setFlipTransition(t, animated: animated, completionHandler: nil)
    }

    @objc public func setFlipTransition(_ t: SJViewFlipTransition, animated: Bool, completionHandler: ((SJFlipTransitionManager) -> Void)?) {
        if t == innerFlipTransition { return }
        if transitioning { return }

        innerFlipTransition = t
        transitioning = true

        var transform = CATransform3DIdentity
        switch t {
        case .identity:
            transform = CATransform3DIdentity
        case .horizontally:
            transform = CATransform3DConcat(CATransform3DMakeRotation(.pi, 0, 1, 0), CATransform3DMakeTranslation(0, 0, -10000))
        @unknown default:
            transform = CATransform3DIdentity
        }

        let rotationAnimation = CABasicAnimation(keyPath: "transform")
        if let layer = target?.layer {
            rotationAnimation.fromValue = NSValue(caTransform3D: layer.transform)
        }
        rotationAnimation.toValue = NSValue(caTransform3D: transform)
        rotationAnimation.duration = duration
        rotationAnimation.isCumulative = true
        rotationAnimation.delegate = self
        target?.layer.add(rotationAnimation, forKey: nil)
        target?.layer.transform = transform
        _completionHandler = completionHandler
    }

    // MARK: CAAnimationDelegate

    // 系统协议 CAAnimationDelegate 要求 nonisolated; 在 @MainActor 类里用 nonisolated + assumeIsolated 闭环。
    nonisolated public func animationDidStart(_ anim: CAAnimation) { }

    nonisolated public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        MainActor.assumeIsolated {
            transitioning = false
            if let handler = _completionHandler {
                handler(self)
                _completionHandler = nil
            }
        }
    }
}

