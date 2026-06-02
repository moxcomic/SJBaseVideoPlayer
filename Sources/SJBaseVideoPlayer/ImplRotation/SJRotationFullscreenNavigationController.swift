//
//  SJRotationFullscreenNavigationController.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationFullscreenNavigationController.h/.m
//  - 全屏窗口的根导航控制器: 隐藏导航栏, 转发状态栏/方向给 topViewController, push 行为转发给 delegate。
//

import UIKit

@MainActor
@objc(SJRotationFullscreenNavigationController)
public class SJRotationFullscreenNavigationController: UINavigationController {

    private weak var sj_delegate: SJRotationFullscreenNavigationControllerDelegate?

    @objc(initWithRootViewController:delegate:)
    public init(rootViewController: UIViewController, delegate: SJRotationFullscreenNavigationControllerDelegate?) {
        super.init(rootViewController: rootViewController)
        self.sj_delegate = delegate
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        super.setNavigationBarHidden(true, animated: false)
    }

    // 屏蔽外部设置导航栏可见性 (与 ObjC 版本一致, 始终隐藏)
    public override var isNavigationBarHidden: Bool {
        get { super.isNavigationBarHidden }
        set { /* no-op */ }
    }

    public override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        // no-op
    }

    public override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? super.shouldAutorotate
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        topViewController?.preferredInterfaceOrientationForPresentation ?? super.preferredInterfaceOrientationForPresentation
    }

    public override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    public override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    public override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if viewControllers.count < 1 {
            super.pushViewController(viewController, animated: animated)
        } else if let delegate = sj_delegate {
            delegate.pushViewController(viewController, animated: animated)
        }
    }
}

// MARK: - Delegate

@MainActor
@objc(SJRotationFullscreenNavigationControllerDelegate)
public protocol SJRotationFullscreenNavigationControllerDelegate: NSObjectProtocol {
    @objc(pushViewController:animated:)
    func pushViewController(_ viewController: UIViewController, animated: Bool)
}

