//
//  SJRotationFullscreenViewController.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/14.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationFullscreenViewController.h/.m
//  - 全屏承载用的 UIViewController 与其内部承载 View。
//  - delegate 协议保持原选择器名, @objc 暴露。
//

import UIKit

// MARK: - 内部承载 View

/// 全屏承载 View: 竖屏尺寸时复用 keyWindow 的安全区
@MainActor
final class SJRotationFullscreenView: UIView {
    override var safeAreaInsets: UIEdgeInsets {
        let size = bounds.size
        if size.width > size.height { return super.safeAreaInsets }
        return UIApplication.shared.keyWindowCompat?.safeAreaInsets ?? super.safeAreaInsets
    }
}

// MARK: - 全屏 ViewController

@MainActor
@objc(SJRotationFullscreenViewController)
public class SJRotationFullscreenViewController: UIViewController {

    @objc public weak var delegate: SJRotationFullscreenViewControllerDelegate?

    public override func loadView() {
        self.view = SJRotationFullscreenView(frame: UIScreen.main.bounds)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = false
        view.backgroundColor = .clear
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        delegate?.preferredStatusBarStyle(for: self) ?? .default
    }

    public override var prefersStatusBarHidden: Bool {
        delegate?.prefersStatusBarHidden(for: self) ?? false
    }

    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
}

// MARK: - Delegate

@MainActor
@objc(SJRotationFullscreenViewControllerDelegate)
public protocol SJRotationFullscreenViewControllerDelegate: NSObjectProtocol {
    @objc(preferredStatusBarStyleForRotationFullscreenViewController:)
    func preferredStatusBarStyle(for viewController: SJRotationFullscreenViewController) -> UIStatusBarStyle

    @objc(prefersStatusBarHiddenForRotationFullscreenViewController:)
    func prefersStatusBarHidden(for viewController: SJRotationFullscreenViewController) -> Bool
}

