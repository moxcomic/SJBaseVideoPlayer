//
//  SJBaseVideoPlayer+Life.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Life)。关于视图控制器(v1.3.0 新增)。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    /// You should call it when view did appear
    @objc public func vc_viewDidAppear() {
        viewControllerManager.viewDidAppear()
        playModelObserver?.refreshAppearState()
    }

    /// You should call it when view will disappear
    @objc public func vc_viewWillDisappear() {
        viewControllerManager.viewWillDisappear()
    }

    @objc public func vc_viewDidDisappear() {
        viewControllerManager.viewDidDisappear()
        pause()
    }

    @objc public func vc_prefersStatusBarHidden() -> Bool {
        return viewControllerManager.prefersStatusBarHidden
    }

    @objc public func vc_preferredStatusBarStyle() -> UIStatusBarStyle {
        return viewControllerManager.preferredStatusBarStyle
    }

    /// 当调用`vc_viewWillDisappear`时, 将设置为YES; 当调用`vc_viewDidAppear`时, 将设置为NO
    @objc public var vc_isDisappeared: Bool {
        get { viewControllerManager.viewDisappeared }
        set {
            newValue ? viewControllerManager.viewWillDisappear() :
                       viewControllerManager.viewDidAppear()
        }
    }

    /// v1.6.0 新增. 临时显示状态栏. Animatable.
    @objc public func needShowStatusBar() {
        viewControllerManager.showStatusBar()
    }

    /// 临时隐藏状态栏. Animatable.
    @objc public func needHiddenStatusBar() {
        viewControllerManager.hiddenStatusBar()
    }
}

