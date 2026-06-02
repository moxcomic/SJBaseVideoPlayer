//
//  SJVideoPlayerRegistrar.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2017/12/5.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  Swift 6.3 转换: App 生命周期与音频路由变更的通知注册. 保留 ObjC 接口与回调.
//  使用 SJUIKit 的 sj_observeWithNotification:target:usingBlock: (自动移除观察者).
//

import UIKit
@preconcurrency import AVFoundation
import SJUIKit

///
/// App 状态. 原始值与 UIApplication.State 保持一致(Active=0, Inactive=1, Background=2).
///
@objc(SJVideoPlayerAppState)
public enum SJVideoPlayerAppState: UInt, Sendable {
    case active = 0       // SJVideoPlayerAppState_Active
    case inactive = 1     // SJVideoPlayerAppState_Inactive
    case background = 2    // SJVideoPlayerAppState_Background, 从前台进入后台
}

@objc(SJVideoPlayerRegistrar)
@MainActor
public final class SJVideoPlayerRegistrar: NSObject {

    ///
    /// 回调类型 (对应 ObjC `void(^)(SJVideoPlayerRegistrar *registrar)`).
    ///
    public typealias Callback = (SJVideoPlayerRegistrar) -> Void

    @objc public var willResignActive: Callback?
    @objc public var didBecomeActive: Callback?
    @objc public var willEnterForeground: Callback?
    @objc public var didEnterBackground: Callback?
    @objc public var willTerminate: Callback?
    @objc public var newDeviceAvailable: Callback?
    @objc public var oldDeviceUnavailable: Callback?
    @objc public var categoryChange: Callback?
    @objc public var audioSessionInterruption: Callback?

    @objc public override init() {
        super.init()
        // 与 ObjC 等价: 在全局队列异步注册通知观察 (sj_observe 内部线程安全, 回调在发送线程触发).
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            self.sj_observe(withNotification: AVAudioSession.routeChangeNotification, target: nil) { (observer, note) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                let info = note.userInfo
                let routeChangeReason = (info?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue ?? 0
                switch AVAudioSession.RouteChangeReason(rawValue: routeChangeReason) {
                case .newDeviceAvailable:
                    self.newDeviceAvailable?(self)
                case .oldDeviceUnavailable:
                    self.oldDeviceUnavailable?(self)
                case .categoryChange:
                    self.categoryChange?(self)
                default:
                    break
                }
            }

            self.sj_observe(withNotification: UIApplication.willResignActiveNotification, target: nil) { (observer, _) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                self.willResignActive?(self)
            }

            self.sj_observe(withNotification: UIApplication.didBecomeActiveNotification, target: nil) { (observer, _) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                self.didBecomeActive?(self)
            }

            self.sj_observe(withNotification: UIApplication.willEnterForegroundNotification, target: nil) { (observer, _) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                self.willEnterForeground?(self)
            }

            self.sj_observe(withNotification: UIApplication.willTerminateNotification, target: nil) { (observer, _) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                self.willTerminate?(self)
            }

            self.sj_observe(withNotification: UIApplication.didEnterBackgroundNotification, target: nil) { (observer, _) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                self.didEnterBackground?(self)
            }

            self.sj_observe(withNotification: AVAudioSession.interruptionNotification, target: AVAudioSession.sharedInstance()) { (observer, note) in
                guard let self = observer as? SJVideoPlayerRegistrar else { return }
                let info = note.userInfo
                let typeValue = (info?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue ?? 0
                if AVAudioSession.InterruptionType(rawValue: typeValue) == .began {
                    self.audioSessionInterruption?(self)
                }
            }
        }
    }

    @objc public var state: SJVideoPlayerAppState {
        let appState = UIApplication.shared.applicationState
        return SJVideoPlayerAppState(rawValue: UInt(appState.rawValue)) ?? .active
    }
}

