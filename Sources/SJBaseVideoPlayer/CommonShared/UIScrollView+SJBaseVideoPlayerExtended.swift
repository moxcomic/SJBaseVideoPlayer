//
//  UIScrollView+SJBaseVideoPlayerExtended.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/22.
//
//  Swift 6.3 转换: 保留全部 ObjC 选择器, 供 SJPlayModel 等定位列表中的播放视图.
//

import UIKit

@objc
public extension UIScrollView {

    ///
    /// 获取对应视图
    ///
    @objc(viewWithTag:atIndexPath:)
    func view(withTag tag: Int, at indexPath: IndexPath?) -> UIView? {
        guard let indexPath = indexPath else { return nil }
        var cell: UIView? = nil
        if let tableView = self as? UITableView {
            cell = tableView.cellForRow(at: indexPath)
        } else if let collectionView = self as? UICollectionView {
            cell = collectionView.cellForItem(at: indexPath)
        }
        return cell?.viewWithTag(tag)
    }

    ///
    /// 对应视图是否在window中显示
    ///
    @objc(isViewAppearedWithTag:insets:atIndexPath:)
    func isViewAppeared(withTag tag: Int, insets: UIEdgeInsets, at indexPath: IndexPath?) -> Bool {
        let view = self.view(withTag: tag, at: indexPath)
        return !intersection(with: view, insets: insets).isEmpty
    }

    ///
    /// 获取对应视图
    ///
    @objc(viewWithProtocol:tag:atIndexPath:)
    func view(with protocol: Protocol, tag: Int, at indexPath: IndexPath?) -> UIView? {
        guard let indexPath = indexPath else { return nil }
        var cell: UIView? = nil
        if let tableView = self as? UITableView {
            cell = tableView.cellForRow(at: indexPath)
        } else if let collectionView = self as? UICollectionView {
            cell = collectionView.cellForItem(at: indexPath)
        }
        return cell?.view(with: `protocol`, tag: tag)
    }

    ///
    /// 获取对应视图 (header)
    ///
    @objc(viewWithProtocol:tag:inHeaderForSection:)
    func view(with protocol: Protocol, tag: Int, inHeaderForSection section: Int) -> UIView? {
        var headerView: UIView? = nil
        if let tableView = self as? UITableView {
            headerView = tableView.headerView(forSection: section)
        } else if let collectionView = self as? UICollectionView {
            headerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section))
        }
        return headerView?.view(with: `protocol`, tag: tag)
    }

    ///
    /// 获取对应视图 (footer)
    ///
    @objc(viewWithProtocol:tag:inFooterForSection:)
    func view(with protocol: Protocol, tag: Int, inFooterForSection section: Int) -> UIView? {
        var footerView: UIView? = nil
        if let tableView = self as? UITableView {
            footerView = tableView.footerView(forSection: section)
        } else if let collectionView = self as? UICollectionView {
            footerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: section))
        }
        return footerView?.view(with: `protocol`, tag: tag)
    }

    ///
    /// 对应视图是否在window中显示
    ///
    @objc(isViewAppearedWithProtocol:tag:insets:atIndexPath:)
    func isViewAppeared(with protocol: Protocol, tag: Int, insets: UIEdgeInsets, at indexPath: IndexPath?) -> Bool {
        let view = self.view(with: `protocol`, tag: tag, at: indexPath)
        return !intersection(with: view, insets: insets).isEmpty
    }

    @objc(viewForSelector:atIndexPath:)
    func view(for selector: Selector?, at indexPath: IndexPath?) -> UIView? {
        guard let indexPath = indexPath, let selector = selector else { return nil }
        var cell: UIView? = nil
        if let tableView = self as? UITableView {
            cell = tableView.cellForRow(at: indexPath)
        } else if let collectionView = self as? UICollectionView {
            cell = collectionView.cellForItem(at: indexPath)
        }
        return cell?.subview(for: selector)
    }

    @objc(viewForSelector:inHeaderForSection:)
    func view(for selector: Selector?, inHeaderForSection section: Int) -> UIView? {
        guard let selector = selector else { return nil }
        var headerView: UIView? = nil
        if let tableView = self as? UITableView {
            headerView = tableView.headerView(forSection: section)
        } else if let collectionView = self as? UICollectionView {
            headerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section))
        }
        return headerView?.subview(for: selector)
    }

    @objc(viewForSelector:inFooterForSection:)
    func view(for selector: Selector?, inFooterForSection section: Int) -> UIView? {
        guard let selector = selector else { return nil }
        var footerView: UIView? = nil
        if let tableView = self as? UITableView {
            footerView = tableView.footerView(forSection: section)
        } else if let collectionView = self as? UICollectionView {
            footerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: section))
        }
        return footerView?.subview(for: selector)
    }

    @objc(isViewAppearedForSelector:insets:atIndexPath:)
    func isViewAppeared(for selector: Selector?, insets: UIEdgeInsets, at indexPath: IndexPath?) -> Bool {
        guard let view = self.view(for: selector, at: indexPath) else { return false }
        return !intersection(with: view, insets: insets).isEmpty
    }
}

