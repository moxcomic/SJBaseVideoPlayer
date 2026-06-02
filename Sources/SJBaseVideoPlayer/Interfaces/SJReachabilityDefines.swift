//
//  SJReachabilityDefines.swift
//  Project
//
//  Created by 畅三江 on 2018/6/1.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  契约层(Swift 6.3): 由原 SJReachabilityDefines.h 转换而来。
//

import Foundation

// MARK: - 网络状态

/// 对应原 NS_ENUM(NSInteger, SJNetworkStatus)。
/// 列出网络的3种状态值, 用来标识当前的网络状态。
@objc(SJNetworkStatus)
public enum SJNetworkStatus: Int, Sendable {
    case notReachable = 0
    case reachableViaWWAN = 1
    case reachableViaWiFi = 2
}

// MARK: - 网络可达性协议

/// 对应原 @protocol SJReachability_Protocol <NSObject>。
@MainActor
@objc(SJReachability)
public protocol SJReachability_Protocol: NSObjectProtocol {
    @objc func getObserver() -> SJReachabilityObserver

    @objc var networkStatus: SJNetworkStatus { get }
    @objc var networkSpeedStr: String { get }

    @objc func startRefresh()
    @objc func stopRefresh()
}

// MARK: - 网络可达性观察者

/// 对应原 @protocol SJReachabilityObserver_Protocol <NSObject>。
@MainActor
@objc(SJReachabilityObserver)
public protocol SJReachabilityObserver_Protocol: NSObjectProtocol {
    @objc var networkStatusDidChangeExeBlock: ((_ r: SJReachability) -> Void)? { get set }
    @objc var networkSpeedDidChangeExeBlock: ((_ r: SJReachability) -> Void)? { get set }
}

