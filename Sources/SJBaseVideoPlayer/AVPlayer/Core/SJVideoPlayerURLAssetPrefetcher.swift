//
//  SJVideoPlayerURLAssetPrefetcher.swift
//  Pods
//
//  Created by 畅三江 on 2019/3/28.
//
//  Swift 6.3 迁移: 由 SJVideoPlayerURLAssetPrefetcher.{h,m} 转写.
//  资源预加载: 最多预加载 maxCount 个, 超出时移除先前的.
//  通过 SJAVMediaPlayerLoader 提前创建 SJAVMediaPlayer.
//

import Foundation

/// 预加载标识符. Swift 中维持 NSInteger 语义(对象指针哈希值)以保持与 ObjC 完全一致的行为.
public typealias SJPrefetchIdentifier = Int

/// - 资源 预加载 -
///
/// 最多预加载 `prefetcher.maxCount` 个. 当超出时, 将会移除先前的.
@MainActor
@objc(SJVideoPlayerURLAssetPrefetcher)
public final class SJVideoPlayerURLAssetPrefetcher: NSObject {

    @objc public static let shared = SJVideoPlayerURLAssetPrefetcher()

    @objc public var maxCount: UInt = 3 // default value is 3;

    private var m: [SJVideoPlayerURLAsset] = []

    private override init() {
        super.init()
    }

    @discardableResult
    @objc(prefetchAsset:)
    public func prefetch(asset: SJVideoPlayerURLAsset?) -> SJPrefetchIdentifier {
        guard let asset = asset else { return 0 }
        let idx = indexOfAsset(asset)
        if idx == NSNotFound {
            if UInt(m.count) > maxCount {
                m.remove(at: 0)
            }
            // load asset
            _ = SJAVMediaPlayerLoader.loadPlayer(forMedia: asset)
            m.append(asset)
        }
        return identifier(of: asset)
    }

    @objc(assetForURL:)
    public func asset(forURL url: URL?) -> SJVideoPlayerURLAsset? {
        guard let url = url else { return nil }
        for asset in m where asset.mediaURL == url {
            return asset
        }
        return nil
    }

    @objc(assetForIdentifier:)
    public func asset(forIdentifier identifier: SJPrefetchIdentifier) -> SJVideoPlayerURLAsset? {
        for asset in m where self.identifier(of: asset) == identifier {
            return asset
        }
        return nil
    }

    @objc(removeAsset:)
    public func remove(asset: SJVideoPlayerURLAsset) {
        let idx = indexOfAsset(asset)
        if idx != NSNotFound {
            m.remove(at: idx)
        }
    }

    private func indexOfAsset(_ asset: SJVideoPlayerURLAsset) -> Int {
        for i in 0..<m.count {
            let a = m[i]
            if a === asset || a.mediaURL == asset.mediaURL {
                return i
            }
        }
        return NSNotFound
    }

    /// 与 ObjC `(NSInteger)asset` 等价: 取对象指针整数值.
    private func identifier(of asset: SJVideoPlayerURLAsset) -> SJPrefetchIdentifier {
        return Int(bitPattern: Unmanaged.passUnretained(asset).toOpaque())
    }
}

