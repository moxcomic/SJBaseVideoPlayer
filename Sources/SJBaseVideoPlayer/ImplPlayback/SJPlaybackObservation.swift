//
//  SJPlaybackObservation.swift
//  Pods
//
//  Created by 畅三江 on 2019/8/27.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import Foundation
@preconcurrency import AVFoundation

@objc(SJPlaybackObservation)
@MainActor
public class SJPlaybackObservation: NSObject {
    /// 播放状态改变后的回调 (聚合: timeControlStatus / assetStatus / playbackDidFinish)
    @objc public var playbackStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 播放完毕的回调
    @objc public var playbackDidFinishExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 资源状态改变的回调
    @objc public var assetStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 播放控制改变的回调
    @objc public var timeControlStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 画中画状态改变的回调
    @available(iOS 14.0, *)
    @objc public var pictureInPictureStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)? {
        get { _pictureInPictureStatusDidChangeExeBlock }
        set { _pictureInPictureStatusDidChangeExeBlock = newValue }
    }
    private var _pictureInPictureStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 调用 seek 之前的回调
    @objc public var willSeekToTimeExeBlock: ((SJBaseVideoPlayer, CMTime) -> Void)?
    /// 调用 seek 之后的回调
    @objc public var didSeekToTimeExeBlock: ((SJBaseVideoPlayer, CMTime) -> Void)?
    /// 调用了重播的回调
    @objc public var didReplayExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 切换清晰度状态改变的回调
    @objc public var definitionSwitchStatusDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 当前时间改变的回调
    @objc public var currentTimeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 播放时长改变的回调
    @objc public var durationDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 缓冲时长改变的回调
    @objc public var playableDurationDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 获取到 video presentation size 时的回调
    @objc public var presentationSizeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 获取到文件类型的回调
    @objc public var playbackTypeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 锁屏状态改变的回调
    @objc public var screenLockStateDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 播放器的静音状态改变的回调
    @objc public var mutedDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 播放器的声音改变的回调
    @objc public var playerVolumeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    /// 调速的回调
    @objc public var rateDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?

    @objc public private(set) weak var player: SJBaseVideoPlayer?

    /// 播放完毕的回调 (已弃用)
    @available(*, deprecated, message: "use `playbackDidFinishExeBlock`")
    @objc public var didPlayToEndTimeExeBlock: ((SJBaseVideoPlayer) -> Void)?

    private nonisolated(unsafe) var tokens: [any NSObjectProtocol] = []

    @objc public init(player: SJBaseVideoPlayer) {
        self.player = player
        super.init()

        let center = NotificationCenter.default
        let queue = OperationQueue.main

        func add(_ name: Notification.Name, _ handler: @escaping @MainActor (Notification) -> Void) {
            let token = center.addObserver(forName: name, object: player, queue: queue) { note in
                nonisolated(unsafe) let n = note
                MainActor.assumeIsolated {
                    handler(n)
                }
            }
            tokens.append(token)
        }

        add(SJVideoPlayerAssetStatusDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.assetStatusDidChangeExeBlock?(player)
            self.playbackStatusDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.timeControlStatusDidChangeExeBlock?(player)
            self.playbackStatusDidChangeExeBlock?(player)
        }

        if #available(iOS 14.0, *) {
            add(SJVideoPlayerPictureInPictureStatusDidChangeNotification) { [weak self] _ in
                guard let self = self, let player = self.player else { return }
                self._pictureInPictureStatusDidChangeExeBlock?(player)
            }
        }

        add(SJVideoPlayerPlaybackDidFinishNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            if let block = self.playbackDidFinishExeBlock {
                block(player)
            } else if let endBlock = self.deprecatedDidPlayToEndTimeExeBlock,
                      (player.value(forKey: "finishedReason") as? String) == SJFinishedReasonToEndTimePosition {
                endBlock(player)
            }
            self.playbackStatusDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerDefinitionSwitchStatusDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.definitionSwitchStatusDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerCurrentTimeDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTimeDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerDurationDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.durationDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerPlayableDurationDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.playableDurationDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerPresentationSizeDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.presentationSizeDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerPlaybackTypeDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.playbackTypeDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerScreenLockStateDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.screenLockStateDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerMutedDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.mutedDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerVolumeDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.playerVolumeDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerRateDidChangeNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.rateDidChangeExeBlock?(player)
        }

        add(SJVideoPlayerPlaybackDidReplayNotification) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.didReplayExeBlock?(player)
        }

        add(SJVideoPlayerPlaybackWillSeekNotification) { [weak self] note in
            guard let self = self else { return }
            guard let obj = note.object as? SJBaseVideoPlayer else { return }
            let time = (note.userInfo?[SJVideoPlayerNotificationUserInfoKeySeekTime] as? NSValue)?.timeValue ?? .zero
            self.willSeekToTimeExeBlock?(obj, time)
        }

        add(SJVideoPlayerPlaybackDidSeekNotification) { [weak self] note in
            guard let self = self else { return }
            guard let obj = note.object as? SJBaseVideoPlayer else { return }
            let time = (note.userInfo?[SJVideoPlayerNotificationUserInfoKeySeekTime] as? NSValue)?.timeValue ?? .zero
            self.didSeekToTimeExeBlock?(obj, time)
        }
    }

    // 内部访问已弃用 block, 规避 deprecation 警告
    private var deprecatedDidPlayToEndTimeExeBlock: ((SJBaseVideoPlayer) -> Void)? {
        return didPlayToEndTimeExeBlock
    }

    deinit {
        let center = NotificationCenter.default
        for token in tokens {
            center.removeObserver(token)
        }
    }
}

