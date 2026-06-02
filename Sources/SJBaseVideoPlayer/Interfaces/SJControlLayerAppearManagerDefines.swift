//
//  SJControlLayerAppearManagerDefines.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/12/31.
//
//  契约层(Swift 6.3): 由原 SJControlLayerAppearManagerDefines.h 转换而来。
//

import UIKit

// MARK: - 控制层显示管理协议

/// 对应原 @protocol SJControlLayerAppearManager。
@MainActor
@objc(SJControlLayerAppearManager)
public protocol SJControlLayerAppearManager: NSObjectProtocol {
    @objc func getObserver() -> SJControlLayerAppearManagerObserver

    /// 是否禁用显示管理类。
    @objc(isDisabled) var disabled: Bool { get set }
    /// 控制层隐藏间隔, 默认5s。
    @objc var interval: TimeInterval { get set }

    // MARK: - Appear state
    @objc var isAppeared: Bool { get }
    @objc func switchAppearState()
    @objc func needAppear()
    @objc func needDisappear()

    @objc func resume()
    @objc func keepAppearState()
    @objc func keepDisappearState()

    @objc var canAutomaticallyDisappear: ((_ mgr: SJControlLayerAppearManager) -> Bool)? { get set }
}

// MARK: - 控制层显示管理观察者

/// 对应原 @protocol SJControlLayerAppearManagerObserver_Protocol。
@MainActor
@objc(SJControlLayerAppearManagerObserver)
public protocol SJControlLayerAppearManagerObserver_Protocol: NSObjectProtocol {
    @objc var onAppearChanged: ((_ mgr: SJControlLayerAppearManager) -> Void)? { get set }
}

