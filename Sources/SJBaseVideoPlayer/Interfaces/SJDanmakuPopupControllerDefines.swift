//
//  SJDanmakuPopupControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/11/12.
//
//  契约层(Swift 6.3): 由原 SJDanmakuPopupControllerDefines.h 转换而来。
//  弹幕控制。
//

import UIKit
import Foundation

// MARK: - 弹幕控制协议

/// 对应原 @protocol SJDanmakuPopupController_Protocol <NSObject>。
@MainActor
@objc(SJDanmakuPopupController)
public protocol SJDanmakuPopupController_Protocol: NSObjectProtocol {
    @objc init(numberOfTracks: UInt)

    /// 是否禁用(禁用后将无法添加弹幕)。
    @objc(isDisabled) var disabled: Bool { get set }

    /// 发送一条弹幕, 弹幕将自动显示(在某一条队列中适时显示)。
    @objc func enqueue(_ danmaku: SJDanmakuItem)

    /// 移除未显示的弹幕。
    @objc func emptyQueue()

    /// 移除已显示的弹幕。
    @objc func removeDisplayedItems()

    /// 移除所有弹幕(已显示的弹幕也会被移除)。
    @objc func removeAll()

    /// 是否已暂停移动。
    @objc(isPaused) var paused: Bool { get }

    /// 使暂停, 弹幕将停止移动。
    @objc func pause()

    /// 使恢复, 弹幕将恢复移动。
    @objc func resume()

    /// 控制器视图。
    @objc var view: UIView { get }

    /// 获取观察者。
    @objc func getObserver() -> SJDanmakuPopupControllerObserver

    /// 未显示的弹幕数量。
    @objc var queueSize: Int { get }
    @objc var numberOfTracks: Int { get set }
}

// MARK: - 弹幕条目协议

/// 对应原 @protocol SJDanmakuItem_Protocol <NSObject>。
@MainActor
@objc(SJDanmakuItem)
public protocol SJDanmakuItem_Protocol: NSObjectProtocol {
    @objc init(content: NSAttributedString)
    @objc init(customView: UIView)

    @objc var content: NSAttributedString? { get }
    @objc var customView: UIView? { get }
}

// MARK: - 弹幕控制观察者

/// 对应原 @protocol SJDanmakuPopupControllerObserver_Protocol <NSObject>。
@MainActor
@objc(SJDanmakuPopupControllerObserver)
public protocol SJDanmakuPopupControllerObserver_Protocol: NSObjectProtocol {
    @objc var onDisabledChanged: ((_ controller: SJDanmakuPopupController) -> Void)? { get set }
    @objc var onPausedChanged: ((_ controller: SJDanmakuPopupController) -> Void)? { get set }

    /// 该条弹幕已出队列, 将要显示时调用。
    @objc var willDisplayItem: ((_ controller: SJDanmakuPopupController, _ item: SJDanmakuItem) -> Void)? { get set }
    /// 结束显示时调用。
    @objc var didEndDisplayingItem: ((_ controller: SJDanmakuPopupController, _ item: SJDanmakuItem) -> Void)? { get set }
}

