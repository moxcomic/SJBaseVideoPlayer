//
//  SJPlaybackRecord.swift
//  SJBaseVideoPlayer
//
//  Created by BlueDancer on 2020/5/25.
//  Swift 6.3 迁移: 保留原 ObjC 类/协议/选择器名.
//
//  注: 该类被 SJUIKit 的 SJSQLite3 通过 ObjC 运行时反射进行模型映射,
//  所以必须保持 @objcMembers + @objc dynamic 存储属性, 否则数据库读写失败.
//

import Foundation

/// 媒体类型 (字符串常量, 与 ObjC 版一致)

@objcMembers
@objc(SJPlaybackRecord)
public final class SJPlaybackRecord: NSObject, SJPlaybackRecord_Protocol {
    public dynamic var mediaId: Int = 0
    public dynamic var userId: Int = 0
    public dynamic var position: TimeInterval = 0
    public dynamic var mediaType: SJMediaType = SJMediaTypeVideo

    // MARK: SJPrivate (供 SJPlaybackHistoryController 与 SQLite3 使用)
    public dynamic var id: Int = 0
    public dynamic var createdTime: TimeInterval = 0
    public dynamic var updatedTime: TimeInterval = 0

    public override init() {
        super.init()
        mediaType = SJMediaTypeVideo
    }

    public init(mediaId: Int, mediaType: SJMediaType, userId: Int) {
        super.init()
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.userId = userId
    }

    // MARK: SJSQLiteTableModelProtocol
    public static func sql_primaryKey() -> String? {
        return "id"
    }

    public static func sql_autoincrementlist() -> [String]? {
        return ["id"]
    }
}

