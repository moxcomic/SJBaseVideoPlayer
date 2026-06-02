//
//  SJBaseVideoPlayer+ScrollView.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (ScrollView)。
//  在`tableView`或`collectionView`上播放(列表滚动播放)。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    /// 刷新显示
    ///
    /// 该方法针对的场景是: 在 CollectionView 或 TableView 调用 reloadData 时, cell 被重新创建后
    /// 播放器会被移除, 调用此方法可以刷新以让播放器显示.
    @objc public func refreshAppearStateForPlayerView() {
        playModelObserver?.refreshAppearState()
    }

    ///
    /// 小浮窗控制(null_resettable). 默认不启用。
    ///
    /// 当需要开启时, 请设置 `player.smallViewFloatingController.enabled = true;`
    ///
    @objc public var smallViewFloatingController: any SJSmallViewFloatingController_Protocol {
        get {
            if _smallViewFloatingController == nil {
                let controller = SJSmallViewFloatingController()
                controller.floatingViewShouldAppear = { [weak self] _ in
                    guard let self = self else { return false }
                    return self.timeControlStatus != .paused && self.assetStatus != .unknown
                }
                _setupSmallViewFloatingController(controller)
            }
            return _smallViewFloatingController!
        }
        set {
            _setupSmallViewFloatingController(newValue)
        }
    }

    ///
    /// 当开启小浮窗控制时, 播放结束后, 会默认隐藏小浮窗. default value is YES.
    ///
    @objc(isHiddenFloatSmallViewWhenPlaybackFinished) public var hiddenFloatSmallViewWhenPlaybackFinished: Bool {
        get { controlInfo.floatSmallViewControl.hiddenFloatSmallViewWhenPlaybackFinished }
        set { controlInfo.floatSmallViewControl.hiddenFloatSmallViewWhenPlaybackFinished = newValue }
    }

    ///
    /// 滚动出去后, 是否暂停. 默认为YES
    ///
    @objc public var pausedWhenScrollDisappeared: Bool {
        get { controlInfo.scrollControl.pausedWhenScrollDisappeared }
        set { controlInfo.scrollControl.pausedWhenScrollDisappeared = newValue }
    }

    ///
    /// 滚动进入时, 是否恢复播放. 默认为YES
    ///
    @objc public var resumePlaybackWhenScrollAppeared: Bool {
        get { controlInfo.scrollControl.resumePlaybackWhenScrollAppeared }
        set { controlInfo.scrollControl.resumePlaybackWhenScrollAppeared = newValue }
    }

    ///
    /// 滚动出去后, 是否隐藏播放器视图. 默认为YES
    ///
    @objc public var hiddenViewWhenScrollDisappeared: Bool {
        get { controlInfo.scrollControl.hiddenPlayerViewWhenScrollDisappeared }
        set { controlInfo.scrollControl.hiddenPlayerViewWhenScrollDisappeared = newValue }
    }

    ///
    /// 是否在 scrollView 中播放
    ///
    @objc public var isPlayOnScrollView: Bool {
        return playModelObserver?.isPlayInScrollView ?? false
    }

    ///
    /// 播放器视图是否显示
    ///
    @objc public var isScrollAppeared: Bool {
        return controlInfo.scrollControl.isScrollAppeared
    }

    @objc public var playerViewWillAppearExeBlock: ((SJBaseVideoPlayer) -> Void)? {
        get { _playerViewWillAppearExeBlock }
        set { _playerViewWillAppearExeBlock = newValue }
    }

    @objc public var playerViewWillDisappearExeBlock: ((SJBaseVideoPlayer) -> Void)? {
        get { _playerViewWillDisappearExeBlock }
        set { _playerViewWillDisappearExeBlock = newValue }
    }
}

