//
//  SJViewControllerManager.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/23.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名.
//

import Foundation
import UIKit

@MainActor
@objc(SJViewControllerManager)
public final class SJViewControllerManager: NSObject, SJViewControllerManager_Protocol, SJRotationActionForwarder {

    @objc public weak var fitOnScreenManager: SJFitOnScreenManager?
    @objc public weak var rotationManager: SJRotationManager?
    @objc public weak var controlLayerAppearManager: SJControlLayerAppearManager?
    @objc public weak var presentView: (UIView & SJVideoPlayerPresentView_Protocol)?

    @objc(isViewDisappeared) public private(set) var viewDisappeared: Bool = false
    @objc(isLockedScreen) public var lockedScreen: Bool = false

    private var tmpShowStatusBar = false
    private var tmpHiddenStatusBar = false

    @objc public var prefersStatusBarHidden: Bool {
        if tmpShowStatusBar { return false }
        if tmpHiddenStatusBar { return true }
        if lockedScreen { return true }
        if controlLayerAppearManager?.isAppeared == true { return false }
        if rotationManager?.rotating == true { return false }
        if fitOnScreenManager?.transitioning == true { return false }

        // 全屏时, 使状态栏根据控制层显示或隐藏
        if rotationManager?.isFullscreen == true || fitOnScreenManager?.fitOnScreen == true {
            return !(controlLayerAppearManager?.isAppeared ?? false)
        }
        return false
    }

    @objc public var preferredStatusBarStyle: UIStatusBarStyle {
        if rotationManager?.rotating == true || fitOnScreenManager?.transitioning == true {
            return .lightContent
        }
        // 全屏时, 使状态栏变成白色
        if rotationManager?.isFullscreen == true || fitOnScreenManager?.fitOnScreen == true {
            return .lightContent
        }
        return .default
    }

    @objc public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        rotationManager?.rotate(.portrait, animated: true, completionHandler: { [weak self] _ in
            guard let self = self else { return }
            let nav = self.presentView?.lookupResponder(for: UINavigationController.self) as? UINavigationController
            if let nav = nav {
                nav.pushViewController(viewController, animated: animated)
            }
        })
    }

    @objc public func viewDidAppear() {
        viewDisappeared = false
    }

    @objc public func viewWillDisappear() {
        viewDisappeared = true
    }

    @objc public func viewDidDisappear() {
    }

    @objc public func showStatusBar() {
        if tmpShowStatusBar { return }
        tmpShowStatusBar = true
        setNeedsStatusBarAppearanceUpdate()
        DispatchQueue.main.async { [weak self] in
            self?.tmpShowStatusBar = false
        }
    }

    @objc public func hiddenStatusBar() {
        if tmpHiddenStatusBar { return }
        tmpHiddenStatusBar = true
        setNeedsStatusBarAppearanceUpdate()
        DispatchQueue.main.async { [weak self] in
            self?.tmpHiddenStatusBar = false
        }
    }

    @objc public func setNeedsStatusBarAppearanceUpdate() {
        UIApplication.shared.keyWindow?.rootViewController?.setNeedsStatusBarAppearanceUpdate()

        if let rotationManager = rotationManager as? SJRotationManager, rotationManager.isFullscreen {
            rotationManager.window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

