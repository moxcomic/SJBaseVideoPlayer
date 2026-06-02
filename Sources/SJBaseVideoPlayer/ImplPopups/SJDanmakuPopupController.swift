//
//  SJDanmakuPopupController.swift
//  Pods
//
//  Created by 畅三江 on 2019/11/12.
//
//  由 ObjC 版 SJDanmakuPopupController.h/.m 转换而来 (Swift 6.3)。
//  Masonry -> SnapKit; SJUIKit 提供 SJQueue / NSAttributedString.sj_textSize();
//  CALayer / NSTimer 扩展由其它块提供(同 module)。
//

import Foundation
import UIKit
import QuartzCore
import SJUIKit
import SnapKit

private let POINT_SPEED_FAST: CGFloat = 0.01

// MARK: - 通知名 / userInfo key

private let SJDanmakuPopupControllerOnDisabledChangedNotification = Notification.Name("SJDanmakuPopupControllerOnDisabledChangedNotification")
private let SJDanmakuPopupControllerOnPausedChangedNotification = Notification.Name("SJDanmakuPopupControllerOnPausedChangedNotification")
private let SJDanmakuPopupControllerWillDisplayItemNotification = Notification.Name("SJDanmakuPopupControllerWillDisplayItemNotification")
private let SJDanmakuPopupControllerDidEndDisplayingItemNotification = Notification.Name("SJDanmakuPopupControllerDidEndDisplayingItemNotification")
private let SJDanmakuItemUserInfoKey = "danmakuItem"

// MARK: - SJDanmakuViewDataSource

@MainActor
private protocol SJDanmakuViewDataSource: AnyObject {
    var content: NSAttributedString? { get }
    var customView: UIView? { get }
    var contentSize: CGSize { get }
}

// MARK: - SJDanmakuView

@MainActor
private final class SJDanmakuView: UILabel {
    private var _customView: UIView?

    weak var dataSource: SJDanmakuViewDataSource? {
        didSet {
            if dataSource !== oldValue {
                if let custom = _customView {
                    custom.removeFromSuperview()
                    _customView = nil
                }

                if let content = dataSource?.content, content.length != 0 {
                    attributedText = content
                } else {
                    attributedText = nil
                    _customView = dataSource?.customView
                    if let size = dataSource?.contentSize {
                        _customView?.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                    }
                    if let custom = dataSource?.customView {
                        addSubview(custom)
                    }
                }
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        dataSource?.contentSize ?? .zero
    }
}

// MARK: - SJDanmakuViewModel

@MainActor
private final class SJDanmakuViewModel: NSObject, SJDanmakuViewDataSource {
    let content: NSAttributedString?
    let customView: UIView?
    let contentSize: CGSize

    var duration: TimeInterval = 0
    var nextItemStartTime: TimeInterval = 0
    var delay: TimeInterval = 0
    var points: CGFloat = 0

    init(item: SJDanmakuItem) {
        if let content = item.content, content.length != 0 {
            let copied = content.copy() as! NSAttributedString
            self.content = copied
            self.contentSize = copied.sj_textSize()
        } else {
            self.content = nil
            self.customView = item.customView
            // 对应原逻辑: _contentSize 默认为 zero, 故走 systemLayoutSizeFittingSize 分支
            self.contentSize = item.customView?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) ?? .zero
            super.init()
            return
        }
        self.customView = nil
        super.init()
    }
}

// MARK: - SJDanmakuViewReusablePool

@MainActor
private final class SJDanmakuViewReusablePool {
    var size: Int = 5
    private var m: [SJDanmakuView] = []

    static func pool() -> SJDanmakuViewReusablePool {
        SJDanmakuViewReusablePool()
    }

    init() {
        m.reserveCapacity(size)
    }

    func dequeueReusableView() -> SJDanmakuView {
        if m.isEmpty {
            m.append(SJDanmakuView(frame: .zero))
        }
        return m.removeLast()
    }

    func addView(_ view: SJDanmakuView?) {
        if let view = view, m.count < size {
            m.append(view)
        }
    }
}

// MARK: - SJDanmakuClock

@MainActor
private protocol SJDanmakuClockDelegate: AnyObject {
    func clock(_ clock: SJDanmakuClock, onTimeUpdated time: TimeInterval)
    func clock(_ clock: SJDanmakuClock, onPausedChanged isPaused: Bool)
}

@MainActor
private final class SJDanmakuClock {
    weak var delegate: SJDanmakuClockDelegate?
    private var timer: Timer?

    private var _time: TimeInterval = 0
    var time: TimeInterval {
        get { _time }
        set {
            _time = newValue
            delegate?.clock(self, onTimeUpdated: newValue)
        }
    }

    private var _paused: Bool = true
    var isPaused: Bool {
        get { _paused }
        set {
            _paused = newValue
            delegate?.clock(self, onPausedChanged: newValue)
        }
    }

    static func clock(delegate: SJDanmakuClockDelegate) -> SJDanmakuClock {
        let clock = SJDanmakuClock()
        clock.delegate = delegate
        return clock
    }

    init() {}

    func pause() {
        if _paused == false {
            timer?.invalidate()
            timer = nil
            isPaused = true
        }
    }

    func resume() {
        if _paused == true {
            // NSTimer 扩展(sj_timerWithTimeInterval:repeats:usingBlock: / sj_fire)由其它块提供。
            let t = Timer.sj_timer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                MainActor.assumeIsolated {
                    self.time += timer.timeInterval
                }
            }
            t.sj_fire()
            RunLoop.main.add(t, forMode: .common)
            timer = t
            isPaused = false
        }
    }
}

// MARK: - SJDanmakuTrackView

@MainActor
private final class SJDanmakuTrackView: UIView {}

// MARK: - SJDanmakuTrack

@MainActor
private final class SJDanmakuTrack {
    let pool: SJDanmakuViewReusablePool
    let view: SJDanmakuTrackView

    init(pool: SJDanmakuViewReusablePool) {
        self.pool = pool
        self.view = SJDanmakuTrackView(frame: .zero)
    }

    var last: SJDanmakuViewModel? {
        let danmakuView = view.subviews.last as? SJDanmakuView
        return danmakuView?.dataSource as? SJDanmakuViewModel
    }

    func pause() {
        for subview in view.subviews {
            subview.layer.pauseAnimation()
        }
    }

    func resume() {
        for subview in view.subviews {
            subview.layer.resumeAnimation()
        }
    }

    func clear() {
        for sub in view.subviews.reversed() {
            sub.layer.removeAllAnimations()
            sub.removeFromSuperview()
        }
    }

    func fire(_ viewModel: SJDanmakuViewModel, stoppedCallback completion: @escaping () -> Void) {
        let danmakuView = pool.dequeueReusableView()
        danmakuView.dataSource = viewModel
        danmakuView.layer.removeAllAnimations()
        view.addSubview(danmakuView)

        var frame = CGRect.zero
        let bounds = view.bounds
        frame.origin.x = bounds.size.width
        frame.origin.y = (bounds.height - viewModel.contentSize.height) * 0.5
        frame.size = viewModel.contentSize
        danmakuView.frame = frame

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        animation.toValue = NSValue(caTransform3D: CATransform3DMakeTranslation(-viewModel.points, 0, 0))
        animation.duration = viewModel.duration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        danmakuView.layer.add(animation, forKey: "anim")
        // CALayer 扩展 addAnimation:stopHandler: 由其它块提供。
        danmakuView.layer.addAnimation(animation, stopHandler: { [weak self, weak danmakuView] _, _ in
            guard let self = self else { return }
            danmakuView?.removeFromSuperview()
            self.pool.addView(danmakuView)
            completion()
        })
    }
}

// MARK: - SJDanmakuLayoutContainerView

@MainActor
private protocol SJDanmakuLayoutContainerViewDelegate: AnyObject {
    func layoutContainerView(_ view: SJDanmakuLayoutContainerView, boundsDidChange bounds: CGRect, previousBounds: CGRect)
}

@MainActor
private final class SJDanmakuLayoutContainerView: UIView {
    weak var delegate: SJDanmakuLayoutContainerViewDelegate?
    private var previousBounds: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        if !bounds.equalTo(previousBounds) {
            delegate?.layoutContainerView(self, boundsDidChange: bounds, previousBounds: previousBounds)
        }
        previousBounds = bounds
    }
}

// MARK: - SJDanmakuPopupControllerObserver

///
/// 弹幕控制观察者。遵循 `SJDanmakuPopupControllerObserver` 协议(接口块)。
/// 通过 NSNotificationCenter 接收 controller 派发的状态变更。
///
@MainActor
public final class SJDanmakuPopupControllerObserver: NSObject, SJDanmakuPopupControllerObserver_Protocol {
    public var onDisabledChanged: ((SJDanmakuPopupController) -> Void)?
    public var onPausedChanged: ((SJDanmakuPopupController) -> Void)?
    public var willDisplayItem: ((SJDanmakuPopupController, SJDanmakuItem) -> Void)?
    public var didEndDisplayingItem: ((SJDanmakuPopupController, SJDanmakuItem) -> Void)?

    init(controller: SJDanmakuPopupController) {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(_onPausedChanged(_:)), name: SJDanmakuPopupControllerOnPausedChangedNotification, object: controller)
        nc.addObserver(self, selector: #selector(_disabledDidChange(_:)), name: SJDanmakuPopupControllerOnDisabledChangedNotification, object: controller)
        nc.addObserver(self, selector: #selector(_willDisplayItem(_:)), name: SJDanmakuPopupControllerWillDisplayItemNotification, object: controller)
        nc.addObserver(self, selector: #selector(_didEndDisplayingItem(_:)), name: SJDanmakuPopupControllerDidEndDisplayingItemNotification, object: controller)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func _onPausedChanged(_ note: Notification) {
        if let controller = note.object as? SJDanmakuPopupController {
            onPausedChanged?(controller)
        }
    }
    @objc private func _disabledDidChange(_ note: Notification) {
        if let controller = note.object as? SJDanmakuPopupController {
            onDisabledChanged?(controller)
        }
    }
    @objc private func _willDisplayItem(_ note: Notification) {
        if let controller = note.object as? SJDanmakuPopupController,
           let item = note.userInfo?[SJDanmakuItemUserInfoKey] as? SJDanmakuItem {
            willDisplayItem?(controller, item)
        }
    }
    @objc private func _didEndDisplayingItem(_ note: Notification) {
        if let controller = note.object as? SJDanmakuPopupController,
           let item = note.userInfo?[SJDanmakuItemUserInfoKey] as? SJDanmakuItem {
            didEndDisplayingItem?(controller, item)
        }
    }
}

// MARK: - SJDanmakuPopupController

///
/// 弹幕弹层控制器。遵循 `SJDanmakuPopupController` 协议(接口块)。
///
@MainActor
public final class SJDanmakuPopupController: NSObject, SJDanmakuPopupController_Protocol {

    private let reusablePool: SJDanmakuViewReusablePool
    private var tracks: [SJDanmakuTrack]
    private let queue: SJQueue
    private let clock: SJDanmakuClock
    private let _view: SJDanmakuLayoutContainerView

    /// 轨道配置
    public let trackConfiguration: SJDanmakuTrackConfiguration

    private static let screenMaxWidth: CGFloat = {
        max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    }()

    // MARK: 协议属性

    private var _numberOfTracks: Int = 0
    public var numberOfTracks: Int {
        get { _numberOfTracks }
        set {
            if newValue != _numberOfTracks {
                _numberOfTracks = newValue

                // 移除多余的行
                if newValue < tracks.count {
                    let useless = tracks[newValue..<tracks.count]
                    for obj in useless {
                        obj.view.removeFromSuperview()
                    }
                    tracks.removeSubrange(newValue..<tracks.count)
                }
                // 创建新增的行
                else if newValue > tracks.count {
                    for _ in tracks.count..<newValue {
                        let track = SJDanmakuTrack(pool: reusablePool)
                        _view.addSubview(track.view)
                        tracks.append(track)
                    }
                }

                reloadTrackConfiguration()
            }
        }
    }

    private var _disabled: Bool = false
    @objc(isDisabled) public var disabled: Bool {
        get { _disabled }
        set {
            if newValue != _disabled {
                _disabled = newValue
                if newValue { removeAll() }
                postNotification(SJDanmakuPopupControllerOnDisabledChangedNotification)
            }
        }
    }

    private var _paused: Bool = false
    @objc(isPaused) public var paused: Bool {
        get { _paused }
        set {
            if newValue != _paused {
                _paused = newValue
                postNotification(SJDanmakuPopupControllerOnPausedChangedNotification)
            }
        }
    }

    public var view: UIView { _view }

    /// 未显示的弹幕数量
    public var queueSize: Int { queue.size }

    // MARK: 初始化

    public init(numberOfTracks: UInt) {
        reusablePool = SJDanmakuViewReusablePool.pool()
        queue = SJQueue.queue()
        clock = SJDanmakuClock()
        let containerView = SJDanmakuLayoutContainerView(frame: .zero)
        _view = containerView
        tracks = []
        tracks.reserveCapacity(4)
        trackConfiguration = SJDanmakuTrackConfiguration()
        super.init()
        clock.delegate = self
        containerView.delegate = self
        self.numberOfTracks = Int(numberOfTracks)
    }

    // MARK: 协议方法

    /// 当配置修改后, 请调用该方法来刷新
    public func reloadTrackConfiguration() {
        let last = tracks.last
        var pret: SJDanmakuTrack?
        for (idx, track) in tracks.enumerated() {
            let topMargin = trackConfiguration.topMargin(forTrackAtIndex: idx)
            let height = trackConfiguration.height(forTrackAtIndex: idx)
            track.view.snp.remakeConstraints { make in
                if let pret = pret {
                    make.top.equalTo(pret.view.snp.bottom).offset(topMargin)
                } else {
                    make.top.equalToSuperview().offset(topMargin)
                }
                make.left.right.equalToSuperview()
                make.height.equalTo(height)
                if track === last {
                    make.bottom.equalToSuperview()
                }
            }
            pret = track
        }
    }

    public func enqueue(_ item: SJDanmakuItem) {
        if _disabled { return }
        queue.enqueue(item)
        if _paused == false { clock.resume() }
    }

    public func emptyQueue() {
        queue.empty()
    }

    public func removeDisplayedItems() {
        for track in tracks { track.clear() }
    }

    public func removeAll() {
        emptyQueue()
        removeDisplayedItems()
        pauseClockIfNeeded()
    }

    public func pause() {
        if _disabled { return }
        clock.pause()
        paused = true
    }

    public func resume() {
        if _disabled { return }
        clock.resume()
        paused = false
    }

    public func getObserver() -> SJDanmakuPopupControllerObserver {
        SJDanmakuPopupControllerObserver(controller: self)
    }

    // MARK: 私有

    private func pointDuration(forLineAtIndex index: Int) -> TimeInterval {
        TimeInterval(POINT_SPEED_FAST / trackConfiguration.rate(forTrackAtIndex: index))
    }

    private func allTransitionPoints(danmakuPoints: CGFloat) -> CGFloat {
        danmakuPoints + Self.screenMaxWidth
    }

    private func pauseClockIfNeeded() {
        if queue.size == 0 {
            for line in tracks where line.last != nil {
                return
            }
            clock.pause()
        }
    }

    private func postNotification(_ name: Notification.Name) {
        postNotification(name, userInfo: nil)
    }

    private func postNotification(_ name: Notification.Name, userInfo: [AnyHashable: Any]?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
        }
    }
}

// MARK: - SJDanmakuLayoutContainerViewDelegate / SJDanmakuClockDelegate

extension SJDanmakuPopupController: SJDanmakuLayoutContainerViewDelegate, SJDanmakuClockDelegate {
    fileprivate func clock(_ clock: SJDanmakuClock, onTimeUpdated time: TimeInterval) {
        if view.bounds.isEmpty { return }

        for index in 0..<_numberOfTracks {
            let line = tracks[index]
            let last = line.last
            let threshold = (last?.nextItemStartTime ?? 0) + (last?.delay ?? 0)
            if time >= threshold {
                if let item = queue.dequeue() as? SJDanmakuItem {
                    postNotification(SJDanmakuPopupControllerWillDisplayItemNotification, userInfo: [SJDanmakuItemUserInfoKey: item])
                    let viewModel = SJDanmakuViewModel(item: item)
                    let itemSpacing = trackConfiguration.itemSpacing(forTrackAtIndex: index)
                    let danmakuPoints = viewModel.contentSize.width
                    let pointDuration = self.pointDuration(forLineAtIndex: index)
                    let allPoints = allTransitionPoints(danmakuPoints: danmakuPoints)

                    viewModel.duration = TimeInterval(allPoints) * pointDuration
                    viewModel.nextItemStartTime = time + TimeInterval(danmakuPoints + itemSpacing) * pointDuration
                    viewModel.points = allPoints

                    line.fire(viewModel) { [weak self] in
                        guard let self = self else { return }
                        self.postNotification(SJDanmakuPopupControllerDidEndDisplayingItemNotification, userInfo: [SJDanmakuItemUserInfoKey: item])
                        self.pauseClockIfNeeded()
                    }
                }
            }
        }
    }

    fileprivate func clock(_ clock: SJDanmakuClock, onPausedChanged isPaused: Bool) {
        for track in tracks {
            if isPaused { track.pause() } else { track.resume() }
        }
    }

    fileprivate func layoutContainerView(_ view: SJDanmakuLayoutContainerView, boundsDidChange bounds: CGRect, previousBounds: CGRect) {
        if previousBounds.size.width > bounds.size.width {
            let points = previousBounds.size.width - bounds.size.width
            for i in 0..<_numberOfTracks {
                tracks[i].last?.delay += TimeInterval(points) * pointDuration(forLineAtIndex: i)
            }
        }
    }
}

// MARK: - SJDanmakuTrackConfiguration

///
/// 弹幕轨道配置。
///
@MainActor
public final class SJDanmakuTrackConfiguration: NSObject {

    public weak var delegate: (any SJDanmakuTrackConfigurationDelegate)? {
        didSet {
            isResponse_rateForTrackAtIndex = delegate?.responds(to: #selector(SJDanmakuTrackConfigurationDelegate.trackConfiguration(_:rateForTrackAtIndex:))) ?? false
            isResponse_topMarginForTrackAtIndex = delegate?.responds(to: #selector(SJDanmakuTrackConfigurationDelegate.trackConfiguration(_:topMarginForTrackAtIndex:))) ?? false
            isResponse_itemSpacingForTrackAtIndex = delegate?.responds(to: #selector(SJDanmakuTrackConfigurationDelegate.trackConfiguration(_:itemSpacingForTrackAtIndex:))) ?? false
            isResponse_heightForTrackAtIndex = delegate?.responds(to: #selector(SJDanmakuTrackConfigurationDelegate.trackConfiguration(_:heightForTrackAtIndex:))) ?? false
        }
    }

    /// 弹幕移动速率 (default value 1.0)
    public var rate: CGFloat = 1
    /// 弹幕之间的间距 (default value is 38.0)
    public var itemSpacing: CGFloat = 38.0
    /// 顶部外间距 (default value is 3.0)
    public var topMargin: CGFloat = 3.0
    /// 行高 (default value is 26.0)
    public var height: CGFloat = 26.0

    private var isResponse_rateForTrackAtIndex = false
    private var isResponse_topMarginForTrackAtIndex = false
    private var isResponse_itemSpacingForTrackAtIndex = false
    private var isResponse_heightForTrackAtIndex = false

    public override init() {
        super.init()
    }

    func rate(forTrackAtIndex index: Int) -> CGFloat {
        let r = isResponse_rateForTrackAtIndex ? (delegate?.trackConfiguration?(self, rateForTrackAtIndex: index) ?? rate) : rate
        return r != 0 ? r : CGFloat.leastNormalMagnitude
    }
    func topMargin(forTrackAtIndex index: Int) -> CGFloat {
        isResponse_topMarginForTrackAtIndex ? (delegate?.trackConfiguration?(self, topMarginForTrackAtIndex: index) ?? topMargin) : topMargin
    }
    func itemSpacing(forTrackAtIndex index: Int) -> CGFloat {
        isResponse_itemSpacingForTrackAtIndex ? (delegate?.trackConfiguration?(self, itemSpacingForTrackAtIndex: index) ?? itemSpacing) : itemSpacing
    }
    func height(forTrackAtIndex index: Int) -> CGFloat {
        isResponse_heightForTrackAtIndex ? (delegate?.trackConfiguration?(self, heightForTrackAtIndex: index) ?? height) : height
    }
}

// MARK: - SJDanmakuTrackConfigurationDelegate

///
/// 弹幕轨道配置代理。原 ObjC 全为 @optional 方法, 这里以 @objc optional 表达。
///
@MainActor
@objc public protocol SJDanmakuTrackConfigurationDelegate: NSObjectProtocol {
    /// 移动速率
    @objc optional func trackConfiguration(_ trackConfiguration: SJDanmakuTrackConfiguration, rateForTrackAtIndex index: Int) -> CGFloat
    /// 弹幕之间的间距
    @objc optional func trackConfiguration(_ trackConfiguration: SJDanmakuTrackConfiguration, itemSpacingForTrackAtIndex index: Int) -> CGFloat
    /// 顶部外间距
    @objc optional func trackConfiguration(_ trackConfiguration: SJDanmakuTrackConfiguration, topMarginForTrackAtIndex index: Int) -> CGFloat
    /// 行高
    @objc optional func trackConfiguration(_ trackConfiguration: SJDanmakuTrackConfiguration, heightForTrackAtIndex index: Int) -> CGFloat
}

