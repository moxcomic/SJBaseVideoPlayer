//
//  SJReachability.swift
//  Project
//
//  Created by 畅三江 on 2018/12/28.
//  Copyright © 2018 changsanjiang. All rights reserved.
//  Swift 6.3 迁移: 自实现 SystemConfiguration 可达性 + 网速观察, 不依赖第三方.
//  保留原 ObjC 类/协议/选择器名.
//

import Foundation
import SystemConfiguration

// MARK: - 内部可达性核心 (基于 SCNetworkReachability, 等价于原 _Reachability)

private let _kReachabilityChangedNotification = Notification.Name("_kReachabilityChangedNotification")

/// 与 ObjC 版 NetworkStatus 对应 (Apple 兼容命名)
private enum _NetworkStatus: Int {
    case notReachable = 0
    case reachableViaWWAN = 1
    case reachableViaWiFi = 2
}

/// 可达性核心实现.
/// 注: 内部以串行队列闭环管理 SCNetworkReachability, 回调仅向主线程发通知, 故并发安全.
private final class _Reachability: NSObject, @unchecked Sendable {
    private var reachabilityRef: SCNetworkReachability?
    private let reachabilitySerialQueue = DispatchQueue(label: "com.tonymillion.reachability")
    private var reachabilityObject: AnyObject?
    var reachableOnWWAN: Bool = true

    init(reachabilityRef ref: SCNetworkReachability) {
        self.reachabilityRef = ref
        super.init()
    }

    static func reachabilityForInternetConnection() -> _Reachability? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let ref = withUnsafePointer(to: &zeroAddress) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, saPtr)
            }
        }
        guard let ref = ref else { return nil }
        return _Reachability(reachabilityRef: ref)
    }

    deinit {
        stopNotifier()
        reachabilityRef = nil
    }

    // MARK: Notifier

    @discardableResult
    func startNotifier() -> Bool {
        // 允许多次调用
        if reachabilityObject != nil, reachabilityObject === self {
            return true
        }
        guard let reachabilityRef = reachabilityRef else { return false }

        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<_Reachability>.passUnretained(self).toOpaque())

        let callback: SCNetworkReachabilityCallBack = { _, _, info in
            guard let info = info else { return }
            let reachability = Unmanaged<_Reachability>.fromOpaque(info).takeUnretainedValue()
            autoreleasepool {
                reachability.reachabilityChanged()
            }
        }

        if SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
            if SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
                reachabilityObject = self
                return true
            } else {
                SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
            }
        }

        reachabilityObject = nil
        return false
    }

    func stopNotifier() {
        if let reachabilityRef = reachabilityRef {
            SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
        }
        reachabilityObject = nil
    }

    // MARK: reachability tests

    private func isReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        var connectionUP = true
        if !flags.contains(.reachable) {
            connectionUP = false
        }
        let testcase: SCNetworkReachabilityFlags = [.connectionRequired, .transientConnection]
        if flags.intersection(testcase) == testcase {
            connectionUP = false
        }
        if flags.contains(.isWWAN) {
            if !reachableOnWWAN {
                connectionUP = false
            }
        }
        return connectionUP
    }

    private var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags()
        guard let reachabilityRef = reachabilityRef else { return flags }
        if SCNetworkReachabilityGetFlags(reachabilityRef, &flags) {
            return flags
        }
        return flags
    }

    func isReachable() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        guard let reachabilityRef = reachabilityRef else { return false }
        if !SCNetworkReachabilityGetFlags(reachabilityRef, &flags) {
            return false
        }
        return isReachable(with: flags)
    }

    func isReachableViaWiFi() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        guard let reachabilityRef = reachabilityRef else { return false }
        if SCNetworkReachabilityGetFlags(reachabilityRef, &flags) {
            if flags.contains(.reachable) {
                if flags.contains(.isWWAN) {
                    return false
                }
                return true
            }
        }
        return false
    }

    func currentReachabilityStatus() -> _NetworkStatus {
        if isReachable() {
            if isReachableViaWiFi() {
                return .reachableViaWiFi
            }
            return .reachableViaWWAN
        }
        return .notReachable
    }

    // MARK: Callback

    func reachabilityChanged() {
        // 与 ObjC 版一致: 在主线程发出变化通知.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: _kReachabilityChangedNotification, object: self)
        }
    }
}

// MARK: - 网速观察 (等价于原 __DJNetworkSpeedObserver)

private let GSDownloadNetworkSpeedNotificationKey = Notification.Name("__GSDownloadNetworkSpeedNotificationKey")

///
/// Thanks @18138870200
/// https://github.com/18138870200/SGNetworkSpeed.git
///
@MainActor
private final class __DJNetworkSpeedObserver: NSObject {
    private nonisolated(unsafe) var timer: Timer?
    fileprivate var speed: UInt32 = 0
    private var iBytes: UInt32 = 0

    deinit {
        // Timer 已带 invalidate, 这里不能跨 actor 访问; 见 stop().
        timer?.invalidate()
    }

    func start() {
        if timer == nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
                nonisolated(unsafe) let t = timer
                MainActor.assumeIsolated {
                    guard let self = self else {
                        t.invalidate()
                        return
                    }
                    self.checkNetworkSpeed()
                }
            }
            timer = t
            t.fire()
            RunLoop.main.add(t, forMode: .common)
            iBytes = 0
        }
    }

    func stop() {
        if let timer = timer, timer.isValid {
            timer.invalidate()
            self.timer = nil
            iBytes = 0
        }
    }

    func speedString() -> String {
        // B
        if speed < 1024 {
            return "0KB"
        }
        // KB
        else if speed >= 1024 && speed < 1024 * 1024 {
            return String(format: "%.fKB/s", Double(speed) / 1024)
        }
        // MB
        else if speed >= 1024 * 1024 && speed < 1024 * 1024 * 1024 {
            return String(format: "%.1fMB/s", Double(speed) / (1024 * 1024))
        }
        // GB
        else {
            return String(format: "%.1fGB/s", Double(speed) / (1024 * 1024 * 1024))
        }
    }

    private func checkNetworkSpeed() {
        let previousIBytes = self.iBytes
        DispatchQueue.global().async { [weak self] in
            var ifaListPtr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaListPtr) == -1 {
                return
            }
            var iBytes: UInt32 = 0
            var ifa = ifaListPtr
            while let cur = ifa {
                defer { ifa = cur.pointee.ifa_next }
                guard let addr = cur.pointee.ifa_addr else { continue }
                if Int32(addr.pointee.sa_family) != AF_LINK {
                    continue
                }
                let flags = Int32(cur.pointee.ifa_flags)
                if (flags & IFF_UP) == 0 && (flags & IFF_RUNNING) == 0 {
                    continue
                }
                guard let data = cur.pointee.ifa_data else {
                    continue
                }
                // network: 排除 lo (回环)
                if let name = cur.pointee.ifa_name {
                    if strncmp(name, "lo", 2) != 0 {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        iBytes &+= ifData.pointee.ifi_ibytes
                    }
                }
            }
            freeifaddrs(ifaListPtr)

            let computedIBytes = iBytes
            if previousIBytes != 0 {
                let speed = computedIBytes &- previousIBytes
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self = self else { return }
                        self.speed = speed
                        NotificationCenter.default.post(name: GSDownloadNetworkSpeedNotificationKey, object: self)
                    }
                }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.iBytes = computedIBytes
                }
            }
        }
    }
}

// MARK: - SJReachabilityObserver

private let SJReachabilityNetworkStatusDidChangeNotification = Notification.Name("SJReachabilityNetworkStatusDidChange")

@objc(SJReachabilityObserver)
public final class SJReachabilityObserver: NSObject, SJReachabilityObserver_Protocol {
    @objc public var networkStatusDidChangeExeBlock: ((SJReachability) -> Void)?
    @objc public var networkSpeedDidChangeExeBlock: ((SJReachability) -> Void)?

    private weak var reachability: SJReachability?

    @objc public init(reachability: SJReachability) {
        self.reachability = reachability
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusDidChange(_:)), name: SJReachabilityNetworkStatusDidChangeNotification, object: reachability)
        NotificationCenter.default.addObserver(self, selector: #selector(networkSpeedDidChange(_:)), name: GSDownloadNetworkSpeedNotificationKey, object: reachability.networkSpeedObserverObject)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func networkStatusDidChange(_ note: Notification) {
        guard let mgr = note.object as? SJReachability else { return }
        networkStatusDidChangeExeBlock?(mgr)
    }

    @objc private func networkSpeedDidChange(_ note: Notification) {
        if let reachability = reachability {
            networkSpeedDidChangeExeBlock?(reachability)
        }
    }
}

// MARK: - SJReachability

@MainActor
@objc(SJReachability)
public final class SJReachability: NSObject, SJReachability_Protocol {

    @objc public private(set) var networkStatus: SJNetworkStatus = .notReachable {
        didSet {
            NotificationCenter.default.post(name: SJReachabilityNetworkStatusDidChangeNotification, object: self)
        }
    }

    private let networkSpeedObserver = __DJNetworkSpeedObserver()

    /// 供 Observer 作为通知 object 关联使用.
    fileprivate var networkSpeedObserverObject: AnyObject { networkSpeedObserver }

    // 全局唯一可达性核心 (对应 ObjC 版的 static _reachability + dispatch_once)
    private static let sharedReachability: _Reachability? = {
        let r = _Reachability.reachabilityForInternetConnection()
        r?.startNotifier()
        return r
    }()

    @objc public static let shared = SJReachability()

    public override init() {
        super.init()
        _initializeReachability()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc public func getObserver() -> SJReachabilityObserver {
        return SJReachabilityObserver(reachability: self)
    }

    @objc public var networkSpeedStr: String {
        return networkSpeedObserver.speedString()
    }

    private func _initializeReachability() {
        _updateNetworkStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged), name: _kReachabilityChangedNotification, object: SJReachability.sharedReachability)
    }

    @objc private func reachabilityChanged() {
        _updateNetworkStatus()
    }

    private func _updateNetworkStatus() {
        let status = SJReachability.sharedReachability?.currentReachabilityStatus() ?? .notReachable
        networkStatus = SJNetworkStatus(rawValue: status.rawValue) ?? .notReachable
    }

    @objc public func startRefresh() {
        networkSpeedObserver.start()
    }

    @objc public func stopRefresh() {
        networkSpeedObserver.stop()
    }
}

