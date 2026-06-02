//
//  SJBaseVideoPlayer+Rotation.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Rotation)。
//  竖屏小屏旋转到横屏全屏(会触发旋转)。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 旋转管理类(nullable)
    ///
    ///     如果需要禁止自动旋转, 可以设置 `player.rotationManager.disabledAutorotation = true;`
    ///     了解更多请前往头文件查看。
    ///
    @objc public var rotationManager: (any SJRotationManager_Protocol)? {
        get {
            // 对应 ObjC: _rotationManager == nil && !self.onlyFitOnScreen 时惰性创建默认管理器
            if _rotationManager == nil && !onlyFitOnScreen {
                let defaultManager = SJRotationManager.rotationManager()
                defaultManager.actionForwarder = viewControllerManager
                _setupRotationManager(defaultManager)
            }
            return _rotationManager
        }
        set {
            _setupRotationManager(newValue)
        }
    }

    ///
    /// 观察者
    ///
    ///     当需要监听旋转时, 可以设置 `player.rotationObserver.onRotatingChanged = ...;`
    ///     了解更多请前往头文件查看。
    ///
    /// 对应 ObjC: 关联对象惰性存储 `[self.rotationManager getObserver]`。
    ///
    @objc public var rotationObserver: any SJRotationManagerObserver {
        if let observer = _rotationObserver { return observer }
        let observer = rotationManager!.getObserver()
        _rotationObserver = observer
        return observer
    }

    ///
    /// 是否可以触发旋转
    ///
    ///     这个 block 的返回值将会作为触发旋转的一个条件, 当 `return false` 时, 将不会触发旋转。
    ///
    @objc public var shouldTriggerRotation: ((SJBaseVideoPlayer) -> Bool)? {
        get { _shouldTriggerRotation }
        set { _shouldTriggerRotation = newValue }
    }

    /// 竖屏全屏后, 是否允许旋转。
    ///
    ///     默认为 false.
    ///
    ///     竖屏全屏的状态下(`player.isFitOnScreen == true`), 如果想继续触发旋转,
    ///     请设置 `allowsRotationInFitOnScreen` 为 true 即可.
    ///
    @objc public var allowsRotationInFitOnScreen: Bool {
        get { _allowsRotationInFitOnScreen }
        set { _allowsRotationInFitOnScreen = newValue }
    }

    /// 自动旋转(带动画)。
    @objc(rotate) public func rotate() {
        rotationManager?.rotate()
    }

    /// 旋转到指定方向。
    ///
    /// - Parameters:
    ///   - orientation: SJOrientation 的任意值。
    ///   - animated:    传入 true 以动画方式旋转; 否则传入 false。
    @objc(rotate:animated:) public func rotate(_ orientation: SJOrientation, animated: Bool) {
        rotationManager?.rotate(orientation, animated: animated)
    }

    /// 旋转到指定方向(带完成回调)。
    ///
    /// - Parameters:
    ///   - orientation: SJOrientation 的任意值。
    ///   - animated:    传入 true 以动画方式旋转; 否则传入 false。
    ///   - block:       旋转完成后回调。
    @objc(rotate:animated:completion:)
    public func rotate(_ orientation: SJOrientation, animated: Bool, completion block: ((SJBaseVideoPlayer) -> Void)?) {
        rotationManager?.rotate(orientation, animated: animated) { [weak self] _ in
            guard let self = self else { return }
            block?(self)
        }
    }

    /// 是否在旋转中。
    @objc public var isRotating: Bool {
        return _rotationManager?.rotating ?? false
    }

    /// 是否已全屏。
    @objc public var isFullscreen: Bool {
        return _rotationManager?.isFullscreen ?? false
    }

    /// 当前的方向。
    ///
    /// 对应 ObjC: `(NSInteger)_rotationManager.currentOrientation`(直接读 ivar, 不惰性创建)。
    /// 当 `_rotationManager == nil` 时, ObjC 对 nil 取属性得 0, 等价于 rawValue 为 0 的方向(.unknown)。
    @objc public var currentOrientation: UIInterfaceOrientation {
        guard let mgr = _rotationManager else { return .unknown }
        return UIInterfaceOrientation(rawValue: Int(mgr.currentOrientation.rawValue)) ?? .unknown
    }

    /// 是否锁屏。
    @objc(isLockedScreen) public var lockedScreen: Bool {
        get { _isLockedScreen }
        set {
            if newValue != _isLockedScreen {
                viewControllerManager.lockedScreen = newValue
                _isLockedScreen = newValue

                if newValue {
                    controlLayerDelegate?.lockedVideoPlayer?(self)
                } else {
                    controlLayerDelegate?.unlockedVideoPlayer?(self)
                }

                _postNotification(SJVideoPlayerScreenLockStateDidChangeNotification)
            }
        }
    }
}

