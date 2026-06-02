//
//  NSTimer+SJAssetAdd.swift
//  SJVideoPlayerAssetCarrier
//
//  Created by 畅三江 on 2018/5/21.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  Swift 6.3 转换: 保留 ObjC 选择器(sj_timerWithTimeInterval:repeats:[usingBlock:]、
//  sj_usingBlock、sj_fire 及已弃用的 assetAdd_ 系列). 关联对象保存回调.
//

import Foundation
import ObjectiveC.runtime

///
/// NSTimer 触发时执行的回调类型 (对应 ObjC `void(^)(NSTimer *timer)`).
///
public typealias SJTimerUsingBlock = (Timer) -> Void

private nonisolated(unsafe) var kSJUsingBlockKey: UInt8 = 0

@objc
public extension Timer {

    @objc(sj_timerWithTimeInterval:repeats:)
    static func sj_timer(withTimeInterval interval: TimeInterval, repeats: Bool) -> Timer {
        return sj_timer(withTimeInterval: interval, repeats: repeats, usingBlock: nil)
    }

    @objc(sj_timerWithTimeInterval:repeats:usingBlock:)
    static func sj_timer(withTimeInterval interval: TimeInterval, repeats: Bool, usingBlock: SJTimerUsingBlock?) -> Timer {
        let timer = Timer(timeInterval: interval, target: Timer.self, selector: #selector(Timer.sj_exeUsingBlock(_:)), userInfo: nil, repeats: repeats)
        timer.sj_usingBlock = usingBlock
        return timer
    }

    @objc(sj_exeUsingBlock:)
    private static func sj_exeUsingBlock(_ timer: Timer) {
        timer.sj_usingBlock?(timer)
    }

    ///
    /// timer 触发时执行的回调 (关联对象保存, COPY 语义).
    ///
    @objc var sj_usingBlock: SJTimerUsingBlock? {
        get {
            return objc_getAssociatedObject(self, &kSJUsingBlockKey) as? SJTimerUsingBlock
        }
        set {
            objc_setAssociatedObject(self, &kSJUsingBlockKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    ///
    /// 立即触发 (将 fireDate 设置为现在 + timeInterval).
    ///
    @objc(sj_fire)
    func sj_fire() {
        self.fireDate = Date(timeIntervalSinceNow: self.timeInterval)
    }
}

///
/// 已弃用
///
@objc
public extension Timer {
    @objc(assetAdd_timerWithTimeInterval:block:repeats:)
    static func assetAdd_timer(withTimeInterval ti: TimeInterval, block: @escaping SJTimerUsingBlock, repeats: Bool) -> Timer {
        return sj_timer(withTimeInterval: ti, repeats: repeats, usingBlock: block)
    }

    @objc(assetAdd_fire)
    func assetAdd_fire() {
        sj_fire()
    }
}

