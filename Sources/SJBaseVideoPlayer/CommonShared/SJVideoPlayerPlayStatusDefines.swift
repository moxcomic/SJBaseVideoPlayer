//
//  SJVideoPlayerPlayStatusDefines.swift
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2017/11/29.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  Swift 6.3 转换: 保留原 ObjC 枚举/常量名与原始值, 全部 @objc 暴露给上层 ObjC 调用方.
//

import Foundation

/// 播放类型
@objc(SJPlaybackType)
public enum SJPlaybackType: Int, Sendable {
    case unknown = 0   // SJPlaybackTypeUnknown
    case LIVE          // SJPlaybackTypeLIVE
    case VOD           // SJPlaybackTypeVOD
    case FILE          // SJPlaybackTypeFILE
}

/// 资源(asset)准备状态
@objc(SJAssetStatus)
public enum SJAssetStatus: Int, Sendable {
    ///
    /// 未知状态
    ///
    case unknown = 0   // SJAssetStatusUnknown

    ///
    /// 准备中
    ///
    case preparing     // SJAssetStatusPreparing

    ///
    /// 当前资源可随时进行播放(播放控制请查看`timeControlStatus`)
    ///
    case readyToPlay   // SJAssetStatusReadyToPlay

    ///
    /// 发生错误
    ///
    case failed        // SJAssetStatusFailed
}

/// 播放控制状态
@objc(SJPlaybackTimeControlStatus)
public enum SJPlaybackTimeControlStatus: Int, Sendable {
    ///
    /// 暂停状态(已调用暂停或未执行任何操作的状态)
    ///
    case paused = 0        // SJPlaybackTimeControlStatusPaused

    ///
    /// 播放状态(已调用播放), 当前正在缓冲或正在评估能否播放. 可以通过`reasonForWaitingToPlay`来获取原因, UI层可以根据原因来控制loading视图的状态.
    ///
    case waitingToPlay     // SJPlaybackTimeControlStatusWaitingToPlay

    ///
    /// 播放状态(已调用播放), 当前播放器正在播放
    ///
    case playing           // SJPlaybackTimeControlStatusPlaying
}

// MARK: - SJWaitingReason

///
/// 等待播放的原因 (对应 ObjC `typedef NSString *SJWaitingReason`)
///
public typealias SJWaitingReason = String

///
/// 缓冲中, UI层建议显示loading视图
///
public let SJWaitingToMinimizeStallsReason: SJWaitingReason = "AVPlayerWaitingToMinimizeStallsReason"

///
/// 正在评估能否播放, 处于此状态时, 不建议UI层显示loading视图
///
public let SJWaitingWhileEvaluatingBufferingRateReason: SJWaitingReason = "AVPlayerWaitingWhileEvaluatingBufferingRateReason"

///
/// 未设置资源
///
public let SJWaitingWithNoAssetToPlayReason: SJWaitingReason = "AVPlayerWaitingWithNoItemToPlayReason"

// MARK: - SJFinishedReason

///
/// 播放完毕的原因 (对应 ObjC `typedef NSString *SJFinishedReason`)
///
public typealias SJFinishedReason = String

///
/// 正常播放完毕
///
public let SJFinishedReasonToEndTimePosition: SJFinishedReason = "SJFinishedReasonToEndTimePosition"

///
/// 播放到了试看结束的位置
///
public let SJFinishedReasonToTrialEndPosition: SJFinishedReason = "SJFinishedReasonToTrialEndPosition"

// MARK: - SJDefinitionSwitchStatus

///
/// 清晰度的切换状态
///
@objc(SJDefinitionSwitchStatus)
public enum SJDefinitionSwitchStatus: Int, Sendable {
    case unknown = 0   // SJDefinitionSwitchStatusUnknown
    case switching     // SJDefinitionSwitchStatusSwitching
    case finished      // SJDefinitionSwitchStatusFinished
    case failed        // SJDefinitionSwitchStatusFailed
}

