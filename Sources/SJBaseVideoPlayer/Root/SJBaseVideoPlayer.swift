//
//  SJBaseVideoPlayer.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  GitHub:     https://github.com/changsanjiang/SJBaseVideoPlayer
//  GitHub:     https://github.com/changsanjiang/SJVideoPlayer
//
//  Email:      changsanjiang@gmail.com
//  QQGroup:    930508201
//
//  Swift 6.3 迁移说明:
//  - 由 ObjC 主门面 SJBaseVideoPlayer.h/.m 转换而来。原 25 个 category 用多个
//    `@MainActor extension SJBaseVideoPlayer { }` 还原(分布在 SJBaseVideoPlayer+*.swift)。
//  - 全类 @MainActor 隔离; @objc 选择器与原 ObjC 完全一致, 供仍为 ObjC 的上层(SJVideoPlayer 本库 + Example)调用。
//  - 原 C 结构 _SJPlayerControlInfo 改为私有 Swift struct(无 calloc/free)。
//  - 原 objc_getAssociatedObject 存储的 block 属性改为普通 @MainActor 存储属性, selector 名保持。
//

import UIKit
@preconcurrency import AVFoundation
#if canImport(SnapKit)
import SnapKit
#endif
#if canImport(SJUIKit)
import SJUIKit
#endif

// MARK: - 内部控制信息(原 C 结构 _SJPlayerControlInfo)

/// 对应原 `typedef struct _SJPlayerControlInfo`。
/// 改为私有 Swift struct(值类型存储), 字段与默认值严格照搬原 init()。
struct _SJPlayerControlInfo {
    struct Pan {
        var factor: CGFloat = 667
        /// pan 手势触发过程中的偏移量(secs)
        var offsetTime: TimeInterval = 0
    }
    struct LongPress {
        var initialRate: CGFloat = 0
    }
    struct GestureControl {
        var disabledGestures: SJPlayerGestureTypeMask = []
        var rateWhenLongPressGestureTriggered: CGFloat = 2.0
        var allowHorizontalTriggeringOfPanGesturesInCells: Bool = false
    }
    struct Placeholder {
        var automaticallyHides: Bool = true
        var delayHidden: TimeInterval = 0.8
    }
    struct ScrollControl {
        var isScrollAppeared: Bool = false
        var pausedWhenScrollDisappeared: Bool = true
        var hiddenPlayerViewWhenScrollDisappeared: Bool = true
        var resumePlaybackWhenScrollAppeared: Bool = true
    }
    struct DeviceVolumeAndBrightness {
        var disableBrightnessSetting: Bool = false
        var disableVolumeSetting: Bool = false
    }
    struct PlaybackControl {
        var accurateSeeking: Bool = false
        var autoplayWhenSetNewAsset: Bool = true
        var resumePlaybackWhenAppDidEnterForeground: Bool = false
        var resumePlaybackWhenPlayerHasFinishedSeeking: Bool = true
        var isUserPaused: Bool = false
    }
    struct ControlLayer {
        var pausedToKeepAppearState: Bool = false
    }
    struct AudioSessionControl {
        var isEnabled: Bool = true
    }
    struct FloatSmallViewControl {
        var isAppeared: Bool = false
        var hiddenFloatSmallViewWhenPlaybackFinished: Bool = true
    }

    var pan = Pan()
    var longPress = LongPress()
    var gestureController = GestureControl()
    var placeholder = Placeholder()
    var scrollControl = ScrollControl()
    var deviceVolumeAndBrightness = DeviceVolumeAndBrightness()
    var playbackControl = PlaybackControl()
    var controlLayer = ControlLayer()
    var audioSessionControl = AudioSessionControl()
    var floatSmallViewControl = FloatSmallViewControl()
}

// MARK: - SJBaseVideoPlayer

@MainActor
@objc(SJBaseVideoPlayer)
open class SJBaseVideoPlayer: NSObject {

    // MARK: 内部存储(对应原 ObjC ivar / 关联对象)

    var controlInfo = _SJPlayerControlInfo()

    nonisolated(unsafe) let _view: SJPlayerView
    /// 视频画面的呈现层
    nonisolated(unsafe) let _presentView: SJVideoPlayerPresentView

    /// - 管理对象: 监听 App在前台, 后台, 耳机插拔, 来电等的通知
    var _registrar: SJVideoPlayerRegistrar?

    /// - observe视图的滚动
    var playModelObserver: SJPlayModelPropertiesObserver?
    var viewControllerManager: SJViewControllerManager!

    /// 当前资源是否播放过 (mpc => Media Playback Controller)
    var _mpc_assetObserver: (any SJVideoPlayerURLAssetObserverProtocol)?

    /// device volume And brightness manager
    var _deviceVolumeAndBrightnessController: (any SJDeviceVolumeAndBrightnessController_Protocol)?
    var _deviceVolumeAndBrightnessTargetViewContext: SJDeviceVolumeAndBrightnessTargetViewContext?
    var _deviceVolumeAndBrightnessControllerObserver: (any SJDeviceVolumeAndBrightnessControllerObserver)?

    /// playback controller
    var _error: Error?
    nonisolated(unsafe) var _playbackController: (any SJVideoPlayerPlaybackController)?
    var _URLAsset: SJVideoPlayerURLAsset?

    /// control layer appear manager
    var _controlLayerAppearManager: (any SJControlLayerAppearManager)?
    var _controlLayerAppearManagerObserver: (any SJControlLayerAppearManagerObserver_Protocol)?

    /// rotation manager
    var _rotationManager: (any SJRotationManager_Protocol)?
    var _rotationManagerObserver: (any SJRotationManagerObserver)?

    /// Fit on screen manager
    var _fitOnScreenManager: (any SJFitOnScreenManager_Protocol)?
    var _fitOnScreenManagerObserver: (any SJFitOnScreenManagerObserver_Protocol)?

    /// Flip Transition manager
    var _flipTransitionManager: (any SJFlipTransitionManager_Protocol)?

    /// Network status
    var _reachability: (any SJReachability_Protocol)?
    var _reachabilityObserver: (any SJReachabilityObserver_Protocol)?

    /// Scroll
    var _smallViewFloatingController: (any SJSmallViewFloatingController_Protocol)?
    var _smallViewFloatingControllerObserver: (any SJSmallViewFloatingControllerObserverProtocol)?

    var _subtitlePopupController: (any SJSubtitlePopupController_Protocol)?
    var _danmakuPopupController: (any SJDanmakuPopupController_Protocol)?

    var _mCategory: AVAudioSession.Category = .playback
    var _mCategoryOptions: AVAudioSession.CategoryOptions = []
    var _mSetActiveOptions: AVAudioSession.SetActiveOptions = .notifyOthersOnDeactivation

    // MARK: 关联对象等价存储(原以 objc_getAssociatedObject 懒加载/存储的属性)

    var _flipTransitionObserver: (any SJFlipTransitionManagerObserver_Protocol)?
    var _playbackObserver: SJPlaybackObservation?
    var _definitionSwitchingInfo: SJVideoDefinitionSwitchingInfo?
    var _controlLayerAppearObserver: (any SJControlLayerAppearManagerObserver_Protocol)?
    var _fitOnScreenObserver: (any SJFitOnScreenManagerObserver_Protocol)?
    var _rotationObserver: (any SJRotationManagerObserver)?
    var _deviceVolumeAndBrightnessObserver: (any SJDeviceVolumeAndBrightnessControllerObserver)?
    var _reachabilityObserverPublic: (any SJReachabilityObserver_Protocol)?
    var _textPopupController: (any SJTextPopupController_Protocol)?
    var _promptingPopupController: (any SJPromptingPopupController_Protocol)?
    var _watermarkView: (UIView & SJWatermarkView_Protocol)?

    var _onlyFitOnScreen: Bool = false
    var _allowsRotationInFitOnScreen: Bool = false
    var _isLockedScreen: Bool = false
    var _subtitleBottomMargin: CGFloat = 22
    var _subtitleHorizontalMinMargin: CGFloat = 22

    // block 属性(原 objc_getAssociatedObject 存储, 改为普通 @MainActor 闭包属性)
    var _canPlayAnAsset: ((SJBaseVideoPlayer) -> Bool)?
    var _canSeekToTime: ((SJBaseVideoPlayer) -> Bool)?
    var _gestureRecognizerShouldTrigger: ((SJBaseVideoPlayer, SJPlayerGestureType, CGPoint) -> Bool)?
    var _canAutomaticallyDisappear: ((SJBaseVideoPlayer) -> Bool)?
    var _shouldTriggerRotation: ((SJBaseVideoPlayer) -> Bool)?
    var _presentationSizeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)?
    var _playerViewWillAppearExeBlock: ((SJBaseVideoPlayer) -> Void)?
    var _playerViewWillDisappearExeBlock: ((SJBaseVideoPlayer) -> Void)?

    // MARK: 工厂 / 版本

    @objc public class func player() -> Self {
        return self.init()
    }

    public class func version() -> String {
        return "v3.7.5"
    }

    // MARK: 核心属性

    ///
    /// 视频画面填充模式
    ///
    @objc public var videoGravity: SJVideoGravity {
        get { playbackController.videoGravity }
        set {
            playbackController.videoGravity = newValue
            if watermarkView != nil {
                UIView.animate(withDuration: 0.28) {
                    self.updateWatermarkViewLayout()
                }
            }
        }
    }

    ///
    /// 播放器视图
    ///
    @objc public var view: UIView { _view }

    @objc public weak var controlLayerDataSource: (any SJVideoPlayerControlLayerDataSource)? {
        didSet {
            let controlLayerDataSource = self.controlLayerDataSource
            if controlLayerDataSource === oldValue { return }
            guard let controlLayerDataSource = controlLayerDataSource else { return }

            let controlView = controlLayerDataSource.controlView()
            controlView.clipsToBounds = true
            // install
            controlView.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.controlLayerViewZIndex)
            controlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controlView.frame = presentView.bounds
            presentView.addSubview(controlView)

            controlLayerDataSource.installedControlView?(toVideoPlayer: self)
        }
    }

    @objc public weak var controlLayerDelegate: (any SJVideoPlayerControlLayerDelegate)?

    // MARK: 便利访问

    var atViewController: UIViewController? {
        return _presentView.lookupResponder(for: UIViewController.self) as? UIViewController
    }

    /// - 当用户触摸到TableView或者ScrollView时, 这个值为YES.
    /// - 这个值用于旋转的条件之一, 如果用户触摸在TableView或者ScrollView上时, 将不会自动旋转.
    var touchedOnTheScrollView: Bool {
        return playModelObserver?.isTouched ?? false
    }

    // MARK: 初始化

    @objc public override required init() {
        _view = SJPlayerView()
        _presentView = SJVideoPlayerPresentView()
        super.init()

        _setupViews()
        // 原: performSelectorOnMainThread:@selector(_prepare) waitUntilDone:NO
        // 类已 @MainActor; 用 async 保持"下一 runloop 再 prepare"的时序。
        DispatchQueue.main.async { [self] in
            self._prepare()
        }
    }

    private func _prepare() {
        _ = fitOnScreenManager
        if !onlyFitOnScreen { _ = rotationManager }
        _ = controlLayerAppearManager
        _ = deviceVolumeAndBrightnessController
        _ = registrar
        _ = reachability
        _ = gestureController
        _setupViewControllerManager()
        _showOrHiddenPlaceholderImageViewIfNeeded()

        let ctx = SJDeviceVolumeAndBrightnessTargetViewContext()
        ctx.isFullscreen = _rotationManager?.isFullscreen ?? false
        ctx.isFitOnScreen = _fitOnScreenManager?.fitOnScreen ?? false
        ctx.isPlayOnScrollView = isPlayOnScrollView
        ctx.isScrollAppeared = isScrollAppeared
        ctx.isFloatingMode = _smallViewFloatingController?.isAppeared ?? false
        _deviceVolumeAndBrightnessTargetViewContext = ctx
        _deviceVolumeAndBrightnessController?.targetViewContext = ctx
        _deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()
    }

    deinit {
        #if DEBUG
        print("\(#line) \t \(#function)")
        #endif
        // 取出需要的引用到本地(deinit 对 @MainActor 隔离存储属性的读取有特殊放宽)。
        // 注意: _playbackController 非 Sendable, 不能作为 object 跨 actor 传给 NotificationCenter,
        //       故将通知 post 放入 MainActor 隔离闭包内(与视图移除同一闭包), 在主线程上下文闭环访问。
        //       通知 object 语义保留(监听方 SJPlaybackRecordSaveHandler 依赖 note.object 识别析构的 controller)。
        let playbackController = _playbackController
        let presentView = _presentView
        let view = _view
        // 等价原 dealloc: post 通知 + 将视图从父视图移除(原 ObjC 用 performSelectorOnMainThread:waitUntilDone:YES)。
        // 主线程: 同步执行(assumeIsolated); 后台线程: 用 main.sync 同步等待(贴近原 waitUntilDone:YES 语义),
        // 与 fork 其它块 deinit 既有写法一致(不在后台 assumeIsolated)。
        let work: @MainActor () -> Void = {
            NotificationCenter.default.post(name: SJVideoPlayerPlaybackControllerWillDeallocateNotification, object: playbackController)
            presentView.removeFromSuperview()
            view.removeFromSuperview()
        }
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { work() }
            }
        }
    }

    // MARK: 视图安装

    private func _setupViews() {
        _view.tag = SJPlayerViewTag
        _view.delegate = self
        _view.backgroundColor = .black

        _presentView.tag = SJPresentViewTag
        _presentView.frame = _view.bounds
        _presentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _presentView.placeholderImageView.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.placeholderImageViewZIndex)
        _presentView.delegate = self
        _configGestureController(_presentView)
        _view.addSubview(_presentView)
        _view.presentView = _presentView
    }

    func _setupViewControllerManager() {
        if viewControllerManager == nil { viewControllerManager = SJViewControllerManager() }
        viewControllerManager.fitOnScreenManager = _fitOnScreenManager as? SJFitOnScreenManager
        viewControllerManager.rotationManager = _rotationManager as? SJRotationManager
        viewControllerManager.controlLayerAppearManager = _controlLayerAppearManager
        viewControllerManager.presentView = _presentView
        viewControllerManager.lockedScreen = lockedScreen

        if let mgr = _rotationManager as? SJRotationManager {
            mgr.actionForwarder = viewControllerManager
        }
    }

    // MARK: 通知

    func _postNotification(_ name: Notification.Name) {
        _postNotification(name, userInfo: nil)
    }

    func _postNotification(_ name: Notification.Name, userInfo: [AnyHashable: Any]?) {
        NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
    }

    // MARK: 占位图

    func _showOrHiddenPlaceholderImageViewIfNeeded() {
        if _playbackController?.isReadyForDisplay == true {
            if controlInfo.placeholder.automaticallyHides {
                let delay = _URLAsset?.original != nil ? 0 : controlInfo.placeholder.delayHidden
                let animated = _URLAsset?.original == nil
                presentView.hidePlaceholderImageView(animated: animated, delay: delay)
            }
        } else {
            presentView.setPlaceholderImageViewHidden(false, animated: false)
        }
    }

    // MARK: registrar

    @objc var registrar: SJVideoPlayerRegistrar {
        if let registrar = _registrar { return registrar }
        let registrar = SJVideoPlayerRegistrar()
        registrar.willTerminate = { [weak self] _ in
            guard let self = self else { return }
            self._postNotification(SJVideoPlayerApplicationWillTerminateNotification)
        }
        _registrar = registrar
        return registrar
    }
}

// MARK: - 旋转管理 setup(供 Rotation / FitOnScreen 分类共用)

@MainActor
extension SJBaseVideoPlayer {

    func _setupRotationManager(_ rotationManager: (any SJRotationManager_Protocol)?) {
        _rotationManager = rotationManager
        _rotationManagerObserver = nil

        guard let rotationManager = rotationManager, !onlyFitOnScreen else { return }

        viewControllerManager.rotationManager = rotationManager as? SJRotationManager

        rotationManager.superview = view
        rotationManager.target = presentView
        rotationManager.shouldTriggerRotation = { [weak self] mgr in
            guard let self = self else { return false }
            if mgr.isFullscreen == false {
                if self.playModelObserver?.isScrolling == true { return false }
                if self.view.superview == nil { return false }
                if self.isPlayOnScrollView && !(self.isScrollAppeared || self.controlInfo.floatSmallViewControl.isAppeared) { return false }
                if self.touchedOnTheScrollView { return false }
            }
            if self.lockedScreen { return false }

            if self.fitOnScreen {
                return self.allowsRotationInFitOnScreen
            }

            if self.viewControllerManager.viewDisappeared { return false }
            if let delegate = self.controlLayerDelegate, delegate.responds(to: #selector(SJRotationControlDelegate.canTriggerRotation(ofVideoPlayer:))) {
                if delegate.canTriggerRotation?(ofVideoPlayer: self) == false {
                    return false
                }
            }
            if self.atViewController?.presentedViewController != nil { return false }
            if let block = self._shouldTriggerRotation, !block(self) { return false }
            return true
        }

        let observer = rotationManager.getObserver()
        _rotationManagerObserver = observer
        observer.onRotatingChanged = { [weak self] mgr, isRotating in
            guard let self = self else { return }
            self._deviceVolumeAndBrightnessTargetViewContext?.isFullscreen = mgr.isFullscreen
            self._deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()

            if isRotating {
                self.controlLayerDelegate?.videoPlayer?(self, willRotateView: mgr.isFullscreen)
                self.controlLayerNeedDisappear()
            } else {
                self.playModelObserver?.refreshAppearState()
                self.controlLayerDelegate?.videoPlayer?(self, didEndRotation: mgr.isFullscreen)

                if mgr.isFullscreen {
                    self.viewControllerManager.setNeedsStatusBarAppearanceUpdate()
                } else {
                    UIView.animate(withDuration: 0.25) {
                        self.viewControllerManager.setNeedsStatusBarAppearanceUpdate()
                    }
                }
            }
        }

        observer.onTransitioningChanged = { [weak self] _, isTransitioning in
            guard let self = self else { return }
            self.controlLayerDelegate?.videoPlayer?(self, onRotationTransitioningChanged: isTransitioning)
        }
    }

    func _clearRotationManager() {
        viewControllerManager?.rotationManager = nil
        _rotationManagerObserver = nil
        _rotationManager = nil
    }

    func _setupFitOnScreenManager(_ fitOnScreenManager: (any SJFitOnScreenManager_Protocol)?) {
        _fitOnScreenManager = fitOnScreenManager
        _fitOnScreenManagerObserver = nil

        guard let fitOnScreenManager = fitOnScreenManager else { return }

        viewControllerManager.fitOnScreenManager = fitOnScreenManager as? SJFitOnScreenManager

        let observer = fitOnScreenManager.getObserver()
        _fitOnScreenManagerObserver = observer
        observer.fitOnScreenWillBeginExeBlock = { [weak self] mgr in
            guard let self = self else { return }
            self._deviceVolumeAndBrightnessTargetViewContext?.isFitOnScreen = mgr.fitOnScreen
            self._deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()

            if self._rotationManager != nil {
                self._rotationManager?.superview = mgr.fitOnScreen ? self.fitOnScreenManager.superviewInFitOnScreen : self.view
            }
            if self._smallViewFloatingController != nil {
                self._smallViewFloatingController?.targetSuperview = mgr.fitOnScreen ? self.fitOnScreenManager.superviewInFitOnScreen : self.view
            }

            self.controlLayerNeedDisappear()
            self.controlLayerDelegate?.videoPlayer?(self, willFitOnScreen: mgr.fitOnScreen)
        }

        observer.fitOnScreenDidEndExeBlock = { [weak self] mgr in
            guard let self = self else { return }
            self.controlLayerDelegate?.videoPlayer?(self, didCompleteFitOnScreen: mgr.fitOnScreen)
            self.viewControllerManager.setNeedsStatusBarAppearanceUpdate()
        }
    }

    func _setupControlLayerAppearManager(_ controlLayerAppearManager: (any SJControlLayerAppearManager)?) {
        _controlLayerAppearManager = controlLayerAppearManager
        _controlLayerAppearManagerObserver = nil

        guard let controlLayerAppearManager = controlLayerAppearManager else { return }

        viewControllerManager.controlLayerAppearManager = controlLayerAppearManager

        controlLayerAppearManager.canAutomaticallyDisappear = { [weak self] _ in
            guard let self = self else { return false }
            if let delegate = self.controlLayerDelegate,
               delegate.responds(to: #selector(SJVideoPlayerControlLayerDelegate.controlLayerOfVideoPlayerCanAutomaticallyDisappear(_:))) {
                if delegate.controlLayerOfVideoPlayerCanAutomaticallyDisappear?(self) == false {
                    return false
                }
            }
            if let block = self._canAutomaticallyDisappear, !block(self) {
                return false
            }
            return true
        }

        let observer = controlLayerAppearManager.getObserver()
        _controlLayerAppearManagerObserver = observer
        observer.onAppearChanged = { [weak self] mgr in
            guard let self = self else { return }
            if mgr.isAppeared {
                self.controlLayerDelegate?.controlLayerNeedAppear?(self)
            } else {
                self.controlLayerDelegate?.controlLayerNeedDisappear?(self)
            }

            if !self.isFullscreen || self.isRotating {
                UIView.animate(withDuration: 0) {
                } completion: { _ in
                    self.viewControllerManager.setNeedsStatusBarAppearanceUpdate()
                }
            } else {
                UIView.animate(withDuration: 0.25) {
                    self.viewControllerManager.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }

    func _setupSmallViewFloatingController(_ smallViewFloatingController: (any SJSmallViewFloatingController_Protocol)?) {
        _smallViewFloatingController = smallViewFloatingController
        _smallViewFloatingControllerObserver = nil

        guard let smallViewFloatingController = smallViewFloatingController else { return }

        smallViewFloatingController.targetSuperview = view
        smallViewFloatingController.target = presentView

        let observer = smallViewFloatingController.getObserver()
        _smallViewFloatingControllerObserver = observer
        observer.onAppearChanged = { [weak self] controller in
            guard let self = self else { return }
            let isAppeared = controller.isAppeared
            self._deviceVolumeAndBrightnessTargetViewContext?.isFloatingMode = isAppeared
            self._deviceVolumeAndBrightnessController?.onTargetViewContextUpdated()
            self.controlInfo.floatSmallViewControl.isAppeared = isAppeared
            self.rotationManager?.superview = isAppeared ? controller.floatingView : self.view
        }
    }

    // MARK: 手势配置

    func _configGestureController(_ gestureController: any SJGestureController) {
        gestureController.gestureRecognizerShouldTrigger = { [weak self] control, type, location in
            guard let self = self else { return false }

            if self.isRotating { return false }

            if type != .singleTap && self.lockedScreen { return false }

            if type == .pan {
                switch control.movingDirection {
                case .H:
                    if self.playbackType == .LIVE { return false }
                    if self.duration <= 0 { return false }
                    if let block = self._canSeekToTime, !block(self) { return false }
                    if self.isPlayOnScrollView {
                        if !self.controlInfo.gestureController.allowHorizontalTriggeringOfPanGesturesInCells {
                            if !self.fitOnScreen && !self.isRotating { return false }
                        }
                    }
                case .V:
                    if self.isPlayOnScrollView {
                        if !self.isFullscreen && !self.fitOnScreen { return false }
                    }
                    switch control.triggeredPosition {
                    case .left:
                        if self.controlInfo.deviceVolumeAndBrightness.disableBrightnessSetting { return false }
                    case .right:
                        if self.controlInfo.deviceVolumeAndBrightness.disableVolumeSetting || self.muted { return false }
                    }
                }
            }

            if type == .longPress {
                if self.assetStatus != .readyToPlay || self.isPaused { return false }
            }

            if let delegate = self.controlLayerDelegate,
               delegate.responds(to: #selector(SJGestureControllerDelegate.videoPlayer(_:gestureRecognizerShouldTrigger:location:))) {
                if delegate.videoPlayer?(self, gestureRecognizerShouldTrigger: type, location: location) == false {
                    return false
                }
            }

            if let block = self._gestureRecognizerShouldTrigger, !block(self, type, location) {
                return false
            }
            return true
        }

        gestureController.singleTapHandler = { [weak self] _, location in
            self?._handleSingleTap(location)
        }
        gestureController.doubleTapHandler = { [weak self] _, location in
            self?._handleDoubleTap(location)
        }
        gestureController.panHandler = { [weak self] _, position, direction, state, translate in
            self?._handlePan(position, direction: direction, state: state, translate: translate)
        }
        gestureController.pinchHandler = { [weak self] _, scale in
            self?._handlePinch(scale)
        }
        gestureController.longPressHandler = { [weak self] _, state in
            self?._handleLongPress(state)
        }
    }

    // MARK: 手势处理

    private func _handleSingleTap(_ location: CGPoint) {
        if controlInfo.floatSmallViewControl.isAppeared {
            let controller = smallViewFloatingController
            // 注: fork 的 onSingleTapped 闭包形参类型为具体类 SJSmallViewFloatingController(非协议),
            //     此处按其类型转换后回调(默认实现即该类)。
            if let onSingleTapped = controller.onSingleTapped, let concrete = controller as? SJSmallViewFloatingController {
                onSingleTapped(concrete)
            }
            return
        }

        if lockedScreen {
            controlLayerDelegate?.tappedPlayer?(onTheLockedState: self)
        } else {
            controlLayerAppearManager.switchAppearState()
        }
    }

    private func _handleDoubleTap(_ location: CGPoint) {
        if controlInfo.floatSmallViewControl.isAppeared {
            let controller = smallViewFloatingController
            if let onDoubleTapped = controller.onDoubleTapped, let concrete = controller as? SJSmallViewFloatingController {
                onDoubleTapped(concrete)
            }
            return
        }

        isPaused ? play() : pauseForUser()
    }

    private func _handlePan(_ position: SJPanGestureTriggeredPosition, direction: SJPanGestureMovingDirection, state: SJPanGestureRecognizerState, translate: CGPoint) {
        switch state {
        case .began:
            switch direction {
            case .H:
                if duration == 0 {
                    _presentView.cancelGesture(.pan)
                    return
                }
                controlInfo.pan.offsetTime = currentTime
            case .V:
                break
            }
        case .changed:
            switch direction {
            case .H:
                let duration = self.duration
                let previous = controlInfo.pan.offsetTime
                let tlt = Double(translate.x)
                let add = tlt / Double(controlInfo.pan.factor) * self.duration
                var offsetTime = previous + add
                if offsetTime > duration { offsetTime = duration }
                else if offsetTime < 0 { offsetTime = 0 }
                controlInfo.pan.offsetTime = offsetTime
            case .V:
                let value = translate.y * 0.005
                switch position {
                case .left:
                    let old = deviceVolumeAndBrightnessController.brightness
                    let new = old - Float(value)
                    print("brightness.set: old: \(old), new: \(new)")
                    deviceVolumeAndBrightnessController.brightness = new
                case .right:
                    deviceVolumeAndBrightnessController.volume -= Float(value)
                }
            }
        case .ended:
            break
        }

        if direction == .H {
            if let delegate = controlLayerDelegate,
               delegate.responds(to: #selector(SJGestureControllerDelegate.videoPlayer(_:panGestureTriggeredInTheHorizontalDirection:progressTime:))) {
                delegate.videoPlayer?(self, panGestureTriggeredInTheHorizontalDirection: state, progressTime: controlInfo.pan.offsetTime)
            }
        }
    }

    private func _handlePinch(_ scale: CGFloat) {
        videoGravity = scale > 1 ? .resizeAspectFill : .resizeAspect
    }

    private func _handleLongPress(_ state: SJLongPressGestureRecognizerState) {
        switch state {
        case .began:
            controlInfo.longPress.initialRate = CGFloat(rate)
            rate = Float(rateWhenLongPressGestureTriggered)
        case .changed:
            rate = Float(rateWhenLongPressGestureTriggered)
        case .ended:
            rate = Float(controlInfo.longPress.initialRate)
        }

        controlLayerDelegate?.videoPlayer?(self, longPressGestureStateDidChange: state)
    }

    // MARK: scrollView 当前播放 indexPath 维护

    func _updateCurrentPlayingIndexPathIfNeeded(_ playModel: SJPlayModel?) {
        guard let playModel = playModel else { return }
        // 维护当前播放的indexPath
        if let scrollView = playModel.inScrollView(), scrollView.sj_enabledAutoplay {
            scrollView.sj_currentPlayingIndexPath = playModel.indexPath()
        }
    }
}

// MARK: - SJVideoPlayerPresentViewDelegate / SJPlayerViewDelegate

@MainActor
extension SJBaseVideoPlayer: SJVideoPlayerPresentViewDelegate, SJPlayerViewDelegate {

    public func playerViewWillMoveToWindow(_ playerView: SJPlayerView) {
        playModelObserver?.refreshAppearState()
    }

    ///
    /// 此处拦截父视图的Tap手势
    ///
    public func playerView(_ playerView: SJPlayerView, hitTestFor view: UIView?) -> UIView? {
        if playerView.isHidden || playerView.alpha < 0.01 || !playerView.isUserInteractionEnabled { return nil }

        if let gestures = playerView.superview?.gestureRecognizers {
            for gesture in gestures {
                if gesture is UITapGestureRecognizer && gesture.isEnabled {
                    gesture.isEnabled = false
                    DispatchQueue.main.async {
                        gesture.isEnabled = true
                    }
                }
            }
        }
        return view
    }

    public func presentViewDidLayoutSubviews(_ presentView: SJVideoPlayerPresentView) {
        updateWatermarkViewLayout()
    }

    public func presentViewDidMove(toWindow presentView: SJVideoPlayerPresentView) {
        if _deviceVolumeAndBrightnessController != nil {
            _deviceVolumeAndBrightnessController?.onTargetViewMoveToWindow()
        }
    }
}

