//
//  SJBaseVideoPlayer+TestLog.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/9/11.
//
//  Swift 6.3 迁移版本. 仅在 SJDEBUG 编译条件下生效, 与 ObjC 版一致.
//

#if SJDEBUG
import Foundation

@MainActor
extension SJBaseVideoPlayer {
    @objc public func showLog_TimeControlStatus() {
        let status = self.timeControlStatus
        var statusStr: String
        switch status {
        case .paused:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.TimeControlStatus.Paused\n", self)
        case .waitingToPlay:
            let reasonStr: String
            if self.reasonForWaitingToPlay == SJWaitingToMinimizeStallsReason {
                reasonStr = "WaitingToMinimizeStallsReason"
            } else if self.reasonForWaitingToPlay == SJWaitingWhileEvaluatingBufferingRateReason {
                reasonStr = "WaitingWhileEvaluatingBufferingRateReason"
            } else if self.reasonForWaitingToPlay == SJWaitingWithNoAssetToPlayReason {
                reasonStr = "WaitingWithNoAssetToPlayReason"
            } else {
                reasonStr = "(null)"
            }
            statusStr = String(format: "SJBaseVideoPlayer<%p>.TimeControlStatus.WaitingToPlay(Reason: %@)\n", self, reasonStr)
        case .playing:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.TimeControlStatus.Playing\n", self)
        @unknown default:
            statusStr = ""
        }
        print(statusStr, terminator: "")
    }

    @objc public func showLog_AssetStatus() {
        let status = self.assetStatus
        var statusStr: String
        switch status {
        case .unknown:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.assetStatus.Unknown\n", self)
        case .preparing:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.assetStatus.Preparing\n", self)
        case .readyToPlay:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.assetStatus.ReadyToPlay\n", self)
        case .failed:
            statusStr = String(format: "SJBaseVideoPlayer<%p>.assetStatus.Failed\n", self)
        @unknown default:
            statusStr = ""
        }
        print(statusStr, terminator: "")
    }
}
#endif

