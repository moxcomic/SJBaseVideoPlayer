//
//  SJBaseVideoPlayer+Screenshot.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Screenshot)。截图。
//

import UIKit
import CoreGraphics

@MainActor
extension SJBaseVideoPlayer {

    // MARK: - Presentation Size -

    /// 画面尺寸发生改变时回调。
    @objc public var presentationSizeDidChangeExeBlock: ((SJBaseVideoPlayer) -> Void)? {
        get { _presentationSizeDidChangeExeBlock }
        set { _presentationSizeDidChangeExeBlock = newValue }
    }

    /// 视频的呈现尺寸(画面尺寸)。
    @objc public var videoPresentationSize: CGSize {
        return _playbackController?.presentationSize ?? .zero
    }

    // MARK: - Screenshot -

    /// 立即截取当前画面。
    @objc public func screenshot() -> UIImage? {
        return _playbackController?.screenshot()
    }

    /// 截取指定时间点的画面。
    @objc(screenshotWithTime:completion:)
    public func screenshot(withTime time: TimeInterval,
                           completion block: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ image: UIImage?, _ error: Error?) -> Void) {
        screenshot(withTime: time, size: .zero, completion: block)
    }

    /// 截取指定时间点、指定尺寸的画面。
    @objc(screenshotWithTime:size:completion:)
    public func screenshot(withTime time: TimeInterval,
                           size: CGSize,
                           completion block: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ image: UIImage?, _ error: Error?) -> Void) {
        if let controller = _playbackController as? SJMediaPlaybackScreenshotController {
            controller.screenshot(withTime: time, size: size) { [weak self] _, image, error in
                // 对应 ObjC: dispatch_async(dispatch_get_main_queue(), ...) 回主线程回调
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    block(self, image, error)
                }
            }
        } else {
            let error = NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["errorMsg": "SJBaseVideoPlayer<\(Unmanaged.passUnretained(self).toOpaque())>.playbackController does not implement the screenshot method"])
            block(self, nil, error)
            #if DEBUG
            print(error.userInfo.description)
            #endif
        }
    }
}

