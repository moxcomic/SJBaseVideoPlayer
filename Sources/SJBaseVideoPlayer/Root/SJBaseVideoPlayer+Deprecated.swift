//
//  SJBaseVideoPlayer+Deprecated.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Deprecated)。已弃用接口, 仅作兼容保留。
//

import UIKit

// MARK: - 已弃用 (Deprecated)

@MainActor
extension SJBaseVideoPlayer {

    /// 不再建议使用, 请使用 `URLAsset` 进行初始化。
    /// 原: - (void)playWithURL:(NSURL *)URL { self.assetURL = URL; }
    @objc public func playWithURL(_ URL: URL) {
        assetURL = URL
    }

    /// 原: @property (nonatomic, strong, nullable) NSURL *assetURL;
    /// getter: return self.URLAsset.mediaURL;
    /// setter: self.URLAsset = [[SJVideoPlayerURLAsset alloc] initWithURL:assetURL];
    @objc public var assetURL: URL? {
        get { urlAsset?.mediaURL }
        set {
            // 与原 ObjC 严格等价: 原 `[[SJVideoPlayerURLAsset alloc] initWithURL:]` 在 URL 为 nil 时
            // 仍会赋一个对象给 URLAsset 并触发后续流程; fork 的 init?(url:) 仅在 url==nil 时返回 nil
            // (对非 nil url 必不返回 nil)。故此处按结果对齐:
            //   - 有 URL: 构造 asset(必非 nil), 触发正常 prepareToPlay;
            //   - 无 URL: 直接置 nil(等价清空, 触发 stop)。
            if let newValue = newValue {
                urlAsset = SJVideoPlayerURLAsset(url: newValue)
            } else {
                urlAsset = nil
            }
        }
    }

    /// 是否已播放结束(当前资源是否已播放结束)。
    /// 原: @property (nonatomic, readonly) BOOL isPlayedToEndTime __deprecated_msg("use `isPlaybackFinished`;");
    /// 原实现: return self.isPlaybackFinished && self.finishedReason == SJFinishedReasonToEndTimePosition;
    @available(*, deprecated, message: "use `isPlaybackFinished`;")
    @objc public var isPlayedToEndTime: Bool {
        return isPlaybackFinished && finishedReason == SJFinishedReasonToEndTimePosition
    }
}

