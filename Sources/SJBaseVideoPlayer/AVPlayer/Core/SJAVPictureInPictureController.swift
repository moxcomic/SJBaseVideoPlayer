//
//  SJAVPictureInPictureController.swift
//  SJBaseVideoPlayer
//
//  Created by BlueDancer on 2020/9/26.
//
//  Swift 6.3 迁移: 由 SJAVPictureInPictureController.{h,m} 转写.
//  封装 AVPictureInPictureController, 管理画中画状态机. iOS 14+.
//  - pictureInPicturePossible KVO 改用 Swift 原生 observe, 回主线程处理.
//

@preconcurrency import AVFoundation
import AVKit

@available(iOS 14.0, *)
@MainActor
@objc(SJAVPictureInPictureController)
public final class SJAVPictureInPictureController: NSObject, SJPictureInPictureController, AVPictureInPictureControllerDelegate {

    @objc public weak var delegate: SJPictureInPictureControllerDelegate?

    private nonisolated(unsafe) let pictureInPictureController: AVPictureInPictureController
    private var possibleObservation: NSKeyValueObservation?

    @objc public private(set) var status: SJPictureInPictureStatus = .unknown {
        didSet {
            if let delegate = delegate,
               delegate.responds(to: #selector(SJPictureInPictureControllerDelegate.pictureInPictureController(_:statusDidChange:))) {
                delegate.pictureInPictureController(self, statusDidChange: status)
            }
        }
    }

    @objc public private(set) var wantsPictureInPictureStart: Bool = false

    @objc public var requiresLinearPlayback: Bool {
        get { pictureInPictureController.requiresLinearPlayback }
        set { pictureInPictureController.requiresLinearPlayback = newValue }
    }

    @available(iOS 14.2, *)
    @objc public var canStartPictureInPictureAutomaticallyFromInline: Bool {
        get { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline }
        set { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = newValue }
    }

    @objc public var isAvailable: Bool {
        return status != .stopping && status != .stopped
    }

    @objc public var isEnabled: Bool {
        return status == .starting || status == .running
    }

    @objc public static func isPictureInPictureSupported() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    @objc public init?(layer: AVPlayerLayer, delegate: SJPictureInPictureControllerDelegate) {
        guard SJAVPictureInPictureController.isPictureInPictureSupported() else { return nil }
        guard let controller = AVPictureInPictureController(playerLayer: layer) else { return nil }
        self.pictureInPictureController = controller
        super.init()
        self.delegate = delegate
        controller.delegate = self
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.startPictureInPictureIfReady() }
        }
    }

    deinit {
        // 取消画中画(若未停止). 直接调用底层 stop, 避免在 deinit 中触碰 actor 隔离状态.
        pictureInPictureController.stopPictureInPicture()
    }

    @objc public func startPictureInPicture() {
        wantsPictureInPictureStart = true
        switch status {
        case .starting, .running:
            return
        case .unknown, .stopping, .stopped:
            status = .starting
            startPictureInPictureIfReady()
        @unknown default:
            break
        }
    }

    @objc public func stopPictureInPicture() {
        wantsPictureInPictureStart = false
        switch status {
        case .stopping, .stopped:
            return
        case .unknown, .starting, .running:
            status = .stopping
            _stopPictureInPicture()
        @unknown default:
            break
        }
    }

    // MARK: -

    private func startPictureInPictureIfReady() {
        let isReady = (status == .starting) && pictureInPictureController.isPictureInPicturePossible
        if isReady {
            DispatchQueue.main.async { [weak self] in
                self?.pictureInPictureController.startPictureInPicture()
            }
        }
    }

    private func _stopPictureInPicture() {
        pictureInPictureController.stopPictureInPicture()
    }

    // MARK: - AVPictureInPictureControllerDelegate

    // 系统协议 AVPictureInPictureControllerDelegate 的要求为 nonisolated; 在 @MainActor 类里用 nonisolated + assumeIsolated 闭环(PiP 回调均在主线程)。
    nonisolated public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        MainActor.assumeIsolated { status = .running }
    }

    nonisolated public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        MainActor.assumeIsolated { _stopPictureInPicture() }
    }

    nonisolated public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        MainActor.assumeIsolated { status = .stopped }
    }

    nonisolated public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        nonisolated(unsafe) let ch = completionHandler
        MainActor.assumeIsolated {
            if let delegate = delegate {
                delegate.pictureInPictureController(self, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: ch)
            } else {
                ch(false)
            }
        }
    }
}

