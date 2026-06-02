//
//  SJBaseVideoPlayer+Playback.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Playback) <SJVideoPlayerPlaybackControllerDelegate>。播放控制。
//

import UIKit
@preconcurrency import AVFoundation
import CoreMedia

@MainActor
extension SJBaseVideoPlayer {

    // MARK: 播放控制器

    ///
    /// 播放控制(null_resettable)
    ///
    @objc public var playbackController: any SJVideoPlayerPlaybackController {
        get {
            if let controller = _playbackController { return controller }
            let controller = SJAVMediaPlaybackController()
            _playbackController = controller
            _playbackControllerDidChange()
            return controller
        }
        set {
            if let old = _playbackController {
                old.playerView.removeFromSuperview()
                NotificationCenter.default.post(name: SJVideoPlayerPlaybackControllerWillDeallocateNotification, object: old)
            }
            _playbackController = newValue
            _playbackControllerDidChange()
        }
    }

    private func _playbackControllerDidChange() {
        guard let playbackController = _playbackController else { return }

        playbackController.delegate = self

        if playbackController.playerView.superview !== presentView {
            playbackController.playerView.frame = presentView.bounds
            playbackController.playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playbackController.playerView.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.playbackViewZIndex)
            _presentView.addSubview(playbackController.playerView)
        }

        _flipTransitionManager?.target = playbackController.playerView
    }

    ///
    /// 观察者
    ///
    @objc public var playbackObserver: SJPlaybackObservation {
        if let obs = _playbackObserver { return obs }
        let obs = SJPlaybackObservation(player: self)
        _playbackObserver = obs
        return obs
    }

    // MARK: 资源

    ///
    /// 设置资源进行播放
    ///
    @objc(URLAsset) public var urlAsset: SJVideoPlayerURLAsset? {
        get { _URLAsset }
        set {
            _resetDefinitionSwitchingInfo()

            _postNotification(SJVideoPlayerURLAssetWillChangeNotification)

            _URLAsset = newValue

            _postNotification(SJVideoPlayerURLAssetDidChangeNotification)

            // prepareToPlay
            playbackController.media = newValue
            definitionSwitchingInfo.currentPlayingAsset = newValue
            _updateAssetObservers()
            _showOrHiddenPlaceholderImageViewIfNeeded()

            // 与原 ObjC 一致: 即使 newValue 为 nil 也无条件回调代理(传 nil),
            // 部分控制层依赖此回调在清空资源时重置 UI。协议形参已改为可选。
            controlLayerDelegate?.videoPlayer?(self, prepareToPlay: newValue)

            guard let newValue = newValue else {
                stop()
                return
            }

            if newValue.subtitles != nil || _subtitlePopupController != nil {
                subtitlePopupController.subtitles = newValue.subtitles
            }

            playbackController.prepareToPlay()
            _tryToPlayIfNeeded()
        }
    }

    private func _tryToPlayIfNeeded() {
        if registrar.state == .background && pausedInBackground { return }
        if controlInfo.playbackControl.autoplayWhenSetNewAsset == false { return }
        if isPlayOnScrollView && isScrollAppeared == false && pausedWhenScrollDisappeared { return }
        play()
    }

    func _updateAssetObservers() {
        _updateCurrentPlayingIndexPathIfNeeded(_URLAsset?.playModel)
        _updatePlayModelObserver(_URLAsset?.playModel)
        _mpc_assetObserver = _URLAsset?.getObserver()
        _mpc_assetObserver?.playModelDidChangeExeBlock = { [weak self] asset in
            guard let self = self else { return }
            self._updateCurrentPlayingIndexPathIfNeeded(asset.playModel)
            self._updatePlayModelObserver(asset.playModel)
        }

        _deviceVolumeAndBrightnessTargetViewContext?.isPlayOnScrollView = isPlayOnScrollView
        _deviceVolumeAndBrightnessTargetViewContext?.isScrollAppeared = isScrollAppeared
        _deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()
    }

    // MARK: 清晰度

    ///
    /// 切换清晰度
    ///
    @objc public func switchVideoDefinition(_ URLAsset: SJVideoPlayerURLAsset) {
        definitionSwitchingInfo.switchingAsset = URLAsset
        playbackController.switchVideoDefinition(URLAsset)
    }

    ///
    /// 当前清晰度切换的信息
    ///
    @objc public var definitionSwitchingInfo: SJVideoDefinitionSwitchingInfo {
        if let info = _definitionSwitchingInfo { return info }
        let info = SJVideoDefinitionSwitchingInfo()
        _definitionSwitchingInfo = info
        return info
    }

    private func _resetDefinitionSwitchingInfo() {
        let info = definitionSwitchingInfo
        info.currentPlayingAsset = nil
        info.switchingAsset = nil
        info.status = .unknown
    }

    // MARK: 状态

    @objc public var playbackType: SJPlaybackType {
        return _playbackController?.playbackType ?? .unknown
    }

    @objc public var error: Error? {
        return _playbackController?.error
    }

    @objc public var assetStatus: SJAssetStatus {
        return _playbackController?.assetStatus ?? .unknown
    }

    @objc public var timeControlStatus: SJPlaybackTimeControlStatus {
        return _playbackController?.timeControlStatus ?? .paused
    }

    @objc public var isPaused: Bool { timeControlStatus == .paused }
    @objc public var isPlaying: Bool { timeControlStatus == .playing }
    @objc public var isBuffering: Bool { timeControlStatus == .waitingToPlay && reasonForWaitingToPlay == SJWaitingToMinimizeStallsReason }
    @objc public var isEvaluating: Bool { timeControlStatus == .waitingToPlay && reasonForWaitingToPlay == SJWaitingWhileEvaluatingBufferingRateReason }
    @objc public var isNoAssetToPlay: Bool { timeControlStatus == .waitingToPlay && reasonForWaitingToPlay == SJWaitingWithNoAssetToPlayReason }

    @objc public var isPlaybackFailed: Bool {
        return assetStatus == .failed
    }

    @objc public var reasonForWaitingToPlay: SJWaitingReason? {
        return _playbackController?.reasonForWaitingToPlay
    }

    @objc public var isPlaybackFinished: Bool {
        return _playbackController?.isPlaybackFinished ?? false
    }

    @objc public var finishedReason: SJFinishedReason? {
        return _playbackController?.finishedReason
    }

    @objc public var isPlayed: Bool {
        return _playbackController?.isPlayed ?? false
    }

    @objc public var isReplayed: Bool {
        return _playbackController?.isReplayed ?? false
    }

    @objc public var isUserPaused: Bool {
        return controlInfo.playbackControl.isUserPaused
    }

    @objc public var currentTime: TimeInterval {
        return playbackController.currentTime
    }

    @objc public var duration: TimeInterval {
        return playbackController.duration
    }

    @objc public var playableDuration: TimeInterval {
        return playbackController.playableDuration
    }

    @objc public var durationWatched: TimeInterval {
        return playbackController.durationWatched
    }

    @objc public func stringForSeconds(_ secs: Int) -> String {
        return NSString.string(withCurrentTime: TimeInterval(secs), duration: duration) as String
    }

    // MARK: 音量 / 静音 / 速率

    @objc public var playerVolume: Float {
        get { playbackController.volume }
        set { playbackController.volume = newValue }
    }

    @objc(isMuted) public var muted: Bool {
        get { playbackController.isMuted }
        set { playbackController.isMuted = newValue }
    }

    @objc public var rate: Float {
        get { playbackController.rate }
        set {
            if let block = _canPlayAnAsset, !block(self) { return }
            if _playbackController?.rate == newValue { return }
            playbackController.rate = newValue
        }
    }

    // MARK: 后台 / 自动播放

    @objc(isPausedInBackground) public var pausedInBackground: Bool {
        get { playbackController.pauseWhenAppDidEnterBackground }
        set { playbackController.pauseWhenAppDidEnterBackground = newValue }
    }

    @objc public var autoplayWhenSetNewAsset: Bool {
        get { controlInfo.playbackControl.autoplayWhenSetNewAsset }
        set { controlInfo.playbackControl.autoplayWhenSetNewAsset = newValue }
    }

    @objc public var resumePlaybackWhenAppDidEnterForeground: Bool {
        get { controlInfo.playbackControl.resumePlaybackWhenAppDidEnterForeground }
        set { controlInfo.playbackControl.resumePlaybackWhenAppDidEnterForeground = newValue }
    }

    @objc public var resumePlaybackWhenPlayerHasFinishedSeeking: Bool {
        get { controlInfo.playbackControl.resumePlaybackWhenPlayerHasFinishedSeeking }
        set { controlInfo.playbackControl.resumePlaybackWhenPlayerHasFinishedSeeking = newValue }
    }

    // MARK: block 属性

    @objc public var canPlayAnAsset: ((SJBaseVideoPlayer) -> Bool)? {
        get { _canPlayAnAsset }
        set { _canPlayAnAsset = newValue }
    }

    @objc public var canSeekToTime: ((SJBaseVideoPlayer) -> Bool)? {
        get { _canSeekToTime }
        set { _canSeekToTime = newValue }
    }

    @objc public var accurateSeeking: Bool {
        get { controlInfo.playbackControl.accurateSeeking }
        set { controlInfo.playbackControl.accurateSeeking = newValue }
    }

    // MARK: 播放控制方法

    @objc public func play() {
        if let delegate = controlLayerDelegate,
           delegate.responds(to: #selector(SJPlaybackControlDelegate.canPerformPlay(forVideoPlayer:))) {
            if delegate.canPerformPlay?(forVideoPlayer: self) == false { return }
        }

        if let block = _canPlayAnAsset, !block(self) { return }

        if registrar.state == .background && pausedInBackground { return }

        controlInfo.playbackControl.isUserPaused = false

        if assetStatus == .failed {
            refresh()
            return
        }

        if controlInfo.audioSessionControl.isEnabled {
            do {
                try AVAudioSession.sharedInstance().setCategory(_mCategory, options: _mCategoryOptions)
            } catch {
                #if DEBUG
                print("\(error)")
                #endif
            }
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: _mSetActiveOptions)
            } catch {
                #if DEBUG
                print("\(error)")
                #endif
            }
        }

        _playbackController?.play()

        controlLayerAppearManager.resume()
    }

    @objc public func pause() {
        if let delegate = controlLayerDelegate,
           delegate.responds(to: #selector(SJPlaybackControlDelegate.canPerformPause(forVideoPlayer:))) {
            if delegate.canPerformPause?(forVideoPlayer: self) == false { return }
        }

        _playbackController?.pause()
    }

    @objc public func pauseForUser() {
        controlInfo.playbackControl.isUserPaused = true
        pause()
    }

    @objc public func refresh() {
        guard urlAsset != nil else { return }
        _postNotification(SJVideoPlayerPlaybackWillRefreshNotification)
        _playbackController?.refresh()
        play()
        _postNotification(SJVideoPlayerPlaybackDidRefreshNotification)
    }

    @objc public func replay() {
        guard urlAsset != nil else { return }
        if assetStatus == .failed {
            refresh()
            return
        }

        controlInfo.playbackControl.isUserPaused = false
        _playbackController?.replay()
    }

    @objc public func stop() {
        if let delegate = controlLayerDelegate,
           delegate.responds(to: #selector(SJPlaybackControlDelegate.canPerformStop(forVideoPlayer:))) {
            if delegate.canPerformStop?(forVideoPlayer: self) == false { return }
        }

        _postNotification(SJVideoPlayerPlaybackWillStopNotification)

        controlInfo.playbackControl.isUserPaused = false
        _subtitlePopupController?.subtitles = nil
        playModelObserver = nil
        _URLAsset = nil
        _playbackController?.stop()
        _resetDefinitionSwitchingInfo()
        _showOrHiddenPlaceholderImageViewIfNeeded()

        _postNotification(SJVideoPlayerPlaybackDidStopNotification)
    }

    // MARK: seek

    @objc(seekToTime:completionHandler:) public func seek(toTime secs: TimeInterval, completionHandler: ((Bool) -> Void)?) {
        if secs.isNaN { return }

        var secs = secs
        if secs > playbackController.duration {
            secs = playbackController.duration * 0.98
        } else if secs < 0 {
            secs = 0
        }

        seek(toTime: CMTimeMakeWithSeconds(secs, preferredTimescale: Int32(NSEC_PER_SEC)),
             toleranceBefore: accurateSeeking ? .zero : .positiveInfinity,
             toleranceAfter: accurateSeeking ? .zero : .positiveInfinity,
             completionHandler: completionHandler)
    }

    @objc(seekToTime:toleranceBefore:toleranceAfter:completionHandler:) public func seek(toTime time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)?) {
        if let block = _canSeekToTime, !block(self) { return }
        if let block = _canPlayAnAsset, !block(self) { return }

        if assetStatus != .readyToPlay {
            completionHandler?(false)
            return
        }

        playbackController.seek(toTime: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter) { [weak self] finished in
            guard let self = self else { return }
            if finished && self.controlInfo.playbackControl.resumePlaybackWhenPlayerHasFinishedSeeking {
                self.play()
            }
            completionHandler?(finished)
        }
    }

    // MARK: 内部

    func _updatePlayModelObserver(_ playModel: SJPlayModel?) {
        // clean
        playModelObserver = nil
        controlInfo.scrollControl.isScrollAppeared = false

        guard let playModel = playModel, type(of: playModel) != SJPlayModel.self else { return }

        // update playModel
        let observer = SJPlayModelPropertiesObserver(playModel: playModel)
        observer.delegate = self
        playModelObserver = observer
        observer.refreshAppearState()
    }
}

// MARK: - SJVideoPlayerPlaybackControllerDelegate

@MainActor
extension SJBaseVideoPlayer: SJVideoPlayerPlaybackControllerDelegate {

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, assetStatusDidChange status: SJAssetStatus) {
        controlLayerDelegate?.videoPlayerPlaybackStatusDidChange?(self)
        _postNotification(SJVideoPlayerAssetStatusDidChangeNotification)
        #if SJDEBUG
        showLog_AssetStatus()
        #endif
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, timeControlStatusDidChange status: SJPlaybackTimeControlStatus) {
        let isBuffering = self.isBuffering || assetStatus == .preparing
        if isBuffering && !(urlAsset?.mediaURL?.isFileURL ?? false) {
            reachability.startRefresh()
        } else {
            reachability.stopRefresh()
        }

        controlLayerDelegate?.videoPlayerPlaybackStatusDidChange?(self)

        _postNotification(SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification)

        if status == .paused && pausedToKeepAppearState {
            controlLayerAppearManager.keepAppearState()
        }

        #if SJDEBUG
        showLog_TimeControlStatus()
        #endif
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, volumeDidChange volume: Float) {
        _postNotification(SJVideoPlayerVolumeDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, rateDidChange rate: Float) {
        controlLayerDelegate?.videoPlayer?(self, rateChanged: rate)
        _postNotification(SJVideoPlayerRateDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, mutedDidChange isMuted: Bool) {
        controlLayerDelegate?.videoPlayer?(self, muteChanged: isMuted)
        _postNotification(SJVideoPlayerMutedDidChangeNotification)
    }

    @available(iOS 14.0, *)
    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, pictureInPictureStatusDidChange status: SJPictureInPictureStatus) {
        controlLayerDelegate?.videoPlayer?(self, pictureInPictureStatusDidChange: status)

        _deviceVolumeAndBrightnessTargetViewContext?.isPictureInPictureMode = (status == .running)
        _deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()

        _postNotification(SJVideoPlayerPictureInPictureStatusDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, durationDidChange duration: TimeInterval) {
        controlLayerDelegate?.videoPlayer?(self, durationDidChange: duration)
        _postNotification(SJVideoPlayerDurationDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, currentTimeDidChange currentTime: TimeInterval) {
        _subtitlePopupController?.currentTime = currentTime
        controlLayerDelegate?.videoPlayer?(self, currentTimeDidChange: currentTime)
        _postNotification(SJVideoPlayerCurrentTimeDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, playbackDidFinish reason: SJFinishedReason) {
        if _smallViewFloatingController?.isAppeared == true && hiddenFloatSmallViewWhenPlaybackFinished {
            _smallViewFloatingController?.dismiss()
        }

        controlLayerDelegate?.videoPlayerPlaybackStatusDidChange?(self)
        _postNotification(SJVideoPlayerPlaybackDidFinishNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, presentationSizeDidChange presentationSize: CGSize) {
        updateWatermarkViewLayout()

        if let block = _presentationSizeDidChangeExeBlock {
            block(self)
        }

        controlLayerDelegate?.videoPlayer?(self, presentationSizeDidChange: presentationSize)

        _postNotification(SJVideoPlayerPresentationSizeDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, playbackTypeDidChange playbackType: SJPlaybackType) {
        controlLayerDelegate?.videoPlayer?(self, playbackTypeDidChange: playbackType)
        _postNotification(SJVideoPlayerPlaybackTypeDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, playableDurationDidChange playableDuration: TimeInterval) {
        if controller.duration == 0 { return }
        controlLayerDelegate?.videoPlayer?(self, playableDurationDidChange: playableDuration)
        _postNotification(SJVideoPlayerPlayableDurationDidChangeNotification)
    }

    public func playbackControllerIsReadyForDisplay(_ controller: any SJVideoPlayerPlaybackController) {
        _showOrHiddenPlaceholderImageViewIfNeeded()
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, willSeekToTime time: CMTime) {
        _postNotification(SJVideoPlayerPlaybackWillSeekNotification, userInfo: [
            SJVideoPlayerNotificationUserInfoKeySeekTime: NSValue(time: time)
        ])
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, didSeekToTime time: CMTime) {
        _postNotification(SJVideoPlayerPlaybackDidSeekNotification, userInfo: [
            SJVideoPlayerNotificationUserInfoKeySeekTime: NSValue(time: time)
        ])
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, switchingDefinitionStatusDidChange status: SJDefinitionSwitchStatus, media: any SJMediaModelProtocol) {
        if status == .finished {
            _URLAsset = media as? SJVideoPlayerURLAsset
            definitionSwitchingInfo.currentPlayingAsset = _URLAsset
            _updateAssetObservers()
        }

        definitionSwitchingInfo.status = status

        controlLayerDelegate?.videoPlayer?(self, switchingDefinitionStatusDidChange: status, media: media)

        _postNotification(SJVideoPlayerDefinitionSwitchStatusDidChangeNotification)
    }

    public func playbackController(_ controller: any SJVideoPlayerPlaybackController, didReplay media: any SJMediaModelProtocol) {
        _postNotification(SJVideoPlayerPlaybackDidReplayNotification)
    }

    public func applicationDidBecomeActive(withPlaybackController controller: any SJVideoPlayerPlaybackController) {
        let canPlay = urlAsset != nil &&
                      isPaused &&
                      controlInfo.playbackControl.resumePlaybackWhenAppDidEnterForeground &&
                      !vc_isDisappeared
        if isPlayOnScrollView {
            if canPlay && isScrollAppeared { play() }
        } else {
            if canPlay { play() }
        }

        controlLayerDelegate?.applicationDidBecomeActive?(withVideoPlayer: self)
    }

    public func applicationWillResignActive(withPlaybackController controller: any SJVideoPlayerPlaybackController) {
        controlLayerDelegate?.applicationWillResignActive?(withVideoPlayer: self)
    }

    public func applicationWillEnterForeground(withPlaybackController controller: any SJVideoPlayerPlaybackController) {
        controlLayerDelegate?.applicationDidEnterBackground?(withVideoPlayer: self)
        _postNotification(SJVideoPlayerApplicationWillEnterForegroundNotification)
    }

    public func applicationDidEnterBackground(withPlaybackController controller: any SJVideoPlayerPlaybackController) {
        controlLayerDelegate?.applicationDidEnterBackground?(withVideoPlayer: self)
        _postNotification(SJVideoPlayerApplicationDidEnterBackgroundNotification)
    }
}

