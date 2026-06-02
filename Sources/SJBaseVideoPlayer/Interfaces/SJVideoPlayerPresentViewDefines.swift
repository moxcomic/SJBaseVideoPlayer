//
//  SJVideoPlayerPresentViewDefines.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/9/10.
//
//  契约层(Swift 6.3): 由原 SJVideoPlayerPresentViewDefines.h 转换而来。
//

import UIKit

// MARK: - 播放画面显示视图协议

/// 对应原 @protocol SJVideoPlayerPresentView_Protocol <NSObject>。
@MainActor
@objc(SJVideoPlayerPresentView)
public protocol SJVideoPlayerPresentView_Protocol: NSObjectProtocol {
    @objc var placeholderImageView: UIImageView { get }
    @objc(isPlaceholderImageViewHidden) var placeholderImageViewHidden: Bool { get }

    /// default value is UIViewContentModeScaleAspectFill
    @objc var placeholderImageViewContentMode: UIView.ContentMode { get set }

    @objc func setPlaceholderImageViewHidden(_ isHidden: Bool, animated: Bool)
    @objc func hidePlaceholderImageView(animated: Bool, delay secs: TimeInterval)
}

