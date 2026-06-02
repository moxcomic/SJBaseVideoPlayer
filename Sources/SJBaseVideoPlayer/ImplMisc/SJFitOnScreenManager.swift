//
//  SJFitOnScreenManager.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/12/31.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名.
//

import Foundation
import UIKit

/// 适配屏幕转场状态改变通知 (内部使用, 名称与 ObjC 版严格一致)
private let SJFitOnScreenManagerTransitioningValueDidChangeNotification = Notification.Name("SJFitOnScreenManagerTransitioningValueDidChange")

// MARK: - Observer

@objc(SJFitOnScreenManagerObserver)
public final class SJFitOnScreenManagerObserver: NSObject, SJFitOnScreenManagerObserver_Protocol {
    @objc public var fitOnScreenWillBeginExeBlock: ((SJFitOnScreenManager) -> Void)?
    @objc public var fitOnScreenDidEndExeBlock: ((SJFitOnScreenManager) -> Void)?

    @objc public init(manager: SJFitOnScreenManager) {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(transitioningValueDidChange(_:)), name: SJFitOnScreenManagerTransitioningValueDidChangeNotification, object: manager)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func transitioningValueDidChange(_ note: Notification) {
        guard let mgr = note.object as? SJFitOnScreenManager else { return }
        if mgr.transitioning {
            fitOnScreenWillBeginExeBlock?(mgr)
        } else {
            fitOnScreenDidEndExeBlock?(mgr)
        }
    }
}

// MARK: - FitOnScreen 模式 ViewController

@MainActor
@objc(SJFitOnScreenModeViewController)
final class SJFitOnScreenModeViewController: UIViewController {
    override var shouldAutorotate: Bool { false }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

@MainActor
@objc(SJFitOnScreenModeNavigationController)
final class SJFitOnScreenModeNavigationController: UINavigationController {
    weak var viewControllerManager: SJViewControllerManager?

    override func viewDidLoad() {
        super.viewDidLoad()
        super.setNavigationBarHidden(true, animated: false)
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) { }

    override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? false
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? .all
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        topViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        topViewController?.preferredStatusBarStyle ?? .default
    }
    override var prefersStatusBarHidden: Bool {
        viewControllerManager?.prefersStatusBarHidden ?? false
    }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

// MARK: - Manager

@MainActor
@objc(SJFitOnScreenManager)
public final class SJFitOnScreenManager: NSObject, SJFitOnScreenManager_Protocol {

    private var _transitioning: Bool = false
    private var innerFitOnScreen: Bool = false
    private let target: UIView
    private let superview: UIView

    @objc public var duration: TimeInterval = 0.3

    @objc public init(target: UIView, targetSuperview superview: UIView) {
        self.target = target
        self.superview = superview
        super.init()
    }

    @objc public func getObserver() -> SJFitOnScreenManagerObserver {
        return SJFitOnScreenManagerObserver(manager: self)
    }

    @objc(isTransitioning) public private(set) var transitioning: Bool {
        get { _transitioning }
        set {
            _transitioning = newValue
            NotificationCenter.default.post(name: SJFitOnScreenManagerTransitioningValueDidChangeNotification, object: self)
        }
    }

    @objc(isFitOnScreen) public var fitOnScreen: Bool {
        get { innerFitOnScreen }
        set { setFitOnScreen(newValue, animated: true) }
    }

    @objc public func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool) {
        setFitOnScreen(fitOnScreen, animated: animated, completionHandler: nil)
    }

    @objc public func setFitOnScreen(_ fitOnScreen: Bool, animated: Bool, completionHandler: ((SJFitOnScreenManager) -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.transitioning { return }
            if fitOnScreen == self.fitOnScreen {
                completionHandler?(self)
                return
            }
            self.setInnerFitOnScreen(fitOnScreen)
            self.transitioning = true
            if fitOnScreen {
                let top = self.topMostController()
                if !animated {
                    self._presentedAnimation(duration: 0, completionHandler: nil)
                }
                top?.present(self.viewController, animated: animated, completion: {
                    completionHandler?(self)
                })
            } else {
                if !animated {
                    self._dismissedAnimation(duration: 0, completionHandler: nil)
                }
                self.viewController.dismiss(animated: animated, completion: {
                    completionHandler?(self)
                })
            }
        }
    }

    @objc public var superviewInFitOnScreen: UIView {
        return viewController.view
    }

    private func topMostController() -> UIViewController? {
        var topController = UIApplication.shared.keyWindow?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }

    private func setInnerFitOnScreen(_ value: Bool) {
        if value == innerFitOnScreen { return }
        innerFitOnScreen = value
    }

    @objc public weak var viewControllerManager: SJViewControllerManager? {
        get { viewController.viewControllerManager }
        set { viewController.viewControllerManager = newValue }
    }

    private lazy var viewController: SJFitOnScreenModeNavigationController = {
        let vc = SJFitOnScreenModeViewController()
        let nav = SJFitOnScreenModeNavigationController(rootViewController: vc)
        let duration = self.duration
        nav.setTransitionDuration(duration, presentedAnimation: { [weak self] _, completion in
            guard let self = self else { return }
            self._presentedAnimation(duration: duration, completionHandler: completion)
        }, dismissedAnimation: { [weak self] _, completion in
            guard let self = self else { return }
            self._dismissedAnimation(duration: duration, completionHandler: completion)
        })
        return nav
    }()

    private func _presentedAnimation(duration: TimeInterval, completionHandler completion: SJAnimationCompletionHandler?) {
        let keyWindow = UIApplication.shared.keyWindow
        let frame = superview.convert(superview.bounds, to: keyWindow)
        target.frame = frame
        viewController.view.addSubview(target)
        UIView.animate(withDuration: duration, animations: {
            self.target.frame = self.viewController.view.bounds
            self.target.layoutIfNeeded()
        }, completion: { _ in
            completion?()
            self.transitioning = false
        })
    }

    private func _dismissedAnimation(duration: TimeInterval, completionHandler completion: SJAnimationCompletionHandler?) {
        let keyWindow = UIApplication.shared.keyWindow
        let frame = superview.convert(superview.bounds, to: keyWindow)
        UIView.animate(withDuration: duration, animations: {
            self.target.frame = frame
            self.target.layoutIfNeeded()
        }, completion: { _ in
            self.target.frame = self.superview.bounds
            self.superview.addSubview(self.target)
            completion?()
            self.transitioning = false
        })
    }
}

