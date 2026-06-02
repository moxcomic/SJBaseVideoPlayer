//
//  SJSmallViewFloatingControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/6/6.
//
//  契约层(Swift 6.3): 由原 SJSmallViewFloatingControllerDefines.h 转换而来。
//

import UIKit

// MARK: - 小浮窗控制协议

/// 对应原 @protocol SJSmallViewFloatingController_Protocol。
@MainActor
@objc(SJSmallViewFloatingController)
public protocol SJSmallViewFloatingController_Protocol: NSObjectProtocol {
    @objc func getObserver() -> SJSmallViewFloatingControllerObserverProtocol

    /// 开启小浮窗, 默认为不开启(NO)。
    @objc(isEnabled) var enabled: Bool { get set }

    /// 小浮窗视图是否已显示, 默认为 NO。
    @objc var isAppeared: Bool { get }

    /// 显示小浮窗视图(只有 floatingViewShouldAppear 返回 YES 才会显示)。
    @objc func show()

    /// 隐藏小浮窗视图(立刻隐藏)。
    @objc func dismiss()

    /// 在 show 时被调用, 返回 NO 将不显示小浮窗。
    @objc var floatingViewShouldAppear: ((_ controller: SJSmallViewFloatingController) -> Bool)? { get set }

    /// 单击小浮窗视图时被调用。
    @objc var onSingleTapped: ((_ controller: SJSmallViewFloatingController) -> Void)? { get set }

    /// 双击小浮窗视图时被调用。
    @objc var onDoubleTapped: ((_ controller: SJSmallViewFloatingController) -> Void)? { get set }

    /// 小浮窗视图是否可以移动, 默认为 YES。
    @objc(isSlidable) var slidable: Bool { get set }

    /// float view
    @objc var floatingView: UIView { get }

    /// 以下属性由播放器维护。
    /// - target 为播放器呈现视图
    /// - targetSuperview 为播放器视图
    @objc weak var target: UIView? { get set }
    @objc weak var targetSuperview: UIView? { get set }
}

// MARK: - 小浮窗控制观察者

/// 对应原 @protocol SJSmallViewFloatingControllerObserverProtocol。
@MainActor
@objc(SJSmallViewFloatingControllerObserverProtocol)
public protocol SJSmallViewFloatingControllerObserverProtocol: NSObjectProtocol {
    @objc weak var controller: SJSmallViewFloatingController? { get }

    @objc var onAppearChanged: ((_ controller: SJSmallViewFloatingController) -> Void)? { get set }
    @objc var onEnabled: ((_ controller: SJSmallViewFloatingController) -> Void)? { get set }
}

