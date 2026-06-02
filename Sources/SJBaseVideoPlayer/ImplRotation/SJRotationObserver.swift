//
//  SJRotationObserver.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationObserver.h/.m
//  - 通过 NotificationCenter 监听旋转/转场通知, 回调闭包。
//  - 实现 SJRotationManagerObserver 协议。
//

import UIKit

@MainActor
@objc(SJRotationObserver)
public class SJRotationObserver: NSObject, SJRotationManagerObserver {

    @objc public var onRotatingChanged: ((SJRotationManager, Bool) -> Void)?
    @objc public var onTransitioningChanged: ((SJRotationManager, Bool) -> Void)?

    @objc(initWithManager:)
    public init(manager: SJRotationManager) {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onRotation(_:)), name: SJRotationManagerRotationNotification, object: manager)
        NotificationCenter.default.addObserver(self, selector: #selector(onTransition(_:)), name: SJRotationManagerTransitionNotification, object: manager)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onRotation(_ note: Notification) {
        guard let mgr = note.object as? SJRotationManager else { return }
        if let block = onRotatingChanged { block(mgr, mgr.rotating) }
    }

    @objc private func onTransition(_ note: Notification) {
        guard let mgr = note.object as? SJRotationManager else { return }
        if let block = onTransitioningChanged { block(mgr, mgr.transitioning) }
    }
}

