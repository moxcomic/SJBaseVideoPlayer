//
//  SJSubtitlePopupControllerDefines.swift
//  Pods
//
//  Created by 畅三江 on 2019/11/8.
//
//  契约层(Swift 6.3): 由原 SJSubtitlePopupControllerDefines.h 转换而来。
//

import UIKit
import Foundation

// MARK: - 时间范围

/// 对应原 C struct SJTimeRange 及其 inline 函数。
/// 说明(notes): struct 无法 @objc 暴露, 改 Swift 原生; 含值的字段保持等价语义。
public struct SJTimeRange: Sendable, Equatable {
    public var start: TimeInterval
    public var duration: TimeInterval

    public init(start: TimeInterval, duration: TimeInterval) {
        self.start = start
        self.duration = duration
    }
}

/// 对应原 inline 函数 SJMakeTimeRange。
@inlinable
public func SJMakeTimeRange(_ start: TimeInterval, _ duration: TimeInterval) -> SJTimeRange {
    SJTimeRange(start: start, duration: duration)
}

/// 对应原 inline 函数 SJTimeRangeContainsTime。
@inlinable
public func SJTimeRangeContainsTime(_ time: TimeInterval, _ range: SJTimeRange) -> Bool {
    (!(time < range.start) && (time - range.start) < range.duration)
}

// MARK: - 字幕弹出控制协议

/// 对应原 @protocol SJSubtitlePopupController_Protocol <NSObject>。
/// 说明(notes): subtitles 元素类型 SJSubtitleItem 因 range 用到 SJTimeRange(非 @objc),
/// 故该协议改为 Swift 原生(不加 @objc)。仅在 module 内部 Swift 互引使用。
@MainActor
public protocol SJSubtitlePopupController_Protocol: NSObjectProtocol {
    /// 设置未来将要显示的字幕。
    var subtitles: [SJSubtitleItem]? { get set }

    /// 内容可显示几行, default value is 0。
    var numberOfLines: Int { get set }

    /// 设置内边距, default value is zero。
    var contentInsets: UIEdgeInsets { get set }

    var view: UIView { get }

    /// 以下属性由播放器维护, 开发者无需设置。
    var currentTime: TimeInterval { get set }
}

// MARK: - 字幕条目协议

/// 对应原 @protocol SJSubtitleItem_Protocol <NSObject>。
/// 说明(notes): 因 range 类型为 SJTimeRange(struct, 非 @objc), 该协议改为 Swift 原生。
@MainActor
public protocol SJSubtitleItem_Protocol: NSObjectProtocol {
    init(content: NSAttributedString, range: SJTimeRange)
    init(content: NSAttributedString, start: TimeInterval, end: TimeInterval)
    var content: NSAttributedString { get }
    var range: SJTimeRange { get }
}

