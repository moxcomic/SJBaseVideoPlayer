//
//  CALayer+SJBaseVideoPlayerExtended.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/22.
//
//  Swift 6.3 转换: 保留 ObjC 选择器(pauseAnimation、resumeAnimation、
//  addAnimation:startHandler:[stopHandler:]). 动画 delegate 用关联对象持有.
//

import QuartzCore
import ObjectiveC.runtime

///
/// 动画开始的回调类型.
///
public typealias SJAnimationDidStartHandler = (CAAnimation) -> Void
///
/// 动画停止的回调类型. isFinished 表示动画是否正常结束.
///
public typealias SJAnimationDidStopHandler = (CAAnimation, Bool) -> Void

///
/// 内部动画代理: 转发 start/stop 回调, 执行后清空避免重复调用.
///
/// 说明: 该类型遵循系统协议 `CAAnimationDelegate`(其要求为 nonisolated), 因此不能给
/// 本类型强制标注 `@MainActor`(否则遵循会"跨入主 actor 隔离代码"). 改为让本类型保持
/// 非隔离, 并在 delegate 回调内用 `MainActor.assumeIsolated` 闭环 —— Core Animation 的
/// start/stop 回调本就在主线程派发, 这样既满足 Swift 6 并发检查, 又保持与 ObjC 基线
/// 等价的主线程访问语义.
///
@MainActor
final class SJExtendedAnimationDelegate: NSObject, CAAnimationDelegate {
    @MainActor var startHandler: SJAnimationDidStartHandler?
    @MainActor var stopHandler: SJAnimationDidStopHandler?

    nonisolated func animationDidStart(_ anim: CAAnimation) {
        nonisolated(unsafe) let a = anim
        // Core Animation 在主线程派发该回调.
        MainActor.assumeIsolated {
            startHandler?(a)
            startHandler = nil
        }
    }

    nonisolated func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        nonisolated(unsafe) let a = anim
        // Core Animation 在主线程派发该回调.
        MainActor.assumeIsolated {
            stopHandler?(a, flag)
            stopHandler = nil
        }
    }
}

nonisolated(unsafe) private var kSJAnimationDelegateKey: UInt8 = 0

@objc
public extension CALayer {

    ///
    /// 暂停动画
    ///
    @objc(pauseAnimation)
    func pauseAnimation() {
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0.0
        timeOffset = pausedTime
    }

    ///
    /// 恢复动画
    ///
    @objc(resumeAnimation)
    func resumeAnimation() {
        let pausedTime = timeOffset
        speed = 1.0
        timeOffset = 0.0
        beginTime = 0.0
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        beginTime = timeSincePause
    }

    ///
    /// 添加动画及设置动画开始的回调
    ///
    @objc(addAnimation:startHandler:)
    @MainActor func addAnimation(_ anim: CAAnimation, startHandler: SJAnimationDidStartHandler?) {
        addAnimation(anim, startHandler: startHandler, stopHandler: nil)
    }

    ///
    /// 添加动画及设置动画停止的回调
    ///
    @objc(addAnimation:stopHandler:)
    @MainActor func addAnimation(_ anim: CAAnimation, stopHandler: SJAnimationDidStopHandler?) {
        addAnimation(anim, startHandler: nil, stopHandler: stopHandler)
    }

    ///
    /// 添加动画及设置动画开始,停止的回调
    ///
    @objc(addAnimation:startHandler:stopHandler:)
    @MainActor func addAnimation(_ anim: CAAnimation, startHandler: SJAnimationDidStartHandler?, stopHandler: SJAnimationDidStopHandler?) {
        // 与 ObjC 行为等价: 该方法在主线程调用 (CALayer 动画 API 主线程使用).
        MainActor.assumeIsolated {
            var delegate = objc_getAssociatedObject(self, &kSJAnimationDelegateKey) as? SJExtendedAnimationDelegate
            if delegate == nil {
                let newDelegate = SJExtendedAnimationDelegate()
                objc_setAssociatedObject(self, &kSJAnimationDelegateKey, newDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                delegate = newDelegate
            }
            delegate?.startHandler = startHandler
            delegate?.stopHandler = stopHandler
            anim.delegate = delegate
            add(anim, forKey: nil)
        }
    }
}

