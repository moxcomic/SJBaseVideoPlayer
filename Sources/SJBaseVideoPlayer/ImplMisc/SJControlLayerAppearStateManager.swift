//
//  SJControlLayerAppearStateManager.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/12/28.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名, @objc 对外暴露.
//

import Foundation
import UIKit

/// 控制层显示状态改变通知 (内部使用, 名称与 ObjC 版严格一致)
private let SJControlLayerAppearStateDidChangeNotification = Notification.Name("SJControlLayerAppearStateDidChangeNotification")

// MARK: - Observer

@objc(SJControlLayerAppearManagerObserver)
public final class SJControlLayerAppearManagerObserver: NSObject, SJControlLayerAppearManagerObserver_Protocol {
    @objc public var onAppearChanged: ((SJControlLayerAppearManager) -> Void)?

    @objc public init(manager mgr: SJControlLayerAppearManager) {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appearStateDidChange(_:)), name: SJControlLayerAppearStateDidChangeNotification, object: mgr)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appearStateDidChange(_ note: Notification) {
        guard let mgr = note.object as? SJControlLayerAppearManager else { return }
        onAppearChanged?(mgr)
    }
}

// MARK: - Manager

@objc(SJControlLayerAppearStateManager)
public final class SJControlLayerAppearStateManager: NSObject, SJControlLayerAppearManager {

    private let timer = SJTimerControl()
    private var _disabled: Bool = false
    private var _isAppeared: Bool = false

    @objc public var canAutomaticallyDisappear: ((SJControlLayerAppearManager) -> Bool)?

    public override init() {
        super.init()
        timer.interval = 5
        timer.exeBlock = { [weak self] control in
            guard let self = self else { return }
            if self.disabled {
                control.interrupt()
                return
            }
            if let canAutomaticallyDisappear = self.canAutomaticallyDisappear {
                if !canAutomaticallyDisappear(self) {
                    return
                }
            }
            self.needDisappear()
        }
    }

    @objc public func getObserver() -> SJControlLayerAppearManagerObserver {
        return SJControlLayerAppearManagerObserver(manager: self)
    }

    @objc public var interval: TimeInterval {
        get { timer.interval }
        set { timer.interval = newValue }
    }

    @objc public var isAppeared: Bool {
        get { _isAppeared }
        set {
            _isAppeared = newValue
            NotificationCenter.default.post(name: SJControlLayerAppearStateDidChangeNotification, object: self)
        }
    }

    @objc(isDisabled) public var disabled: Bool {
        get { _disabled }
        set {
            if newValue == _disabled { return }
            _disabled = newValue
            if newValue {
                _clear()
            } else if _isAppeared {
                _start()
            }
        }
    }

    @objc public func switchAppearState() {
        if _isAppeared {
            needDisappear()
        } else {
            needAppear()
        }
    }

    @objc public func needAppear() {
        if _disabled { return }
        _start()
        isAppeared = true
    }

    @objc public func needDisappear() {
        if _disabled { return }
        _clear()
        isAppeared = false
    }

    @objc public func resume() {
        if _isAppeared { _start() }
    }

    @objc public func keepAppearState() {
        needAppear()
        _clear()
    }

    @objc public func keepDisappearState() {
        needDisappear()
    }

    private func _start() {
        if _disabled { return }
        timer.resume()
    }

    private func _clear() {
        timer.interrupt()
    }
}

