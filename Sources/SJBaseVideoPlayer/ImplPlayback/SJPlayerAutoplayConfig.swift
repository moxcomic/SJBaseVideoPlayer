//
//  SJPlayerAutoplayConfig.swift
//  Masonry
//
//  Created by 畅三江 on 2018/7/10.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import UIKit

@objc(SJPlayerAutoplayDelegate)
public protocol SJPlayerAutoplayDelegate: NSObjectProtocol {
    @objc func sj_playerNeedPlayNewAsset(at indexPath: IndexPath)
}

@objc(SJPlayerAutoplayConfig)
@MainActor
public class SJPlayerAutoplayConfig: NSObject {
    @objc public class func config(playerSuperviewSelector: Selector?, autoplayDelegate delegate: SJPlayerAutoplayDelegate) -> SJPlayerAutoplayConfig {
        let config = SJPlayerAutoplayConfig()
        config.autoplayDelegate = delegate
        config.playerSuperviewSelector = playerSuperviewSelector
        return config
    }

    @objc public var playerSuperviewSelector: Selector?

    @objc public private(set) weak var autoplayDelegate: SJPlayerAutoplayDelegate?

    /// 滑动方向默认为 垂直方向, 当 UICollectionView 水平滑动时, 记得设置此属性;
    @objc public var scrollDirection: UICollectionView.ScrollDirection = .vertical

    /// 可播区域的insets
    @objc public var playableAreaInsets: UIEdgeInsets = .zero

    // 已弃用; 通过 KVC 兼容 ObjC 旧调用
    private var _playerSuperviewTag: Int = 0
}

// MARK: - 已弃用
public extension SJPlayerAutoplayConfig {
    @available(*, deprecated, message: "use `configWithPlayerSuperviewSelector:autoplayDelegate:`;")
    @objc(configWithAutoplayDelegate:)
    class func config(autoplayDelegate: SJPlayerAutoplayDelegate) -> SJPlayerAutoplayConfig {
        return config(playerSuperviewSelector: nil, autoplayDelegate: autoplayDelegate)
    }

    @available(*, deprecated, message: "use `configWithPlayerSuperviewSelector:autoplayDelegate:`;")
    @objc(configWithPlayerSuperviewTag:autoplayDelegate:)
    class func config(playerSuperviewTag: Int, autoplayDelegate: SJPlayerAutoplayDelegate) -> SJPlayerAutoplayConfig {
        let config = self.config(autoplayDelegate: autoplayDelegate)
        config.playerSuperviewTag = playerSuperviewTag
        return config
    }

    @available(*, deprecated, message: "use `config.scrollViewSelector`")
    @objc var playerSuperviewTag: Int {
        get { value(forKey: "_playerSuperviewTag") as? Int ?? 0 }
        set { setValue(newValue, forKey: "_playerSuperviewTag") }
    }
}

