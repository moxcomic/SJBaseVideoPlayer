//
//  SJViewControllerManagerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/11/23.
//
//  契约层(Swift 6.3): 由原 SJViewControllerManagerDefines.h 转换而来。
//

import UIKit

// MARK: - 视图控制器管理协议

/// 对应原 @protocol SJViewControllerManager_Protocol <NSObject>。
@MainActor
@objc(SJViewControllerManager)
public protocol SJViewControllerManager_Protocol: NSObjectProtocol {
    @objc(isViewDisappeared) var viewDisappeared: Bool { get }
    @objc var preferredStatusBarStyle: UIStatusBarStyle { get }
    @objc var prefersStatusBarHidden: Bool { get }

    @objc func viewDidAppear()
    @objc func viewWillDisappear()
    @objc func viewDidDisappear()
    @objc func pushViewController(_ viewController: UIViewController, animated: Bool)
    @objc func showStatusBar()
    @objc func hiddenStatusBar()
    @objc func setNeedsStatusBarAppearanceUpdate()
}

