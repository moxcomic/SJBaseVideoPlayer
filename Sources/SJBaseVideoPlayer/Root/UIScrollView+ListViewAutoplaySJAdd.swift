//
//  UIScrollView+ListViewAutoplaySJAdd.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2018/7/9.
//
//  Swift 6.3 迁移版本. 列表自动播放功能 (v1.3.0 新增).
//

import UIKit
import ObjectiveC.runtime
import SJUIKit

// MARK: - 公共 API

extension UIScrollView {
    private static var enabledAutoplayKey: UInt8 = 0
    private static var autoplayConfigKey: UInt8 = 0
    private static var hasDelayedEndScrollTaskKey: UInt8 = 0
    private static var currentPlayingIndexPathKey: UInt8 = 0
    private static var contentOffsetObserverKey: UInt8 = 0

    /// 是否已开启自动播放
    @objc public var sj_enabledAutoplay: Bool {
        get { (objc_getAssociatedObject(self, &UIScrollView.enabledAutoplayKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &UIScrollView.enabledAutoplayKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 开启自动播放
    @objc(sj_enableAutoplayWithConfig:)
    public func sj_enableAutoplay(config autoplayConfig: SJPlayerAutoplayConfig) {
        sj_enabledAutoplay = true
        sj_autoplayConfig = autoplayConfig

        UIScrollView.sj_scrollViewContentOffsetDidChange(self) { [weak self] in
            guard let self else { return }
            if self.sj_hasDelayedEndScrollTask {
                self.sj_hasDelayedEndScrollTask = false
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(UIScrollView.sj_playNextAssetAfterEndScroll), object: nil)
            }

            UIScrollView.sj_queue.empty()
            // Thanks @YangYus
            // Fix #180 (https://github.com/changsanjiang/SJVideoPlayer/issues/180)
            if self.window == nil { return }

            UIScrollView.sj_queue.enqueue { [weak self] in
                guard let self else { return }
                self.sj_hasDelayedEndScrollTask = true
                self.perform(#selector(UIScrollView.sj_playNextAssetAfterEndScroll), with: nil, afterDelay: 0.4)
            }
        }
    }

    /// 关闭自动播放
    @objc public func sj_disableAutoplay() {
        sj_enabledAutoplay = false
        sj_autoplayConfig = nil
        sj_currentPlayingIndexPath = nil
        UIScrollView.sj_removeContentOffsetObserver(self)
    }

    /// 移除当前播放视图
    @objc public func sj_removeCurrentPlayerView() {
        sj_currentPlayingIndexPath = nil
        viewWithTag(SJPlayerViewTag)?.removeFromSuperview()
    }

    @objc public func sj_playNextAssetAfterEndScroll() {
        sj_hasDelayedEndScrollTask = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIScrollView._sj_playNextAssetAfterEndScroll(self)
        }
    }

    fileprivate var sj_hasDelayedEndScrollTask: Bool {
        get { (objc_getAssociatedObject(self, &UIScrollView.hasDelayedEndScrollTaskKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &UIScrollView.hasDelayedEndScrollTaskKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - 由播放器自动维护的赋值分类

extension UIScrollView {
    /// 当前正在播放的 indexPath (由播放器自动维护, 开发者无需关心)
    @objc public var sj_currentPlayingIndexPath: IndexPath? {
        get { objc_getAssociatedObject(self, &UIScrollView.currentPlayingIndexPathKey) as? IndexPath }
        set { objc_setAssociatedObject(self, &UIScrollView.currentPlayingIndexPathKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - 内部任务队列

extension UIScrollView {
    private static let _queueName = "SJBaseVideoPlayerAutoplayTaskQueue"
    fileprivate static let sj_queue: SJRunLoopTaskQueue = {
        return SJRunLoopTaskQueue.queue(_queueName).update(CFRunLoopGetMain(), CFRunLoopMode.defaultMode)!
    }()
}

// MARK: - contentOffset 观察者

final class _SJScrollViewContentOffsetObserver: NSObject {
    private let contentOffsetDidChangeExeBlock: () -> Void

    init(scrollView: UIScrollView, contentOffsetDidChangeExeBlock block: @escaping () -> Void) {
        self.contentOffsetDidChangeExeBlock = block
        super.init()
        scrollView.sj_addObserver(self, forKeyPath: "contentOffset")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        contentOffsetDidChangeExeBlock()
    }
}

extension UIScrollView {
    fileprivate static func sj_scrollViewContentOffsetDidChange(_ scrollView: UIScrollView, _ contentOffsetDidChangeExeBlock: @escaping () -> Void) {
        DispatchQueue.main.async {
            if objc_getAssociatedObject(scrollView, &UIScrollView.contentOffsetObserverKey) is _SJScrollViewContentOffsetObserver {
                return
            }
            let observer = _SJScrollViewContentOffsetObserver(scrollView: scrollView, contentOffsetDidChangeExeBlock: contentOffsetDidChangeExeBlock)
            objc_setAssociatedObject(scrollView, &UIScrollView.contentOffsetObserverKey, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    fileprivate static func sj_removeContentOffsetObserver(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            objc_setAssociatedObject(scrollView, &UIScrollView.contentOffsetObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - 滚动结束后选取并播放最近视频

extension UIScrollView {
    fileprivate static func _sj_playNextAssetAfterEndScroll(_ scrollView: UIScrollView) {
        if scrollView.window == nil { return }

        guard let sortedVisibleIndexPaths = scrollView.sj_sortedVisibleIndexPaths,
              sortedVisibleIndexPaths.count >= 1 else { return }

        guard let config = scrollView.sj_autoplayConfig else { return }
        let current = scrollView.sj_currentPlayingIndexPath

        let scrollDirection = config.scrollDirection
        switch scrollDirection {
        case .vertical:
            if !scrollView.sj_isScrolledToTop && !scrollView.sj_isScrolledToBottom &&
                scrollView.sj_isAutoplayTargetViewAppeared(for: config, at: current) {
                return
            }
        case .horizontal:
            if !scrollView.sj_isScrolledToLeft && !scrollView.sj_isScrolledToRight &&
                scrollView.sj_isAutoplayTargetViewAppeared(for: config, at: current) {
                return
            }
        @unknown default:
            break
        }

        var next: IndexPath? = nil
        // 参考线: 距离参考线最近的视频将被播放
        let guideline = scrollView.sj_autoplayGuideline(for: config)
        if guideline < 0 { return }

        let count = sortedVisibleIndexPaths.count
        var subs = CGFloat.greatestFiniteMagnitude
        for i in 0..<count {
            let indexPath = sortedVisibleIndexPaths[i]
            guard let target = scrollView.sj_autoplayTargetView(for: config, at: indexPath) else { continue }
            let playableAreaInsets = scrollView.sj_autoplayPlayableAreaInsets(for: config)
            let intersection = scrollView.intersection(with: target, insets: playableAreaInsets)
            var result = CGFloat.greatestFiniteMagnitude
            switch scrollDirection {
            case .vertical:
                if intersection.size.height != 0 { result = floor(abs(guideline - intersection.midY)) }
            case .horizontal:
                if intersection.size.width != 0 { result = floor(abs(guideline - intersection.midX)) }
            @unknown default:
                break
            }
            if result < subs {
                subs = result
                next = indexPath
            }
        }

        if let next, next != current {
            config.autoplayDelegate?.sj_playerNeedPlayNewAsset(at: next)
        }
    }
}

// MARK: - 内部计算属性

extension UIScrollView {
    fileprivate var sj_isScrolledToTop: Bool { floor(contentOffset.y) == 0 }
    fileprivate var sj_isScrolledToLeft: Bool { floor(contentOffset.x) == 0 }
    fileprivate var sj_isScrolledToRight: Bool {
        floor(contentOffset.x + bounds.size.width) == floor(contentSize.width)
    }
    fileprivate var sj_isScrolledToBottom: Bool {
        floor(contentOffset.y + bounds.size.height) == floor(contentSize.height)
    }

    fileprivate func sj_isAutoplayTargetViewAppeared(for config: SJPlayerAutoplayConfig, at indexPath: IndexPath?) -> Bool {
        guard let indexPath else { return false }
        if let sel = config.playerSuperviewSelector {
            return isViewAppeared(for: sel, insets: config.playableAreaInsets, at: indexPath)
        }
        let superviewTag = config.playerSuperviewTag
        if superviewTag != 0 {
            return isViewAppeared(withTag: superviewTag, insets: config.playableAreaInsets, at: indexPath)
        }
        return isViewAppeared(with: SJPlayModelPlayerSuperview.self, tag: 0, insets: config.playableAreaInsets, at: indexPath)
    }

    fileprivate func sj_autoplayTargetView(for config: SJPlayerAutoplayConfig, at indexPath: IndexPath) -> UIView? {
        if let sel = config.playerSuperviewSelector {
            return view(for: sel, at: indexPath)
        }
        let superviewTag = config.playerSuperviewTag
        if superviewTag != 0 {
            return view(withTag: superviewTag, at: indexPath)
        }
        return view(with: SJPlayModelPlayerSuperview.self, tag: 0, at: indexPath)
    }

    fileprivate func sj_autoplayGuideline(for config: SJPlayerAutoplayConfig) -> CGFloat {
        var guideline: CGFloat = 0
        switch config.scrollDirection {
        case .vertical:
            if sj_isScrolledToTop {
                // nothing
            } else if sj_isScrolledToBottom {
                guideline = contentSize.height
            } else {
                guideline = floor((bounds.height - adjustedContentInset.top) * 0.5)
            }
        case .horizontal:
            if sj_isScrolledToLeft {
                // nothing
            } else if sj_isScrolledToBottom {
                guideline = contentSize.width
            } else {
                guideline = floor((bounds.width - adjustedContentInset.left) * 0.5)
            }
        @unknown default:
            break
        }
        return guideline
    }

    fileprivate func sj_autoplayPlayableAreaInsets(for config: SJPlayerAutoplayConfig) -> UIEdgeInsets {
        var insets = config.playableAreaInsets
        switch config.scrollDirection {
        case .vertical:
            if sj_isScrolledToTop { insets.top = 0 }
            else if sj_isScrolledToBottom { insets.bottom = 0 }
        case .horizontal:
            if sj_isScrolledToLeft { insets.left = 0 }
            else if sj_isScrolledToRight { insets.right = 0 }
        @unknown default:
            break
        }
        return insets
    }

    fileprivate var sj_autoplayConfig: SJPlayerAutoplayConfig? {
        get { objc_getAssociatedObject(self, &UIScrollView.autoplayConfigKey) as? SJPlayerAutoplayConfig }
        set { objc_setAssociatedObject(self, &UIScrollView.autoplayConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var sj_sortedVisibleIndexPaths: [IndexPath]? {
        if let tableView = self as? UITableView {
            return tableView.indexPathsForVisibleRows
        } else if let collectionView = self as? UICollectionView {
            return collectionView.indexPathsForVisibleItems.sorted { $0 < $1 }
        }
        return nil
    }
}

