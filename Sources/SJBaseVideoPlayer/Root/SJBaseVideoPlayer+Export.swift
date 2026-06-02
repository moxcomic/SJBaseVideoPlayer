//
//  SJBaseVideoPlayer+Export.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Export)。输出(导出片段 / 生成 GIF)。
//

import UIKit
import CoreGraphics

@MainActor
extension SJBaseVideoPlayer {

    /// 导出指定时间区间的视频片段。
    ///
    /// - Parameters:
    ///   - beginTime:     起始时间。
    ///   - duration:      时长。
    ///   - presetName:    导出预设名(可空)。
    ///   - progressBlock: 进度回调。
    ///   - completion:    完成回调(返回导出文件 URL 与缩略图)。
    ///   - failure:       失败回调。
    @objc(exportWithBeginTime:duration:presetName:progress:completion:failure:)
    public func export(withBeginTime beginTime: TimeInterval,
                       duration: TimeInterval,
                       presetName: String?,
                       progress progressBlock: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ progress: Float) -> Void,
                       completion: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ fileURL: URL, _ thumbnailImage: UIImage) -> Void,
                       failure: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ error: Error) -> Void) {
        if let controller = _playbackController as? SJMediaPlaybackExportController {
            controller.export(withBeginTime: beginTime, duration: duration, presetName: presetName) { [weak self] _, progress in
                guard let self = self else { return }
                progressBlock(self, progress)
            } completion: { [weak self] _, fileURL, thumbImage in
                guard let self = self else { return }
                completion(self, fileURL ?? URL(fileURLWithPath: ""), thumbImage ?? UIImage())
            } failure: { [weak self] _, error in
                guard let self = self else { return }
                failure(self, error ?? NSError(domain: NSCocoaErrorDomain, code: -1))
            }
        } else {
            let error = NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["errorMsg": "SJBaseVideoPlayer<\(Unmanaged.passUnretained(self).toOpaque())>.playbackController does not implement the exportWithBeginTime:endTime:presetName:progress:completion:failure: method"])
            failure(self, error)
            #if DEBUG
            print(error.userInfo.description)
            #endif
        }
    }

    /// 取消导出操作。
    @objc public func cancelExportOperation() {
        if let controller = _playbackController as? SJMediaPlaybackExportController {
            controller.cancelExportOperation()
        }
    }

    /// 生成指定时间区间的 GIF。
    ///
    /// - Parameters:
    ///   - beginTime:     起始时间。
    ///   - duration:      时长。
    ///   - progressBlock: 进度回调。
    ///   - completion:    完成回调(返回 GIF 图、缩略图与保存路径)。
    ///   - failure:       失败回调。
    @objc(generateGIFWithBeginTime:duration:progress:completion:failure:)
    public func generateGIF(withBeginTime beginTime: TimeInterval,
                            duration: TimeInterval,
                            progress progressBlock: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ progress: Float) -> Void,
                            completion: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ imageGIF: UIImage, _ thumbnailImage: UIImage, _ filePath: URL) -> Void,
                            failure: @escaping (_ videoPlayer: SJBaseVideoPlayer, _ error: Error) -> Void) {
        if let controller = _playbackController as? SJMediaPlaybackExportController {
            let filePath = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("SJGeneratedGif.gif"))
            controller.generateGIF(withBeginTime: beginTime, duration: duration, maximumSize: CGSize(width: 375, height: 375), interval: 0.1, gifSavePath: filePath) { [weak self] _, progress in
                guard let self = self else { return }
                progressBlock(self, progress)
            } completion: { [weak self] _, imageGIF, screenshot in
                guard let self = self else { return }
                completion(self, imageGIF, screenshot, filePath)
            } failure: { [weak self] _, error in
                guard let self = self else { return }
                failure(self, error)
            }
        } else {
            let error = NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["errorMsg": "SJBaseVideoPlayer<\(Unmanaged.passUnretained(self).toOpaque())>.playbackController does not implement the generateGIFWithBeginTime:duration:maximumSize:interval:gifSavePath:progress:completion:failure: method"])
            failure(self, error)
            #if DEBUG
            print(error.userInfo.description)
            #endif
        }
    }

    /// 取消生成 GIF 操作。
    @objc public func cancelGenerateGIFOperation() {
        if let controller = _playbackController as? SJMediaPlaybackExportController {
            controller.cancelGenerateGIFOperation()
        }
    }
}

