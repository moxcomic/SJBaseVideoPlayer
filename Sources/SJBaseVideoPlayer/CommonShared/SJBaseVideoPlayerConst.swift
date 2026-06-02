//
//  SJBaseVideoPlayerConst.swift
//  Pods
//
//  Created by 畅三江 on 2019/8/6.
//
//  用于记录常量和一些未来可能提供的通知.
//  Swift 6.3 转换: 常量值与 ObjC 完全一致, 通知名 @objc 暴露.
//

import Foundation

// MARK: - View Tags

public let SJPlayerViewTag: Int = 0xFFFFFFF0
public let SJPresentViewTag: Int = 0xFFFFFFF1

// MARK: - SJPlayerZIndexes

///
/// 播放器内部各视图的层级 (z-index) 配置.
/// 单例, 等价原 ObjC 的 `+shared` 与不可用的 init/new.
///
@objc(SJPlayerZIndexes)
@MainActor
public final class SJPlayerZIndexes: NSObject {
    @objc public static let shared = SJPlayerZIndexes()

    @objc public var textPopupViewZIndex: Int = -10
    @objc public var promptingPopupViewZIndex: Int = -20
    @objc public var controlLayerViewZIndex: Int = -30
    @objc public var danmakuViewZIndex: Int = -40
    @objc public var placeholderImageViewZIndex: Int = -50
    @objc public var watermarkViewZIndex: Int = -60
    @objc public var subtitleViewZIndex: Int = -70
    @objc public var playbackViewZIndex: Int = -80

    private override init() {
        super.init()
    }
}

// MARK: - Playback Notifications

///
/// assetStatus 改变的通知
///
public let SJVideoPlayerAssetStatusDidChangeNotification = Notification.Name("SJVideoPlayerAssetStatusDidChangeNotification")

///
/// 切换清晰度状态 改变的通知
///
public let SJVideoPlayerDefinitionSwitchStatusDidChangeNotification = Notification.Name("SJVideoPlayerDefinitionSwitchStatusDidChangeNotification")

///
/// 播放资源将要改变前发出的通知
///
public let SJVideoPlayerURLAssetWillChangeNotification = Notification.Name("SJVideoPlayerURLAssetWillChangeNotification")
///
/// 播放资源改变后发出的通知
///
public let SJVideoPlayerURLAssetDidChangeNotification = Notification.Name("SJVideoPlayerURLAssetDidChangeNotification")

///
/// 播放器收到App进入后台的通知后发出的通知
///
public let SJVideoPlayerApplicationDidEnterBackgroundNotification = Notification.Name("SJVideoPlayerApplicationDidEnterBackgroundNotification")
///
/// 播放器收到App进入前台的通知后发出的通知
///
public let SJVideoPlayerApplicationWillEnterForegroundNotification = Notification.Name("SJVideoPlayerApplicationWillEnterForegroundNotification")
///
/// 播放器收到App将要关闭的通知后发出的通知
///
public let SJVideoPlayerApplicationWillTerminateNotification = Notification.Name("SJVideoPlayerApplicationWillTerminateNotification")

///
/// 播放器的playbackController将要进行销毁前的通知
/// 注意: 发送对象变为了`SJMediaPlaybackController`(目前只此一个, 其他都为player对象)
///
public let SJVideoPlayerPlaybackControllerWillDeallocateNotification = Notification.Name("SJVideoPlayerPlaybackControllerWillDeallocateNotification")

///
/// timeControlStatus 改变的通知
///
public let SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification = Notification.Name("SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification")
///
/// picture in picture status 改变的通知
///
public let SJVideoPlayerPictureInPictureStatusDidChangeNotification = Notification.Name("SJVideoPlayerPictureInPictureStatusDidChangeNotification")
///
/// 播放完毕后发出的通知
///
public let SJVideoPlayerPlaybackDidFinishNotification = Notification.Name("SJVideoPlayerPlaybackDidFinishNotification")
///
/// 执行replay发出的通知
///
public let SJVideoPlayerPlaybackDidReplayNotification = Notification.Name("SJVideoPlayerPlaybackDidReplayNotification")
///
/// 执行stop前发出的通知
///
public let SJVideoPlayerPlaybackWillStopNotification = Notification.Name("SJVideoPlayerPlaybackWillStopNotification")
///
/// 执行stop后发出的通知
///
public let SJVideoPlayerPlaybackDidStopNotification = Notification.Name("SJVideoPlayerPlaybackDidStopNotification")
///
/// 执行refresh前发出的通知
///
public let SJVideoPlayerPlaybackWillRefreshNotification = Notification.Name("SJVideoPlayerPlaybackWillRefreshNotification")
///
/// 执行refresh后发出的通知
///
public let SJVideoPlayerPlaybackDidRefreshNotification = Notification.Name("SJVideoPlayerPlaybackDidRefreshNotification")
///
/// 执行seek前发出的通知
///
public let SJVideoPlayerPlaybackWillSeekNotification = Notification.Name("SJVideoPlayerPlaybackWillSeekNotification")
///
/// 执行seek后发出的通知
///
public let SJVideoPlayerPlaybackDidSeekNotification = Notification.Name("SJVideoPlayerPlaybackDidSeekNotification")

///
/// 当前播放时间 改变的通知
///
public let SJVideoPlayerCurrentTimeDidChangeNotification = Notification.Name("SJVideoPlayerCurrentTimeDidChangeNotification")
///
/// 获取到播放时长的通知
///
public let SJVideoPlayerDurationDidChangeNotification = Notification.Name("SJVideoPlayerDurationDidChangeNotification")
///
/// 缓冲时长 改变的通知
///
public let SJVideoPlayerPlayableDurationDidChangeNotification = Notification.Name("SJVideoPlayerPlayableDurationDidChangeNotification")
///
/// 获取到视频宽高的通知
///
public let SJVideoPlayerPresentationSizeDidChangeNotification = Notification.Name("SJVideoPlayerPresentationSizeDidChangeNotification")
///
/// 获取到播放类型的通知
///
public let SJVideoPlayerPlaybackTypeDidChangeNotification = Notification.Name("SJVideoPlayerPlaybackTypeDidChangeNotification")

///
/// 调速 改变的通知
///
public let SJVideoPlayerRateDidChangeNotification = Notification.Name("SJVideoPlayerRateDidChangeNotification")
///
/// 静音状态 改变的通知
///
public let SJVideoPlayerMutedDidChangeNotification = Notification.Name("SJVideoPlayerMutedDidChangeNotification")
///
/// 音量 改变的通知
///
public let SJVideoPlayerVolumeDidChangeNotification = Notification.Name("SJVideoPlayerVolumeDidChangeNotification")
///
/// 锁屏状态 改变的通知
///
public let SJVideoPlayerScreenLockStateDidChangeNotification = Notification.Name("SJVideoPlayerScreenLockStateDidChangeNotification")

///
/// seek 通知 userInfo 中存放 time 的 key
///
public let SJVideoPlayerNotificationUserInfoKeySeekTime: String = "time"

