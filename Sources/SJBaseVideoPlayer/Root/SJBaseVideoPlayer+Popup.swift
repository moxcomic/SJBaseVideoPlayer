//
//  SJBaseVideoPlayer+Popup.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Popup)。弹出提示文本。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 中心弹出文本提示(null_resettable)
    ///
    @objc public var textPopupController: any SJTextPopupController_Protocol {
        get {
            if let controller = _textPopupController { return controller }
            let controller = SJTextPopupController()
            _textPopupController = controller
            _setupTextPopupController(controller)
            return controller
        }
        set {
            _textPopupController = newValue
            _setupTextPopupController(newValue)
        }
    }

    private func _setupTextPopupController(_ controller: any SJTextPopupController_Protocol) {
        controller.target = presentView
    }

    ///
    /// 左下角弹出提示(null_resettable)
    ///
    @objc public var promptingPopupController: any SJPromptingPopupController_Protocol {
        get {
            if let controller = _promptingPopupController { return controller }
            let controller = SJPromptingPopupController()
            _promptingPopupController = controller
            _setupPromptingPopupController(controller)
            return controller
        }
        set {
            _promptingPopupController = newValue
            _setupPromptingPopupController(newValue)
        }
    }

    private func _setupPromptingPopupController(_ controller: any SJPromptingPopupController_Protocol) {
        controller.target = presentView
    }
}

