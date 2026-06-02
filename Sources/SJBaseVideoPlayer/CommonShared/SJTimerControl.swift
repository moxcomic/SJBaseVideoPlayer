//
//  SJTimerControl.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2017/12/6.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  Swift 6.3 转换: 倒计时控制. 保留 ObjC 接口(interval、exeBlock、resume、interrupt).
//  内部使用 NSTimer + sj_ 扩展, 主线程运行循环.
//

import Foundation

///
/// 倒计时控制器: interval 秒后触发 exeBlock, 可中断与恢复.
/// 默认 interval 为 3 秒.
///
@objc(SJTimerControl)
@MainActor
public final class SJTimerControl: NSObject {

    ///
    /// exeBlock 回调类型 (对应 ObjC `void(^)(SJTimerControl *control)`).
    ///
    public typealias ExeBlock = (SJTimerControl) -> Void

    /// default is 3;
    @objc public var interval: TimeInterval = 3 {
        didSet {
            point = Int(interval)
        }
    }

    @objc public var exeBlock: ExeBlock?

    private var timer: Timer?
    private var point: Int = 3

    @objc public override init() {
        super.init()
        self.interval = 3
    }

    @objc public func resume() {
        interrupt()
        weak var weakSelf = self
        let timer = Timer.sj_timer(withTimeInterval: 1, repeats: true) { t in
            MainActor.assumeIsolated {
                guard let self = weakSelf else {
                    t.invalidate()
                    return
                }
                self.point -= 1
                if self.point <= 0 {
                    self.interrupt()
                    self.exeBlock?(self)
                }
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        timer.sj_fire()
    }

    @objc public func interrupt() {
        timer?.invalidate()
        timer = nil
        point = Int(interval)
    }
}

