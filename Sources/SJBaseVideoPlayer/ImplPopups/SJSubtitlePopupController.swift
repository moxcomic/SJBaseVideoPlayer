//
//  SJSubtitlePopupController.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/8.
//
//  由 ObjC 版 SJSubtitlePopupController.h/.m 转换而来 (Swift 6.3)。
//  Masonry -> SnapKit。
//

import Foundation
import UIKit
import SnapKit

///
/// 字幕弹层控制器。
///
/// 遵循 `SJSubtitlePopupController` 协议(定义在接口块)。
/// 全部为 UIKit 视图操作, 标注 @MainActor。
///
@MainActor
public final class SJSubtitlePopupController: NSObject, SJSubtitlePopupController_Protocol {

    // MARK: 私有视图
    private let containerView: UIView = UIView(frame: .zero)
    private let subtitleLabel: UILabel = UILabel(frame: .zero)

    // MARK: 协议属性

    ///
    /// 设置未来将要显示的字幕。
    ///
    /// 协议中字幕元素类型为 `id<SJSubtitleItem>`; 这里使用具体类型 `SJSubtitleItem` 数组,
    /// 与 ObjC 头文件 (NSArray<SJSubtitleItem *> *) 一致。
    ///
    public var subtitles: [SJSubtitleItem]?

    /// 内容可显示几行 (default value is 0)
    public var numberOfLines: Int {
        get { subtitleLabel.numberOfLines }
        set { subtitleLabel.numberOfLines = newValue }
    }

    /// 内边距 (default value is zero)
    private var _contentInsets: UIEdgeInsets = .zero
    public var contentInsets: UIEdgeInsets {
        get { _contentInsets }
        set {
            _contentInsets = newValue
            subtitleLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(newValue.top)
                make.left.equalToSuperview().offset(newValue.left)
                make.bottom.equalToSuperview().offset(-newValue.bottom)
                make.right.equalToSuperview().offset(-newValue.right)
            }
        }
    }

    /// 控制器视图
    public var view: UIView { containerView }

    /// 当前播放时间 (由播放器维护)
    private var _currentTime: TimeInterval = 0
    public var currentTime: TimeInterval {
        get { _currentTime }
        set {
            _currentTime = newValue
            let item = self.item(at: newValue)
            let alpha: CGFloat = (item == nil) ? 0.001 : 1
            if alpha != containerView.alpha {
                UIView.animate(withDuration: 0.25) {
                    self.containerView.alpha = (item == nil) ? 0.001 : 1
                }
            }
            if let item = item, item.content != subtitleLabel.attributedText {
                subtitleLabel.attributedText = item.content
            }
        }
    }

    // MARK: 初始化

    public override init() {
        super.init()
        setupView()
    }

    // MARK: 私有

    private func item(at time: TimeInterval) -> SJSubtitleItem? {
        guard let subtitles = subtitles else { return nil }
        for item in subtitles {
            if SJTimeRangeContainsTime(time, item.range) {
                return item
            }
        }
        return nil
    }

    private func setupView() {
        subtitleLabel.numberOfLines = 0
        containerView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

