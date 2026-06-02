//
//  SJBaseVideoPlayer+FitOnScreen.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (FitOnScreen)。
//  竖屏小屏 到 竖屏全屏(全屏或小屏, 不会触发旋转)。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 使播放器充满屏幕并且禁止旋转(null_resettable)
    ///
    ///         充满屏幕后, 播放器将无法触发旋转
    ///         了解更多请前往头文件查看
    ///
    @objc public var fitOnScreenManager: any SJFitOnScreenManager_Protocol {
        get {
            if _fitOnScreenManager == nil {
                _setupFitOnScreenManager(SJFitOnScreenManager(target: presentView, targetSuperview: view))
            }
            return _fitOnScreenManager!
        }
        set {
            _setupFitOnScreenManager(newValue)
        }
    }

    ///
    /// 观察者
    ///
    @objc public var fitOnScreenObserver: any SJFitOnScreenManagerObserver_Protocol {
        if let observer = _fitOnScreenObserver { return observer }
        let observer = fitOnScreenManager.getObserver()
        _fitOnScreenObserver = observer
        return observer
    }

    ///
    /// 是否仅在竖屏全屏与竖屏小屏之间切换, 不触发旋转.
    ///
    ///     注意: 开启后, 旋转功能将会失效.
    ///
    @objc public var onlyFitOnScreen: Bool {
        get { _onlyFitOnScreen }
        set {
            _onlyFitOnScreen = newValue
            if newValue {
                _clearRotationManager()
            } else {
                _ = rotationManager
            }
        }
    }

    ///
    /// Whether fullscreen or smallscreen, this method does not trigger rotation.
    /// 全屏或小屏, 此方法不触发旋转. Animated
    ///
    @objc(isFitOnScreen) public var fitOnScreen: Bool {
        get { fitOnScreenManager.fitOnScreen }
        set { setFitOnScreen(newValue, animated: true) }
    }

    /// Whether fullscreen or smallscreen, this method does not trigger rotation.
    /// 全屏或小屏, 此方法不触发旋转
    /// - animated : 是否动画
    @objc(setFitOnScreen:animated:) public func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool) {
        setFitOnScreen(fitOnScreen, animated: animated, completionHandler: nil)
    }

    /// Whether fullscreen or smallscreen, this method does not trigger rotation.
    /// 全屏或小屏, 此方法不触发旋转
    /// - animated : 是否动画
    /// - completionHandler : 操作完成的回调
    @objc(setFitOnScreen:animated:completionHandler:) public func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool, completionHandler: ((SJBaseVideoPlayer) -> Void)?) {
        assert(!isFullscreen, "横屏全屏状态下, 无法执行竖屏全屏!")

        fitOnScreenManager.setFitOnScreen(fitOnScreen, animated: animated) { [weak self] _ in
            guard let self = self else { return }
            completionHandler?(self)
        }
    }
}

