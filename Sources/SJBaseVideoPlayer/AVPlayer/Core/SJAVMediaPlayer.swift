//
//  SJAVMediaPlayer.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/18.
//
//  Swift 6.3 迁移: 由 SJAVMediaPlayer.{h,m} 转写.
//  AVPlayer 引擎包装. KVO / time observer / NotificationCenter 全部包装为并发安全形式:
//  - 该类在 @MainActor 隔离域运行(状态机与 UIKit 一致, 通知统一在主线程派发).
//  - KVO 使用 Swift 原生 NSKeyValueObservation; 回调在主线程派发后再驱动状态机, 与 ObjC 版 dispatch_get_main_queue 一致.
//

@preconcurrency import AVFoundation
import UIKit

@MainActor
@objc(SJAVMediaPlayer)
public final class SJAVMediaPlayer: NSObject, SJMediaPlayer {

    // MARK: 对外只读/可写属性

    @objc public private(set) var avPlayer: AVPlayer
    @objc public private(set) var playbackType: SJPlaybackType = .unknown {
        didSet { postNotification(SJMediaPlayerPlaybackTypeDidChangeNotification) }
    }
    @objc public var minBufferedDuration: TimeInterval = 8
    @objc public var accurateSeeking: Bool = false

    @objc public var trialEndPosition: TimeInterval = 0 {
        didSet {
            if trialEndPosition != oldValue {
                refreshOrStop()
            }
        }
    }

    // MARK: SJMediaPlayer 协议

    @objc public var assetStatus: SJAssetStatus = .preparing {
        didSet {
            postNotification(SJMediaPlayerAssetStatusDidChangeNotification)
            #if DEBUG
            if assetStatus == .failed {
                if let innerError = innerError {
                    NSLog("SJAVMediaPlayer: %@", innerError as NSError)
                } else if let e = avPlayer.error {
                    NSLog("SJAVMediaPlayer: %@", e as NSError)
                } else if let e = avPlayer.currentItem?.error {
                    NSLog("SJAVMediaPlayer: %@", e as NSError)
                }
            }
            #endif
        }
    }

    @objc public var reasonForWaitingToPlay: SJWaitingReason?

    @objc public var timeControlStatus: SJPlaybackTimeControlStatus = .paused {
        didSet {
            refreshOrStop()
            postNotification(SJMediaPlayerTimeControlStatusDidChangeNotification)
        }
    }

    public var seekingInfo: SJSeekingInfo = SJSeekingInfo(isSeeking: false, time: .zero)

    @objc public var presentationSize: CGSize {
        return avPlayer.currentItem?.presentationSize ?? .zero
    }

    @objc public private(set) var isReplayed: Bool = false
    @objc public private(set) var isPlayed: Bool = false

    @objc public var isPlaybackFinished: Bool = false {
        didSet {
            if isPlaybackFinished != oldValue {
                if !isPlaybackFinished { finishedReason = nil }
                if isPlaybackFinished {
                    postNotification(SJMediaPlayerPlaybackDidFinishNotification)
                }
            }
        }
    }

    @objc public var finishedReason: SJFinishedReason?

    @objc public var rate: Float = 1 {
        didSet {
            if rate != 0 {
                if timeControlStatus == .paused {
                    play()
                } else {
                    avPlayer.rate = rate
                }
            } else {
                pause()
            }
            postNotification(SJMediaPlayerRateDidChangeNotification)
        }
    }

    @objc public var volume: Float {
        get { avPlayer.volume }
        set {
            avPlayer.volume = newValue
            postNotification(SJMediaPlayerVolumeDidChangeNotification)
        }
    }

    @objc public var isMuted: Bool {
        get { avPlayer.isMuted }
        set {
            avPlayer.isMuted = newValue
            postNotification(SJMediaPlayerMutedDidChangeNotification)
        }
    }

    @objc public var duration: TimeInterval = 0 {
        didSet { postNotification(SJMediaPlayerDurationDidChangeNotification) }
    }

    @objc public var currentTime: TimeInterval {
        if isPlaybackFinished {
            if finishedReason == SJFinishedReasonToEndTimePosition {
                return duration
            } else if finishedReason == SJFinishedReasonToTrialEndPosition {
                return trialEndPosition
            }
        }
        return CMTimeGetSeconds(avPlayer.currentTime())
    }

    private var _playableDuration: TimeInterval = 0
    @objc public var playableDuration: TimeInterval {
        get {
            if trialEndPosition != 0 && _playableDuration >= trialEndPosition {
                return trialEndPosition
            }
            return _playableDuration
        }
        set {
            _playableDuration = newValue
            postNotification(SJMediaPlayerPlayableDurationDidChangeNotification)
        }
    }

    @objc public var error: Error? {
        if let innerError = innerError { return innerError }
        if let e = avPlayer.currentItem?.error { return e }
        if let e = avPlayer.error { return e }
        return nil
    }

    // MARK: 内部状态

    private var innerError: Error? {
        didSet { toEvaluating() }
    }
    private var startPosition: TimeInterval = 0
    private var needsSeekToStartPosition: Bool = false
    private var refreshTimer: Timer?

    private var isPlayedToTrialEndPosition: Bool {
        return trialEndPosition != 0 && currentTime >= trialEndPosition
    }

    // KVO 观察令牌
    private var observations: [NSKeyValueObservation] = []
    private var notificationTokens: [NSObjectProtocol] = []

    // MARK: 初始化

    @objc public init(avPlayer player: AVPlayer, startPosition time: TimeInterval) {
        self.avPlayer = player
        super.init()
        self.rate = 1
        self.assetStatus = .preparing
        self.startPosition = time
        self.needsSeekToStartPosition = (time != 0)
        self.minBufferedDuration = 8
        prepareToPlay()
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: 播放控制

    @objc public func play() {
        if assetStatus == .failed { return }
        if isPlaybackFinished {
            replay()
            return
        }
        isPlayed = true
        if timeControlStatus == .paused {
            reasonForWaitingToPlay = SJWaitingWhileEvaluatingBufferingRateReason
            timeControlStatus = .waitingToPlay
        }
        // fix 播放后立即设置倍速,可能会导致画面卡住的问题, 直接使用系统提供api设置倍速播放
        avPlayer.playImmediately(atRate: rate)
        toEvaluating()
    }

    @objc public func pause() {
        timeControlStatus = .paused
        avPlayer.pause()
    }

    @objc public func replay() {
        if assetStatus == .failed { return }
        isReplayed = true
        if timeControlStatus == .paused {
            reasonForWaitingToPlay = SJWaitingWhileEvaluatingBufferingRateReason
            timeControlStatus = .waitingToPlay
        }
        seek(toTime: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.postNotification(SJMediaPlayerDidReplayNotification)
            self.play()
        }
    }

    @objc public func seek(toTime time: CMTime, completionHandler: ((Bool) -> Void)?) {
        let tolerance: CMTime = accurateSeeking ? .zero : .positiveInfinity
        seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: completionHandler)
    }

    @objc public func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)?) {
        if avPlayer.currentItem?.status != .readyToPlay {
            completionHandler?(false)
            return
        }
        let adjusted = adjustSeekTimeIfNeeded(time)
        willSeeking(adjusted)
        avPlayer.seek(to: adjusted, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter) { [weak self] finished in
            guard let self = self else { return }
            self.didEndSeeking()
            completionHandler?(finished)
        }
    }

    @objc public func report() {
        postNotification(SJMediaPlayerAssetStatusDidChangeNotification)
        postNotification(SJMediaPlayerTimeControlStatusDidChangeNotification)
        postNotification(SJMediaPlayerDurationDidChangeNotification)
        postNotification(SJMediaPlayerPlayableDurationDidChangeNotification)
        postNotification(SJMediaPlayerPlaybackTypeDidChangeNotification)
    }

    @objc public func screenshot() -> UIImage? {
        return avPlayer.currentItem?.asset.sj_screenshot(with: avPlayer.currentTime())
    }

    // MARK: 私有

    private func postNotification(_ name: NSNotification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }

    private func willSeeking(_ time: CMTime) {
        avPlayer.currentItem?.cancelPendingSeeks()
        isPlaybackFinished = false
        seekingInfo.time = time
        seekingInfo.isSeeking = true
    }

    private func didEndSeeking() {
        seekingInfo.time = .zero
        seekingInfo.isSeeking = false
    }

    private func playImmediately() {
        avPlayer.playImmediately(atRate: rate)
        toEvaluating()
    }

    private func prepareToPlay() {
        guard let playerItem = avPlayer.currentItem else { return }

        playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in self.updateDuration() }
        }

        // KVO -> 原生观察, 统一回主线程驱动状态机
        observations.append(playerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })
        observations.append(playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })
        observations.append(playerItem.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })
        observations.append(playerItem.observe(\.isPlaybackBufferFull, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })
        observations.append(playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.loadedTimeRangesDidChange() }
        })
        observations.append(playerItem.observe(\.presentationSize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.presentationSizeDidChange() }
        })
        observations.append(avPlayer.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })
        observations.append(avPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.toEvaluating() }
        })

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: nil) { [weak self] note in
            Task { @MainActor in self?.failedToPlayToEndTime(note) }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: nil) { [weak self] note in
            Task { @MainActor in self?.didPlayToEndTime(note) }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: playerItem, queue: nil) { [weak self] note in
            Task { @MainActor in self?.updatePlaybackType(note) }
        })

        toEvaluating()
    }

    private func toEvaluating() {
        guard let playerItem = avPlayer.currentItem else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var status = self.assetStatus
            if self.innerError != nil || playerItem.status == .failed || self.avPlayer.status == .failed {
                status = .failed
            } else if playerItem.status == .readyToPlay && self.avPlayer.status == .readyToPlay {
                status = .readyToPlay
            }

            if status != self.assetStatus {
                self.assetStatus = status
            }

            if status == .failed {
                self.timeControlStatus = .paused
            }

            if self.isPlayedToTrialEndPosition {
                self.didPlayToTrialEndPosition()
                return
            }

            if self.needsSeekToStartPosition && !self.seekingInfo.isSeeking && status == .readyToPlay {
                self.seek(to: CMTimeMakeWithSeconds(self.startPosition, preferredTimescale: Int32(NSEC_PER_SEC)), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    guard let self = self else { return }
                    self.needsSeekToStartPosition = false
                    self.toEvaluating()
                }
                return
            }

            let avt = self.timeControlStatus(forAVPlayerTimeControlStatus: self.avPlayer.timeControlStatus)
            let avr = self.waitingReason(forAVPlayerWaitingReason: self.avPlayer.reasonForWaitingToPlay)
            if self.timeControlStatus != avt || (avr != SJWaitingWithNoAssetToPlayReason && self.reasonForWaitingToPlay != avr) {
                self.reasonForWaitingToPlay = avr
                self.timeControlStatus = avt
            }
        }
    }

    private func updateDuration() {
        guard let asset = avPlayer.currentItem?.asset else { return }
        let duration = CMTimeGetSeconds(asset.duration)
        DispatchQueue.main.async { [weak self] in
            self?.duration = duration
        }
    }

    private func loadedTimeRangesDidChange() {
        guard let playerItem = avPlayer.currentItem else { return }
        let playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd((playerItem.loadedTimeRanges.first?.timeRangeValue) ?? CMTimeRange()))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playableDuration = playableDuration
            if self.timeControlStatus == .waitingToPlay &&
                self.reasonForWaitingToPlay == SJWaitingToMinimizeStallsReason &&
                playerItem.isPlaybackBufferEmpty == false {
                let curTime = CMTimeGetSeconds(playerItem.currentTime())
                let playableMilli = Int(playableDuration * 1000)
                let curMilli = Int(curTime * 1000)
                let buffMilli = playableMilli - curMilli
                let maxBuffMilli = Int(self.minBufferedDuration != 0 ? self.minBufferedDuration : 8 * 1000)
                if buffMilli > maxBuffMilli {
                    self.playImmediately()
                }
            }
        }
    }

    private func presentationSizeDidChange() {
        postNotification(SJMediaPlayerPresentationSizeDidChangeNotification)
    }

    private func failedToPlayToEndTime(_ note: Notification) {
        let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        DispatchQueue.main.async { [weak self] in
            self?.innerError = error
        }
    }

    private func didPlayToEndTime(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.finishedReason = SJFinishedReasonToEndTimePosition
            self.isPlaybackFinished = true
            self.pause()
        }
    }

    private func updatePlaybackType(_ note: Notification) {
        // 后台读取 accessLog, 计算后回主线程更新
        let player = avPlayer
        DispatchQueue.global().async {
            let event = player.currentItem?.accessLog()?.events.first
            var type: SJPlaybackType = .unknown
            if event?.playbackType == "LIVE" {
                type = .LIVE
            } else if event?.playbackType == "VOD" {
                type = .VOD
            } else if event?.playbackType == "FILE" {
                type = .FILE
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if type != self.playbackType {
                    self.playbackType = type
                }
            }
        }
    }

    private func waitingReason(forAVPlayerWaitingReason reason: AVPlayer.WaitingReason?) -> SJWaitingReason? {
        if reason == .noItemToPlay { return SJWaitingWithNoAssetToPlayReason }
        if reason == .toMinimizeStalls { return SJWaitingToMinimizeStallsReason }
        if reason == .evaluatingBufferingRate { return SJWaitingWhileEvaluatingBufferingRateReason }
        return nil
    }

    private func timeControlStatus(forAVPlayerTimeControlStatus status: AVPlayer.TimeControlStatus) -> SJPlaybackTimeControlStatus {
        switch status {
        case .paused: return .paused
        case .waitingToPlayAtSpecifiedRate: return .waitingToPlay
        case .playing: return .playing
        @unknown default: return .paused
        }
    }

    private func didPlayToTrialEndPosition() {
        if finishedReason != SJFinishedReasonToTrialEndPosition {
            finishedReason = SJFinishedReasonToTrialEndPosition
            isPlaybackFinished = true
            pause()
        }
    }

    private func adjustSeekTimeIfNeeded(_ time: CMTime) -> CMTime {
        if trialEndPosition != 0 && CMTimeGetSeconds(time) >= trialEndPosition {
            return CMTimeMakeWithSeconds(trialEndPosition * 0.98, preferredTimescale: Int32(NSEC_PER_SEC))
        }
        return time
    }

    private func refreshOrStop() {
        if trialEndPosition == 0 || timeControlStatus == .paused {
            if refreshTimer != nil {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
        } else {
            if refreshTimer == nil {
                let timer = Timer.sj_timer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.isPlayedToTrialEndPosition {
                        self.didPlayToTrialEndPosition()
                    }
                }
                refreshTimer = timer
                timer.sj_fire()
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
}

