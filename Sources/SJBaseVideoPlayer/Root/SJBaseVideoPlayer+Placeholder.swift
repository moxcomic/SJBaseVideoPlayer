//
//  SJBaseVideoPlayer+Placeholder.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Placeholder)。播放画面显示层 / 占位图。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 播放画面显示层
    ///
    /// \code
    ///     // 设置占位图
    ///     _player.presentView.placeholderImageView.image = [UIImage imageNamed:@"..."];
    ///     // [_player.presentView.placeholderImageView sd_setImageWithURL:URL];
    /// \endcode
    ///
    @objc public var presentView: UIView & SJVideoPlayerPresentView_Protocol {
        return _presentView
    }

    ///
    /// 准备好显示画面时, 是否隐藏占位图
    ///
    ///         default value is YES
    ///
    @objc public var automaticallyHidesPlaceholderImageView: Bool {
        get { controlInfo.placeholder.automaticallyHides }
        set { controlInfo.placeholder.automaticallyHides = newValue }
    }

    ///
    /// 将要隐藏占位图时, 延迟多少秒才去隐藏
    ///
    ///         default value is 0.8s
    ///
    @objc public var delayInSecondsForHiddenPlaceholderImageView: TimeInterval {
        get { controlInfo.placeholder.delayHidden }
        set { controlInfo.placeholder.delayHidden = newValue }
    }
}

