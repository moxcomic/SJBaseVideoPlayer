//
//  SJBaseVideoPlayer+Subtitles.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Subtitles)。字幕。
//  Masonry -> SnapKit (mas_makeConstraints -> snp.makeConstraints, mas_updateConstraints -> snp.updateConstraints)。
//

import UIKit
import SnapKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 字幕管理(null_resettable)
    ///
    /// 注: SJSubtitlePopupController_Protocol 非 @objc(其 SJSubtitleItem.range 用到非 @objc 的 SJTimeRange),
    ///     故该属性无法 @objc 暴露, 仅 Swift 可见(与 fork 字幕块决策一致)。
    ///
    public var subtitlePopupController: any SJSubtitlePopupController_Protocol {
        get {
            if _subtitlePopupController == nil {
                subtitlePopupController = SJSubtitlePopupController()
            }
            return _subtitlePopupController!
        }
        set {
            _subtitlePopupController?.view.removeFromSuperview()
            _subtitlePopupController = newValue
            newValue.view.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.subtitleViewZIndex)
            presentView.addSubview(newValue.view)
            newValue.view.snp.makeConstraints { make in
                make.left.greaterThanOrEqualToSuperview().offset(subtitleHorizontalMinMargin)
                make.right.lessThanOrEqualToSuperview().offset(-subtitleHorizontalMinMargin)
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-subtitleBottomMargin)
            }
        }
    }

    ///
    /// 字幕底部间距. default value is 22
    ///
    @objc public var subtitleBottomMargin: CGFloat {
        get { _subtitleBottomMargin }
        set {
            _subtitleBottomMargin = newValue
            subtitlePopupController.view.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-newValue)
            }
        }
    }

    ///
    /// 左右距离屏幕最小间距. default value is 22
    ///
    @objc public var subtitleHorizontalMinMargin: CGFloat {
        get { _subtitleHorizontalMinMargin }
        set {
            _subtitleHorizontalMinMargin = newValue
            subtitlePopupController.view.snp.updateConstraints { make in
                make.left.greaterThanOrEqualToSuperview().offset(newValue)
                make.right.lessThanOrEqualToSuperview().offset(-newValue)
            }
        }
    }
}

