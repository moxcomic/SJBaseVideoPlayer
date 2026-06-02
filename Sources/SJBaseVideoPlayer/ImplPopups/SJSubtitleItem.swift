//
//  SJSubtitleItem.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/8.
//
//  由 ObjC 版 SJSubtitleItem.h/.m 转换而来 (Swift 6.3)。
//

import Foundation
import UIKit

///
/// 字幕条目。
///
/// 注意:
/// - 遵循 `SJSubtitleItem` 协议(协议定义在接口块的 `SJSubtitlePopupControllerDefines` 中)。
/// - `range` 类型 `SJTimeRange` 是 Swift 值类型(struct), 无法通过 @objc 表达, 因此涉及
///   `SJTimeRange` 的成员(`init(content:range:)`、`range` 属性)对 ObjC 不可见; 见本块 notes。
/// - `init(content:start:end:)` 参数全为 Double, 可 @objc 暴露给 ObjC 上层使用。
///
@MainActor
public final class SJSubtitleItem: NSObject, SJSubtitleItem_Protocol {
    /// 字幕内容
    public let content: NSAttributedString
    /// 显示时间范围(Swift 值类型, 非 @objc)
    public let range: SJTimeRange

    /// 用内容和时间范围初始化 (Swift / 同 module 调用; SJTimeRange 非 @objc)
    public init(content: NSAttributedString, range: SJTimeRange) {
        self.content = content.copy() as! NSAttributedString
        self.range = range
        super.init()
    }

    /// 用内容和开始/结束时间初始化 (@objc 可见, 参数均为 Double)
    @objc public convenience init(content: NSAttributedString, start: TimeInterval, end: TimeInterval) {
        self.init(content: content, range: SJMakeTimeRange(start, end - start))
    }
}

