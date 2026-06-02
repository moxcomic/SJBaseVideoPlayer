//
//  SJAVMediaPlayerLoader.swift
//  Pods
//
//  Created by 畅三江 on 2019/4/10.
//
//  Swift 6.3 迁移: 由 SJAVMediaPlayerLoader.{h,m} 转写.
//  通过关联对象在 SJVideoPlayerURLAsset 上缓存对应的 SJAVMediaPlayer 实例.
//  注意修复: 重新创建 playerItem 规避 `An AVPlayerItem cannot be associated with more than one instance of AVPlayer`.
//

@preconcurrency import AVFoundation
import Foundation
import ObjectiveC

@MainActor
@objc(SJAVMediaPlayerLoader)
public final class SJAVMediaPlayerLoader: NSObject {

    private static var kPlayer = 0

    @objc(loadPlayerForMedia:)
    public static func loadPlayer(forMedia media: SJVideoPlayerURLAsset?) -> SJAVMediaPlayer? {
        #if DEBUG
        assert(media != nil)
        #endif
        guard let media = media else { return nil }

        let target: SJVideoPlayerURLAsset = media.original ?? media
        if let player = objc_getAssociatedObject(target, &kPlayer) as? SJAVMediaPlayer,
           player.assetStatus != .failed {
            return player
        }

        var avPlayer = target.avPlayer
        if avPlayer == nil {
            var avPlayerItem = target.avPlayerItem
            // fix: 重新创建playerItem规避多 AVPlayer 关联崩溃.
            if let item = avPlayerItem, item.status != .unknown {
                var url: URL?
                if let urlAsset = item.asset as? AVURLAsset {
                    url = urlAsset.url
                }
                guard let url = url else { return nil }
                let newItem = AVPlayerItem(url: url)
                target.avPlayerItem = newItem
                avPlayerItem = newItem
            }

            if avPlayerItem == nil {
                var avAsset = target.avAsset
                if avAsset == nil, let mediaURL = target.mediaURL {
                    avAsset = AVURLAsset(url: mediaURL, options: nil)
                }
                if let avAsset = avAsset {
                    avPlayerItem = AVPlayerItem(asset: avAsset)
                }
            }
            if let avPlayerItem = avPlayerItem {
                avPlayer = AVPlayer(playerItem: avPlayerItem)
            }
        }

        guard let avPlayer = avPlayer else { return nil }
        let player = SJAVMediaPlayer(avPlayer: avPlayer, startPosition: media.startPosition)
        objc_setAssociatedObject(target, &kPlayer, player, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return player
    }

    @objc(clearPlayerForMedia:)
    public static func clearPlayer(forMedia media: SJVideoPlayerURLAsset?) {
        if let media = media {
            let target = media.original ?? media
            objc_setAssociatedObject(target, &kPlayer, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

