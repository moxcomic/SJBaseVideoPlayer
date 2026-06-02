//
//  SJAVMediaPlaybackController.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/18.
//
//  Swift 6.3 迁移: 由 SJAVMediaPlaybackController.{h,m} 转写.
//  基于 AVPlayer 的播放控制器实现(继承 SJMediaPlaybackController).
//  负责: 加载/创建播放器与 LayerView、前后台处理、清晰度切换、画中画、导出/截图/GIF.
//

@preconcurrency import AVFoundation
import UIKit

@MainActor
@objc(SJAVMediaPlaybackController)
public class SJAVMediaPlaybackController: SJMediaPlaybackController, SJPictureInPictureControllerDelegate {

    @objc public var accurateSeeking: Bool = false {
        didSet {
            sj_currentPlayer?.accurateSeeking = accurateSeeking
        }
    }

    /// 强类型当前播放器
    @objc public var sj_currentPlayer: SJAVMediaPlayer? {
        return currentPlayer as? SJAVMediaPlayer
    }

    /// 强类型当前播放器视图
    @objc public var sj_currentPlayerView: SJAVMediaPlayerLayerView? {
        return currentPlayerView as? SJAVMediaPlayerLayerView
    }

    private var _pictureInPictureController: AnyObject?
    @available(iOS 14.0, *)
    private var pictureInPictureController: SJAVPictureInPictureController? {
        get { _pictureInPictureController as? SJAVPictureInPictureController }
        set { _pictureInPictureController = newValue }
    }

    // https://github.com/changsanjiang/SJVideoPlayer/issues/339
    private var needsToRefresh_fix339: Bool = false

    @objc public override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(_av_playbackTypeDidChange(_:)), name: SJMediaPlayerPlaybackTypeDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(_av_playerViewReadyForDisplay(_:)), name: SJMediaPlayerViewReadyForDisplayNotification, object: nil)
        center.addObserver(self, selector: #selector(_av_rateDidChange(_:)), name: SJMediaPlayerRateDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(_av_volumeDidChange(_:)), name: SJMediaPlayerVolumeDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(_av_mutedDidChange(_:)), name: SJMediaPlayerMutedDidChangeNotification, object: nil)
        if #available(iOS 14.2, *) {
            center.addObserver(self, selector: #selector(_av_assetStatusDidChange(_:)), name: SJMediaPlayerAssetStatusDidChangeNotification, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: -

    public override func player(withMedia media: SJVideoPlayerURLAsset, completionHandler: @escaping (SJMediaPlayer?) -> Void) {
        nonisolated(unsafe) let m = media
        nonisolated(unsafe) let ch = completionHandler
        DispatchQueue.global().async { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let player = SJAVMediaPlayerLoader.loadPlayer(forMedia: m)
                player?.minBufferedDuration = self.minBufferedDuration
                player?.accurateSeeking = self.accurateSeeking

                if let player = player,
                   (player.isPlayed && m.original == nil) || player.isPlaybackFinished {
                    nonisolated(unsafe) let p = player
                    player.seek(toTime: .zero) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ch(p)
                        }
                    }
                } else {
                    nonisolated(unsafe) let p = player
                    DispatchQueue.main.async {
                        ch(p)
                    }
                }
            }
        }
    }

    public override func playerView(withPlayer player: SJMediaPlayer) -> UIView & SJMediaPlayerView {
        let view = SJAVMediaPlayerLayerView(frame: .zero)
        view.avPlayerLayer.player = (player as? SJAVMediaPlayer)?.avPlayer
        return view
    }

    @objc public override func receivedApplicationDidBecomeActiveNotification() {
        if #available(iOS 14.0, *) {
            if pictureInPictureController?.isEnabled == true {
                return
            }
        }

        if #available(iOS 14.0, *) {
            if (media as? SJVideoPlayerURLAsset)?.isM3u8 == true {
                if pauseWhenAppDidEnterBackground ||
                    // fix: https://github.com/changsanjiang/SJVideoPlayer/issues/535
                    timeControlStatus == .paused {
                    if timeControlStatus == .paused {
                        needsToRefresh_fix339 = true
                        return
                    }
                }
            }
        }

        let view = sj_currentPlayerView
        view?.avPlayerLayer.player = sj_currentPlayer?.avPlayer

        // fix: https://github.com/changsanjiang/SJVideoPlayer/issues/395
        if sj_currentPlayerView?.isReadyForDisplay == true {
            sj_currentPlayerView?.setScreenshot(nil)
        }
    }

    @objc public override func receivedApplicationDidEnterBackgroundNotification() {
        if #available(iOS 14.0, *) {
            if pictureInPictureController?.isEnabled == true {
                return
            }
        }

        if pauseWhenAppDidEnterBackground {
            pause()
        } else {
            removePlayerForLayerIfNeeded()
        }
    }

    @objc public override func receivedApplicationWillResignActiveNotification() {
        if #available(iOS 14.0, *) {
            if pictureInPictureController?.isEnabled == true {
                return
            }
        }

        if pauseWhenAppDidEnterBackground && assetStatus == .readyToPlay /*fix #430 */ {
            sj_currentPlayerView?.setScreenshot(screenshot())
        }

        // 修复 14.0 后台播放失效的问题
        if #available(iOS 14.0, *) {
            removePlayerForLayerIfNeeded()
        }
    }

    @objc public override func replaceMedia(forDefinitionMedia definitionMedia: SJVideoPlayerURLAsset) {
        if #available(iOS 14.0, *) {
            cancelPictureInPicture()
        }
        if let media = media {
            SJAVMediaPlayerLoader.clearPlayer(forMedia: media as? SJVideoPlayerURLAsset)
        }
        super.replaceMedia(forDefinitionMedia: definitionMedia)
    }

    // MARK: - PiP

    @available(iOS 14.0, *)
    @objc public override func isPictureInPictureSupported() -> Bool {
        return SJAVPictureInPictureController.isPictureInPictureSupported()
    }

    @available(iOS 14.0, *)
    @objc public override var requiresLinearPlaybackInPictureInPicture: Bool {
        get { super.requiresLinearPlaybackInPictureInPicture }
        set {
            super.requiresLinearPlaybackInPictureInPicture = newValue
            pictureInPictureController?.requiresLinearPlayback = newValue
        }
    }

    @available(iOS 14.0, *)
    @objc public override var pictureInPictureStatus: SJPictureInPictureStatus {
        return pictureInPictureController?.status ?? .unknown
    }

    @available(iOS 14.2, *)
    @objc public override var canStartPictureInPictureAutomaticallyFromInline: Bool {
        get { super.canStartPictureInPictureAutomaticallyFromInline }
        set {
            super.canStartPictureInPictureAutomaticallyFromInline = newValue
            pictureInPictureController?.canStartPictureInPictureAutomaticallyFromInline = newValue
            if newValue { prepareForPictureInPicture() }
        }
    }

    @available(iOS 14.0, *)
    @objc public func prepareForPictureInPicture() {
        if pictureInPictureController == nil && assetStatus == .readyToPlay {
            guard let layer = sj_currentPlayerView?.avPlayerLayer else { return }
            let controller = SJAVPictureInPictureController(layer: layer, delegate: self)
            controller?.requiresLinearPlayback = requiresLinearPlaybackInPictureInPicture
            if #available(iOS 14.2, *) {
                controller?.canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline
            }
            pictureInPictureController = controller
        }
    }

    @available(iOS 14.0, *)
    @objc public override func startPictureInPicture() {
        if sj_currentPlayerView != nil {
            prepareForPictureInPicture()
            pictureInPictureController?.startPictureInPicture()
        }
    }

    @available(iOS 14.0, *)
    @objc public override func stopPictureInPicture() {
        pictureInPictureController?.stopPictureInPicture()
    }

    @available(iOS 14.0, *)
    @objc public override func cancelPictureInPicture() {
        pictureInPictureController?.stopPictureInPicture()
        pictureInPictureController = nil
    }

    @available(iOS 14.0, *)
    public func pictureInPictureController(_ controller: SJPictureInPictureController, statusDidChange status: SJPictureInPictureStatus) {
        if let delegate = delegate,
           delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:pictureInPictureStatusDidChange:))) {
            delegate.playbackController?(self, pictureInPictureStatusDidChange: status)
        }
    }

    @available(iOS 14.0, *)
    public func pictureInPictureController(_ controller: SJPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        if let restore = restoreUserInterfaceForPictureInPictureStop {
            restore(self, completionHandler)
        } else {
            completionHandler(false)
        }
    }

    // MARK: -

    @objc public override func seek(toTime time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)?) {
        var time = time
        if let media = media, media.trialEndPosition != 0, CMTimeGetSeconds(time) >= media.trialEndPosition {
            time = CMTimeMakeWithSeconds(media.trialEndPosition * 0.98, preferredTimescale: Int32(NSEC_PER_SEC))
        }
        sj_currentPlayer?.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
    }

    @objc public override var durationWatched: TimeInterval {
        var time: TimeInterval = 0
        let events = sj_currentPlayer?.avPlayer.currentItem?.accessLog()?.events ?? []
        for event in events {
            if event.durationWatched <= 0 { continue }
            time += event.durationWatched
        }
        return time
    }

    @objc public override var minBufferedDuration: TimeInterval {
        get { super.minBufferedDuration }
        set {
            super.minBufferedDuration = newValue
            sj_currentPlayer?.minBufferedDuration = newValue
        }
    }

    @objc public override func refresh() {
        if let media = media {
            SJAVMediaPlayerLoader.clearPlayer(forMedia: media as? SJVideoPlayerURLAsset)
        }
        if #available(iOS 14.0, *) {
            needsToRefresh_fix339 = false
            cancelPictureInPicture()
        }
        cancelGenerateGIFOperation()
        cancelExportOperation()
        super.refresh()
    }

    @objc public override func play() {
        if #available(iOS 14.0, *) {
            needsToRefresh_fix339 ? refresh() : super.play()
        } else {
            super.play()
        }
    }

    @objc public override func stop() {
        cancelGenerateGIFOperation()
        cancelExportOperation()
        if #available(iOS 14.0, *) {
            needsToRefresh_fix339 = false
            cancelPictureInPicture()
        }
        super.stop()
    }

    @objc public override var playbackType: SJPlaybackType {
        return sj_currentPlayer?.playbackType ?? .unknown
    }

    // MARK: - 通知处理

    @objc private func _av_playbackTypeDidChange(_ note: Notification) {
        if (note.object as AnyObject?) === sj_currentPlayer {
            if let delegate = delegate,
               delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:playbackTypeDidChange:))) {
                delegate.playbackController?(self, playbackTypeDidChange: playbackType)
            }
        }
    }

    @objc private func _av_playerViewReadyForDisplay(_ note: Notification) {
        if (sj_currentPlayerView as AnyObject?) === (note.object as AnyObject?) {
            if sj_currentPlayerView?.isReadyForDisplay == true {
                sj_currentPlayerView?.setScreenshot(nil)
            }
        }
    }

    @objc private func _av_rateDidChange(_ note: Notification) {
        if (sj_currentPlayer as AnyObject?) === (note.object as AnyObject?),
           let player = sj_currentPlayer, rate != player.rate {
            rate = player.rate
        }
    }

    @objc private func _av_volumeDidChange(_ note: Notification) {
        if (sj_currentPlayer as AnyObject?) === (note.object as AnyObject?),
           let player = sj_currentPlayer, volume != player.volume {
            volume = player.volume
        }
    }

    @objc private func _av_mutedDidChange(_ note: Notification) {
        if (sj_currentPlayer as AnyObject?) === (note.object as AnyObject?),
           let player = sj_currentPlayer, isMuted != player.isMuted {
            isMuted = player.isMuted
        }
    }

    @available(iOS 14.2, *)
    @objc private func _av_assetStatusDidChange(_ note: Notification) {
        if (sj_currentPlayer as AnyObject?) === (note.object as AnyObject?),
           canStartPictureInPictureAutomaticallyFromInline, assetStatus == .readyToPlay {
            prepareForPictureInPicture()
        }
    }

    private func removePlayerForLayerIfNeeded() {
        if pauseWhenAppDidEnterBackground { return }

        if #available(iOS 14.0, *) {
            if pictureInPictureController != nil && timeControlStatus != .paused {
                return
            }
        }

        sj_currentPlayerView?.avPlayerLayer.player = nil
    }
}

// MARK: - SJAVMediaPlaybackAdd (导出/截图/GIF)

extension SJAVMediaPlaybackController: SJMediaPlaybackExportController, SJMediaPlaybackScreenshotController {

    @objc(screenshotWithTime:size:completion:)
    public func screenshot(withTime time: TimeInterval,
                           size: CGSize,
                           completion block: @escaping (SJVideoPlayerPlaybackController, UIImage?, Error?) -> Void) {
        sj_currentPlayer?.avPlayer.currentItem?.asset.sj_screenshot(with: time, size: size) { [weak self] _, image, error in
            guard let self = self else { return }
            block(self, image, error)
        }
    }

    @objc(exportWithBeginTime:duration:presetName:progress:completion:failure:)
    public func export(withBeginTime beginTime: TimeInterval,
                       duration: TimeInterval,
                       presetName: String?,
                       progress progressBlock: @escaping (SJVideoPlayerPlaybackController, Float) -> Void,
                       completion completionBlock: @escaping (SJVideoPlayerPlaybackController, URL?, UIImage?) -> Void,
                       failure failureBlock: @escaping (SJVideoPlayerPlaybackController, Error?) -> Void) {
        cancelExportOperation()
        let exportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Export.mp4")
        guard let exportURL = exportURL else { return }
        try? FileManager.default.removeItem(at: exportURL)
        sj_currentPlayer?.avPlayer.currentItem?.asset.sj_export(startTime: beginTime, duration: duration, toFile: exportURL, presetName: presetName, progress: { [weak self] _, progress in
            guard let self = self else { return }
            progressBlock(self, progress)
        }, success: { [weak self] _, _, fileURL, thumbImage in
            guard let self = self else { return }
            completionBlock(self, fileURL, thumbImage)
        }, failure: { [weak self] _, error in
            guard let self = self else { return }
            failureBlock(self, error)
        })
    }

    @objc(generateGIFWithBeginTime:duration:maximumSize:interval:gifSavePath:progress:completion:failure:)
    public func generateGIF(withBeginTime beginTime: TimeInterval,
                            duration: TimeInterval,
                            maximumSize: CGSize,
                            interval: Float,
                            gifSavePath: URL,
                            progress progressBlock: @escaping (SJVideoPlayerPlaybackController, Float) -> Void,
                            completion: @escaping (SJVideoPlayerPlaybackController, UIImage, UIImage) -> Void,
                            failure: @escaping (SJVideoPlayerPlaybackController, Error) -> Void) {
        cancelGenerateGIFOperation()
        sj_currentPlayer?.avPlayer.currentItem?.asset.sj_generateGIF(beginTime: beginTime, duration: duration, imageMaxSize: maximumSize, interval: interval, toFile: gifSavePath, progress: { [weak self] _, progress in
            guard let self = self else { return }
            progressBlock(self, progress)
        }, success: { [weak self] _, gifImage, thumbnailImage in
            guard let self = self else { return }
            completion(self, gifImage, thumbnailImage)
        }, failure: { [weak self] _, error in
            guard let self = self else { return }
            failure(self, error)
        })
    }

    @objc(cancelExportOperation)
    public func cancelExportOperation() {
        sj_currentPlayer?.avPlayer.currentItem?.asset.sj_cancelExportOperation()
    }

    @objc(cancelGenerateGIFOperation)
    public func cancelGenerateGIFOperation() {
        sj_currentPlayer?.avPlayer.currentItem?.asset.sj_cancelGenerateGIFOperation()
    }
}

