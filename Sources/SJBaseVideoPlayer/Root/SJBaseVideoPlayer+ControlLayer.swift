//
//  SJBaseVideoPlayer+ControlLayer.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (ControlLayer)。播放器控制层 显示/隐藏 控制。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    /// 控制层需要显示
    ///
    /// When you want to appear the control layer, you should call this method to appear.
    /// This method will call the control layer delegate method.
    @objc public func controlLayerNeedAppear() {
        controlLayerAppearManager.needAppear()
    }

    /// 控制层需要隐藏
    ///
    /// When you want to disappear the control layer, you should call this method to disappear.
    /// This method will call the control layer delegate method.
    @objc public func controlLayerNeedDisappear() {
        controlLayerAppearManager.needDisappear()
    }

    ///
    /// 对控制层显示/隐藏的控制(null_resettable)
    ///
    ///         仅仅对控制层的显示和隐藏做控制(如控制层显示后, 一段时间该管理类将尝试隐藏控制层)
    ///         其他操作由开发者自己处理, 当不需要该管理类时, 可以禁用
    ///         `player.controlLayerAppearManager.disabled = YES;`
    ///
    @objc public var controlLayerAppearManager: any SJControlLayerAppearManager {
        get {
            if _controlLayerAppearManager == nil {
                _setupControlLayerAppearManager(SJControlLayerAppearStateManager())
            }
            return _controlLayerAppearManager!
        }
        set {
            _setupControlLayerAppearManager(newValue)
        }
    }

    ///
    /// 观察者
    ///
    ///         当需要监听控制层的显示和隐藏时, 可以设置
    ///         `player.controlLayerAppearObserver.onAppearChanged = ...;`
    ///
    @objc public var controlLayerAppearObserver: any SJControlLayerAppearManagerObserver_Protocol {
        if let observer = _controlLayerAppearObserver { return observer }
        let observer = controlLayerAppearManager.getObserver()
        _controlLayerAppearObserver = observer
        return observer
    }

    ///
    /// 控制层的显示状态(是否已显示)
    ///
    @objc(isControlLayerAppeared) public var controlLayerAppeared: Bool {
        get { controlLayerAppearManager.isAppeared }
        set {
            newValue ? controlLayerAppearManager.needAppear() :
                       controlLayerAppearManager.needDisappear()
        }
    }

    ///
    /// 控制层是否可以隐藏
    ///
    ///         这个 block 的返回值将会作为触发隐藏控制层的一个条件, 当 `return NO` 时, 将不会触发隐藏控制层
    ///
    @objc public var canAutomaticallyDisappear: ((SJBaseVideoPlayer) -> Bool)? {
        get { _canAutomaticallyDisappear }
        set { _canAutomaticallyDisappear = newValue }
    }

    ///
    /// 暂停的时候是否保持控制层显示. default value is NO
    ///
    @objc public var pausedToKeepAppearState: Bool {
        get { controlInfo.controlLayer.pausedToKeepAppearState }
        set { controlInfo.controlLayer.pausedToKeepAppearState = newValue }
    }
}

