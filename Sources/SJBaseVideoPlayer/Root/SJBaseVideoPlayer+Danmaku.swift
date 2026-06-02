//
//  SJBaseVideoPlayer+Danmaku.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Danmaku)。弹幕。
//  Masonry -> SnapKit (mas_makeConstraints -> snp.makeConstraints)。
//

import UIKit
import SnapKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 弹幕控制(null_resettable)
    ///
    @objc public var danmakuPopupController: any SJDanmakuPopupController_Protocol {
        get {
            if let controller = _danmakuPopupController { return controller }
            let controller = SJDanmakuPopupController(numberOfTracks: 4)
            danmakuPopupController = controller
            return controller
        }
        set {
            if _danmakuPopupController != nil {
                _danmakuPopupController?.view.removeFromSuperview()
            }
            _danmakuPopupController = newValue
            newValue.view.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.danmakuViewZIndex)
            presentView.addSubview(newValue.view)
            newValue.view.snp.makeConstraints { make in
                make.top.left.right.equalToSuperview()
            }
        }
    }
}

