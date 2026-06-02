//
//  SJPlayModelPropertiesObserver.swift
//  SJVideoPlayerAssetCarrier
//
//  Created by 畅三江 on 2018/6/29.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import UIKit
#if canImport(SJUIKit)
import SJUIKit
#endif

@objc(SJPlayModelPropertiesObserverDelegate)
@MainActor public protocol SJPlayModelPropertiesObserverDelegate: NSObjectProtocol {
    @objc optional func observer(_ observer: SJPlayModelPropertiesObserver, userTouchedTableView touched: Bool)
    @objc optional func observer(_ observer: SJPlayModelPropertiesObserver, userTouchedCollectionView touched: Bool)
    @objc optional func playerWillAppear(for observer: SJPlayModelPropertiesObserver, superview: UIView)
    @objc optional func playerWillDisappear(for observer: SJPlayModelPropertiesObserver)
}

@objc(SJPlayModelPropertiesObserver)
@MainActor
public class SJPlayModelPropertiesObserver: NSObject {
    @objc public weak var delegate: SJPlayModelPropertiesObserverDelegate?

    @objc public private(set) var isTouched: Bool = false

    private let playModel: SJPlayModel
    private var beforeOffset: CGPoint = CGPoint(x: -1, y: -1)
    private let taskQueue: SJRunLoopTaskQueue

    private var _isAppeared: Bool = false
    @objc public var isAppeared: Bool {
        get { _isAppeared }
        set { setIsAppeared(newValue) }
    }

    // KVO context
    private static var kContentOffset = "contentOffset"
    private static var kState = "state"

    @objc public init(playModel: SJPlayModel) {
        self.playModel = playModel
        self.taskQueue = SJRunLoopTaskQueue.queue("SJPlayModelObserverRunLoopTaskQueue").delay(3)!
        super.init()
        if type(of: playModel) == SJPlayModel.self {
            _isAppeared = true
        } else {
            _observeProperties()
        }
        refreshAppearState()
    }

    private func _observeProperties() {
        if playModel is SJScrollViewPlayModel ||
           playModel is SJCollectionViewCellPlayModel ||
           playModel is SJCollectionViewSectionHeaderViewPlayModel ||
           playModel is SJCollectionViewSectionFooterViewPlayModel ||
           playModel is SJTableViewCellPlayModel ||
           playModel is SJTableViewSectionHeaderViewPlayModel ||
           playModel is SJTableViewSectionFooterViewPlayModel ||
           playModel is SJTableViewTableHeaderViewPlayModel ||
           playModel is SJTableViewTableFooterViewPlayModel {
            var curr: SJPlayModel? = playModel
            beforeOffset = curr?.inScrollView()?.contentOffset ?? .zero
            while let c = curr {
                _observeScrollView(c.inScrollView())
                curr = c.nextPlayModel
            }
        }
        // 以下已弃用, 未来可能会删除
        else if let m = playModel as? SJUITableViewCellPlayModel {
            _observeScrollView(m.tableView)
        }
        else if let m = playModel as? SJUICollectionViewCellPlayModel {
            _observeScrollView(m.collectionView)
        }
        else if let m = playModel as? SJUITableViewHeaderViewPlayModel {
            _observeScrollView(m.tableView)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUITableViewHeaderViewPlayModel {
            _observeScrollView(m.collectionView)
            _observeScrollView(m.tableView)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUITableViewCellPlayModel {
            _observeScrollView(m.collectionView())
            _observeScrollView(m.tableView)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUICollectionViewCellPlayModel {
            _observeScrollView(m.collectionView())
            _observeScrollView(m.rootCollectionView)
        }
        else if let m = playModel as? SJUITableViewHeaderFooterViewPlayModel {
            _observeScrollView(m.tableView)
        }
    }

    private func _observeScrollView(_ scrollView: UIScrollView?) {
        guard let scrollView = scrollView else { return }
        scrollView.sj_addObserver(self, forKeyPath: Self.kContentOffset, context: &Self.kContentOffset)
        scrollView.panGestureRecognizer.sj_addObserver(self, forKeyPath: Self.kState, context: &Self.kState)
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context == &Self.kContentOffset {
            let scrollView = object as? UIScrollView
            taskQueue.empty()?.enqueue { [weak self] in
                MainActor.assumeIsolated {
                    self?._scrollViewDidScroll(scrollView)
                }
            }
        } else if context == &Self.kState {
            _panGestureStateDidChange(object as? UIPanGestureRecognizer)
        }
    }

    private func _panGestureStateDidChange(_ pan: UIPanGestureRecognizer?) {
        guard let pan = pan else { return }
        switch pan.state {
        case .changed, .possible:
            return
        case .began:
            isTouched = true
        case .ended, .failed, .cancelled:
            isTouched = false
        @unknown default:
            break
        }
    }

    private func _isAppeared(inTheScrollingView scrollView: UIScrollView) -> Bool {
        return scrollView.isViewAppeared(playModel.playerSuperview(), insets: playModel.playableAreaInsets)
    }

    private func _scrollViewDidScroll(_ scrollView: UIScrollView?) {
        guard let scrollView = scrollView else { return }
        if beforeOffset == scrollView.contentOffset { return }

        if playModel.nextPlayModel != nil {
            var curr: SJPlayModel? = playModel.nextPlayModel
            while let c = curr {
                _observeScrollView(c.inScrollView())
                curr = c.nextPlayModel
            }
        }
        // 以下已弃用, 未来可能会删除
        else if let m = playModel as? SJUICollectionViewNestedInUITableViewCellPlayModel {
            if scrollView === m.tableView {
                _observeScrollView(m.collectionView())
            }
        }
        else if let m = playModel as? SJUICollectionViewNestedInUICollectionViewCellPlayModel {
            if scrollView === m.rootCollectionView {
                _observeScrollView(m.collectionView())
            }
        }

        isAppeared = _isAppeared(inTheScrollingView: scrollView)
        beforeOffset = scrollView.contentOffset
    }

    private func setIsAppeared(_ value: Bool) {
        if value == _isAppeared { return }
        _isAppeared = value
        if value {
            if let superview = playModel.playerSuperview() {
                delegate?.playerWillAppear?(for: self, superview: superview)
            }
        } else {
            delegate?.playerWillDisappear?(for: self)
        }
    }

    @objc public var isPlayInScrollView: Bool {
        return playModel.isPlayInScrollView()
    }

    @objc public func refreshAppearState() {
        _isAppeared = false
        if type(of: playModel) == SJPlayModel.self {
            isAppeared = true
            return
        }
        guard let superview = playModel.inScrollView() else {
            isAppeared = false
            return
        }
        isAppeared = _isAppeared(inTheScrollingView: superview)
    }

    @objc public var isScrolling: Bool {
        if playModel is SJScrollViewPlayModel ||
           playModel is SJCollectionViewCellPlayModel ||
           playModel is SJCollectionViewSectionHeaderViewPlayModel ||
           playModel is SJCollectionViewSectionFooterViewPlayModel ||
           playModel is SJTableViewCellPlayModel ||
           playModel is SJTableViewSectionHeaderViewPlayModel ||
           playModel is SJTableViewSectionFooterViewPlayModel ||
           playModel is SJTableViewTableHeaderViewPlayModel ||
           playModel is SJTableViewTableFooterViewPlayModel {
            var curr: SJPlayModel? = playModel
            while let c = curr {
                if let sv = c.inScrollView(), sv.isDragging || sv.isDecelerating {
                    return true
                }
                curr = c.nextPlayModel
            }
        }
        // 以下已弃用, 未来可能会删除
        else if let m = playModel as? SJUITableViewCellPlayModel {
            return (m.tableView?.isDragging ?? false) || (m.tableView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUICollectionViewCellPlayModel {
            return (m.collectionView?.isDragging ?? false) || (m.collectionView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUITableViewHeaderViewPlayModel {
            return (m.tableView?.isDragging ?? false) || (m.tableView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUITableViewHeaderViewPlayModel {
            return (m.collectionView?.isDragging ?? false) || (m.collectionView?.isDecelerating ?? false) ||
                   (m.tableView?.isDragging ?? false) || (m.tableView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUITableViewCellPlayModel {
            return (m.collectionView()?.isDragging ?? false) || (m.collectionView()?.isDecelerating ?? false) ||
                   (m.tableView?.isDragging ?? false) || (m.tableView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUICollectionViewNestedInUICollectionViewCellPlayModel {
            return (m.collectionView()?.isDragging ?? false) || (m.collectionView()?.isDecelerating ?? false) ||
                   (m.rootCollectionView?.isDragging ?? false) || (m.rootCollectionView?.isDecelerating ?? false)
        }
        else if let m = playModel as? SJUITableViewHeaderFooterViewPlayModel {
            return (m.tableView?.isDragging ?? false) || (m.tableView?.isDecelerating ?? false)
        }
        return false
    }
}

