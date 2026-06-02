//
//  SJPlayModel+SJDeprecated.swift
//  SJVideoPlayerAssetCarrier
//
//  Created by 畅三江 on 2018/6/28.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//  Swift 6.3 重写 (SJBaseVideoPlayer) - 已弃用的 PlayModel 子类与工厂方法
//
//  对应 ObjC SJPlayModel.m 中过期内容 + SJPlayModel+SJPrivate.h 的过期子类.
//  这些类型 SJPlayModelPropertiesObserver 仍按运行时类型判断引用, 故必须保留.
//

import UIKit

@objc(SJUITableViewCellPlayModel)
@MainActor
open class SJUITableViewCellPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var _indexPath: IndexPath
    @objc public private(set) weak var tableView: UITableView?

    @objc public convenience init(playerSuperview: UIView, at indexPath: IndexPath, tableView: UITableView?) {
        self.init(playerSuperviewTag: playerSuperview.tag, at: indexPath, tableView: tableView)
    }

    @objc public init(playerSuperviewTag: Int, at indexPath: IndexPath, tableView: UITableView?) {
        assert(playerSuperviewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self._indexPath = indexPath
        self.tableView = tableView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        return tableView?.cellForRow(at: _indexPath)?.viewWithTag(playerSuperviewTag)
    }
    open override func inScrollView() -> UIScrollView? { return tableView }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJUICollectionViewCellPlayModel)
@MainActor
open class SJUICollectionViewCellPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var _indexPath: IndexPath
    @objc public private(set) weak var collectionView: UICollectionView?

    @objc public convenience init(playerSuperview: UIView, at indexPath: IndexPath, collectionView: UICollectionView?) {
        self.init(playerSuperviewTag: playerSuperview.tag, at: indexPath, collectionView: collectionView)
    }

    @objc public init(playerSuperviewTag: Int, at indexPath: IndexPath, collectionView: UICollectionView?) {
        assert(playerSuperviewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self._indexPath = indexPath
        self.collectionView = collectionView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        return collectionView?.cellForItem(at: _indexPath)?.viewWithTag(playerSuperviewTag)
    }
    open override func inScrollView() -> UIScrollView? { return collectionView }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJUITableViewHeaderViewPlayModel)
@MainActor
open class SJUITableViewHeaderViewPlayModel: SJPlayModel {
    @objc public private(set) weak var _playerSuperview: UIView?
    @objc public private(set) weak var tableView: UITableView?

    @objc public init(playerSuperview: UIView?, tableView: UITableView?) {
        self._playerSuperview = playerSuperview
        self.tableView = tableView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? { return _playerSuperview }
    open override func inScrollView() -> UIScrollView? { return tableView }
}

@objc(SJUICollectionViewNestedInUITableViewHeaderViewPlayModel)
@MainActor
open class SJUICollectionViewNestedInUITableViewHeaderViewPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var _indexPath: IndexPath
    @objc public private(set) weak var collectionView: UICollectionView?
    @objc public private(set) weak var tableView: UITableView?

    @objc public convenience init(playerSuperview: UIView, at indexPath: IndexPath, collectionView: UICollectionView?, tableView: UITableView?) {
        self.init(playerSuperviewTag: playerSuperview.tag, at: indexPath, collectionView: collectionView, tableView: tableView)
    }

    @objc public init(playerSuperviewTag: Int, at indexPath: IndexPath, collectionView: UICollectionView?, tableView: UITableView?) {
        assert(playerSuperviewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self._indexPath = indexPath
        self.collectionView = collectionView
        self.tableView = tableView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        return collectionView?.cellForItem(at: _indexPath)?.viewWithTag(playerSuperviewTag)
    }
    open override func inScrollView() -> UIScrollView? { return collectionView }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJUICollectionViewNestedInUITableViewCellPlayModel)
@MainActor
open class SJUICollectionViewNestedInUITableViewCellPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var _indexPath: IndexPath
    @objc public private(set) var collectionViewTag: Int = 0
    @objc public private(set) var collectionViewAtIndexPath: IndexPath
    @objc public private(set) weak var tableView: UITableView?

    @objc public convenience init(playerSuperview: UIView, at indexPath: IndexPath, collectionView: UICollectionView, collectionViewAtIndexPath: IndexPath, tableView: UITableView?) {
        self.init(playerSuperviewTag: playerSuperview.tag, at: indexPath, collectionViewTag: collectionView.tag, collectionViewAtIndexPath: collectionViewAtIndexPath, tableView: tableView)
    }

    @objc public init(playerSuperviewTag: Int, at indexPath: IndexPath, collectionViewTag: Int, collectionViewAtIndexPath: IndexPath, tableView: UITableView?) {
        assert(playerSuperviewTag != 0)
        assert(collectionViewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self._indexPath = indexPath
        self.collectionViewTag = collectionViewTag
        self.collectionViewAtIndexPath = collectionViewAtIndexPath
        self.tableView = tableView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        return collectionView()?.cellForItem(at: _indexPath)?.viewWithTag(playerSuperviewTag)
    }
    @objc public func collectionView() -> UICollectionView? {
        return tableView?.cellForRow(at: collectionViewAtIndexPath)?.viewWithTag(collectionViewTag) as? UICollectionView
    }
    open override func inScrollView() -> UIScrollView? { return collectionView() }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJUICollectionViewNestedInUICollectionViewCellPlayModel)
@MainActor
open class SJUICollectionViewNestedInUICollectionViewCellPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var _indexPath: IndexPath
    @objc public private(set) var collectionViewTag: Int = 0
    @objc public private(set) var collectionViewAtIndexPath: IndexPath
    @objc public private(set) weak var rootCollectionView: UICollectionView?

    @objc public init(playerSuperviewTag: Int, at indexPath: IndexPath, collectionViewTag: Int, collectionViewAtIndexPath: IndexPath, rootCollectionView: UICollectionView?) {
        assert(playerSuperviewTag != 0)
        assert(collectionViewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self._indexPath = indexPath
        self.collectionViewTag = collectionViewTag
        self.collectionViewAtIndexPath = collectionViewAtIndexPath
        self.rootCollectionView = rootCollectionView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        return collectionView()?.cellForItem(at: _indexPath)?.viewWithTag(playerSuperviewTag)
    }
    @objc public func collectionView() -> UICollectionView? {
        return rootCollectionView?.cellForItem(at: collectionViewAtIndexPath)?.viewWithTag(collectionViewTag) as? UICollectionView
    }
    open override func inScrollView() -> UIScrollView? { return collectionView() }
    open override func indexPath() -> IndexPath? { return _indexPath }
}

@objc(SJUITableViewHeaderFooterViewPlayModel)
@MainActor
open class SJUITableViewHeaderFooterViewPlayModel: SJPlayModel {
    @objc public private(set) var playerSuperviewTag: Int = 0
    @objc public private(set) var inSection: Int = 0
    @objc public private(set) var isHeader: Bool = false
    @objc public private(set) weak var tableView: UITableView?

    @objc public init(playerSuperviewTag: Int, inSection: Int, isHeader: Bool, tableView: UITableView?) {
        assert(playerSuperviewTag != 0)
        self.playerSuperviewTag = playerSuperviewTag
        self.inSection = inSection
        self.isHeader = isHeader
        self.tableView = tableView
        super.init()
    }

    open override func isPlayInScrollView() -> Bool { return true }
    open override func playerSuperview() -> UIView? {
        if isHeader {
            return tableView?.headerView(forSection: inSection)?.viewWithTag(playerSuperviewTag)
        }
        return tableView?.footerView(forSection: inSection)?.viewWithTag(playerSuperviewTag)
    }
    open override func inScrollView() -> UIScrollView? { return tableView }
    open override func section() -> Int { return inSection }
}

// MARK: - 已弃用工厂方法

public extension SJPlayModel {
    @available(*, deprecated, message: "use `SJPlayModel()`!")
    @objc class func uiViewPlayModel() -> Self {
        return unsafeDowncast(SJPlayModel(), to: Self.self)
    }

    @available(*, deprecated, message: "use `playModelWithTableView:indexPath`!")
    @objc(UITableViewCellPlayModelWithPlayerSuperviewTag:atIndexPath:tableView:)
    class func uiTableViewCellPlayModel(playerSuperviewTag: Int, at indexPath: IndexPath, tableView: UITableView?) -> Self {
        return unsafeDowncast(SJUITableViewCellPlayModel(playerSuperviewTag: playerSuperviewTag, at: indexPath, tableView: tableView), to: Self.self)
    }

    @available(*, deprecated, message: "use `playModelWithCollectionView:indexPath`!")
    @objc(UICollectionViewCellPlayModelWithPlayerSuperviewTag:atIndexPath:collectionView:)
    class func uiCollectionViewCellPlayModel(playerSuperviewTag: Int, at indexPath: IndexPath, collectionView: UICollectionView?) -> Self {
        return unsafeDowncast(SJUICollectionViewCellPlayModel(playerSuperviewTag: playerSuperviewTag, at: indexPath, collectionView: collectionView), to: Self.self)
    }

    @available(*, deprecated, message: "use `playModelWithTableView:tableHeaderView`!")
    @objc(UITableViewHeaderViewPlayModelWithPlayerSuperview:tableView:)
    class func uiTableViewHeaderViewPlayModel(playerSuperview: UIView?, tableView: UITableView?) -> Self {
        return unsafeDowncast(SJUITableViewHeaderViewPlayModel(playerSuperview: playerSuperview, tableView: tableView), to: Self.self)
    }

    @available(*, deprecated, message: "use `nextPlayModel`!")
    @objc(UICollectionViewNestedInUITableViewHeaderViewPlayModelWithPlayerSuperviewTag:atIndexPath:collectionView:tableView:)
    class func uiCollectionViewNestedInUITableViewHeaderViewPlayModel(playerSuperviewTag: Int, at indexPath: IndexPath, collectionView: UICollectionView?, tableView: UITableView?) -> Self {
        return unsafeDowncast(SJUICollectionViewNestedInUITableViewHeaderViewPlayModel(playerSuperviewTag: playerSuperviewTag, at: indexPath, collectionView: collectionView, tableView: tableView), to: Self.self)
    }

    @available(*, deprecated, message: "use `nextPlayModel`!")
    @objc(UICollectionViewNestedInUITableViewCellPlayModelWithPlayerSuperviewTag:atIndexPath:collectionViewTag:collectionViewAtIndexPath:tableView:)
    class func uiCollectionViewNestedInUITableViewCellPlayModel(playerSuperviewTag: Int, at indexPath: IndexPath, collectionViewTag: Int, collectionViewAtIndexPath: IndexPath, tableView: UITableView?) -> Self {
        return unsafeDowncast(SJUICollectionViewNestedInUITableViewCellPlayModel(playerSuperviewTag: playerSuperviewTag, at: indexPath, collectionViewTag: collectionViewTag, collectionViewAtIndexPath: collectionViewAtIndexPath, tableView: tableView), to: Self.self)
    }

    @available(*, deprecated, message: "use `nextPlayModel`!")
    @objc(UICollectionViewNestedInUICollectionViewCellPlayModelWithPlayerSuperviewTag:atIndexPath:collectionViewTag:collectionViewAtIndexPath:rootCollectionView:)
    class func uiCollectionViewNestedInUICollectionViewCellPlayModel(playerSuperviewTag: Int, at indexPath: IndexPath, collectionViewTag: Int, collectionViewAtIndexPath: IndexPath, rootCollectionView: UICollectionView?) -> Self {
        return unsafeDowncast(SJUICollectionViewNestedInUICollectionViewCellPlayModel(playerSuperviewTag: playerSuperviewTag, at: indexPath, collectionViewTag: collectionViewTag, collectionViewAtIndexPath: collectionViewAtIndexPath, rootCollectionView: rootCollectionView), to: Self.self)
    }

    @available(*, deprecated, message: "use `playModelWithTableView:tableFooterView`!")
    @objc(UITableViewHeaderFooterViewPlayModelWithPlayerSuperviewTag:inSection:isHeader:tableView:)
    class func uiTableViewHeaderFooterViewPlayModel(playerSuperviewTag: Int, inSection section: Int, isHeader: Bool, tableView: UITableView?) -> Self {
        return unsafeDowncast(SJUITableViewHeaderFooterViewPlayModel(playerSuperviewTag: playerSuperviewTag, inSection: section, isHeader: isHeader, tableView: tableView), to: Self.self)
    }
}

