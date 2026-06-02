//
//  NSString+SJBaseVideoPlayerExtended.swift
//  Pods
//
//  Created by 畅三江 on 2019/12/12.
//
//  Swift 6.3 转换: 保留 ObjC 选择器 `+stringWithCurrentTime:duration:`.
//

import Foundation

@objc
public extension NSString {
    ///
    /// 将当前时间转为字符串格式
    ///
    ///     e.g.
    ///
    ///         @"12:12"       => duration 小于1个小时
    ///
    ///         @"00:12:12"    => duration 大于1个小时
    ///
    ///         @"12:12:12"    => duration 大于1个小时
    ///
    ///         @"123:12:12"   => duration 大于24个小时
    ///
    @objc(stringWithCurrentTime:duration:)
    static func string(withCurrentTime currentTime: TimeInterval, duration: TimeInterval) -> NSString {
        let min: Int = 60
        let hour: Int = 60 * min

        let hours = Int(currentTime) / hour
        let minutes = (Int(currentTime) - hours * hour) / 60
        let seconds = Int(currentTime) % 60
        if duration < Double(hour) {
            return NSString(format: "%02ld:%02ld", minutes, seconds)
        } else if hours < 100 {
            return NSString(format: "%02ld:%02ld:%02ld", hours, minutes, seconds)
        } else {
            return NSString(format: "%ld:%02ld:%02ld", hours, minutes, seconds)
        }
    }
}

