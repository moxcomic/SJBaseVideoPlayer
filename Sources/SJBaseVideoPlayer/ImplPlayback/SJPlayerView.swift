//
//  SJPlayerView.swift
//  Pods
//
//  Created by 畅三江 on 2019/3/28.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import UIKit

/// 播放器根视图代理
@objc(SJPlayerViewDelegate)
@MainActor public protocol SJPlayerViewDelegate: NSObjectProtocol {
    @objc func playerViewWillMoveToWindow(_ playerView: SJPlayerView)
    @objc func playerView(_ playerView: SJPlayerView, hitTestFor view: UIView?) -> UIView?
}

@objc(SJPlayerView)
@MainActor
open class SJPlayerView: UIView {
    /// 播放显示视图
    @objc public internal(set) var presentView: UIView?

    @objc public weak var delegate: SJPlayerViewDelegate?

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if let delegate = delegate, delegate.responds(to: #selector(SJPlayerViewDelegate.playerView(_:hitTestFor:))) {
            return delegate.playerView(self, hitTestFor: view)
        }
        return view
    }

    open override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.window != nil {
                if let delegate = self.delegate, delegate.responds(to: #selector(SJPlayerViewDelegate.playerViewWillMoveToWindow(_:))) {
                    delegate.playerViewWillMoveToWindow(self)
                }
            }
        }
    }
}

