//
//  SJRotationManager_iOS_9_15.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationManager_iOS_9_15.h/.m
//  - iOS 9~15 旋转实现: 通过 KVC 写 UIDevice.orientation 触发系统旋转, 在
//    viewWillTransitionToSize 协调动画完成承载视图迁移。
//  - SJRotationFullscreenViewController_iOS_9_15: 带 shouldAutorotate / viewWillTransitionToSize
//    回调的全屏 VC 子类, 内含 playerSuperview。
//

import UIKit

#if canImport(SJUIKit)
import SJUIKit
#endif

// MARK: - iOS 9~15 全屏 VC

@available(iOS, introduced: 9.0, deprecated: 16.0, message: "deprecated!")
@MainActor
@objc(SJRotationFullscreenViewController_iOS_9_15)
public class SJRotationFullscreenViewController_iOS_9_15: SJRotationFullscreenViewController {

    private(set) var playerSuperview: UIView = UIView(frame: .zero)

    // 重声明为强类型的 9_15 delegate (覆盖父类的 SJRotationFullscreenViewControllerDelegate)
    weak var delegate_iOS_9_15: SJRotationFullscreenViewControllerDelegate_iOS_9_15?

    public override func viewDidLoad() {
        super.viewDidLoad()
        playerSuperview = UIView(frame: .zero)
        playerSuperview.backgroundColor = .clear
        view.addSubview(playerSuperview)
    }

    public override var shouldAutorotate: Bool {
        delegate_iOS_9_15?.shouldAutorotate(for: self) ?? false
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .none
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        delegate_iOS_9_15?.viewController(self, viewWillTransitionTo: size, with: coordinator)
    }
}

// MARK: - iOS 9~15 全屏 VC delegate

@available(iOS, introduced: 9.0, deprecated: 16.0, message: "deprecated!")
@MainActor
protocol SJRotationFullscreenViewControllerDelegate_iOS_9_15: SJRotationFullscreenViewControllerDelegate {
    func shouldAutorotate(for viewController: SJRotationFullscreenViewController_iOS_9_15) -> Bool
    func viewController(_ viewController: SJRotationFullscreenViewController_iOS_9_15,
                        viewWillTransitionTo size: CGSize,
                        with coordinator: UIViewControllerTransitionCoordinator)
}

// MARK: - iOS 9~15 旋转管理器

@available(iOS, introduced: 9.0, deprecated: 16.0, message: "deprecated!")
@MainActor
@objc(SJRotationManager_iOS_9_15)
public class SJRotationManager_iOS_9_15: SJRotationManager, SJRotationFullscreenViewControllerDelegate_iOS_9_15 {

    private var _completionHandler: ((SJRotationManager) -> Void)?

    private var _rotationFullscreenViewController: SJRotationFullscreenViewController_iOS_9_15?
    private var fullscreenVC_iOS_9_15: SJRotationFullscreenViewController_iOS_9_15 {
        if _rotationFullscreenViewController == nil {
            let vc = SJRotationFullscreenViewController_iOS_9_15()
            vc.delegate_iOS_9_15 = self
            _rotationFullscreenViewController = vc
        }
        return _rotationFullscreenViewController!
    }

    override var rotationFullscreenViewController: SJRotationFullscreenViewController {
        fullscreenVC_iOS_9_15
    }

    override func pointInside(_ point: CGPoint, with event: UIEvent?) -> Bool {
        let playerSuperview = fullscreenVC_iOS_9_15.playerSuperview
        guard target?.superview == playerSuperview else { return false }
        let converted = window.convert(point, to: playerSuperview)
        return playerSuperview.point(inside: converted, with: event)
    }

    @objc(supportedInterfaceOrientationsForWindow:)
    public override func supportedInterfaceOrientations(forWindow window: UIWindow?) -> UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    override func rotateToOrientation(_ orientation: SJOrientation, animated: Bool, complete completionHandler: ((SJRotationManager) -> Void)?) {
#if DEBUG
        assert(animated, "暂不支持关闭动画!")
#endif
        _completionHandler = completionHandler
        // 通过 KVC 写 UIDevice.orientation 触发系统旋转 (与原 ObjC 一致)
        UIDevice.current.setValue(UIDeviceOrientation.unknown.rawValue, forKey: "orientation")
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
    }

    override func rotationBegin() {
        if window.isHidden { window.makeKeyAndVisible() }
        setCurrentOrientation(deviceOrientation)
        super.rotationBegin()
        UIView.animate(withDuration: 0.0, animations: {}, completion: { [weak self] _ in
            self?.window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        })
    }

    override func rotationEnd() {
        if !window.isHidden && !isFullscreen {
            superview?.window?.makeKeyAndVisible()
            window.isHidden = true
        }
        super.rotationEnd()
        if let handler = _completionHandler {
            handler(self)
            _completionHandler = nil
        }
    }

    // MARK: SJRotationFullscreenViewControllerDelegate_iOS_9_15

    func shouldAutorotate(for viewController: SJRotationFullscreenViewController_iOS_9_15) -> Bool {
        if allowsRotation() {
            if !rotating { rotationBegin() }
            return true
        }
        return false
    }

    func viewController(_ viewController: SJRotationFullscreenViewController_iOS_9_15,
                        viewWillTransitionTo size: CGSize,
                        with coordinator: UIViewControllerTransitionCoordinator) {
        transitionBegin()
        let playerSuperview = fullscreenVC_iOS_9_15.playerSuperview
        if currentOrientation != .portrait {
            if let target = self.target, target.superview != playerSuperview {
                let frame = target.convert(target.bounds, to: target.window)
                playerSuperview.frame = frame // t1

                target.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
                target.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                playerSuperview.addSubview(target) // t2
                target.layoutIfNeeded()
            }

            UIView.animate(withDuration: 0.0, animations: { /* preparing */ }, completion: { [weak self] _ in
                guard let self else { return }
                UIView.animate(withDuration: 0.3, animations: {
                    playerSuperview.frame = CGRect(origin: .zero, size: size)
                    self.target?.layoutIfNeeded()
                }, completion: { [weak self] _ in
                    guard let self else { return }
                    self.transitionEnd()
                    self.rotationEnd()
                })
            })
        } else {
            UIView.animate(withDuration: 0.0, animations: { /* preparing */ }, completion: { [weak self] _ in
                guard let self else { return }
                self._fixNavigationBarLayout()
                UIView.animate(withDuration: 0.3, animations: {
                    if let superview = self.superview {
                        playerSuperview.frame = superview.convert(superview.bounds, to: superview.window)
                    }
                    self.target?.layoutIfNeeded()
                }, completion: { [weak self] _ in
                    guard let self, let superview = self.superview, let target = self.target else { return }
                    let snapshot = target.snapshotView(afterScreenUpdates: false)
                    snapshot?.frame = superview.bounds
                    snapshot?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    if let snapshot { superview.addSubview(snapshot) }
                    UIView.animate(withDuration: 0.0, animations: { /* preparing */ }, completion: { [weak self] _ in
                        guard let self, let superview = self.superview, let target = self.target else { return }
                        target.frame = superview.bounds
                        target.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        superview.addSubview(target)
                        target.layoutIfNeeded()
                        snapshot?.removeFromSuperview()
                        self.transitionEnd()
                        self.rotationEnd()
                    })
                })
            })
        }
    }

    private func _fixNavigationBarLayout() {
        if currentOrientation == .portrait {
            let nav = superview?.lookupResponder(for: UINavigationController.self) as? UINavigationController
            nav?.viewDidAppear(false)
            nav?.navigationBar.layoutSubviews()
        }
    }
}

