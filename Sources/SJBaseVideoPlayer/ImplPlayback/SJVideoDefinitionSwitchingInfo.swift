//
//  SJVideoDefinitionSwitchingInfo.swift
//  Pods
//
//  Created by 畅三江 on 2019/7/12.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//
//  对应 ObjC: SJVideoDefinitionSwitchingInfo.h/.m + SJVideoDefinitionSwitchingInfo+Private.h
//

import Foundation

private let _SJVideoDefinitionSwitchStatusDidChangeNotification = Notification.Name("_SJVideoDefinitionSwitchStatusDidChangeNotification")

@objc(SJVideoDefinitionSwitchingInfo)
@MainActor
public class SJVideoDefinitionSwitchingInfo: NSObject {
    // 原 ObjC: readonly + (Private) 可写; 这里 internal(set) 让同 module 其它块(播放/切换逻辑)可写,
    // 对外仍只读, 等价于 +Private.h 的可见性约束.
    @objc public internal(set) weak var currentPlayingAsset: SJVideoPlayerURLAsset?

    @objc public internal(set) weak var switchingAsset: SJVideoPlayerURLAsset?

    @objc public internal(set) var status: SJDefinitionSwitchStatus = .unknown {
        didSet {
            if status != oldValue {
                NotificationCenter.default.post(name: _SJVideoDefinitionSwitchStatusDidChangeNotification, object: self)
            }
        }
    }

    @objc public func getObserver() -> SJVideoDefinitionSwitchingInfoObserver {
        return SJVideoDefinitionSwitchingInfoObserver(info: self)
    }
}

@objc(SJVideoDefinitionSwitchingInfoObserver)
@MainActor
public class SJVideoDefinitionSwitchingInfoObserver: NSObject {
    @objc public var statusDidChangeExeBlock: ((SJVideoDefinitionSwitchingInfo) -> Void)?

    private nonisolated(unsafe) var token: (any NSObjectProtocol)?

    @objc public init(info: SJVideoDefinitionSwitchingInfo) {
        super.init()
        token = NotificationCenter.default.addObserver(forName: _SJVideoDefinitionSwitchStatusDidChangeNotification, object: info, queue: .main) { [weak self] note in
            nonisolated(unsafe) let n = note
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if let info = n.object as? SJVideoDefinitionSwitchingInfo {
                    self.statusDidChangeExeBlock?(info)
                }
            }
        }
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

