//
//  SJBaseVideoPlayer+PlayModelObserver.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (SJPlayModelPropertiesObserverDelegate)。
//  监听视图(cell)在 scrollView 中的出现/消失, 据此控制播放暂停/恢复、视图复用与小窗浮层。
//

import UIKit
import SnapKit
@preconcurrency import AVFoundation

// MARK: - 滚动观察 (SJPlayModelPropertiesObserverDelegate)

@MainActor
extension SJBaseVideoPlayer: SJPlayModelPropertiesObserverDelegate {

    // 原: - (void)observer:userTouchedCollectionView: { /* nothing */ }
    public func observer(_ observer: SJPlayModelPropertiesObserver, userTouchedCollectionView touched: Bool) { /* nothing */ }

    // 原: - (void)observer:userTouchedTableView: { /* nothing */ }
    public func observer(_ observer: SJPlayModelPropertiesObserver, userTouchedTableView touched: Bool) { /* nothing */ }

    // 原: - (void)playerWillAppearForObserver:superview:
    public func playerWillAppear(for observer: SJPlayModelPropertiesObserver, superview: UIView) {
        if controlInfo.scrollControl.isScrollAppeared {
            return
        }

        controlInfo.scrollControl.isScrollAppeared = true
        _deviceVolumeAndBrightnessTargetViewContext?.isScrollAppeared = true
        _deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()

        if controlInfo.scrollControl.hiddenPlayerViewWhenScrollDisappeared {
            _view.isHidden = false
        }

        if _playbackController?.isPlayed == true {
            if !viewControllerManager.viewDisappeared {
                if isPlayOnScrollView {
                    if controlInfo.scrollControl.resumePlaybackWhenScrollAppeared {
                        play()
                    }
                }
            }
        }

        // 原: if ( superview && self.view.superview != superview ) { ... }
        // superview 在 Swift 签名中为非可选, 故仅判断 superview 是否变化。
        if view.superview !== superview {
            superview.addSubview(view)
            view.snp.remakeConstraints { make in
                make.edges.equalTo(superview)
            }
        }

        if _smallViewFloatingController?.isAppeared == true {
            _smallViewFloatingController?.dismiss()
        }

        controlLayerDelegate?.videoPlayerWillAppear?(inScrollView: self)

        if let block = _playerViewWillAppearExeBlock {
            block(self)
        }
    }

    // 原: - (void)playerWillDisappearForObserver:
    public func playerWillDisappear(for observer: SJPlayModelPropertiesObserver) {
        if controlInfo.scrollControl.isScrollAppeared == false {
            return
        }

        if _rotationManager?.rotating == true {
            return
        }

        controlInfo.scrollControl.isScrollAppeared = false
        _deviceVolumeAndBrightnessTargetViewContext?.isScrollAppeared = false
        _deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()

        _view.isHidden = controlInfo.scrollControl.hiddenPlayerViewWhenScrollDisappeared

        if _smallViewFloatingController?.enabled == true {
            _smallViewFloatingController?.show()
        } else if controlInfo.scrollControl.pausedWhenScrollDisappeared {
            if #available(iOS 14.0, *) {
                if _playbackController?.pictureInPictureStatus != .running {
                    pause()
                }
            } else {
                pause()
            }
        }

        controlLayerDelegate?.videoPlayerWillDisappear?(inScrollView: self)

        if let block = _playerViewWillDisappearExeBlock {
            block(self)
        }
    }
}

