//
//  SJPlaybackHistoryController.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/19.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名.
//
//  `SJPlaybackRecord` 播放记录
//
//  如需为播放记录扩充自己的属性, 在 Swift 中可通过对 SJPlaybackRecord 增加
//  @objc dynamic 关联属性(分类/扩展)实现, 管理类保存该条记录时, 相应的扩充属性
//  也会被保存进数据库中.
//
//  注: SJUIKit 的 SQLite3 已由 ObjC 重写为 Codable Swift 版,
//  其增删改查方法签名变更如下(均以 NSErrorPointer 形式返回错误, 对齐原 ObjC NULL 调用):
//    - save(_:error:) -> Bool
//    - objects(for:conditions:orderBy:range:error:) -> [Any]?
//    - countOfObjects(for:conditions:error:) -> UInt
//    - removeObjects(for:primaryKeyValues:error:) -> Bool
//    - removeAllObjects(for:conditions:error:) -> Bool
//  SJSQLite3Condition / SJSQLite3ColumnOrder 的 init 已私有化, 改用其公开静态工厂方法构造.
//

import Foundation
import SJUIKit

/// "不限制数量" 的范围长度哨兵. 对齐原 ObjC 实现使用的 NSUIntegerMax.
///
/// NSRange.length 在 Swift 中为 Int, 这里以与 ObjC NSUIntegerMax 完全相同的位模式表示;
/// SJSQLite3 查询扩展内部正是以 `UInt(bitPattern:) == UInt.max` 判定 "不限制范围".
private let sj_NSUIntegerMaxLength = Int(bitPattern: UInt.max)

@objc(SJPlaybackHistoryController)
@MainActor
public final class SJPlaybackHistoryController: NSObject, SJPlaybackHistoryController_Protocol {

    private var sqlite: SJSQLite3?

    @objc(shared)
    public static let shared: SJPlaybackHistoryController = {
        let path = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString)
            .appendingPathComponent("com.SJBaseVideoPlayer.history/sj.db")
        return SJPlaybackHistoryController(path: path)
    }()

    @objc(initWithPath:)
    public init(path: String) {
        super.init()
        self.sqlite = SJSQLite3(databasePath: path)
    }

    // MARK: 保存或更新

    @objc(save:)
    public func save(_ record: SJPlaybackRecord) {
        let old = self.record(forMedia: record.mediaId, user: record.userId, mediaType: record.mediaType)
        if let old = old {
            record.id = old.id
        } else {
            record.createdTime = Date().timeIntervalSince1970
        }
        record.updatedTime = Date().timeIntervalSince1970
        sqlite?.save(record, error: nil)
    }

    // MARK: 查询

    @objc(recordForMedia:user:mediaType:)
    public func record(forMedia mediaId: Int, user userId: Int, mediaType: SJMediaType) -> SJPlaybackRecord? {
        assert(!mediaType.isEmpty)
        return records(forConditions: [
            SJSQLite3Condition.condition(column: "mediaId", value: NSNumber(value: mediaId)),
            SJSQLite3Condition.condition(column: "userId", value: NSNumber(value: userId)),
            SJSQLite3Condition.condition(column: "mediaType", value: mediaType as NSString)
        ], orderBy: nil)?.last
    }

    @objc(recordsForUser:mediaType:range:)
    public func records(forUser userId: Int, mediaType: SJMediaType, range: NSRange) -> [SJPlaybackRecord]? {
        return records(forConditions: [
            SJSQLite3Condition.condition(column: "userId", value: NSNumber(value: userId)),
            SJSQLite3Condition.condition(column: "mediaType", value: mediaType as NSString)
        ], orderBy: [
            SJSQLite3ColumnOrder.order(column: "updatedTime", ascending: false)
        ], range: range)
    }

    @objc(recordsForUser:mediaType:)
    public func records(forUser userId: Int, mediaType: SJMediaType) -> [SJPlaybackRecord]? {
        return records(forUser: userId, mediaType: mediaType, range: NSRange(location: 0, length: sj_NSUIntegerMaxLength))
    }

    @objc(recordsForConditions:orderBy:)
    public func records(forConditions conditions: [SJSQLite3Condition]?, orderBy orders: [SJSQLite3ColumnOrder]?) -> [SJPlaybackRecord]? {
        return records(forConditions: conditions, orderBy: orders, range: NSRange(location: 0, length: sj_NSUIntegerMaxLength))
    }

    @objc(recordsForConditions:orderBy:range:)
    public func records(forConditions conditions: [SJSQLite3Condition]?, orderBy orders: [SJSQLite3ColumnOrder]?, range: NSRange) -> [SJPlaybackRecord]? {
        return sqlite?.objects(for: SJPlaybackRecord.self, conditions: conditions, orderBy: orders, range: range, error: nil) as? [SJPlaybackRecord]
    }

    // MARK: 数量

    @objc(countOfRecordsForUser:mediaType:)
    public func countOfRecords(forUser userId: Int, mediaType: SJMediaType) -> UInt {
        return countOfRecords(forConditions: [
            SJSQLite3Condition.condition(column: "userId", value: NSNumber(value: userId)),
            SJSQLite3Condition.condition(column: "mediaType", value: mediaType as NSString)
        ])
    }

    @objc(countOfRecordsForConditions:)
    public func countOfRecords(forConditions conditions: [SJSQLite3Condition]?) -> UInt {
        return sqlite?.countOfObjects(for: SJPlaybackRecord.self, conditions: conditions, error: nil) ?? 0
    }

    // MARK: 删除

    @objc(remove:user:mediaType:)
    public func remove(_ media: Int, user userId: Int, mediaType: SJMediaType) {
        assert(!mediaType.isEmpty)
        guard let record = record(forMedia: media, user: userId, mediaType: mediaType) else { return }
        sqlite?.removeObjects(for: SJPlaybackRecord.self, primaryKeyValues: [NSNumber(value: record.id)], error: nil)
    }

    @objc(removeAllRecordsForUser:mediaType:)
    public func removeAllRecords(forUser userId: Int, mediaType: SJMediaType) {
        assert(!mediaType.isEmpty)
        sqlite?.removeAllObjects(for: SJPlaybackRecord.self, conditions: [
            SJSQLite3Condition.condition(column: "userId", value: NSNumber(value: userId)),
            SJSQLite3Condition.condition(column: "mediaType", value: mediaType as NSString)
        ], error: nil)
    }

    @objc(removeForConditions:)
    public func removeForConditions(_ conditions: [SJSQLite3Condition]?) {
        sqlite?.removeAllObjects(for: SJPlaybackRecord.self, conditions: conditions, error: nil)
    }
}
