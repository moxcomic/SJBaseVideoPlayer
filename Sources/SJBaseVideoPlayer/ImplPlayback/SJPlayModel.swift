//
//  SJPlayModel.swift
//  SJVideoPlayerAssetCarrier
//
//  Created by 畅三江 on 2018/6/28.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//
//  含: SJPlayModel.h/.m + SJPlayModel+SJPrivate.h (子类) + 已弃用类型
//

import UIKit

// 这两个标记协议在 ObjC 已弃用, 仅用于运行时 protocol 查找
@objc(SJPlayModelPlayerSuperview)
public protocol SJPlayModelPlayerSuperview: NSObjectProtocol {}

@objc(SJPlayModelNestedView)
public protocol SJPlayModelNestedView: NSObjectProtocol {}

@objc(SJPlayerDefaultSelectors)
public protocol SJPlayerDefaultSelectors: NSObjectProtocol {
    @objc var playerSuperview: Any { get }
    @objc var collectionView: Any { get }
}

@objc(SJPlayModel)
@MainActor
open class SJPlayModel: NSObject {
    @objc public var superviewSelector: Selector?
    @objc public var nextPlayModel: SJPlayModel?
    @objc public var scrollViewSelector: Selector?
    /// 可播区域的 insets
    @objc public var playableAreaInsets: UIEdgeInsets = .zero
    /// 视图 tag (区分多播放器父视图; 不可为 0)
    @objc public var superviewTag: UInt = 0

    @objc public override init() {
        super.init()
    }

    // MARK: - UIScrollView

    @objc(playModelWithScrollView:)
    public class func playModel(scrollView: UIScrollView?) -> Self {
        return unsafeDowncast(SJScrollViewPlayModel(scrollView: scrollView), to: Self.self)
    }

    @objc(playModelWithScrollView:superviewSelector:)
    public class func playModel(scrollView: UIScrollView?, superviewSelector: Selector) -> Self {
        let model = SJScrollViewPlayModel(scrollView: scrollView)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    // MARK: - UITableView

    @objc(playModelWithTableView:indexPath:)
    public class func playModel(tableView: UITableView?, indexPath: IndexPath) -> Self {
        return unsafeDowncast(SJTableViewCellPlayModel(tableView: tableView, indexPath: indexPath), to: Self.self)
    }

    @objc(playModelWithTableView:indexPath:superviewSelector:)
    public class func playModel(tableView: UITableView?, indexPath: IndexPath, superviewSelector: Selector) -> Self {
        let model = SJTableViewCellPlayModel(tableView: tableView, indexPath: indexPath)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithTableView:tableHeaderView:)
    public class func playModel(tableView: UITableView?, tableHeaderView: UIView?) -> Self {
        return unsafeDowncast(SJTableViewTableHeaderViewPlayModel(tableView: tableView, tableHeaderView: tableHeaderView), to: Self.self)
    }

    @objc(playModelWithTableView:tableHeaderView:superviewSelector:)
    public class func playModel(tableView: UITableView?, tableHeaderView: UIView?, superviewSelector: Selector) -> Self {
        let model = SJTableViewTableHeaderViewPlayModel(tableView: tableView, tableHeaderView: tableHeaderView)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithTableView:tableFooterView:)
    public class func playModel(tableView: UITableView?, tableFooterView: UIView?) -> Self {
        return unsafeDowncast(SJTableViewTableFooterViewPlayModel(tableView: tableView, tableFooterView: tableFooterView), to: Self.self)
    }

    @objc(playModelWithTableView:tableFooterView:superviewSelector:)
    public class func playModel(tableView: UITableView?, tableFooterView: UIView?, superviewSelector: Selector) -> Self {
        let model = SJTableViewTableFooterViewPlayModel(tableView: tableView, tableFooterView: tableFooterView)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithTableView:inHeaderForSection:)
    public class func playModel(tableView: UITableView?, inHeaderForSection section: Int) -> Self {
        return unsafeDowncast(SJTableViewSectionHeaderViewPlayModel(tableView: tableView, inHeaderForSection: section), to: Self.self)
    }

    @objc(playModelWithTableView:inHeaderForSection:superviewSelector:)
    public class func playModel(tableView: UITableView?, inHeaderForSection section: Int, superviewSelector: Selector) -> Self {
        let model = SJTableViewSectionHeaderViewPlayModel(tableView: tableView, inHeaderForSection: section)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithTableView:inFooterForSection:)
    public class func playModel(tableView: UITableView?, inFooterForSection section: Int) -> Self {
        return unsafeDowncast(SJTableViewSectionFooterViewPlayModel(tableView: tableView, inFooterForSection: section), to: Self.self)
    }

    @objc(playModelWithTableView:inFooterForSection:superviewSelector:)
    public class func playModel(tableView: UITableView?, inFooterForSection section: Int, superviewSelector: Selector) -> Self {
        let model = SJTableViewSectionFooterViewPlayModel(tableView: tableView, inFooterForSection: section)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    // MARK: - UICollectionView

    @objc(playModelWithCollectionView:indexPath:)
    public class func playModel(collectionView: UICollectionView?, indexPath: IndexPath) -> Self {
        return unsafeDowncast(SJCollectionViewCellPlayModel(collectionView: collectionView, indexPath: indexPath), to: Self.self)
    }

    @objc(playModelWithCollectionView:indexPath:superviewSelector:)
    public class func playModel(collectionView: UICollectionView?, indexPath: IndexPath, superviewSelector: Selector) -> Self {
        let model = SJCollectionViewCellPlayModel(collectionView: collectionView, indexPath: indexPath)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithCollectionView:inHeaderForSection:)
    public class func playModel(collectionView: UICollectionView?, inHeaderForSection section: Int) -> Self {
        return unsafeDowncast(SJCollectionViewSectionHeaderViewPlayModel(collectionView: collectionView, inHeaderForSection: section), to: Self.self)
    }

    @objc(playModelWithCollectionView:inHeaderForSection:superviewSelector:)
    public class func playModel(collectionView: UICollectionView?, inHeaderForSection section: Int, superviewSelector: Selector) -> Self {
        let model = SJCollectionViewSectionHeaderViewPlayModel(collectionView: collectionView, inHeaderForSection: section)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    @objc(playModelWithCollectionView:inFooterForSection:)
    public class func playModel(collectionView: UICollectionView?, inFooterForSection section: Int) -> Self {
        return unsafeDowncast(SJCollectionViewSectionFooterViewPlayModel(collectionView: collectionView, inFooterForSection: section), to: Self.self)
    }

    @objc(playModelWithCollectionView:inFooterForSection:superviewSelector:)
    public class func playModel(collectionView: UICollectionView?, inFooterForSection section: Int, superviewSelector: Selector) -> Self {
        let model = SJCollectionViewSectionFooterViewPlayModel(collectionView: collectionView, inFooterForSection: section)
        model.superviewSelector = superviewSelector
        return unsafeDowncast(model, to: Self.self)
    }

    // MARK: - 子类可重写

    @objc open func isPlayInScrollView() -> Bool { return false }
    @objc open func playerSuperview() -> UIView? { return nil }
    @objc open func inScrollView() -> UIScrollView? { return nil }
    @objc open func indexPath() -> IndexPath? { return nil }
    @objc open func section() -> Int { return 0 }
}

// MARK: - 子类实现 (对应 SJPlayModel+SJPrivate.h)

@objc(SJScrollViewPlayModel)
@MainActor
open class SJScrollViewPlayModel: SJPlayModel {
    @objc public private(set) weak var scrollView: UIScrollView?

    @objc public init(scrollView: UIScrollView?) {
        self.scrollView = scrollView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return scrollView?.subview(for: sel)
        }
        return scrollView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag))
    }

    open override func inScrollView() -> UIScrollView? { return scrollView }
}

@objc(SJTableViewCellPlayModel)
@MainActor
open class SJTableViewCellPlayModel: SJPlayModel {
    @objc public private(set) weak var tableView: UITableView?
    @objc public private(set) var _indexPath: IndexPath

    @objc public init(tableView: UITableView?, indexPath: IndexPath) {
        self.tableView = tableView
        self._indexPath = indexPath
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return tableView?.view(for: sel, at: _indexPath)
        }
        return tableView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), at: _indexPath)
    }

    open override func inScrollView() -> UIScrollView? { return tableView }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJTableViewTableHeaderViewPlayModel)
@MainActor
open class SJTableViewTableHeaderViewPlayModel: SJPlayModel {
    @objc public private(set) weak var tableView: UITableView?
    @objc public private(set) weak var tableHeaderView: UIView?

    @objc public init(tableView: UITableView?, tableHeaderView: UIView?) {
        self.tableView = tableView
        self.tableHeaderView = tableHeaderView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return tableHeaderView?.subview(for: sel)
        }
        return tableHeaderView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag))
    }

    open override func inScrollView() -> UIScrollView? { return tableView }
}

@objc(SJTableViewTableFooterViewPlayModel)
@MainActor
open class SJTableViewTableFooterViewPlayModel: SJPlayModel {
    @objc public private(set) weak var tableView: UITableView?
    @objc public private(set) weak var tableFooterView: UIView?

    @objc public init(tableView: UITableView?, tableFooterView: UIView?) {
        self.tableView = tableView
        self.tableFooterView = tableFooterView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return tableFooterView?.subview(for: sel)
        }
        return tableFooterView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag))
    }

    open override func inScrollView() -> UIScrollView? { return tableView }
}

@objc(SJTableViewSectionHeaderViewPlayModel)
@MainActor
open class SJTableViewSectionHeaderViewPlayModel: SJPlayModel {
    @objc public private(set) weak var tableView: UITableView?
    @objc public private(set) var _section: Int

    @objc public init(tableView: UITableView?, inHeaderForSection section: Int) {
        self.tableView = tableView
        self._section = section
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return tableView?.view(for: sel, inHeaderForSection: _section)
        }
        return tableView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), inHeaderForSection: _section)
    }

    open override func inScrollView() -> UIScrollView? { return tableView }
    open override func section() -> Int { return _section }
}

@objc(SJTableViewSectionFooterViewPlayModel)
@MainActor
open class SJTableViewSectionFooterViewPlayModel: SJPlayModel {
    @objc public private(set) weak var tableView: UITableView?
    @objc public private(set) var _section: Int

    @objc public init(tableView: UITableView?, inFooterForSection section: Int) {
        self.tableView = tableView
        self._section = section
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return tableView?.view(for: sel, inFooterForSection: _section)
        }
        return tableView?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), inFooterForSection: _section)
    }

    open override func inScrollView() -> UIScrollView? { return tableView }
    open override func section() -> Int { return _section }
}

@objc(SJCollectionViewCellPlayModel)
@MainActor
open class SJCollectionViewCellPlayModel: SJPlayModel {
    @objc public private(set) weak var collectionView: UICollectionView?
    @objc public private(set) var _indexPath: IndexPath

    @objc public init(collectionView: UICollectionView?, indexPath: IndexPath) {
        self.collectionView = collectionView
        self._indexPath = indexPath
        super.init()
    }

    open override var nextPlayModel: SJPlayModel? {
        didSet {
            // 嵌套情况需处理复用的问题(cell / section 存在复用)
            if let next = nextPlayModel,
               (next is SJCollectionViewCellPlayModel ||
                next is SJCollectionViewSectionHeaderViewPlayModel ||
                next is SJCollectionViewSectionFooterViewPlayModel ||
                next is SJTableViewCellPlayModel ||
                next is SJTableViewSectionHeaderViewPlayModel ||
                next is SJTableViewSectionFooterViewPlayModel) {
                assert((collectionView?.conforms(to: SJPlayModelNestedView.self) ?? false) || next.scrollViewSelector != nil || next.superviewSelector != nil,
                       "`collectionView` must implement `SJPlayModelNestedView` protocol! or specify nextPlayModel.superviewSelector!")
            }
        }
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return inScrollView()?.view(for: sel, at: _indexPath)
        }
        return inScrollView()?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), at: _indexPath)
    }

    open override func indexPath() -> IndexPath? { return _indexPath }

    open override func inScrollView() -> UIScrollView? {
        guard let next = nextPlayModel else {
            return collectionView
        }

        if next is SJCollectionViewCellPlayModel || next is SJTableViewCellPlayModel {
            if let sel = next.scrollViewSelector, let ip = next.indexPath() {
                return next.inScrollView()?.view(for: sel, at: ip) as? UIScrollView
            } else if let ip = next.indexPath() {
                return next.inScrollView()?.view(with: SJPlayModelNestedView.self, tag: Int(next.superviewTag), at: ip) as? UIScrollView
            }
            return nil
        }

        if next is SJCollectionViewSectionHeaderViewPlayModel || next is SJTableViewSectionHeaderViewPlayModel {
            if let sel = next.scrollViewSelector {
                return next.inScrollView()?.view(for: sel, inHeaderForSection: next.section()) as? UIScrollView
            }
            return next.inScrollView()?.view(with: SJPlayModelNestedView.self, tag: Int(next.superviewTag), inHeaderForSection: next.section()) as? UIScrollView
        }

        if next is SJCollectionViewSectionFooterViewPlayModel || next is SJTableViewSectionFooterViewPlayModel {
            if let sel = next.scrollViewSelector {
                return next.inScrollView()?.view(for: sel, inFooterForSection: next.section()) as? UIScrollView
            }
            return next.inScrollView()?.view(with: SJPlayModelNestedView.self, tag: Int(next.superviewTag), inFooterForSection: next.section()) as? UIScrollView
        }
        return nil
    }
}

@objc(SJCollectionViewSectionHeaderViewPlayModel)
@MainActor
open class SJCollectionViewSectionHeaderViewPlayModel: SJPlayModel {
    @objc public private(set) weak var collectionView: UICollectionView?
    @objc public private(set) var _section: Int

    @objc public init(collectionView: UICollectionView?, inHeaderForSection section: Int) {
        self.collectionView = collectionView
        self._section = section
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return inScrollView()?.view(for: sel, inHeaderForSection: _section)
        }
        return inScrollView()?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), inHeaderForSection: _section)
    }

    open override func inScrollView() -> UIScrollView? { return collectionView }
    open override func section() -> Int { return _section }
}

@objc(SJCollectionViewSectionFooterViewPlayModel)
@MainActor
open class SJCollectionViewSectionFooterViewPlayModel: SJPlayModel {
    @objc public private(set) weak var collectionView: UICollectionView?
    @objc public private(set) var _section: Int

    @objc public init(collectionView: UICollectionView?, inFooterForSection section: Int) {
        self.collectionView = collectionView
        self._section = section
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }

    open override func playerSuperview() -> UIView? {
        if let sel = superviewSelector {
            return inScrollView()?.view(for: sel, inFooterForSection: _section)
        }
        return inScrollView()?.view(with: SJPlayModelPlayerSuperview.self, tag: Int(superviewTag), inFooterForSection: _section)
    }

    open override func inScrollView() -> UIScrollView? { return collectionView }
    open override func section() -> Int { return _section }
}

