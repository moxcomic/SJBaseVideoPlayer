//
//  SJBaseVideoPlayer+AudioSession.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (AudioSession)。
//

import UIKit
@preconcurrency import AVFoundation

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 每次执行play的时候是否设置 AVAudioSession
    ///
    ///         default value is YES
    ///
    @objc(isAudioSessionControlEnabled) public var audioSessionControlEnabled: Bool {
        get { controlInfo.audioSessionControl.isEnabled }
        set { controlInfo.audioSessionControl.isEnabled = newValue }
    }

    @objc(setCategory:withOptions:) public func setCategory(_ category: AVAudioSession.Category, withOptions options: AVAudioSession.CategoryOptions) {
        _mCategory = category
        _mCategoryOptions = options
        do {
            try AVAudioSession.sharedInstance().setCategory(_mCategory, options: _mCategoryOptions)
        } catch {
            #if DEBUG
            print("\(error)")
            #endif
        }
    }

    @objc(setActiveOptions:) public func setActiveOptions(_ options: AVAudioSession.SetActiveOptions) {
        _mSetActiveOptions = options
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: _mSetActiveOptions)
        } catch {
            #if DEBUG
            print("\(error)")
            #endif
        }
    }
}

