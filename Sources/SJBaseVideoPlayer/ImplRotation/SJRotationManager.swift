//
//  SJRotationManager.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationManager.h/.m + SJRotationManagerInternal.h
//  - 旋转管理器基类, 实现 SJRotationManager 协议; 真正旋转逻辑由 iOS 16+/9~15 子类重写。
//  - 内部抽象方法 (rotationFullscreenViewController / pointInside / supportedInterfaceOrientationsForWindow
//    / rotateToOrientation / onDeviceOrientationChanged) 必须由子类重写, 基类抛异常。
//  - 子类需访问的内部 API (_init / window / forcedRotation / deviceOrientation / currentOrientation /
//    allowsRotation / rotationBegin / rotationEnd / transitionBegin / transitionEnd /
//    rotationFullscreenViewController / setNeeds... 等) 在本 module 内以 internal/open 暴露,
//    替代原 ObjC 的 Internal 分类。
//  - safe area 修复用的 UIViewController swizzle (SJRotationSafeAreaFixing) 仅在 iOS 13~16 生效。
//

import UIKit
import ObjectiveC

#if canImport(SJUIKit)
import SJUIKit
#endif

// MARK: - SJRotationActivation
//
// 应用活跃状态守卫: 应用从后台回到前台后, 延迟一小段时间才允许旋转, 避免后台/即将激活期间误旋转。
// (原 ObjC 内部类, 用 SJTimerControl 做延时)

@MainActor
final class SJRotationActivation {
    private(set) var isActive: Bool
    private let timer = SJTimerControl()

    init() {
        isActive = UIApplication.shared.applicationState == .active
        timer.exeBlock = { [weak self] _ in
            guard let self else { return }
            self.isActive = true
        }
        observeNotifies()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeNotifies() {
        NotificationCenter.default.addObserver(self, selector: #selector(onApplicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onApplicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func forceActive() {
        if !isActive {
            isActive = true
            timer.interrupt()
        }
    }

    @objc private func onApplicationWillResignActive(_ note: Notification) {
        timer.interrupt()
        isActive = false
    }

    @objc private func onApplicationDidBecomeActive(_ note: Notification) {
        timer.resume()
    }
}

// MARK: - SJRotationManager

@MainActor
@objc(SJRotationManager)
public class SJRotationManager: NSObject,
                               SJRotationManagerProtocol,
                               SJRotationFullscreenWindowDelegate,
                               SJRotationFullscreenNavigationControllerDelegate,
                               SJRotationFullscreenViewControllerDelegate {

    // MARK: 内部状态

    fileprivate var _window: SJRotationFullscreenWindow!
    private var _windowPreparing: Bool = false
    private var _rotationActivation: SJRotationActivation!
    private var _deviceOrientation: SJOrientation = .portrait
    private var _forcedRotation: Bool = false

    // MARK: SJRotationManager 协议属性

    @objc public var shouldTriggerRotation: ((SJRotationManager) -> Bool)?

    @objc(isDisabledAutorotation) public var disabledAutorotation: Bool = false

    public var _autorotationSupportedOrientations: SJOrientationMask = .all

    @objc public var autorotationSupportedOrientations: UInt {
        get { _autorotationSupportedOrientations.rawValue }
        set { _autorotationSupportedOrientations = SJOrientationMask(rawValue: newValue) }
    }

    @objc public private(set) var currentOrientation: SJOrientation = .portrait

    @objc public weak var superview: UIView?
    @objc public weak var target: UIView?
    @objc public weak var actionForwarder: SJRotationActionForwarder?

    @objc(isRotating) public internal(set) var rotating: Bool = false
    @objc(isTransitioning) public internal(set) var transitioning: Bool = false

    // MARK: 构造 / 工厂

    @objc public class func rotationManager() -> SJRotationManager {
        if #available(iOS 16.0, *) {
            return SJRotationManager_iOS_16_Later(_init: ())
        } else {
            return SJRotationManager_iOS_9_15(_init: ())
        }
    }

    /// 内部指定初始化器 (替代 ObjC 的 -_init), 仅供子类调用
    init(_init: Void) {
        super.init()
        _autorotationSupportedOrientations = .all
        currentOrientation = .portrait
        _deviceOrientation = .portrait
        _rotationActivation = SJRotationActivation()
        // 先注册通知, 再做准备, 保证通知回调先执行;
        observeDeviceOrientation()
        prepareWindowForRotation()
    }

    @available(*, unavailable)
    public override init() {
        fatalError("use SJRotationManager.rotationManager() instead")
    }

    deinit {
        _window?.isHidden = true
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: 观察者

    @objc public func getObserver() -> SJRotationManagerObserver {
        SJRotationObserver(manager: self)
    }

    // MARK: 内部只读访问 (替代 Internal 分类)

    /// 全屏窗口
    var window: UIWindow { _window }

    /// 是否为强制旋转 (调用 rotate: 触发)
    @objc(isForcedRotation) public var forcedRotation: Bool { _forcedRotation }

    /// 设备方向
    var deviceOrientation: SJOrientation { _deviceOrientation }

    /// 供子类设置 currentOrientation
    func setCurrentOrientation(_ orientation: SJOrientation) {
        currentOrientation = orientation
    }

    // MARK: 静态: 窗口支持方向反查

    @objc(supportedInterfaceOrientationsForWindow:)
    public class func supportedInterfaceOrientations(forWindow window: UIWindow?) -> UIInterfaceOrientationMask {
        if let win = window as? SJRotationFullscreenWindow,
           let manager = win.rotationManager {
            return manager.supportedInterfaceOrientations(forWindow: window)
        }
        return .all
    }

    // MARK: 旋转允许判定

    func allowsRotation() -> Bool {
        if _windowPreparing { return false }
        if !_rotationActivation.isActive { return false }
        if rotating && !transitioning { return true }
        if currentOrientation == _deviceOrientation { return false }
        if !_forcedRotation {
            if disabledAutorotation { return false }
            if !SJRotationIsSupportedOrientation(_deviceOrientation, _autorotationSupportedOrientations) { return false }
        }
        if rotating && transitioning { return false }
        if let should = shouldTriggerRotation, !should(self) { return false }
        return true
    }

    // MARK: 旋转/转场状态广播 (NS_REQUIRES_SUPER)

    func rotationBegin() {
        rotating = true
        NotificationCenter.default.post(name: SJRotationManagerRotationNotification, object: self)
    }

    func rotationEnd() {
        rotating = false
        _forcedRotation = false
        NotificationCenter.default.post(name: SJRotationManagerRotationNotification, object: self)
    }

    func transitionBegin() {
        transitioning = true
        NotificationCenter.default.post(name: SJRotationManagerTransitionNotification, object: self)
    }

    func transitionEnd() {
        transitioning = false
        NotificationCenter.default.post(name: SJRotationManagerTransitionNotification, object: self)
    }

    // MARK: 抽象方法 (子类必须重写)

    func pointInside(_ point: CGPoint, with event: UIEvent?) -> Bool {
        fatalError("You must override \(#function) in a subclass.")
    }

    @objc(supportedInterfaceOrientationsForWindow:)
    public func supportedInterfaceOrientations(forWindow window: UIWindow?) -> UIInterfaceOrientationMask {
        fatalError("You must override \(#function) in a subclass.")
    }

    var rotationFullscreenViewController: SJRotationFullscreenViewController {
        fatalError("You must override \(#function) in a subclass.")
    }

    func rotateToOrientation(_ orientation: SJOrientation, animated: Bool, complete completionHandler: ((SJRotationManager) -> Void)?) {
        fatalError("You must override \(#function) in a subclass.")
    }

    func onDeviceOrientationChanged(_ deviceOrientation: SJOrientation) {
        // 子类重写
    }

    // MARK: 旋转公开 API

    @objc public var isFullscreen: Bool {
        SJRotationIsFullscreenOrientation(currentOrientation)
    }

    @objc public func rotate() {
        let orientation: SJOrientation
        if SJRotationIsFullscreenOrientation(currentOrientation) {
            orientation = .portrait
        } else {
            orientation = SJRotationIsFullscreenOrientation(_deviceOrientation) ? _deviceOrientation : .landscapeLeft
        }
        rotate(orientation, animated: true)
    }

    @objc(rotate:animated:)
    public func rotate(_ orientation: SJOrientation, animated: Bool) {
        rotate(orientation, animated: animated, completionHandler: nil)
    }

    @objc(rotate:animated:completionHandler:)
    public func rotate(_ orientation: SJOrientation, animated: Bool, completionHandler: ((SJRotationManager) -> Void)?) {
        let fromOrientation = currentOrientation
        let toOrientation = orientation
        if fromOrientation == toOrientation {
            completionHandler?(self)
            return
        }

        _forcedRotation = true
        _deviceOrientation = orientation
        _rotationActivation.forceActive()
        rotateToOrientation(orientation, animated: animated, complete: completionHandler)
    }

    // MARK: SJRotationFullscreenWindowDelegate

    public func window(_ window: SJRotationFullscreenWindow, point: CGPoint, with event: UIEvent?) -> Bool {
        pointInside(point, with: event)
    }

    // MARK: SJRotationFullscreenNavigationControllerDelegate

    public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        actionForwarder?.pushViewController(viewController, animated: animated)
    }

    // MARK: SJRotationFullscreenViewControllerDelegate

    public func prefersStatusBarHidden(for viewController: SJRotationFullscreenViewController) -> Bool {
        if rotating {
            return SJRotationIsFullscreenOrientation(_deviceOrientation)
        }
        return actionForwarder?.prefersStatusBarHidden ?? false
    }

    public func preferredStatusBarStyle(for viewController: SJRotationFullscreenViewController) -> UIStatusBarStyle {
        actionForwarder?.preferredStatusBarStyle ?? .default
    }

    // MARK: 私有准备

    private func prepareWindowForRotation() {
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.keyWindowCompat?.windowScene
                ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)
            if let scene {
                _window = SJRotationFullscreenWindow(windowScene: scene, delegate: self)
            } else {
                _window = SJRotationFullscreenWindow(frame: UIScreen.main.bounds, delegate: self)
            }
        } else {
            _window = SJRotationFullscreenWindow(frame: UIScreen.main.bounds, delegate: self)
        }
        _window.rotationManager = self
        let fullscreenViewController = rotationFullscreenViewController
        fullscreenViewController.delegate = self
        let rootViewController = SJRotationFullscreenNavigationController(rootViewController: fullscreenViewController, delegate: self)
        _window.rootViewController = rootViewController
        _windowPreparing = true
        UIView.animate(withDuration: 0.0, animations: { /* next */ }, completion: { [weak self] _ in
            guard let self else { return }
            self._window.windowLevel = UIWindow.Level.normal - 1
            self._window.isHidden = false
            UIView.animate(withDuration: 0.0, animations: { /* preparing */ }, completion: { [weak self] _ in
                guard let self else { return }
                self._window.isHidden = true
                self._window.windowLevel = UIWindow.Level.statusBar - 1
                self._windowPreparing = false
            })
        })
    }

    private func observeDeviceOrientation() {
        let device = UIDevice.current
        if !device.isGeneratingDeviceOrientationNotifications {
            device.beginGeneratingDeviceOrientationNotifications()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceOrientationChangedWithNote(_:)), name: UIDevice.orientationDidChangeNotification, object: device)
    }

    @objc private func onDeviceOrientationChangedWithNote(_ note: Notification) {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait, .landscapeLeft, .landscapeRight:
            // SJOrientation 与 UIDeviceOrientation 的 rawValue 完全对应
            if let sj = SJOrientation(rawValue: UInt(orientation.rawValue)), _deviceOrientation != sj {
                _deviceOrientation = sj
                onDeviceOrientationChanged(sj)
            }
        default:
            break
        }
    }
}

// MARK: - keyWindow 兼容工具

extension UIApplication {
    /// iOS 15+ 下从 connectedScenes 拿 keyWindow, 兼容旧写法
    var keyWindowCompat: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - SJRotationActionForwarder

@MainActor
@objc(SJRotationActionForwarder)
public protocol SJRotationActionForwarder: NSObjectProtocol {
    @objc(pushViewController:animated:)
    func pushViewController(_ viewController: UIViewController, animated: Bool)

    @objc var preferredStatusBarStyle: UIStatusBarStyle { get }

    @objc var prefersStatusBarHidden: Bool { get }
}

// MARK: - fix safe area
//
// 原 ObjC 中通过 method swizzling 修复 iOS 13~16 全屏窗口下系统对其它 window 的 contentOverlayInsets 调整。
// Swift 版保留同等行为: 仅在 iOS 13~16 安装 swizzle (iOS 16 起已不需要)。
// 关联对象保存 disabledAdjustSafeAreaInsetsMask。

public struct SJSafeAreaInsetsMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let none = SJSafeAreaInsetsMask([])
    public static let top = SJSafeAreaInsetsMask(rawValue: 1 << 0)
    public static let left = SJSafeAreaInsetsMask(rawValue: 1 << 1)
    public static let bottom = SJSafeAreaInsetsMask(rawValue: 1 << 2)
    public static let right = SJSafeAreaInsetsMask(rawValue: 1 << 3)

    public static let horizontal: SJSafeAreaInsetsMask = [.left, .right]
    // 注意: 保持与原 ObjC 完全一致 (原定义 Vertical = Top | Right, 疑似笔误但行为对齐)
    public static let vertical: SJSafeAreaInsetsMask = [.top, .right]
    public static let all: SJSafeAreaInsetsMask = [.horizontal, .vertical]
}

private nonisolated(unsafe) var sj_disabledAdjustSafeAreaInsetsMaskKey: UInt8 = 0

extension UIViewController {
    /// 禁止调整哪些方向的安全区
    public var disabledAdjustSafeAreaInsetsMask: SJSafeAreaInsetsMask {
        get {
            let value = (objc_getAssociatedObject(self, &sj_disabledAdjustSafeAreaInsetsMaskKey) as? NSNumber)?.uintValue ?? 0
            return SJSafeAreaInsetsMask(rawValue: value)
        }
        set {
            objc_setAssociatedObject(self, &sj_disabledAdjustSafeAreaInsetsMaskKey, NSNumber(value: newValue.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc func sj_setContentOverlayInsets(_ insets: UIEdgeInsets, andLeftMargin leftMargin: CGFloat, rightMargin: CGFloat) {
        var insets = insets
        let mask = disabledAdjustSafeAreaInsetsMask
        if mask.contains(.top) { insets.top = 0 }
        if mask.contains(.left) { insets.left = 0 }
        if mask.contains(.bottom) { insets.bottom = 0 }
        if mask.contains(.right) { insets.right = 0 }

        // 经过 swizzle 后, 调用 sj_setContentOverlayInsets 实际指向原始实现
        let keyWindow = UIApplication.shared.keyWindowCompat
        let otherWindow = self.view.window
        if let key = keyWindow as? SJRotationFullscreenWindow, let otherWindow {
            let manager = key.rotationManager
            let superviewWindow = manager?.superview?.window
            if superviewWindow != otherWindow {
                sj_setContentOverlayInsets(insets, andLeftMargin: leftMargin, rightMargin: rightMargin)
            }
        } else {
            sj_setContentOverlayInsets(insets, andLeftMargin: leftMargin, rightMargin: rightMargin)
        }
    }
}

/// 安装 safe area 修复 swizzle (仅 iOS 13~16)。需要由 module 初始化时调用一次 (见 notes)。
@MainActor
public func SJRotationInstallSafeAreaFixingIfNeeded() {
    if #available(iOS 16.0, *) { return }
    guard #available(iOS 13.0, *) else { return }

    struct Once { @MainActor static var done = false }
    if Once.done { return }
    Once.done = true

    let cls: AnyClass = UIViewController.self
    // 原始选择器经 base64 还原: "_setContentOverlayInsets:andLeftMargin:rightMargin:"
    guard let data = Data(base64Encoded: "X3NldENvbnRlbnRPdmVybGF5SW5zZXRzOmFuZExlZnRNYXJnaW46cmlnaHRNYXJnaW46"),
          let method = String(data: data, encoding: .utf8) else { return }
    let originalSelector = NSSelectorFromString(method)
    let swizzledSelector = #selector(UIViewController.sj_setContentOverlayInsets(_:andLeftMargin:rightMargin:))

    guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
          let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

