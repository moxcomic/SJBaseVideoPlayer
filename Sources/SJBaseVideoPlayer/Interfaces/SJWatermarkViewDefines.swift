//
//  SJWatermarkViewDefines.swift
//  Pods
//
//  Created by BlueDancer on 2020/6/13.
//
//  契约层(Swift 6.3): 由原 SJWatermarkViewDefines.h 转换而来。
//

import UIKit
import CoreGraphics

// MARK: - 水印视图协议

/// 对应原 @protocol SJWatermarkView_Protocol <NSObject>。
/// SJVideoGravity 定义见 SJVideoPlayerPlaybackControllerDefines.swift。
@MainActor
@objc(SJWatermarkView)
public protocol SJWatermarkView_Protocol: NSObjectProtocol {
    @objc func layoutWatermark(in rect: CGRect, videoPresentationSize vSize: CGSize, videoGravity: SJVideoGravity)
}

