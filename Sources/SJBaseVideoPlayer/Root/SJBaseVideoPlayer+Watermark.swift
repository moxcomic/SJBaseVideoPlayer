//
//  SJBaseVideoPlayer+Watermark.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Watermark)。水印视图。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 添加水印视图(nullable)
    ///
    @objc public var watermarkView: (UIView & SJWatermarkView_Protocol)? {
        get { _watermarkView }
        set {
            let oldView = _watermarkView
            if let oldView = oldView {
                if oldView === newValue { return }
                oldView.removeFromSuperview()
            }

            _watermarkView = newValue

            if let watermarkView = newValue {
                watermarkView.layer.zPosition = CGFloat(SJPlayerZIndexes.shared.watermarkViewZIndex)
                presentView.addSubview(watermarkView)
                watermarkView.layoutWatermark(in: presentView.bounds, videoPresentationSize: videoPresentationSize, videoGravity: videoGravity)
            }
        }
    }

    @objc public func updateWatermarkViewLayout() {
        watermarkView?.layoutWatermark(in: presentView.bounds, videoPresentationSize: videoPresentationSize, videoGravity: videoGravity)
    }
}

