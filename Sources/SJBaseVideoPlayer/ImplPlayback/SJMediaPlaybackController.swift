//
//  SJMediaPlaybackController.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/17.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import UIKit
@preconcurrency import AVFoundation

// MARK: - 通知名 (本块定义, 供子类/播放器发送)

public let SJMediaPlayerAssetStatusDidChangeNotification = Notification.Name("SJMediaPlayerAssetStatusDidChangeNotification")
public let SJMediaPlayerTimeControlStatusDidChangeNotification = Notification.Name("SJMediaPlayerTimeControlStatusDidChangeNotification")
public let SJMediaPlayerPresentationSizeDidChangeNotification = Notification.Name("SJMediaPlayerPresentationSizeDidChangeNotification")
public let SJMediaPlayerPlaybackDidFinishNotification = Notification.Name("SJMediaPlayerPlaybackDidFinishNotification")
public let SJMediaPlayerDidReplayNotification = Notification.Name("SJMediaPlayerDidReplayNotification")
public let SJMediaPlayerDurationDidChangeNotification = Notification.Name("SJMediaPlayerDurationDidChangeNotification")
public let SJMediaPlayerPlayableDurationDidChangeNotification = Notification.Name("SJMediaPlayerPlayableDurationDidChangeNotification")
public let SJMediaPlayerRateDidChangeNotification = Notification.Name("SJMediaPlayerRateDidChangeNotification")
public let SJMediaPlayerVolumeDidChangeNotification = Notification.Name("SJMediaPlayerVolumeDidChangeNotification")
public let SJMediaPlayerMutedDidChangeNotification = Notification.Name("SJMediaPlayerMutedDidChangeNotification")
public let SJMediaPlayerViewReadyForDisplayNotification = Notification.Name("SJMediaPlayerViewReadyForDisplayNotification")
/// 这个通知是可选的(如果可以获取到 playbackType, 请发送该通知)
public let SJMediaPlayerPlaybackTypeDidChangeNotification = Notification.Name("SJMediaPlayerPlaybackTypeDidChangeNotification")

// MARK: - SJMediaPlayerView / SJMediaPlayer 协议

/// 注: 原 ObjC 协议为 @objc<SJMediaPlayerView>。Swift 6.3 端 `SJMediaPlayerView`
/// 与实现类(SJAVMediaPlayerLayerView)均在 @MainActor 隔离域运行, 故协议标 @MainActor
/// 以避免 "conformance crosses into main actor-isolated code"。
/// 该协议仅在 module 内部使用(对外通过 SJAVMediaPlaybackController.sj_currentPlayerView 暴露),
/// 因此不再 @objc。
@MainActor
public protocol SJMediaPlayerView: NSObjectProtocol {
    var videoGravity: SJVideoGravity { get set }
    var isReadyForDisplay: Bool { get }
}

/// 注: 原 ObjC 协议为 @objc<SJMediaPlayer>。Swift 6.3 端 `SJMediaPlayer` 含 `seekingInfo`,
/// 其类型 `SJSeekingInfo` 在端口层已改为 Swift struct(无法 @objc 暴露), 故该协议整体不再 @objc;
/// 同时实现类(SJAVMediaPlayer)在 @MainActor 隔离域运行, 协议标 @MainActor 以闭环主线程语义。
/// 该协议仅在 module 内部使用(对外通过 SJAVMediaPlaybackController.sj_currentPlayer 暴露)。
@MainActor
public protocol SJMediaPlayer: NSObjectProtocol {
    var error: Error? { get }
    var reasonForWaitingToPlay: SJWaitingReason? { get }
    var timeControlStatus: SJPlaybackTimeControlStatus { get }
    var assetStatus: SJAssetStatus { get }
    var seekingInfo: SJSeekingInfo { get }
    var presentationSize: CGSize { get }
    var isReplayed: Bool { get }   ///< 是否调用过 `replay` 方法
    var isPlayed: Bool { get }     ///< 是否调用过 `play` 方法
    var isPlaybackFinished: Bool { get }              ///< 播放结束
    var finishedReason: SJFinishedReason? { get }     ///< 播放结束的 reason
    var trialEndPosition: TimeInterval { get set }    ///< 试用结束的位置, 单位秒
    var rate: Float { get set }
    var volume: Float { get set }
    var isMuted: Bool { get set }

    func seek(toTime time: CMTime, completionHandler: ((Bool) -> Void)?)

    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playableDuration: TimeInterval { get }

    func play()
    func pause()
    func replay()
    func report()

    func screenshot() -> UIImage?
}

// MARK: - 周期时间观察者

@MainActor
private final class SJMediaPlayerTimeObserverItem: NSObject {
    private var currentTimeDidChangeExeBlock: ((TimeInterval) -> Void)?
    private var playableDurationDidChangeExeBlock: ((TimeInterval) -> Void)?
    private var durationDidChangeExeBlock: ((TimeInterval) -> Void)?
    private weak var player: (any SJMediaPlayer)?
    private let interval: TimeInterval

    private var timer: Timer?
    private var currentTimeValue: TimeInterval = 0

    init(interval: TimeInterval,
         player: (any SJMediaPlayer)?,
         currentTimeDidChangeExeBlock: @escaping (TimeInterval) -> Void,
         playableDurationDidChangeExeBlock: @escaping (TimeInterval) -> Void,
         durationDidChangeExeBlock: @escaping (TimeInterval) -> Void) {
        self.interval = interval
        self.player = player
        self.currentTimeDidChangeExeBlock = currentTimeDidChangeExeBlock
        self.playableDurationDidChangeExeBlock = playableDurationDidChangeExeBlock
        self.durationDidChangeExeBlock = durationDidChangeExeBlock
        super.init()

        resumeOrPause()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(resumeOrPause), name: SJMediaPlayerTimeControlStatusDidChangeNotification, object: player)
        center.addObserver(self, selector: #selector(durationDidChange), name: SJMediaPlayerDurationDidChangeNotification, object: player)
        center.addObserver(self, selector: #selector(playableDurationDidChange), name: SJMediaPlayerPlayableDurationDidChangeNotification, object: player)
    }

    deinit {
        // 注: timer 为 @MainActor 隔离的非 Sendable 属性, 不能在 nonisolated deinit 中访问。
        // 正常生命周期里 owner 会先调用 invalidate()/stop() 使 timer 失效;
        // 即便未失效, 触发块持 [weak self], self 释放后会自行 t.invalidate()(见 resumeOrPause)。
        NotificationCenter.default.removeObserver(self)
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func durationDidChange() {
        durationDidChangeExeBlock?(player?.duration ?? 0)
    }

    @objc private func playableDurationDidChange() {
        playableDurationDidChangeExeBlock?(player?.playableDuration ?? 0)
    }

    @objc func resumeOrPause() {
        if player?.timeControlStatus == .paused {
            invalidate()
        } else if timer == nil {
            let t = Timer.sj_timer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                MainActor.assumeIsolated {
                    guard let self = self else { timer.invalidate(); return }
                    self._refresh()
                }
            }
            t.fireDate = Date(timeIntervalSinceNow: interval)
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    func stop() {
        invalidate()
        playableDurationDidChangeExeBlock?(0)
        currentTimeDidChangeExeBlock?(0)
        durationDidChangeExeBlock?(0)
    }

    private func _refresh() {
        let currentTime = player?.currentTime ?? 0
        if currentTimeValue != currentTime {
            currentTimeValue = currentTime
            currentTimeDidChangeExeBlock?(currentTime)
        }
    }
}

// MARK: - 播放器内容容器视图

@MainActor
private final class SJMediaPlayerContentView: UIView {
    private var _view: (UIView & SJMediaPlayerView)?
    var view: (UIView & SJMediaPlayerView)? {
        get { _view }
        set {
            _view?.removeFromSuperview()
            _view = newValue
            if let v = newValue {
                v.frame = bounds
                v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(v)
            }
        }
    }
}

// MARK: - SJMediaPlaybackController

@objc(SJMediaPlaybackController)
@MainActor
open class SJMediaPlaybackController: NSObject, SJVideoPlayerPlaybackController {
    /// 协议要求 `media: SJMediaModelProtocol?`(对应原 ObjC `id<SJMediaModelProtocol> media`)。
    /// 实际承载类型恒为 `SJVideoPlayerURLAsset`(本生态唯一实现), 内部通过 `currentMedia` 取强类型。
    @objc public var media: SJMediaModelProtocol? {
        didSet {
            // setMedia: 若已有 media 则先 stop (replaceMedia 走旁路, 不触发 stop)
            if bypassStopOnNextSet { return }
            if oldValue != nil { stop() }
        }
    }

    /// 强类型便捷访问(等价 ObjC 端 `SJVideoPlayerURLAsset *media` 的协变声明)。
    private var currentMedia: SJVideoPlayerURLAsset? {
        media as? SJVideoPlayerURLAsset
    }

    /// 当前的播放器
    /// 注: `SJMediaPlayer` 端口层不再 @objc(见上方协议说明), 故该属性为 Swift-only;
    /// 对外的 ObjC 访问通过子类 SJAVMediaPlaybackController.sj_currentPlayer 提供。
    public private(set) var currentPlayer: (any SJMediaPlayer)?

    public var currentPlayerView: (UIView & SJMediaPlayerView)? {
        get { _playerView?.view }
        set {
            newValue?.videoGravity = videoGravity
            _playerView?.view = newValue
        }
    }

    /// PiP
    @objc public var restoreUserInterfaceForPictureInPictureStop: ((any SJVideoPlayerPlaybackController, @escaping (Bool) -> Void) -> Void)?

    // MARK: SJVideoPlayerPlaybackController 必需属性

    @objc public var periodicTimeInterval: TimeInterval = 0.5 {
        didSet {
            _removePeriodicTimeObserver()
            _addPeriodicTimeObserver()
        }
    }
    @objc public var minBufferedDuration: TimeInterval = 0
    @objc public weak var delegate: (any SJVideoPlayerPlaybackControllerDelegate)?
    @objc public var pauseWhenAppDidEnterBackground: Bool = true

    @objc public private(set) var timeControlStatus: SJPlaybackTimeControlStatus = .paused {
        didSet {
            if timeControlStatus == .paused { reasonForWaitingToPlay = nil }
            let status = timeControlStatus
            DispatchQueue.main.async { [weak self] in
                UIApplication.shared.isIdleTimerDisabled = (status != .paused)
                guard let self = self else { return }
                if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:timeControlStatusDidChange:))) {
                    delegate.playbackController?(self, timeControlStatusDidChange: status)
                }
            }
        }
    }

    @objc public private(set) var reasonForWaitingToPlay: SJWaitingReason?

    private var _videoGravity: SJVideoGravity?
    @objc public var videoGravity: SJVideoGravity {
        get { _videoGravity ?? .resizeAspect }
        set {
            _videoGravity = newValue
            currentPlayerView?.videoGravity = videoGravity
        }
    }

    @objc public var volume: Float = 1 {
        didSet {
            currentPlayer?.volume = volume
            if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:volumeDidChange:))) {
                delegate.playbackController?(self, volumeDidChange: volume)
            }
        }
    }

    @objc public var rate: Float = 1 {
        didSet {
            if timeControlStatus != .paused { currentPlayer?.rate = rate }
            if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:rateDidChange:))) {
                delegate.playbackController?(self, rateDidChange: rate)
            }
        }
    }

    @objc public var isMuted: Bool = false {
        didSet {
            currentPlayer?.isMuted = isMuted
            if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:mutedDidChange:))) {
                delegate.playbackController?(self, mutedDidChange: isMuted)
            }
        }
    }

    // MARK: 私有

    private var _playerViewStorage: SJMediaPlayerContentView?
    private var _playerView: SJMediaPlayerContentView? {
        return _playerViewStorage
    }
    private var periodicTimeObserver: SJMediaPlayerTimeObserverItem?
    private var definitionMediaPlayerLoader: SJDefinitionMediaPlayerLoader?
    private var definitionMedia: SJVideoPlayerURLAsset?

    @objc public override init() {
        super.init()
        _initObservations()
    }

    deinit {
        #if DEBUG
        print("\(#line) - \(#function)")
        #endif
        let pv = _playerViewStorage
        // 与 ObjC 一致: 主线程移除视图
        if Thread.isMainThread {
            MainActor.assumeIsolated { pv?.removeFromSuperview() }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { pv?.removeFromSuperview() }
            }
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 子类返回

    /// 注: 入参/返回含 `SJMediaPlayer`/`SJMediaPlayerView`(端口层不再 @objc), 故为 Swift-only 重写点。
    open func player(withMedia media: SJVideoPlayerURLAsset, completionHandler: @escaping ((any SJMediaPlayer)?) -> Void) {
        fatalError("You must override \(#function) in a subclass.")
    }

    /// 注: 入参/返回含 `SJMediaPlayer`/`SJMediaPlayerView`(端口层不再 @objc), 故为 Swift-only 重写点。
    open func playerView(withPlayer player: any SJMediaPlayer) -> (UIView & SJMediaPlayerView) {
        fatalError("You must override \(#function) in a subclass.")
    }

    // MARK: - 应用通知回调 (子类可重写)

    @objc open func receivedApplicationDidBecomeActiveNotification() {}
    @objc open func receivedApplicationWillResignActiveNotification() {}
    @objc open func receivedApplicationWillEnterForegroundNotification() {}
    @objc open func receivedApplicationDidEnterBackgroundNotification() {
        if pauseWhenAppDidEnterBackground { pause() }
    }

    // MARK: - 准备播放

    @objc open func prepareToPlay() {
        guard let media = currentMedia else { return }
        player(withMedia: media) { [weak self] player in
            guard let self = self else { return }
            if self.currentMedia !== media { return }
            guard let player = player else { return }
            player.trialEndPosition = media.trialEndPosition
            self.setCurrentPlayer(player)
            self.currentPlayerView = self.playerView(withPlayer: player)
        }
    }

    // MARK: - PiP (基类不支持)

    @available(iOS 14.0, *)
    @objc open func isPictureInPictureSupported() -> Bool {
        #if DEBUG
        print("\(NSStringFromClass(type(of: self))) 暂不支持画中画")
        #endif
        return false
    }

    @available(iOS 14.0, *)
    @objc open var pictureInPictureStatus: SJPictureInPictureStatus {
        #if DEBUG
        print("\(NSStringFromClass(type(of: self))) 暂不支持画中画")
        #endif
        return .unknown
    }

    @objc public var requiresLinearPlaybackInPictureInPicture: Bool = false
    @objc public var canStartPictureInPictureAutomaticallyFromInline: Bool = false

    @available(iOS 14.0, *)
    @objc open func startPictureInPicture() {
        #if DEBUG
        print("\(NSStringFromClass(type(of: self))) 暂不支持画中画")
        #endif
    }

    @available(iOS 14.0, *)
    @objc open func stopPictureInPicture() {
        #if DEBUG
        print("\(NSStringFromClass(type(of: self))) 暂不支持画中画")
        #endif
    }

    @available(iOS 14.0, *)
    @objc open func cancelPictureInPicture() {
        #if DEBUG
        print("\(NSStringFromClass(type(of: self))) 暂不支持画中画")
        #endif
    }

    // MARK: - 播放控制

    @objc open func pause() {
        timeControlStatus = .paused
        currentPlayer?.pause()
    }

    @objc open func play() {
        if assetStatus == .failed {
            refresh()
            return
        }

        // no item to play
        if currentPlayer == nil {
            reasonForWaitingToPlay = SJWaitingWithNoAssetToPlayReason
            timeControlStatus = .waitingToPlay
        } else {
            reasonForWaitingToPlay = SJWaitingWhileEvaluatingBufferingRateReason
            timeControlStatus = .waitingToPlay
            if isPlaybackFinished {
                currentPlayer?.replay()
            } else {
                currentPlayer?.play()
            }
            if currentPlayer?.rate != rate { currentPlayer?.rate = rate }
            _toEvaluating()
        }
    }

    @objc open func replay() {
        if assetStatus == .failed {
            refresh()
            return
        }
        if currentPlayer == nil { return }

        reasonForWaitingToPlay = SJWaitingWhileEvaluatingBufferingRateReason
        timeControlStatus = .waitingToPlay
        currentPlayer?.replay()
        _toEvaluating()
    }

    @objc open func stop() {
        definitionMediaPlayerLoader?.cancel()
        definitionMediaPlayerLoader = nil
        definitionMedia = nil
        currentPlayerView?.removeFromSuperview()
        _playerViewStorage?.view = nil
        setCurrentPlayer(nil)
        media = nil
        periodicTimeObserver?.stop()
        _removePeriodicTimeObserver()
        if timeControlStatus != .paused {
            timeControlStatus = .paused
        }
    }

    @objc open func refresh() {
        if let player = currentPlayer, player.isPlayed, duration != 0, currentTime != 0 {
            media?.startPosition = currentTime
        }
        setCurrentPlayer(nil)
        prepareToPlay()
        play()
    }

    @objc open func screenshot() -> UIImage? {
        return currentPlayer?.screenshot()
    }

    @objc open func seek(toTime secs: TimeInterval, completionHandler: ((Bool) -> Void)?) {
        seek(toTime: CMTimeMakeWithSeconds(secs, preferredTimescale: Int32(NSEC_PER_SEC)),
             toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completionHandler)
    }

    @objc open func seek(toTime time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)?) {
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:willSeekToTime:))) {
            delegate.playbackController?(self, willSeekToTime: time)
        }
        currentPlayer?.seek(toTime: time) { [weak self] finished in
            guard let self = self else { return }
            completionHandler?(finished)
            if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:didSeekToTime:))) {
                delegate.playbackController?(self, didSeekToTime: time)
            }
        }
    }

    // MARK: - 清晰度切换

    @objc open func switchVideoDefinition(_ media: any SJMediaModelProtocol) {
        guard let media = media as? SJVideoPlayerURLAsset else { return }

        // clean
        if definitionMediaPlayerLoader != nil {
            definitionMediaPlayerLoader?.cancel()
            definitionMediaPlayerLoader = nil
        }

        guard currentPlayer != nil else { return }

        definitionMedia = media

        // reset status
        _definitionMedia(media, switchStatusDidChange: .unknown)
        // begin
        _definitionMedia(media, switchStatusDidChange: .switching)

        // load
        player(withMedia: media) { [weak self] player in
            guard let self = self else { return }
            if media != self.definitionMedia { return }
            guard let player = player else { return }

            let definitionMediaPlayer = player
            let definitionMediaPlayerView = self.playerView(withPlayer: player)
            guard let currentPlayer = self.currentPlayer, let currentPlayerView = self.currentPlayerView else { return }

            self.definitionMediaPlayerLoader = SJDefinitionMediaPlayerLoader(
                definitionMediaPlayer: definitionMediaPlayer,
                definitionMediaPlayerView: definitionMediaPlayerView,
                currentPlayer: currentPlayer,
                currentPlayerView: currentPlayerView) { [weak self] loader, isFinished in
                guard let self = self else { return }
                if media != self.definitionMedia { return }
                self.definitionMedia = nil
                self.definitionMediaPlayerLoader = nil
                if !isFinished {
                    self._definitionMedia(media, switchStatusDidChange: .failed)
                } else {
                    let newPlayer = loader.definitionMediaPlayer
                    let newMedia = media
                    self.replaceMedia(forDefinitionMedia: newMedia)

                    let oldPlayer = self.currentPlayer
                    self.setCurrentPlayer(newPlayer)
                    self.currentPlayerView = definitionMediaPlayerView
                    oldPlayer?.pause()
                    if self.timeControlStatus != .paused {
                        newPlayer?.play()
                    } else {
                        newPlayer?.pause()
                    }
                    self._definitionMedia(media, switchStatusDidChange: .finished)
                }
            }
        }
    }

    /// 该方法通知子类, 切换清晰度即将完成, 将要设置 media 为新的清晰度资源
    @objc open func replaceMedia(forDefinitionMedia definitionMedia: SJVideoPlayerURLAsset) {
        // 直接赋值底层存储, 避免触发 setMedia: 的 stop 逻辑
        setMediaWithoutStop(definitionMedia)
    }

    private func setMediaWithoutStop(_ newMedia: SJVideoPlayerURLAsset?) {
        // 通过 willSet/didSet 旁路: 利用一个标志位实现等价于 ObjC 直接 _media = xxx
        bypassStopOnNextSet = true
        media = newMedia
        bypassStopOnNextSet = false
    }
    private var bypassStopOnNextSet = false

    // MARK: - 只读状态

    @objc public var assetStatus: SJAssetStatus {
        return currentPlayer?.assetStatus ?? .unknown
    }

    @objc public var currentTime: TimeInterval {
        guard let p = currentPlayer else { return 0 }
        return p.seekingInfo.isSeeking ? CMTimeGetSeconds(p.seekingInfo.time) : p.currentTime
    }

    @objc public var duration: TimeInterval {
        return currentPlayer?.duration ?? 0
    }

    @objc public var durationWatched: TimeInterval {
        return 0
    }

    @objc public var error: Error? {
        return currentPlayer?.error
    }

    @objc public var isPlayed: Bool {
        return currentPlayer?.isPlayed ?? false
    }

    @objc public var isReplayed: Bool {
        return currentPlayer?.isReplayed ?? false
    }

    @objc public var isPlaybackFinished: Bool {
        return currentPlayer?.isPlaybackFinished ?? false
    }

    @objc public var finishedReason: SJFinishedReason? {
        return currentPlayer?.finishedReason
    }

    @objc public var playableDuration: TimeInterval {
        return currentPlayer?.playableDuration ?? 0
    }

    @objc open var playbackType: SJPlaybackType {
        return .unknown
    }

    @objc public var isReadyForDisplay: Bool {
        return currentPlayerView?.isReadyForDisplay ?? false
    }

    @objc public var presentationSize: CGSize {
        return currentPlayer?.presentationSize ?? .zero
    }

    @objc public var playerView: UIView {
        if _playerViewStorage == nil {
            _playerViewStorage = SJMediaPlayerContentView(frame: .zero)
        }
        return _playerViewStorage!
    }

    // MARK: - 设置 currentPlayer

    private func setCurrentPlayer(_ player: (any SJMediaPlayer)?) {
        currentPlayer = player
        if let player = player {
            player.volume = volume
            player.isMuted = isMuted
            if timeControlStatus != .paused { player.rate = rate }
            _addPeriodicTimeObserver()
            player.report()
        }
    }

    // MARK: - 评估

    private func _toEvaluating() {
        if assetStatus == .failed {
            timeControlStatus = .paused
        }

        if currentPlayer?.isPlaybackFinished == true {
            timeControlStatus = .paused
        }

        if timeControlStatus == .paused && currentPlayer?.timeControlStatus != .playing {
            return
        }

        // 处于准备 | 失败中
        if currentPlayer?.assetStatus != .readyToPlay {
            return
        }

        if reasonForWaitingToPlay == SJWaitingWithNoAssetToPlayReason {
            currentPlayer?.play()
        }

        if timeControlStatus != currentPlayer?.timeControlStatus ||
           reasonForWaitingToPlay != currentPlayer?.reasonForWaitingToPlay {
            reasonForWaitingToPlay = currentPlayer?.reasonForWaitingToPlay
            if let s = currentPlayer?.timeControlStatus { timeControlStatus = s }
        }
    }

    private func _definitionMedia(_ media: any SJMediaModelProtocol, switchStatusDidChange status: SJDefinitionSwitchStatus) {
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:switchingDefinitionStatusDidChange:media:))) {
            delegate.playbackController?(self, switchingDefinitionStatusDidChange: status, media: media)
        }
    }

    // MARK: - 周期时间观察者

    private func _addPeriodicTimeObserver() {
        periodicTimeObserver = SJMediaPlayerTimeObserverItem(
            interval: periodicTimeInterval,
            player: currentPlayer,
            currentTimeDidChangeExeBlock: { [weak self] time in
                guard let self = self else { return }
                if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:currentTimeDidChange:))) {
                    delegate.playbackController?(self, currentTimeDidChange: time)
                }
            },
            playableDurationDidChangeExeBlock: { [weak self] time in
                guard let self = self else { return }
                if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:playableDurationDidChange:))) {
                    delegate.playbackController?(self, playableDurationDidChange: time)
                }
            },
            durationDidChangeExeBlock: { [weak self] time in
                guard let self = self else { return }
                if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:durationDidChange:))) {
                    delegate.playbackController?(self, durationDidChange: time)
                }
            })
    }

    private func _removePeriodicTimeObserver() {
        periodicTimeObserver?.invalidate()
        periodicTimeObserver = nil
    }

    // MARK: - 通知注册

    private func _initObservations() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(playerAssetStatusDidChange(_:)), name: SJMediaPlayerAssetStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(playerTimeControlStatusDidChange(_:)), name: SJMediaPlayerTimeControlStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(playbackDidFinish(_:)), name: SJMediaPlayerPlaybackDidFinishNotification, object: nil)
        center.addObserver(self, selector: #selector(playerPresentationSizeDidChange(_:)), name: SJMediaPlayerPresentationSizeDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(playerViewReadyForDisplay(_:)), name: SJMediaPlayerViewReadyForDisplayNotification, object: nil)
        center.addObserver(self, selector: #selector(playerDidReplay(_:)), name: SJMediaPlayerDidReplayNotification, object: nil)
        center.addObserver(self, selector: #selector(audioSessionInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(audioSessionRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)

        center.addObserver(self, selector: #selector(_receivedApplicationDidBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(_receivedApplicationWillResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(_receivedApplicationWillEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
        center.addObserver(self, selector: #selector(_receivedApplicationDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func _receivedApplicationDidBecomeActiveNotification() {
        receivedApplicationDidBecomeActiveNotification()
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.applicationDidBecomeActive(withPlaybackController:))) {
            delegate.applicationDidBecomeActive?(withPlaybackController: self)
        }
    }

    @objc private func _receivedApplicationWillResignActiveNotification() {
        receivedApplicationWillResignActiveNotification()
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.applicationWillResignActive(withPlaybackController:))) {
            delegate.applicationWillResignActive?(withPlaybackController: self)
        }
    }

    @objc private func _receivedApplicationWillEnterForegroundNotification() {
        receivedApplicationWillEnterForegroundNotification()
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.applicationWillEnterForeground(withPlaybackController:))) {
            delegate.applicationWillEnterForeground?(withPlaybackController: self)
        }
    }

    @objc private func _receivedApplicationDidEnterBackgroundNotification() {
        receivedApplicationDidEnterBackgroundNotification()
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.applicationDidEnterBackground(withPlaybackController:))) {
            delegate.applicationDidEnterBackground?(withPlaybackController: self)
        }
    }

    @objc private func playerAssetStatusDidChange(_ note: Notification) {
        guard isCurrentPlayer(note.object) else { return }
        _toEvaluating()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let delegate = self.delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:assetStatusDidChange:))) {
                delegate.playbackController?(self, assetStatusDidChange: self.assetStatus)
            }
        }
    }

    @objc private func playerTimeControlStatusDidChange(_ note: Notification) {
        guard isCurrentPlayer(note.object) else { return }
        _toEvaluating()
    }

    @objc private func playbackDidFinish(_ note: Notification) {
        guard isCurrentPlayer(note.object) else { return }
        _toEvaluating()
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:playbackDidFinish:))) {
            delegate.playbackController?(self, playbackDidFinish: finishedReason ?? SJFinishedReasonToEndTimePosition)
        }
    }

    @objc private func playerPresentationSizeDidChange(_ note: Notification) {
        guard isCurrentPlayer(note.object) else { return }
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:presentationSizeDidChange:))) {
            delegate.playbackController?(self, presentationSizeDidChange: presentationSize)
        }
    }

    @objc private func playerViewReadyForDisplay(_ note: Notification) {
        guard let view = note.object as AnyObject?, view === (currentPlayerView as AnyObject?) else { return }
        if let delegate = delegate, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackControllerIsReadyForDisplay(_:))) {
            delegate.playbackControllerIsReadyForDisplay?(self)
        }
    }

    @objc private func playerDidReplay(_ note: Notification) {
        guard isCurrentPlayer(note.object) else { return }
        if let delegate = delegate, let media = media, delegate.responds(to: #selector(SJVideoPlayerPlaybackControllerDelegate.playbackController(_:didReplay:))) {
            delegate.playbackController?(self, didReplay: media)
        }
    }

    @objc private func audioSessionInterruption(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               AVAudioSession.InterruptionType(rawValue: raw) == .began {
                self.pause()
            }
        }
    }

    @objc private func audioSessionRouteChange(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable {
                self.pause()
            }
        }
    }

    private func isCurrentPlayer(_ object: Any?) -> Bool {
        guard let object = object as AnyObject?, let player = currentPlayer as AnyObject? else { return false }
        return object === player
    }
}

// MARK: - 清晰度切换加载控制

@MainActor
private final class SJDefinitionMediaPlayerLoader: NSObject {
    private(set) var definitionMediaPlayer: (any SJMediaPlayer)?
    private(set) var definitionMediaPlayerView: (UIView & SJMediaPlayerView)?
    private(set) var currentPlayer: (any SJMediaPlayer)?
    private(set) var currentPlayerView: (UIView & SJMediaPlayerView)?

    private var completionHandler: ((SJDefinitionMediaPlayerLoader, Bool) -> Void)?
    private var isSeeking = false

    init(definitionMediaPlayer: any SJMediaPlayer,
         definitionMediaPlayerView: UIView & SJMediaPlayerView,
         currentPlayer: any SJMediaPlayer,
         currentPlayerView: UIView & SJMediaPlayerView,
         completionHandler: @escaping (SJDefinitionMediaPlayerLoader, Bool) -> Void) {
        self.definitionMediaPlayer = definitionMediaPlayer
        self.definitionMediaPlayerView = definitionMediaPlayerView
        self.currentPlayer = currentPlayer
        self.currentPlayerView = currentPlayerView
        self.completionHandler = completionHandler
        super.init()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(_statusDidChange), name: SJMediaPlayerAssetStatusDidChangeNotification, object: definitionMediaPlayer)
        center.addObserver(self, selector: #selector(_statusDidChange), name: SJMediaPlayerViewReadyForDisplayNotification, object: definitionMediaPlayerView)

        let superview = currentPlayerView.superview
        definitionMediaPlayerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        definitionMediaPlayerView.frame = superview?.bounds ?? .zero
        superview?.insertSubview(definitionMediaPlayerView, at: 0)

        definitionMediaPlayer.isMuted = true
        definitionMediaPlayer.play()

        _statusDidChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func _statusDidChange() {
        switch definitionMediaPlayer?.assetStatus {
        case .unknown, .preparing, .none:
            break
        case .readyToPlay:
            if definitionMediaPlayerView?.isReadyForDisplay == true && isSeeking == false {
                _seekToCurPos()
            }
        case .failed:
            _didCompleteLoad(false)
        @unknown default:
            break
        }
    }

    private func _seekToCurPos() {
        isSeeking = true
        let pos = currentPlayer?.currentTime ?? 0
        definitionMediaPlayer?.seek(toTime: CMTimeMakeWithSeconds(pos, preferredTimescale: Int32(NSEC_PER_SEC))) { [weak self] finished in
            guard let self = self else { return }
            self._didCompleteLoad(finished)
        }
    }

    private func _didCompleteLoad(_ result: Bool) {
        if result {
            definitionMediaPlayerView?.removeFromSuperview()
            definitionMediaPlayer?.isMuted = false
        } else {
            definitionMediaPlayerView?.removeFromSuperview()
            definitionMediaPlayer?.pause()
            definitionMediaPlayer = nil
        }
        completionHandler?(self, result)
        completionHandler = nil
    }

    func cancel() {
        completionHandler = nil
        definitionMediaPlayerView?.removeFromSuperview()
        definitionMediaPlayer = nil
    }
}

