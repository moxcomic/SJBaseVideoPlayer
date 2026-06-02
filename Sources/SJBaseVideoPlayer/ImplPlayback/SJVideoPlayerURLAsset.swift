//
//  SJVideoPlayerURLAsset.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2018/1/29.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//
//  含: SJVideoPlayerURLAsset.h/.m, SJVideoPlayerURLAsset+SJSubtitlesAdd.h/.m
//

import UIKit
#if canImport(SJUIKit)
import SJUIKit
#endif

@objc(SJVideoPlayerURLAssetObserver)
@MainActor public protocol SJVideoPlayerURLAssetObserverProtocol: NSObjectProtocol {
    @objc var playModelDidChangeExeBlock: ((SJVideoPlayerURLAsset) -> Void)? { get set }
}

@objc(SJVideoPlayerURLAsset)
@MainActor
public class SJVideoPlayerURLAsset: NSObject, SJMediaModelProtocol {
    // MARK: SJMediaModelProtocol

    @objc public var mediaURL: URL? {
        didSet {
            isM3u8 = mediaURL?.pathExtension.contains("m3u8") ?? false
        }
    }

    /// 开始播放的位置, 单位秒
    @objc public var startPosition: TimeInterval = 0

    /// 试用结束的位置, 单位秒
    @objc public var trialEndPosition: TimeInterval = 0

    // 内部存储; getter 保证 null_resettable 行为(为空时回填默认值)
    private var _playModel: SJPlayModel?
    @objc public var playModel: SJPlayModel! {
        get {
            if let m = _playModel { return m }
            let m = SJPlayModel()
            _playModel = m
            return m
        }
        set {
            // KVO 兼容: 通过 sj_addObserver 监听 "playModel"
            _playModel = newValue
        }
    }

    @objc public var isM3u8: Bool = false

    // MARK: 初始化

    /// 无 URL 的指定构造器, 用于 AVAsset / AVPlayerItem / AVPlayer / 清晰度切换等场景.
    /// 等价 ObjC 基线中的 `[super init]`(此时 `mediaURL == nil`, 由对应分类设置底层资源).
    @objc public override init() {
        super.init()
    }

    @objc public init?(url URL: URL?, startPosition: TimeInterval, playModel: SJPlayModel?) {
        guard let URL = URL else { return nil }
        super.init()
        self.mediaURL = URL
        self.startPosition = startPosition
        self._playModel = playModel ?? SJPlayModel()
        self.isM3u8 = URL.pathExtension.contains("m3u8")
    }

    @objc public convenience init?(url URL: URL?, startPosition: TimeInterval) {
        self.init(url: URL, startPosition: startPosition, playModel: SJPlayModel())
    }

    @objc public convenience init?(url URL: URL?, playModel: SJPlayModel?) {
        self.init(url: URL, startPosition: 0, playModel: playModel)
    }

    @objc public convenience init?(url URL: URL?) {
        self.init(url: URL, startPosition: 0)
    }

    @objc public func getObserver() -> any SJVideoPlayerURLAssetObserverProtocol {
        return SJVideoPlayerURLAssetObserverImpl(asset: self)
    }
}

// MARK: - 内部观察者实现 (KVO "playModel")

@MainActor
private final class SJVideoPlayerURLAssetObserverImpl: NSObject, SJVideoPlayerURLAssetObserverProtocol {
    var playModelDidChangeExeBlock: ((SJVideoPlayerURLAsset) -> Void)?

    init(asset: SJVideoPlayerURLAsset) {
        super.init()
        asset.sj_addObserver(self, forKeyPath: "playModel")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let asset = object as? SJVideoPlayerURLAsset {
            playModelDidChangeExeBlock?(asset)
        }
    }
}

// MARK: - SJSubtitlesAdd

private nonisolated(unsafe) var kSubtitlesKey: UInt8 = 0

public extension SJVideoPlayerURLAsset {
    /// 未来将要显示的字幕
    @objc var subtitles: [SJSubtitleItem]? {
        get { objc_getAssociatedObject(self, &kSubtitlesKey) as? [SJSubtitleItem] }
        set { objc_setAssociatedObject(self, &kSubtitlesKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
}

