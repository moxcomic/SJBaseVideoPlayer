//
//  SJVideoPlayerPresentView.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2017/11/29.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//  Swift 6.3 重写 (SJBaseVideoPlayer)
//

import UIKit
#if canImport(SJUIKit)
import SJUIKit
#endif

@objc(SJVideoPlayerPresentViewDelegate)
@MainActor public protocol SJVideoPlayerPresentViewDelegate: NSObjectProtocol {
    @objc optional func presentViewDidLayoutSubviews(_ presentView: SJVideoPlayerPresentView)
    @objc optional func presentViewDidMove(toWindow presentView: SJVideoPlayerPresentView)
}

@objc(SJVideoPlayerPresentView)
@MainActor
open class SJVideoPlayerPresentView: UIView, SJVideoPlayerPresentView_Protocol, SJGestureController, UIGestureRecognizerDelegate {
    @objc public weak var delegate: SJVideoPlayerPresentViewDelegate?

    // MARK: SJGestureController
    public var _supportedGestureTypes: SJPlayerGestureTypeMask = .default

    @objc public var supportedGestureTypes: UInt {
        get { _supportedGestureTypes.rawValue }
        set { _supportedGestureTypes = SJPlayerGestureTypeMask(rawValue: newValue) }
    }
    @objc public var gestureRecognizerShouldTrigger: ((any SJGestureController, SJPlayerGestureType, CGPoint) -> Bool)?
    @objc public var singleTapHandler: ((any SJGestureController, CGPoint) -> Void)?
    @objc public var doubleTapHandler: ((any SJGestureController, CGPoint) -> Void)?
    @objc public var panHandler: ((any SJGestureController, SJPanGestureTriggeredPosition, SJPanGestureMovingDirection, SJPanGestureRecognizerState, CGPoint) -> Void)?
    @objc public var pinchHandler: ((any SJGestureController, CGFloat) -> Void)?
    @objc public var longPressHandler: ((any SJGestureController, SJLongPressGestureRecognizerState) -> Void)?
    @objc public private(set) var movingDirection: SJPanGestureMovingDirection = .H
    @objc public private(set) var triggeredPosition: SJPanGestureTriggeredPosition = .left

    // MARK: 私有手势
    private var pan: UIPanGestureRecognizer!
    private var pinch: UIPinchGestureRecognizer!
    private var longPress: UILongPressGestureRecognizer!

    private var timer: Timer? ///< 单击与双击手势识别 timer
    private var numberOfTaps: Int = 0

    // MARK: 占位图
    private var _placeholderImageView: UIImageView?
    @objc public var placeholderImageView: UIImageView {
        if let v = _placeholderImageView { return v }
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        _placeholderImageView = v
        return v
    }

    @objc(isPlaceholderImageViewHidden) public var placeholderImageViewHidden: Bool {
        return _placeholderImageView?.isHidden ?? true
    }

    @objc public var placeholderImageViewContentMode: UIView.ContentMode {
        get { placeholderImageView.contentMode }
        set { placeholderImageView.contentMode = newValue }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        _setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 手势处理

    private func handleSingleTap(_ tap: UITouch) {
        guard _isGestureSupported(.singleTap) else { return }
        let location = tap.location(in: self)
        if let should = gestureRecognizerShouldTrigger, should(self, .singleTap, location) {
            singleTapHandler?(self, location)
        }
    }

    private func handleDoubleTap(_ tap: UITouch) {
        guard _isGestureSupported(.doubleTap) else { return }
        let location = tap.location(in: self)
        if let should = gestureRecognizerShouldTrigger, should(self, .doubleTap, location) {
            doubleTapHandler?(self, location)
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translate = pan.translation(in: pan.view)
        switch pan.state {
        case .began:
            panHandler?(self, triggeredPosition, movingDirection, .began, translate)
        case .changed:
            panHandler?(self, triggeredPosition, movingDirection, .changed, translate)
        case .failed, .cancelled, .ended:
            panHandler?(self, triggeredPosition, movingDirection, .ended, translate)
        default:
            break
        }
        pan.setTranslation(.zero, in: pan.view)
    }

    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .ended:
            pinchHandler?(self, pinch.scale)
        default:
            break
        }
    }

    @objc private func handleLongPress(_ longPress: UILongPressGestureRecognizer) {
        switch longPress.state {
        case .began:
            longPressHandler?(self, .began)
        case .changed:
            longPressHandler?(self, .changed)
        case .ended, .cancelled, .failed:
            longPressHandler?(self, .ended)
        default:
            break
        }
    }

    @objc public func cancelGesture(_ type: SJPlayerGestureType) {
        var gesture: UIGestureRecognizer?
        switch type {
        case .pan: gesture = pan
        case .pinch: gesture = pinch
        case .longPress: gesture = longPress
        default: break
        }
        gesture?.state = .cancelled
    }

    @objc public func stateOfGesture(_ type: SJPlayerGestureType) -> UIGestureRecognizer.State {
        var gesture: UIGestureRecognizer?
        switch type {
        case .pan: gesture = pan
        case .pinch: gesture = pinch
        default: break
        }
        return gesture?.state ?? .possible
    }

    // MARK: - 占位图显隐

    @objc public func setPlaceholderImageViewHidden(_ isHidden: Bool, animated: Bool) {
        if isHidden {
            _hidePlaceholderImageView(animated: animated, delay: 0)
        } else {
            _showPlaceholderImageView(animated: animated)
        }
    }

    @objc public func hidePlaceholderImageView(animated: Bool, delay secs: TimeInterval) {
        _hidePlaceholderImageView(animated: animated, delay: secs)
    }

    private func _showPlaceholderImageView(animated: Bool) {
        guard let placeholder = _placeholderImageView, placeholder.isHidden else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        placeholder.alpha = 0.001
        placeholder.isHidden = false
        if animated {
            UIView.animate(withDuration: 0.4) {
                placeholder.alpha = 1
            }
        } else {
            placeholder.alpha = 1
        }
    }

    private func _hidePlaceholderImageView(animated: Bool, delay secs: TimeInterval) {
        guard let placeholder = _placeholderImageView, placeholder.isHidden == false else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if secs == 0 {
            _hidePlaceholderImageViewAnimated(NSNumber(value: animated))
        } else {
            perform(#selector(_hidePlaceholderImageViewAnimated(_:)), with: NSNumber(value: animated), afterDelay: secs, inModes: [.common])
        }
    }

    @objc private func _hidePlaceholderImageViewAnimated(_ animated: NSNumber) {
        guard let placeholder = _placeholderImageView else { return }
        if animated.boolValue {
            UIView.animate(withDuration: 0.4) {
                placeholder.alpha = 0.001
            } completion: { _ in
                placeholder.isHidden = true
            }
        } else {
            placeholder.alpha = 0.001
            placeholder.isHidden = true
        }
    }

    // MARK: - 布局 / window

    open override func layoutSubviews() {
        super.layoutSubviews()
        delegate?.presentViewDidLayoutSubviews?(self)
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()
        delegate?.presentViewDidMove?(toWindow: self)
    }

    // MARK: - 初始化视图

    private func _setupViews() {
        _supportedGestureTypes = .default
        backgroundColor = .black
        let placeholder = placeholderImageView
        placeholder.frame = bounds
        placeholder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholder.isHidden = true
        addSubview(placeholder)

        // Pan
        pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        pan.delaysTouchesBegan = true

        // Pinch
        pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self

        // LongPress
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.delaysTouchesBegan = true
        longPress.delegate = self
        // 与原 ObjC 等价: 调用返回值无影响, 保留原行为
        _ = pan.shouldRequireFailure(of: longPress)

        addGestureRecognizer(pan)
        addGestureRecognizer(pinch)
        addGestureRecognizer(longPress)
    }

    // MARK: - UIGestureRecognizerDelegate

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var type: SJPlayerGestureType = .pan
        if gestureRecognizer === pinch {
            type = .pinch
        } else if gestureRecognizer === longPress {
            type = .longPress
        }

        switch type {
        case .pan:
            if !_isGestureSupported(.pan) { return false }

            let location = pan.location(in: self)
            if location.x > bounds.size.width * 0.5 {
                triggeredPosition = .right
            } else {
                triggeredPosition = .left
            }

            let velocity = pan.velocity(in: pan.view)
            let x = abs(velocity.x)
            let y = abs(velocity.y)
            if x > y {
                movingDirection = .H
            } else {
                movingDirection = .V
            }

            if movingDirection == .H && !_isGestureSupported(.pan_H) { return false }
            if movingDirection == .V && !_isGestureSupported(.pan_V) { return false }
            if longPress.state == .changed { return false }
        case .pinch:
            if !_isGestureSupported(.pinch) { return false }
        case .longPress:
            if !_isGestureSupported(.longPress) { return false }
        default:
            break
        }

        if let should = gestureRecognizerShouldTrigger, !should(self, type, gestureRecognizer.location(in: self)) {
            return false
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.state == .failed || gestureRecognizer.state == .cancelled {
            return false
        }
        if otherGestureRecognizer !== pan && otherGestureRecognizer !== pinch {
            return false
        }
        if gestureRecognizer.numberOfTouches >= 2 {
            return false
        }
        return true
    }

    /// 每个子视图需要重写该方法, 判断是否消费该事件
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var prev: UIView?
        var retv: UIView?
        for subview in subviews {
            let target = subview.hitTest(convert(point, to: subview), with: event)
            if target != nil {
                if retv == nil || subview.layer.zPosition > (prev?.layer.zPosition ?? 0) {
                    retv = target
                    prev = subview
                }
            }
        }
        return retv
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (event?.allTouches?.count ?? 0) != 1 {
            _reset()
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 由于 pan 手势的存在, 拖动事件将会被 pan 手势拦截, 因此此处可以放心处理点击事件

        // 只识别单指操作, 此处取消识别, return
        if (event?.allTouches?.count ?? 0) != 1 {
            _reset()
            return
        }

        // 增加点击数
        numberOfTaps += 1

        // 开启 timer, 用于间隔到达之后, 识别单击手势
        if timer == nil {
            let t = Timer.sj_timer(withTimeInterval: 0.2, repeats: true)
            t.sj_fire()
            RunLoop.current.add(t, forMode: .common)
            timer = t
        }

        // 间隔到达之后, 识别为单击手势, 执行单击处理
        let anyTouch = touches.first
        timer?.sj_usingBlock = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self._reset()
                if let anyTouch = anyTouch {
                    self.handleSingleTap(anyTouch)
                }
            }
        }

        // 计数为 2 时, 识别为双击手势, 执行双击处理
        if numberOfTaps >= 2 {
            _reset()
            timer?.invalidate()
            if let anyTouch = anyTouch {
                handleDoubleTap(anyTouch)
            }
        }
    }

    private func _reset() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        numberOfTaps = 0
    }

    private func _isGestureSupported(_ type: SJPlayerGestureTypeMask) -> Bool {
        return _supportedGestureTypes.contains(type)
    }
}

