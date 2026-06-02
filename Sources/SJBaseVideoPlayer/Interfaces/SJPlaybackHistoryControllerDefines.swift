//
//  SJPlaybackHistoryControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/19.
//
//  契约层(Swift 6.3): 由原 SJPlaybackHistoryControllerDefines.h 转换而来。
//  依赖 SJUIKit 的 SJSQLite3Condition / SJSQLite3ColumnOrder(已为 Swift module, 同名直接用)。
//

import Foundation
import SJUIKit

// MARK: - 媒体类型

/// 对应原 typedef NSString *SJMediaType 及其常量。
/// 目前存在两种类型: SJMediaTypeVideo(视频) 与 SJMediaTypeAudio(音乐)。
public typealias SJMediaType = String

/// 视频。对应原 extern SJMediaType const SJMediaTypeVideo。
public let SJMediaTypeVideo: SJMediaType = "video"
/// 音乐。对应原 extern SJMediaType const SJMediaTypeAudio。
public let SJMediaTypeAudio: SJMediaType = "audio"

// MARK: - 播放记录历史控制协议

/// 对应原 @protocol SJPlaybackHistoryController_Protocol <NSObject>。
/// 说明(notes): 方法含 SJMediaType(String typealias) 及 SQLite 条件类型参数,
/// 此协议改为 Swift 原生(不加 @objc), 在 module 内部 Swift 互引使用。
@MainActor public protocol SJPlaybackHistoryController_Protocol: NSObjectProtocol {
    /// 保存或更新播放记录。
    func save(_ record: SJPlaybackRecord)

    /// 查询, 如不存在将返回 nil。
    func record(forMedia mediaId: Int, user userId: Int, mediaType: SJMediaType) -> SJPlaybackRecord?

    /// 查询(分页)。
    func records(forUser userId: Int, mediaType: SJMediaType, range: NSRange) -> [SJPlaybackRecord]?

    /// 查询。
    func records(forUser userId: Int, mediaType: SJMediaType) -> [SJPlaybackRecord]?

    /// 条件查询(分页)。
    func records(forConditions conditions: [SJSQLite3Condition]?, orderBy orders: [SJSQLite3ColumnOrder]?, range: NSRange) -> [SJPlaybackRecord]?

    /// 条件查询。
    func records(forConditions conditions: [SJSQLite3Condition]?, orderBy orders: [SJSQLite3ColumnOrder]?) -> [SJPlaybackRecord]?

    /// 查询数量。
    func countOfRecords(forUser userId: Int, mediaType: SJMediaType) -> UInt

    /// 条件查询数量。
    func countOfRecords(forConditions conditions: [SJSQLite3Condition]?) -> UInt

    /// 删除。
    func remove(_ media: Int, user userId: Int, mediaType: SJMediaType)

    /// 删除指定用户全部记录。
    func removeAllRecords(forUser userId: Int, mediaType: SJMediaType)

    /// 条件删除。
    func removeForConditions(_ conditions: [SJSQLite3Condition]?)
}

// MARK: - 播放记录协议

/// 对应原 @protocol SJPlaybackRecord_Protocol <NSObject>。
/// 说明(notes): mediaType 为 SJMediaType(String typealias), 故该协议改为 Swift 原生。
public protocol SJPlaybackRecord_Protocol: NSObjectProtocol {
    var mediaId: Int { get }
    var userId: Int { get }
    var mediaType: SJMediaType { get }
    /// 上次观看到的位置。
    var position: TimeInterval { get }
    var createdTime: TimeInterval { get }
    var updatedTime: TimeInterval { get }
}

