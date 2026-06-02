//
//  SJVideoPlayerURLAsset+SJAVMediaPlaybackAdd.swift
//  Project
//
//  Created by 畅三江 on 2018/8/12.
//  Copyright © 2018 changsanjiang. All rights reserved.
//
//  Swift 6.3 迁移: 由 SJVideoPlayerURLAsset+SJAVMediaPlaybackAdd.{h,m} 转写.
//  为 SJVideoPlayerURLAsset 增加 AVAsset / AVPlayerItem / AVPlayer 初始化入口及关联对象存取.
//  original 链用于清晰度切换时共享底层播放器.
//

@preconcurrency import AVFoundation
import Foundation
import ObjectiveC

@objc public extension SJVideoPlayerURLAsset {

    // MARK: AVAsset 初始化

    @objc(initWithAVAsset:)
    convenience init?(avAsset asset: AVAsset) {
        self.init(avAsset: asset, playModel: SJPlayModel())
    }

    @objc(initWithAVAsset:playModel:)
    convenience init?(avAsset asset: AVAsset, playModel: SJPlayModel) {
        self.init(avAsset: asset, startPosition: 0, playModel: playModel)
    }

    @objc(initWithAVAsset:startPosition:playModel:)
    convenience init?(avAsset asset: AVAsset, startPosition: TimeInterval, playModel: SJPlayModel) {
        self.init()
        self.avAsset = asset
        self.playModel = playModel
        self.startPosition = startPosition
    }

    // MARK: AVPlayerItem 初始化

    @objc(initWithAVPlayerItem:)
    convenience init?(avPlayerItem playerItem: AVPlayerItem) {
        self.init(avPlayerItem: playerItem, playModel: SJPlayModel())
    }

    @objc(initWithAVPlayerItem:playModel:)
    convenience init?(avPlayerItem playerItem: AVPlayerItem, playModel: SJPlayModel) {
        self.init(avPlayerItem: playerItem, startPosition: 0, playModel: playModel)
    }

    @objc(initWithAVPlayerItem:startPosition:playModel:)
    convenience init?(avPlayerItem playerItem: AVPlayerItem, startPosition: TimeInterval, playModel: SJPlayModel) {
        self.init()
        self.avPlayerItem = playerItem
        self.playModel = playModel
        self.startPosition = startPosition
    }

    // MARK: AVPlayer 初始化

    @objc(initWithAVPlayer:)
    convenience init?(avPlayer player: AVPlayer) {
        self.init(avPlayer: player, playModel: SJPlayModel())
    }

    @objc(initWithAVPlayer:playModel:)
    convenience init?(avPlayer player: AVPlayer, playModel: SJPlayModel) {
        self.init(avPlayer: player, startPosition: 0, playModel: playModel)
    }

    @objc(initWithAVPlayer:startPosition:playModel:)
    convenience init?(avPlayer player: AVPlayer, startPosition: TimeInterval, playModel: SJPlayModel?) {
        self.init()
        self.avPlayer = player
        self.playModel = playModel ?? SJPlayModel()
        self.startPosition = startPosition
    }

    // MARK: 关联对象

    @objc var avAsset: AVAsset? {
        get {
            if let original = original { return original.avAsset }
            return objc_getAssociatedObject(self, &AssociatedKeys.avAsset) as? AVAsset
        }
        set { objc_setAssociatedObject(self, &AssociatedKeys.avAsset, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @objc var avPlayerItem: AVPlayerItem? {
        get {
            if let original = original { return original.avPlayerItem }
            return objc_getAssociatedObject(self, &AssociatedKeys.avPlayerItem) as? AVPlayerItem
        }
        set { objc_setAssociatedObject(self, &AssociatedKeys.avPlayerItem, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @objc var avPlayer: AVPlayer? {
        get {
            if let original = original { return original.avPlayer }
            return objc_getAssociatedObject(self, &AssociatedKeys.avPlayer) as? AVPlayer
        }
        set { objc_setAssociatedObject(self, &AssociatedKeys.avPlayer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: 清晰度切换共享

    @objc(initWithOtherAsset:playModel:)
    convenience init?(otherAsset: SJVideoPlayerURLAsset, playModel: SJPlayModel?) {
        self.init()
        var curr = otherAsset
        while let o = curr.original, curr !== o {
            curr = o
        }
        self.original = curr
        self.mediaURL = curr.mediaURL
        self.playModel = playModel ?? SJPlayModel()
    }

    @objc internal(set) var original: SJVideoPlayerURLAsset? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.original) as? SJVideoPlayerURLAsset }
        set { objc_setAssociatedObject(self, &AssociatedKeys.original, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @available(*, deprecated, message: "ues `original`")
    @objc func originAsset() -> SJVideoPlayerURLAsset? {
        return original
    }
}

private extension SJVideoPlayerURLAsset {
    enum AssociatedKeys {
        nonisolated(unsafe) static var avAsset = 0
        nonisolated(unsafe) static var avPlayerItem = 0
        nonisolated(unsafe) static var avPlayer = 0
        nonisolated(unsafe) static var original = 0
    }
}

