//
//  SJPlaybackRecordSaveHandler.swift
//  SJVideoPlayer_Example
//
//  Created by BlueDancer on 2020/2/20.
//  Copyright © 2020 changsanjiang. All rights reserved.
//
//  Swift 6.3 迁移版本. 播放记录保存管理类.
//  ObjC 版以 `#if __has_include(<YYModel/...>)` 守卫, Swift 改为 SJ_HAS_YYMODEL 编译条件
//  (注: 见 notes, 由 podspec/SwiftSettings 注入).
//

#if SJ_HAS_YYMODEL
import Foundation
import ObjectiveC.runtime

/// 触发保存播放记录的事件
@objc(SJPlayerEvent)
public enum SJPlayerEvent: UInt {
    /// 播放器资源将要改变时
    case urlAssetWillChange
    /// 播放控制将要销毁前
    case playbackControllerWillDeallocate
    /// 播放器执行了暂停
    case playbackDidPause
    /// 播放器将要执行 stop 前
    case playbackWillStop
    /// 播放器将要执行 refresh 前
    case playbackWillRefresh
    /// 播放器接收到 App 进入后台时
    case applicationDidEnterBackground
    /// 播放器接收到 App 将要销毁时
    case applicationWillTerminate
}

/// 事件掩码 (NS_OPTIONS 等价)
public struct SJPlayerEventMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let urlAssetWillChange = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.urlAssetWillChange.rawValue)
    public static let playbackControllerWillDeallocate = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.playbackControllerWillDeallocate.rawValue)
    public static let playbackDidPause = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.playbackDidPause.rawValue)
    public static let playbackWillStop = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.playbackWillStop.rawValue)
    public static let playbackWillRefresh = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.playbackWillRefresh.rawValue)
    public static let applicationDidEnterBackground = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.applicationDidEnterBackground.rawValue)
    public static let applicationWillTerminate = SJPlayerEventMask(rawValue: 1 << SJPlayerEvent.applicationWillTerminate.rawValue)

    public static let playbackEvents: SJPlayerEventMask = [.playbackControllerWillDeallocate, .playbackWillStop, .playbackWillRefresh, .playbackDidPause]
    public static let applicationEvents: SJPlayerEventMask = [.applicationDidEnterBackground, .applicationWillTerminate]
    public static let all: SJPlayerEventMask = [.urlAssetWillChange, .playbackEvents, .applicationEvents]
}

// MARK: - SJVideoPlayerURLAsset 关联记录扩展

extension SJVideoPlayerURLAsset {
    private static var recordKey: UInt8 = 0
    /// 关联的播放记录对象
    @objc public var record: SJPlaybackRecord? {
        get { objc_getAssociatedObject(self, &SJVideoPlayerURLAsset.recordKey) as? SJPlaybackRecord }
        set { objc_setAssociatedObject(self, &SJVideoPlayerURLAsset.recordKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - 保存处理器

@objc(SJPlaybackRecordSaveHandler)
@MainActor
public final class SJPlaybackRecordSaveHandler: NSObject {
    private var _observer: SJPlayerEventObserver!
    private let _controller: SJPlaybackHistoryController

    @objc public static let shared: SJPlaybackRecordSaveHandler = SJPlaybackRecordSaveHandler(events: .all, playbackHistoryController: SJPlaybackHistoryController.shared)

    @objc(initWithEvents:playbackHistoryController:)
    public init(events: SJPlayerEventMask, playbackHistoryController controller: SJPlaybackHistoryController) {
        _controller = controller
        super.init()
        _observer = SJPlayerEventObserver(events: events) { [weak self] target, event in
            guard let self else { return }
            self._target(target, event: event)
        }
    }

    /// 设置保存的时机 (发生某个事件后自动保存)
    @objc public var events: SJPlayerEventMask {
        get { _observer.events }
        set { _observer.events = newValue }
    }

    private func _target(_ target: AnyObject, event: SJPlayerEvent) {
        switch event {
        case .playbackDidPause:
            if let player = target as? SJBaseVideoPlayer, player.isPaused {
                _saveForPlayer(player)
            }
        case .playbackWillRefresh, .urlAssetWillChange, .playbackWillStop,
             .applicationDidEnterBackground, .applicationWillTerminate:
            if let player = target as? SJBaseVideoPlayer { _saveForPlayer(player) }
        case .playbackControllerWillDeallocate:
            if let controller = target as? SJVideoPlayerPlaybackController { _saveForPlaybackController(controller) }
        }
    }

    private func _saveForPlayer(_ player: SJBaseVideoPlayer) {
        if let record = player.urlAsset?.record {
            record.position = player.currentTime
            _saveRecord(record)
        }
    }

    private func _saveForPlaybackController(_ playbackController: SJVideoPlayerPlaybackController) {
        if let record = (playbackController.media as? SJVideoPlayerURLAsset)?.record {
            record.position = playbackController.currentTime
            _saveRecord(record)
        }
    }

    private func _saveRecord(_ record: SJPlaybackRecord) {
        _controller.save(record)
        #if DEBUG
        print("\(#line) \t \(#function) \t 已保存播放位置: \(record.position)")
        #endif
    }
}

// MARK: - 事件观察者 (基于通知)

@objc(SJPlayerEventObserver)
@MainActor
public final class SJPlayerEventObserver: NSObject {
    @objc public var events: SJPlayerEventMask
    private let _block: (AnyObject, SJPlayerEvent) -> Void

    @objc(initWithEvents:handler:)
    public init(events: SJPlayerEventMask, handler block: @escaping (AnyObject, SJPlayerEvent) -> Void) {
        self.events = events
        self._block = block
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(_timeControlStatusDidChange(_:)), name: NSNotification.Name(SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification), object: nil)
        nc.addObserver(self, selector: #selector(_URLAssetWillChange(_:)), name: NSNotification.Name(SJVideoPlayerURLAssetWillChangeNotification), object: nil)
        nc.addObserver(self, selector: #selector(_playbackWillStop(_:)), name: NSNotification.Name(SJVideoPlayerPlaybackWillStopNotification), object: nil)
        nc.addObserver(self, selector: #selector(_playbackWillRefresh(_:)), name: NSNotification.Name(SJVideoPlayerPlaybackWillRefreshNotification), object: nil)
        nc.addObserver(self, selector: #selector(_didEnterBackground(_:)), name: NSNotification.Name(SJVideoPlayerApplicationDidEnterBackgroundNotification), object: nil)
        nc.addObserver(self, selector: #selector(_willTerminate(_:)), name: NSNotification.Name(SJVideoPlayerApplicationWillTerminateNotification), object: nil)
        nc.addObserver(self, selector: #selector(_playbackControllerWillDeallocate(_:)), name: NSNotification.Name(SJVideoPlayerPlaybackControllerWillDeallocateNotification), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func _timeControlStatusDidChange(_ note: Notification) {
        if events.contains(.playbackDidPause) {
            if let player = note.object as? SJBaseVideoPlayer, player.isPaused {
                _block(player, .playbackDidPause)
            }
        }
    }
    @objc private func _URLAssetWillChange(_ note: Notification) {
        if events.contains(.urlAssetWillChange), let obj = note.object as AnyObject? {
            _block(obj, .urlAssetWillChange)
        }
    }
    @objc private func _playbackWillStop(_ note: Notification) {
        if events.contains(.playbackWillStop), let obj = note.object as AnyObject? {
            _block(obj, .playbackWillStop)
        }
    }
    @objc private func _playbackWillRefresh(_ note: Notification) {
        if events.contains(.playbackWillRefresh), let obj = note.object as AnyObject? {
            _block(obj, .playbackWillRefresh)
        }
    }
    @objc private func _didEnterBackground(_ note: Notification) {
        if events.contains(.applicationDidEnterBackground), let obj = note.object as AnyObject? {
            _block(obj, .applicationDidEnterBackground)
        }
    }
    @objc private func _willTerminate(_ note: Notification) {
        if events.contains(.applicationWillTerminate), let obj = note.object as AnyObject? {
            _block(obj, .applicationWillTerminate)
        }
    }
    @objc private func _playbackControllerWillDeallocate(_ note: Notification) {
        if events.contains(.playbackControllerWillDeallocate), let obj = note.object as AnyObject? {
            _block(obj, .playbackControllerWillDeallocate)
        }
    }
}
#endif

