//
//  SJBaseVideoPlayer+Gesture.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Gesture)。手势控制相关操作。
//

import UIKit
import CoreGraphics

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 手势控制
    ///
    ///         如果想自己设置支持的手势类型, 可以
    ///         `player.gestureController.supportedGestureTypes = SJPlayerGestureTypeMask_SingleTap | 其他支持的手势;`
    ///         了解更多请前往头文件查看
    ///
    @objc public var gestureController: any SJGestureController {
        return _presentView
    }

    ///
    /// 是否可以触发某个手势
    ///
    ///         这个 block 的返回值将会作为触发手势的一个条件, 当 `return NO` 时, 相应的手势将不会触发
    ///
    @objc public var gestureRecognizerShouldTrigger: ((SJBaseVideoPlayer, SJPlayerGestureType, CGPoint) -> Bool)? {
        get { _gestureRecognizerShouldTrigger }
        set { _gestureRecognizerShouldTrigger = newValue }
    }

    ///
    /// 在 cell 中播放时, 是否允许水平方向触发 Pan 手势. default value is NO
    ///
    @objc public var allowHorizontalTriggeringOfPanGesturesInCells: Bool {
        get { controlInfo.gestureController.allowHorizontalTriggeringOfPanGesturesInCells }
        set { controlInfo.gestureController.allowHorizontalTriggeringOfPanGesturesInCells = newValue }
    }

    ///
    /// 长按手势触发时的播放速度. default value is 2.0
    ///
    @objc public var rateWhenLongPressGestureTriggered: CGFloat {
        get { controlInfo.gestureController.rateWhenLongPressGestureTriggered }
        set { controlInfo.gestureController.rateWhenLongPressGestureTriggered = newValue }
    }

    ///
    /// 调整水平 pan 手势移动时的速率. default value is 667.0
    ///
    @objc public var offsetFactorForHorizontalPanGesture: CGFloat {
        get { controlInfo.pan.factor }
        set {
            assert(newValue != 0, "The factor can't be set to 0!")
            controlInfo.pan.factor = newValue
        }
    }
}

