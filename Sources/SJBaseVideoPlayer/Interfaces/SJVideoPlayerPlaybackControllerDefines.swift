//
//  SJVideoPlayerPlaybackControllerDefines.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/8/10.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  契约层(Swift 6.3): 由原 SJVideoPlayerPlaybackController.h(SJMediaPlaybackProtocol_h) 转换而来。
//  保留原 ObjC 协议名/方法名/选择器, 对外 @objc 暴露, 供仍是 ObjC 的上层(SJVideoPlayer 本库 + Example)调用。
//

@preconcurrency import AVFoundation
import UIKit
import CoreMedia

// MARK: - 视频画面填充模式

/// 对应原 typedef: typedef AVLayerVideoGravity SJVideoGravity;
/// AVLayerVideoGravity 即 NSString *, 直接 typealias。
public typealias SJVideoGravity = AVLayerVideoGravity

// MARK: - Seek 信息

/// 对应原 C struct SJSeekingInfo。
/// struct 无法 @objc 暴露, 改 Swift 原生(见 notes)。仅在 module 内部使用。
public struct SJSeekingInfo: Sendable, Equatable {
    public var isSeeking: Bool
    public var time: CMTime

    public init(isSeeking: Bool = false, time: CMTime = .zero) {
        self.isSeeking = isSeeking
        self.time = time
    }
}

// MARK: - 媒体模型协议

/// 对应原 @protocol SJMediaModelProtocol。
@MainActor
@objc(SJMediaModelProtocol)
public protocol SJMediaModelProtocol: NSObjectProtocol {
    /// played by URL
    @objc var mediaURL: URL? { get set }

    /// 开始播放的位置, 单位秒
    @objc var startPosition: TimeInterval { get set }

    /// 试用结束的位置, 单位秒
    @objc var trialEndPosition: TimeInterval { get set }
}

// MARK: - 播放控制器协议

/// 对应原 @protocol SJVideoPlayerPlaybackController<NSObject>。
/// 注意: 原协议含 CMTime / CGSize 参数, AVFoundation 类型非 Sendable, 实现类在 @MainActor 闭环。
@MainActor
@objc(SJVideoPlayerPlaybackController)
public protocol SJVideoPlayerPlaybackController: NSObjectProtocol {
    /// default value is 0.5
    @objc var periodicTimeInterval: TimeInterval { get set }
    /// default value is 8.0
    @objc var minBufferedDuration: TimeInterval { get set }
    @objc var error: Error? { get }
    @objc weak var delegate: SJVideoPlayerPlaybackControllerDelegate? { get set }

    @objc var playbackType: SJPlaybackType { get }
    @objc var playerView: UIView { get }
    @objc var media: SJMediaModelProtocol? { get set }
    /// default value is AVLayerVideoGravityResizeAspect
    @objc var videoGravity: SJVideoGravity { get set }

    // MARK: - status
    @objc var assetStatus: SJAssetStatus { get }
    @objc var timeControlStatus: SJPlaybackTimeControlStatus { get }
    @objc var reasonForWaitingToPlay: SJWaitingReason? { get }

    @objc var currentTime: TimeInterval { get }
    @objc var duration: TimeInterval { get }
    @objc var playableDuration: TimeInterval { get }
    /// 已观看的时长
    @objc var durationWatched: TimeInterval { get }
    @objc var presentationSize: CGSize { get }
    @objc(isReadyForDisplay) var isReadyForDisplay: Bool { get }

    @objc var volume: Float { get set }
    @objc var rate: Float { get set }
    @objc(isMuted) var isMuted: Bool { get set }

    /// 当前media是否调用过play
    @objc var isPlayed: Bool { get }
    /// 当前media是否调用过replay
    @objc(isReplayed) var isReplayed: Bool { get }
    /// 播放结束
    @objc var isPlaybackFinished: Bool { get }
    /// 播放结束的reason
    @objc var finishedReason: SJFinishedReason? { get }

    @objc func prepareToPlay()
    @objc func replay()
    @objc func refresh()
    @objc func play()
    @objc var pauseWhenAppDidEnterBackground: Bool { get set }
    @objc func pause()
    @objc func stop()
    @objc func seek(toTime secs: TimeInterval, completionHandler: ((Bool) -> Void)?)
    @objc func seek(toTime time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)?)
    @objc func screenshot() -> UIImage?
    @objc func switchVideoDefinition(_ media: SJMediaModelProtocol)

    // MARK: - Picture in Picture (iOS 14+)
    @available(iOS 14.0, *)
    @objc func isPictureInPictureSupported() -> Bool
    @available(iOS 14.0, *)
    @objc var requiresLinearPlaybackInPictureInPicture: Bool { get set }
    @available(iOS 14.2, *)
    @objc var canStartPictureInPictureAutomaticallyFromInline: Bool { get set }
    @available(iOS 14.0, *)
    @objc var pictureInPictureStatus: SJPictureInPictureStatus { get }
    @objc var restoreUserInterfaceForPictureInPictureStop: ((_ controller: SJVideoPlayerPlaybackController, _ completionHandler: @escaping (Bool) -> Void) -> Void)? { get set }
    @available(iOS 14.0, *)
    @objc func startPictureInPicture()
    @available(iOS 14.0, *)
    @objc func stopPictureInPicture()
    @available(iOS 14.0, *)
    @objc func cancelPictureInPicture()
}

// MARK: - 截图控制器协议

/// 对应原 @protocol SJMediaPlaybackScreenshotController。
@MainActor
@objc(SJMediaPlaybackScreenshotController)
public protocol SJMediaPlaybackScreenshotController: NSObjectProtocol {
    @objc func screenshot(withTime time: TimeInterval,
                          size: CGSize,
                          completion block: @escaping (_ controller: SJVideoPlayerPlaybackController, _ image: UIImage?, _ error: Error?) -> Void)
}

// MARK: - 导出控制器协议

/// 对应原 @protocol SJMediaPlaybackExportController。
@MainActor
@objc(SJMediaPlaybackExportController)
public protocol SJMediaPlaybackExportController: NSObjectProtocol {
    @objc func export(withBeginTime beginTime: TimeInterval,
                      duration: TimeInterval,
                      presetName: String?,
                      progress: @escaping (_ controller: SJVideoPlayerPlaybackController, _ progress: Float) -> Void,
                      completion: @escaping (_ controller: SJVideoPlayerPlaybackController, _ saveURL: URL?, _ thumbImage: UIImage?) -> Void,
                      failure: @escaping (_ controller: SJVideoPlayerPlaybackController, _ error: Error?) -> Void)

    @objc func generateGIF(withBeginTime beginTime: TimeInterval,
                           duration: TimeInterval,
                           maximumSize: CGSize,
                           interval: Float,
                           gifSavePath: URL,
                           progress progressBlock: @escaping (_ controller: SJVideoPlayerPlaybackController, _ progress: Float) -> Void,
                           completion: @escaping (_ controller: SJVideoPlayerPlaybackController, _ imageGIF: UIImage, _ screenshot: UIImage) -> Void,
                           failure: @escaping (_ controller: SJVideoPlayerPlaybackController, _ error: Error) -> Void)

    @objc func cancelExportOperation()
    @objc func cancelGenerateGIFOperation()
}

// MARK: - 播放控制器代理协议

/// 对应原 @protocol SJVideoPlayerPlaybackControllerDelegate<NSObject>。
@MainActor
@objc(SJVideoPlayerPlaybackControllerDelegate)
public protocol SJVideoPlayerPlaybackControllerDelegate: NSObjectProtocol {
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, assetStatusDidChange status: SJAssetStatus)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, timeControlStatusDidChange status: SJPlaybackTimeControlStatus)

    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, volumeDidChange volume: Float)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, rateDidChange rate: Float)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, mutedDidChange isMuted: Bool)

    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, playbackDidFinish reason: SJFinishedReason)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, durationDidChange duration: TimeInterval)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, currentTimeDidChange currentTime: TimeInterval)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, presentationSizeDidChange presentationSize: CGSize)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, playbackTypeDidChange playbackType: SJPlaybackType)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, playableDurationDidChange playableDuration: TimeInterval)
    @objc optional func playbackControllerIsReadyForDisplay(_ controller: SJVideoPlayerPlaybackController)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, switchingDefinitionStatusDidChange status: SJDefinitionSwitchStatus, media: SJMediaModelProtocol)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, didReplay media: SJMediaModelProtocol)

    @available(iOS 14.0, *)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, pictureInPictureStatusDidChange status: SJPictureInPictureStatus)

    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, willSeekToTime time: CMTime)
    @objc optional func playbackController(_ controller: SJVideoPlayerPlaybackController, didSeekToTime time: CMTime)

    @objc optional func applicationWillEnterForeground(withPlaybackController controller: SJVideoPlayerPlaybackController)
    @objc optional func applicationDidBecomeActive(withPlaybackController controller: SJVideoPlayerPlaybackController)
    @objc optional func applicationWillResignActive(withPlaybackController controller: SJVideoPlayerPlaybackController)
    @objc optional func applicationDidEnterBackground(withPlaybackController controller: SJVideoPlayerPlaybackController)
}

