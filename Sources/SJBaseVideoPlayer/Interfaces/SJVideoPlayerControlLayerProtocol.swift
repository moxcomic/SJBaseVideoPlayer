//
//  SJVideoPlayerControlLayerProtocol.swift
//  Project
//
//  Created by 畅三江 on 2018/6/1.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  契约层(Swift 6.3): 由原 SJVideoPlayerControlLayerProtocol.h 转换而来。
//  控制层的数据源/代理协议聚合, 全部 @objc 暴露, 选择器与原 ObjC 一致。
//

import UIKit
import CoreGraphics

// MARK: - 控制层数据源

/// 对应原 @protocol SJVideoPlayerControlLayerDataSource <NSObject>。
@MainActor
@objc(SJVideoPlayerControlLayerDataSource)
public protocol SJVideoPlayerControlLayerDataSource: NSObjectProtocol {
    /// 请返回控制层的根视图, 这个视图将会添加到播放器中。
    @objc func controlView() -> UIView

    /// 当安装好控制层后, 会回调这个方法。
    @objc optional func installedControlView(toVideoPlayer videoPlayer: SJBaseVideoPlayer)
}

// MARK: - 控制层代理(聚合)

/// 对应原 @protocol SJVideoPlayerControlLayerDelegate, 继承多个子代理协议。
@MainActor
@objc(SJVideoPlayerControlLayerDelegate)
public protocol SJVideoPlayerControlLayerDelegate:
    SJPlaybackInfoDelegate,
    SJRotationControlDelegate,
    SJGestureControllerDelegate,
    SJNetworkStatusControlDelegate,
    SJVolumeBrightnessRateControlDelegate,
    SJLockScreenStateControlDelegate,
    SJAppActivityControlDelegate,
    SJFitOnScreenControlDelegate,
    SJSwitchVideoDefinitionControlDelegate,
    SJPlaybackControlDelegate
{
    /// 控制层需要显示, 你应该在这里做一些显示的工作。
    @objc optional func controlLayerNeedAppear(_ videoPlayer: SJBaseVideoPlayer)

    /// 控制层需要隐藏, 你应该在这里做一些隐藏的工作。
    @objc optional func controlLayerNeedDisappear(_ videoPlayer: SJBaseVideoPlayer)

    /// 控制层是否可以自动隐藏。
    @objc optional func controlLayerOfVideoPlayerCanAutomaticallyDisappear(_ videoPlayer: SJBaseVideoPlayer) -> Bool

    /// 当滚动scrollView时, 播放器即将出现时会回调这个方法。
    @objc optional func videoPlayerWillAppear(inScrollView videoPlayer: SJBaseVideoPlayer)

    /// 当滚动scrollView时, 播放器即将消失时会回调这个方法。
    @objc optional func videoPlayerWillDisappear(inScrollView videoPlayer: SJBaseVideoPlayer)
}

// MARK: - 播放控制代理

/// 对应原 @protocol SJPlaybackControlDelegate。
@MainActor
@objc(SJPlaybackControlDelegate)
public protocol SJPlaybackControlDelegate: NSObjectProtocol {
    @objc optional func canPerformPlay(forVideoPlayer videoPlayer: SJBaseVideoPlayer) -> Bool
    @objc optional func canPerformPause(forVideoPlayer videoPlayer: SJBaseVideoPlayer) -> Bool
    @objc optional func canPerformStop(forVideoPlayer videoPlayer: SJBaseVideoPlayer) -> Bool
}

// MARK: - 播放信息代理

/// 对应原 @protocol SJPlaybackInfoDelegate。
@MainActor
@objc(SJPlaybackInfoDelegate)
public protocol SJPlaybackInfoDelegate: NSObjectProtocol {
    /// 当播放器准备播放一个新的资源时, 会回调这个方法。
    /// 注: 形参为可选 — 与原 ObjC 一致, 清空资源(asset==nil)时也会回调(传 nil), 便于控制层在清空时重置 UI。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, prepareToPlay asset: SJVideoPlayerURLAsset?)

    /// 播放状态改变后的回调(timeControlStatus / assetStatus / 播放完毕变更时触发)。
    @objc optional func videoPlayerPlaybackStatusDidChange(_ videoPlayer: SJBaseVideoPlayer)

    @available(iOS 14.0, *)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, pictureInPictureStatusDidChange status: SJPictureInPictureStatus)

    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, currentTimeDidChange currentTime: TimeInterval)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, durationDidChange duration: TimeInterval)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, playableDurationDidChange duration: TimeInterval)

    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, playbackTypeDidChange playbackType: SJPlaybackType)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, presentationSizeDidChange size: CGSize)
}

// MARK: - 音量/亮度/速率代理

/// 对应原 @protocol SJVolumeBrightnessRateControlDelegate。
@MainActor
@objc(SJVolumeBrightnessRateControlDelegate)
public protocol SJVolumeBrightnessRateControlDelegate: NSObjectProtocol {
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, muteChanged mute: Bool)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, volumeChanged volume: Float)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, brightnessChanged brightness: Float)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, rateChanged rate: Float)
}

// MARK: - 旋转控制代理

/// 对应原 @protocol SJRotationControlDelegate。
@MainActor
@objc(SJRotationControlDelegate)
public protocol SJRotationControlDelegate: NSObjectProtocol {
    /// 是否允许触发播放器旋转。
    @objc optional func canTriggerRotation(ofVideoPlayer videoPlayer: SJBaseVideoPlayer) -> Bool

    /// 当播放器将要旋转的时候, 会回调这个方法。isFull 标识是否是全屏。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, willRotateView isFull: Bool)

    /// 当播放器旋转完成的时候, 会回调这个方法。isFull 标识是否是全屏。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, didEndRotation isFull: Bool)

    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, onRotationTransitioningChanged isTransitioning: Bool)
}

// MARK: - 全屏(不旋转)控制代理

/// 对应原 @protocol SJFitOnScreenControlDelegate。(v1.3.1 新增)
@MainActor
@objc(SJFitOnScreenControlDelegate)
public protocol SJFitOnScreenControlDelegate: NSObjectProtocol {
    /// 当播放器即将全屏(但不旋转)时, 这个方法将会被调用。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, willFitOnScreen isFitOnScreen: Bool)
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, didCompleteFitOnScreen isFitOnScreen: Bool)
}

// MARK: - 手势控制代理

/// 对应原 @protocol SJGestureControllerDelegate。
@MainActor
@objc(SJGestureControllerDelegate)
public protocol SJGestureControllerDelegate: NSObjectProtocol {
    /// 是否可以触发某个手势。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, gestureRecognizerShouldTrigger type: SJPlayerGestureType, location: CGPoint) -> Bool

    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, panGestureTriggeredInTheHorizontalDirection state: SJPanGestureRecognizerState, progressTime: TimeInterval)

    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, longPressGestureStateDidChange state: SJLongPressGestureRecognizerState)
}

// MARK: - 网络状态控制代理

/// 对应原 @protocol SJNetworkStatusControlDelegate。
@MainActor
@objc(SJNetworkStatusControlDelegate)
public protocol SJNetworkStatusControlDelegate: NSObjectProtocol {
    /// 当网络状态变更时, 会回调这个方法。
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, reachabilityChanged status: SJNetworkStatus)
}

// MARK: - 锁屏状态控制代理

/// 对应原 @protocol SJLockScreenStateControlDelegate。
@MainActor
@objc(SJLockScreenStateControlDelegate)
public protocol SJLockScreenStateControlDelegate: NSObjectProtocol {
    /// 锁屏状态下, 用户每次点击播放器都会回调这个方法。
    @objc optional func tappedPlayer(onTheLockedState videoPlayer: SJBaseVideoPlayer)

    /// 当设置 videoPlayer.lockedScreen == YES 时调用。
    @objc optional func lockedVideoPlayer(_ videoPlayer: SJBaseVideoPlayer)

    /// 当设置 videoPlayer.lockedScreen == NO 时调用。
    @objc optional func unlockedVideoPlayer(_ videoPlayer: SJBaseVideoPlayer)
}

// MARK: - 清晰度切换控制代理

/// 对应原 @protocol SJSwitchVideoDefinitionControlDelegate。
@MainActor
@objc(SJSwitchVideoDefinitionControlDelegate)
public protocol SJSwitchVideoDefinitionControlDelegate: NSObjectProtocol {
    @objc optional func videoPlayer(_ videoPlayer: SJBaseVideoPlayer, switchingDefinitionStatusDidChange status: SJDefinitionSwitchStatus, media: SJMediaModelProtocol)
}

// MARK: - App 活动状态控制代理

/// 对应原 @protocol SJAppActivityControlDelegate。
@MainActor
@objc(SJAppActivityControlDelegate)
public protocol SJAppActivityControlDelegate: NSObjectProtocol {
    @objc optional func applicationWillEnterForeground(withVideoPlayer videoPlayer: SJBaseVideoPlayer)
    @objc optional func applicationDidBecomeActive(withVideoPlayer videoPlayer: SJBaseVideoPlayer)
    @objc optional func applicationWillResignActive(withVideoPlayer videoPlayer: SJBaseVideoPlayer)
    @objc optional func applicationDidEnterBackground(withVideoPlayer videoPlayer: SJBaseVideoPlayer)
}

