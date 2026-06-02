//
//  SJAVMediaPlayerLayerView.swift
//  Pods
//
//  Created by 畅三江 on 2020/2/19.
//
//  Swift 6.3 迁移: 由 SJAVMediaPlayerLayerView.{h,m} 转写.
//  - layerClass 替换为 AVPlayerLayer, 强类型化 layer.
//  - readyForDisplay KVO 改用 Swift 原生 observe, 回主线程发送通知.
//

@preconcurrency import AVFoundation
import UIKit

@MainActor
@objc(SJAVMediaPlayerLayerView)
public final class SJAVMediaPlayerLayerView: UIView, SJMediaPlayerView {

    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    // 强类型 layer
    @objc public var avPlayerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        return layer as! AVPlayerLayer
    }

    private let screenshotLayer = CALayer()
    private var readyForDisplayObservation: NSKeyValueObservation?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        readyForDisplayObservation = avPlayerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self = self else { return }
                NotificationCenter.default.post(name: SJMediaPlayerViewReadyForDisplayNotification, object: self)
            }
        }
        avPlayerLayer.addSublayer(screenshotLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc public var isReadyForDisplay: Bool {
        return avPlayerLayer.isReadyForDisplay
    }

    @objc public var videoGravity: SJVideoGravity {
        get { avPlayerLayer.videoGravity }
        set {
            avPlayerLayer.videoGravity = newValue
            if newValue == .resize {
                screenshotLayer.contentsGravity = .resize
            } else if newValue == .resizeAspect {
                screenshotLayer.contentsGravity = .resizeAspect
            } else if newValue == .resizeAspectFill {
                screenshotLayer.contentsGravity = .resizeAspectFill
            }
        }
    }

    @objc public func setScreenshot(_ image: UIImage?) {
        screenshotLayer.contents = image?.cgImage
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        screenshotLayer.frame = bounds
    }
}

