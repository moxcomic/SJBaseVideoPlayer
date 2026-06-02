//
//  SJBaseVideoPlayer+DeviceVolumeAndBrightness.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (DeviceVolumeAndBrightness)。设置设备的音量和亮度。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 设备 音量和亮度调整管理类(null_resettable)
    ///
    @objc public var deviceVolumeAndBrightnessController: any SJDeviceVolumeAndBrightnessController_Protocol {
        get {
            if let controller = _deviceVolumeAndBrightnessController { return controller }
            let controller = SJDeviceVolumeAndBrightnessController()
            _deviceVolumeAndBrightnessController = controller
            _configDeviceVolumeAndBrightnessController(controller)
            return controller
        }
        set {
            _deviceVolumeAndBrightnessController = newValue
            _configDeviceVolumeAndBrightnessController(newValue)
        }
    }

    private func _configDeviceVolumeAndBrightnessController(_ mgr: any SJDeviceVolumeAndBrightnessController_Protocol) {
        mgr.targetViewContext = _deviceVolumeAndBrightnessTargetViewContext
        mgr.target = presentView

        let observer = mgr.getObserver()
        _deviceVolumeAndBrightnessControllerObserver = observer
        observer.volumeDidChangeExeBlock = { [weak self] _, volume in
            guard let self = self else { return }
            self.controlLayerDelegate?.videoPlayer?(self, volumeChanged: volume)
        }
        observer.brightnessDidChangeExeBlock = { [weak self] _, brightness in
            guard let self = self else { return }
            self.controlLayerDelegate?.videoPlayer?(self, brightnessChanged: brightness)
        }

        mgr.onTargetViewMoveToWindow()
        mgr.onTargetViewContextUpdated()
    }

    ///
    /// 观察者
    ///
    @objc public var deviceVolumeAndBrightnessObserver: any SJDeviceVolumeAndBrightnessControllerObserver {
        if let observer = _deviceVolumeAndBrightnessObserver { return observer }
        let observer = deviceVolumeAndBrightnessController.getObserver()
        _deviceVolumeAndBrightnessObserver = observer
        return observer
    }

    ///
    /// 禁止设置亮度
    ///
    @objc public var disableBrightnessSetting: Bool {
        get { controlInfo.deviceVolumeAndBrightness.disableBrightnessSetting }
        set { controlInfo.deviceVolumeAndBrightness.disableBrightnessSetting = newValue }
    }

    ///
    /// 禁止设置音量
    ///
    @objc public var disableVolumeSetting: Bool {
        get { controlInfo.deviceVolumeAndBrightness.disableVolumeSetting }
        set { controlInfo.deviceVolumeAndBrightness.disableVolumeSetting = newValue }
    }
}

