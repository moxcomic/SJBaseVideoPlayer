//
//  SJWatermarkView.swift
//  Pods
//
//  Created by BlueDancer on 2020/6/13.
//  Swift 6.3 迁移: 保留原 ObjC 类/枚举/选择器名.
//

import UIKit
@preconcurrency import AVFoundation

/// 水印布局位置 (与 ObjC 版枚举值严格一致)
@objc(SJWatermarkLayoutPosition)
public enum SJWatermarkLayoutPosition: UInt {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

@MainActor
@objc(SJWatermarkView)
public final class SJWatermarkView: UIImageView, SJWatermarkView_Protocol {

    /// default value is SJWatermarkLayoutPositionTopRight.
    /// 注: ObjC 实现 _setup 实际默认设置为 BottomLeft, 此处保持与实现一致.
    @objc public var layoutPosition: SJWatermarkLayoutPosition = .bottomLeft
    /// default value is (20, 20, 20, 20).
    @objc public var layoutInsets: UIEdgeInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    /// default value is 0. If `0`, the height of the watermark image will be used for layout.
    @objc public var layoutHeight: CGFloat = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        _setup()
    }

    public override init(image: UIImage?) {
        super.init(image: image)
        _setup()
    }

    public override init(image: UIImage?, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        _setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func _setup() {
        layoutPosition = .bottomLeft
        layoutInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }

    @objc public func layoutWatermark(in rect: CGRect, videoPresentationSize vSize: CGSize, videoGravity: SJVideoGravity) {
        let imageSize = self.image?.size ?? .zero
        isHidden = vSize.equalTo(.zero) ||
                   rect.size.equalTo(.zero) ||
                   imageSize.equalTo(.zero)
        if isHidden { return }

        var videoDisplayedSize: CGSize = .zero
        if videoGravity == .resizeAspect {
            // 等比例模式
            // 16/9 的会将宽度进行等比缩放, 以显示全部高度
            // 9/16 的会将高度进行等比缩放, 以显示全部宽度
            videoDisplayedSize = vSize.width > vSize.height ?
                CGSize(width: rect.size.width, height: vSize.height * rect.size.width / vSize.width) :
                CGSize(width: vSize.width * rect.size.height / vSize.height, height: rect.size.height)
        } else if videoGravity == .resizeAspectFill {
            // 填充模式
            // 16/9 的会将宽度进行等比拉伸, 以显示全部高度
            // 9/16 的会将高度进行等比拉伸, 以显示全部宽度
            videoDisplayedSize = vSize.width > vSize.height ?
                CGSize(width: vSize.width * rect.size.height / vSize.height, height: rect.size.height) :
                CGSize(width: rect.size.width, height: vSize.height * rect.size.width / vSize.width)
        }
        // 注: ObjC 原文存在重复的 resizeAspect 分支, 永远不会命中, 此处忠实保留语义(已被上面分支覆盖).

        isHidden = videoDisplayedSize.equalTo(.zero)
        if isHidden { return }

        // frame 计算
        let height: CGFloat = (layoutHeight != 0) ? layoutHeight : imageSize.height
        let width: CGFloat = imageSize.width * height / imageSize.height
        let size = CGSize(width: width, height: height)
        var frame = CGRect(origin: .zero, size: size)

        switch layoutPosition {
        case .topLeft, .bottomLeft:
            frame.origin.x = layoutInsets.left
        case .topRight, .bottomRight:
            frame.origin.x = videoDisplayedSize.width - width - layoutInsets.right
        }

        switch layoutPosition {
        case .topLeft, .topRight:
            frame.origin.y = layoutInsets.top
        case .bottomLeft, .bottomRight:
            frame.origin.y = videoDisplayedSize.height - height - layoutInsets.bottom
        }

        // convert
        frame.origin.x -= (videoDisplayedSize.width - rect.size.width) * 0.5
        frame.origin.y -= (videoDisplayedSize.height - rect.size.height) * 0.5
        self.frame = frame
    }
}

