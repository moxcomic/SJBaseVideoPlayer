//
//  SJBaseVideoPlayer+VideoFlipTransition.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (VideoFlipTransition)。镜像翻转。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 镜像翻转(null_resettable)
    ///
    ///         如果需要水平镜像翻转, 可以 player.flipTransitionManager.flipTransition = .horizontally;
    ///         了解更多请前往协议头文件查看
    ///
    @objc public var flipTransitionManager: any SJFlipTransitionManager_Protocol {
        get {
            if let manager = _flipTransitionManager { return manager }
            let manager = SJFlipTransitionManager(target: playbackController.playerView)
            _flipTransitionManager = manager
            return manager
        }
        set {
            _flipTransitionManager = newValue
        }
    }

    ///
    /// 观察者
    ///
    ///         可以如下设置block, 来监听某个状态的改变
    ///
    ///         player.flipTransitionObserver.flipTransitionDidStartExeBlock = ...;
    ///         player.flipTransitionObserver.flipTransitionDidStopExeBlock = ...;
    ///
    @objc public var flipTransitionObserver: any SJFlipTransitionManagerObserver_Protocol {
        if let observer = _flipTransitionObserver { return observer }
        let observer = flipTransitionManager.getObserver()
        _flipTransitionObserver = observer
        return observer
    }
}

