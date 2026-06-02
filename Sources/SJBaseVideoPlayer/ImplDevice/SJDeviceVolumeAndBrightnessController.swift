//
//  SJDeviceVolumeAndBrightnessController.swift
//  SJDeviceVolumeAndBrightnessController
//
//  Created by 畅三江 on 2017/12/10.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  Swift 6.3 移植 (等价于原 ObjC 版 SJDeviceVolumeAndBrightnessController.h/.m)
//

import UIKit
import SnapKit
@preconcurrency import AVFoundation
import MediaPlayer

// MARK: - Popup View 数据源 / 视图协议 (原定义于 SJDeviceVolumeAndBrightnessController.h, 属本块)

/// 音量 / 亮度弹出视图的数据源
@objc(SJDeviceVolumeAndBrightnessPopupViewDataSource)
@MainActor public protocol SJDeviceVolumeAndBrightnessPopupViewDataSource: NSObjectProtocol {
    /// 起始状态(progress == 0)
    @objc var startImage: UIImage? { get set }
    /// 普通状态
    @objc var image: UIImage? { get set }
    @objc var progress: Float { get set }
    @objc var traceColor: UIColor! { get set }
    @objc var trackColor: UIColor! { get set }
}

/// 音量 / 亮度弹出视图
@objc(SJDeviceVolumeAndBrightnessPopupView)
@MainActor public protocol SJDeviceVolumeAndBrightnessPopupView: NSObjectProtocol {
    @objc var dataSource: SJDeviceVolumeAndBrightnessPopupViewDataSource { get set }
    @objc func refreshData()
}

// MARK: - SJDeviceVolumeAndBrightnessController

/// 设备音量 / 亮度控制器 (每个播放器持有一个)。
///
/// - 监听全局 `SJDeviceVolumeAndBrightness` 的音量 / 亮度变化, 在 target 视图上弹出对应提示视图。
/// - 通过 `SJDeviceSystemVolumeViewDisplayManager` 协调系统音量条的显示 / 隐藏。
@MainActor
@objc(SJDeviceVolumeAndBrightnessController)
public final class SJDeviceVolumeAndBrightnessController: NSObject, SJDeviceVolumeAndBrightnessController_Protocol, SJDeviceVolumeAndBrightnessObserver {

    // 系统音量视图 (来自全局单例)
    private var _sysVolumeView: UIView

    private var _volumeView: (UIView & SJDeviceVolumeAndBrightnessPopupView)?
    private var _brightnessView: (UIView & SJDeviceVolumeAndBrightnessPopupView)?

    // MARK: 协议: SJDeviceVolumeAndBrightnessController

    @objc public weak var target: UIView?
    @objc public var targetViewContext: SJDeviceVolumeAndBrightnessTargetViewContext?

    @objc public var volume: Float {
        get { SJDeviceVolumeAndBrightness.shared.volume }
        set { SJDeviceVolumeAndBrightness.shared.volume = newValue }
    }

    @objc public var brightness: Float {
        get { SJDeviceVolumeAndBrightness.shared.brightness }
        set { SJDeviceVolumeAndBrightness.shared.brightness = newValue }
    }

    @objc public override init() {
        _sysVolumeView = SJDeviceVolumeAndBrightness.shared.sysVolumeView
        super.init()
        SJDeviceVolumeAndBrightness.shared.addObserver(self)
        SJDeviceSystemVolumeViewDisplayManager.shared.addController(self)
    }

    deinit {
        // 与原 ObjC dealloc 等价: 从全局单例与系统音量条管理者中注销。
        // 这些调用涉及 @MainActor 隔离对象, deinit 为 nonisolated, 故跳回主线程异步执行。
        let obj = self as SJDeviceVolumeAndBrightnessObserver
        MainActor.assumeIsolatedSafe {
            SJDeviceVolumeAndBrightness.shared.removeObserver(obj)
        }
    }

    // MARK: SJDeviceVolumeAndBrightnessObserver

    public func device(_ device: SJDeviceVolumeAndBrightness, onVolumeChanged volume: Float) {
        _onVolumeChanged()
    }

    public func device(_ device: SJDeviceVolumeAndBrightness, onBrightnessChanged brightness: Float) {
        _onBrightnessChanged()
    }

    @objc public func getObserver() -> SJDeviceVolumeAndBrightnessControllerObserver {
        return SJDeviceVolumeAndBrightnessControllerObserverImpl(mgr: self)
    }

    @objc public func onTargetViewMoveToWindow() {
        SJDeviceSystemVolumeViewDisplayManager.shared.update()
    }

    @objc public func onTargetViewContextUpdated() {
        SJDeviceSystemVolumeViewDisplayManager.shared.update()
    }

    // MARK: - volume

    private func _onVolumeChanged() {
        _showVolumeViewIfNeeded()
        _updateContentsForVolumeViewIfNeeded()
        NotificationCenter.default.post(name: .sjDeviceVolumeDidChange, object: self)
    }

    @objc public var volumeView: (UIView & SJDeviceVolumeAndBrightnessPopupView)? {
        get {
            if _volumeView == nil {
                let view = SJDeviceVolumeAndBrightnessPopupViewImpl()
                let model = SJDeviceVolumeAndBrightnessPopupItem()
                DispatchQueue.global().async {
                    let muteImage = SJBaseVideoPlayerResourceLoader.image(named: "mute")
                    let volumeImage = SJBaseVideoPlayerResourceLoader.image(named: "volume")
                    DispatchQueue.main.async {
                        model.startImage = muteImage
                        model.image = volumeImage
                        self._volumeView?.refreshData()
                    }
                }
                view.dataSource = model
                _volumeView = view
            }
            return _volumeView
        }
        set { _volumeView = newValue }
    }

    private func _showVolumeViewIfNeeded() {
        if _sysVolumeView.superview == nil || !SJDeviceSystemVolumeViewDisplayManager.shared.automaticallyDisplaySystemVolumeView {
            return
        }
        let targetView = self.target
        guard let volumeView = self.volumeView else { return }
        if targetView?.window != nil, volumeView.superview != targetView, let targetView = targetView {
            targetView.addSubview(volumeView)
            volumeView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_hideVolumeView), object: nil)
        perform(#selector(_hideVolumeView), with: nil, afterDelay: 1, inModes: [.common])
    }

    @objc private func _hideVolumeView() {
        _volumeView?.removeFromSuperview()
    }

    private func _updateContentsForVolumeViewIfNeeded() {
        guard let volumeView = self.volumeView, volumeView.superview != nil else { return }
        let volume = self.volume
        volumeView.dataSource.progress = volume
        volumeView.refreshData()
    }

    // MARK: - brightness

    private func _onBrightnessChanged() {
        _showBrightnessView()
        _updateContentsForBrightnessViewIfNeeded()
        NotificationCenter.default.post(name: .sjDeviceBrightnessDidChange, object: self)
    }

    @objc public var brightnessView: (UIView & SJDeviceVolumeAndBrightnessPopupView)? {
        get {
            if _brightnessView == nil {
                let view = SJDeviceVolumeAndBrightnessPopupViewImpl()
                let model = SJDeviceVolumeAndBrightnessPopupItem()
                DispatchQueue.global().async {
                    let image = SJBaseVideoPlayerResourceLoader.image(named: "brightness")
                    DispatchQueue.main.async {
                        model.startImage = image
                        model.image = image
                        self._brightnessView?.refreshData()
                    }
                }
                view.dataSource = model
                _brightnessView = view
            }
            return _brightnessView
        }
        set { _brightnessView = newValue }
    }

    private func _updateContentsForBrightnessViewIfNeeded() {
        guard let brightnessView = self.brightnessView, brightnessView.superview != nil else { return }
        let brightness = self.brightness
        brightnessView.dataSource.progress = brightness
        brightnessView.refreshData()
    }

    private func _showBrightnessView() {
        let targetView = self.target
        guard let brightnessView = self.brightnessView else { return }
        if let targetView = targetView, brightnessView.superview != targetView {
            targetView.addSubview(brightnessView)
            brightnessView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_hideBrightnessView), object: nil)
        perform(#selector(_hideBrightnessView), with: nil, afterDelay: 1, inModes: [.common])
    }

    @objc private func _hideBrightnessView() {
        _brightnessView?.removeFromSuperview()
    }
}

// MARK: - 通知名

extension Notification.Name {
    /// 设备音量改变 (object 为 SJDeviceVolumeAndBrightnessController)
    static let sjDeviceVolumeDidChange = Notification.Name("SJDeviceVolumeDidChangeNotification")
    /// 设备亮度改变 (object 为 SJDeviceVolumeAndBrightnessController)
    static let sjDeviceBrightnessDidChange = Notification.Name("SJDeviceBrightnessDidChangeNotification")
}

// MARK: - SJDeviceVolumeAndBrightnessControllerObserver 实现

/// 控制器观察者实现 (基于 NotificationCenter, 与原 ObjC 版等价)。
///
/// 类名加 Impl 后缀以避免与同名 @objc protocol `SJDeviceVolumeAndBrightnessControllerObserver` 冲突;
/// 原 ObjC 实现类亦为内部私有类型, 不对外暴露具体类名, 仅通过协议引用, 故重命名不影响兼容。
@MainActor
final class SJDeviceVolumeAndBrightnessControllerObserverImpl: NSObject, SJDeviceVolumeAndBrightnessControllerObserver {
    var volumeDidChangeExeBlock: ((SJDeviceVolumeAndBrightnessController, Float) -> Void)?
    var brightnessDidChangeExeBlock: ((SJDeviceVolumeAndBrightnessController, Float) -> Void)?

    private nonisolated(unsafe) var volumeDidChangeToken: NSObjectProtocol?
    private nonisolated(unsafe) var brightnessDidChangeToken: NSObjectProtocol?

    init(mgr: SJDeviceVolumeAndBrightnessController_Protocol) {
        super.init()
        volumeDidChangeToken = NotificationCenter.default.addObserver(forName: .sjDeviceVolumeDidChange, object: mgr, queue: .main) { [weak self] note in
            nonisolated(unsafe) let n = note
            MainActor.assumeIsolated {
                guard let self = self else { return }
                guard let mgr = n.object as? SJDeviceVolumeAndBrightnessController else { return }
                self.volumeDidChangeExeBlock?(mgr, mgr.volume)
            }
        }
        brightnessDidChangeToken = NotificationCenter.default.addObserver(forName: .sjDeviceBrightnessDidChange, object: mgr, queue: .main) { [weak self] note in
            nonisolated(unsafe) let n = note
            MainActor.assumeIsolated {
                guard let self = self else { return }
                guard let mgr = n.object as? SJDeviceVolumeAndBrightnessController else { return }
                self.brightnessDidChangeExeBlock?(mgr, mgr.brightness)
            }
        }
    }

    deinit {
        if let token = volumeDidChangeToken { NotificationCenter.default.removeObserver(token) }
        if let token = brightnessDidChangeToken { NotificationCenter.default.removeObserver(token) }
    }
}

// MARK: - Popup View 实现

@MainActor
final class SJDeviceVolumeAndBrightnessPopupViewImpl: UIView, SJDeviceVolumeAndBrightnessPopupView {
    // 协议要求 dataSource 为非可选; 提供默认值占位, 由外部赋真实数据源。
    var dataSource: SJDeviceVolumeAndBrightnessPopupViewDataSource = SJDeviceVolumeAndBrightnessPopupItem()

    private let imageView = UIImageView(frame: .zero)
    private let progressView = UIProgressView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        _setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _setupView()
    }

    func refreshData() {
        imageView.image = (dataSource.progress > 0) ? dataSource.image : (dataSource.startImage ?? dataSource.image)
        progressView.progress = dataSource.progress
        progressView.trackTintColor = dataSource.trackColor
        progressView.progressTintColor = dataSource.traceColor
    }

    private func _setupView() {
        backgroundColor = UIColor(white: 0, alpha: 0.8)
        layer.cornerRadius = 5

        imageView.contentMode = .center
        addSubview(imageView)

        progressView.progress = 0.5
        addSubview(progressView)

        imageView.snp.makeConstraints { make in
            make.top.left.bottom.equalToSuperview()
            make.width.equalTo(self.imageView.snp.height)
            make.height.equalTo(38)
        }

        progressView.snp.makeConstraints { make in
            make.left.equalTo(self.imageView.snp.right).offset(5)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(2)
            make.width.equalTo(100)
        }

        imageView.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
        progressView.setContentHuggingPriority(UILayoutPriority(250), for: .horizontal)
    }
}

@MainActor
final class SJDeviceVolumeAndBrightnessPopupItem: NSObject, SJDeviceVolumeAndBrightnessPopupViewDataSource {
    var startImage: UIImage?
    var image: UIImage?
    var progress: Float = 0

    private var _traceColor: UIColor?
    private var _trackColor: UIColor?

    var traceColor: UIColor! {
        get { _traceColor ?? UIColor.white }
        set { _traceColor = newValue }
    }

    var trackColor: UIColor! {
        get { _trackColor ?? UIColor(white: 0.6, alpha: 0.5) }
        set { _trackColor = newValue }
    }
}

// MARK: - 系统音量条的显示管理

/// 系统音量条的显示管理 (单例)。
///
/// 决定隐藏的系统 MPVolumeView 是否挂到 keyWindow (挂上 = 隐藏系统 HUD; 移除 = 显示系统 HUD)。
@MainActor
@objc(SJDeviceSystemVolumeViewDisplayManager)
public final class SJDeviceSystemVolumeViewDisplayManager: NSObject {

    @objc(shared)
    public static let shared = SJDeviceSystemVolumeViewDisplayManager()

    /// 是否自动控制系统音量条显示, default value is YES;
    ///
    ///     如需直接使用系统音量条, 请设置 NO 关闭自动控制;
    @objc public var automaticallyDisplaySystemVolumeView: Bool = true

    private let mControllers = NSHashTable<AnyObject>.weakObjects()
    private let mSysVolumeView: UIView

    private override init() {
        mSysVolumeView = SJDeviceVolumeAndBrightness.shared.sysVolumeView
        super.init()
        _makeHidingForSysVolumeView()
    }

    @objc(addController:)
    public func addController(_ controller: SJDeviceVolumeAndBrightnessController_Protocol?) {
        guard let controller = controller else { return }
        mControllers.add(controller)
    }

    @objc(removeController:)
    public func removeController(_ controller: SJDeviceVolumeAndBrightnessController_Protocol?) {
        guard let controller = controller else { return }
        mControllers.remove(controller)
    }

    //    1. 未显示或不在keyWindow中时则略过
    //    2. 根据状态确定是否显示系统音量条
    //       2.1 处于 fullscreen or fitOnScreen 隐藏系统条
    //       2.2 小屏状态
    //           2.2.1 在cell中播放, 显示系统条
    //           2.2.2 小浮窗模式, 显示系统条
    //           2.2.3 画中画模式, 显示系统条
    //           2.2.x 常规模式隐藏系统条
    @objc public func update() {
        var needsShowing = true
        if automaticallyDisplaySystemVolumeView {
            for case let controller as SJDeviceVolumeAndBrightnessController_Protocol in mControllers.allObjects {
                let targetView = controller.target
                let targetViewWindow = targetView?.window
                let appKeyWindow = UIApplication.shared.keyWindow
                if targetViewWindow == nil || targetViewWindow != appKeyWindow {
                    // 1. 未显示或不在keyWindow中时则略过
                    continue
                }

                guard let ctx = controller.targetViewContext else {
                    // 无上下文时按常规模式隐藏系统条
                    needsShowing = false
                    _makeHidingForSysVolumeView()
                    continue
                }
                // 2.1
                if ctx.isFullscreen || ctx.isFitOnScreen {
                    needsShowing = false
                    _makeHidingForSysVolumeView()
                    break
                }
                // 2.2
                else {
                    // 2.2.1
                    if ctx.isPlayOnScrollView {
                        needsShowing = false
                        _makeShowingForSysVolumeView()
                        break
                    }
                    // 2.2.2
                    if ctx.isFloatingMode {
                        needsShowing = false
                        _makeShowingForSysVolumeView()
                        break
                    }
                    // 2.2.3
                    if ctx.isPictureInPictureMode {
                        needsShowing = false
                        _makeShowingForSysVolumeView()
                        break
                    }
                    // 2.2.x
                    needsShowing = false
                    _makeHidingForSysVolumeView()
                }
            }
        }
        if needsShowing { _makeShowingForSysVolumeView() }
    }

    // 隐藏系统音量条 (挂到 keyWindow 上, 位置在屏幕外)
    private func _makeHidingForSysVolumeView() {
        let window = UIApplication.shared.keyWindow
        if mSysVolumeView.superview != window {
            window?.addSubview(mSysVolumeView)
        }
    }

    // 显示系统音量条 (从父视图移除, 让系统 HUD 自然出现)
    private func _makeShowingForSysVolumeView() {
        if mSysVolumeView.superview != nil {
            mSysVolumeView.removeFromSuperview()
        }
    }
}

// MARK: - MainActor deinit 辅助

extension MainActor {
    /// 在 nonisolated deinit 中安全执行 @MainActor 闭包:
    /// 若已在主线程则同步执行 (assumeIsolated), 否则异步派发到主线程。
    fileprivate static func assumeIsolatedSafe(_ body: @MainActor @escaping () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }
        } else {
            DispatchQueue.main.async { body() }
        }
    }
}

