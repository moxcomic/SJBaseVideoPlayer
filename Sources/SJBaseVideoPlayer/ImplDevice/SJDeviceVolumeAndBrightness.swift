//
//  SJDeviceVolumeAndBrightness.swift
//  SJBaseVideoPlayer
//
//  Created by 蓝舞者 on 2022/10/14.
//
//  Swift 6.3 移植 (等价于原 ObjC 版 SJDeviceVolumeAndBrightness.h/.m)
//

import UIKit
import MediaPlayer
@preconcurrency import AVFoundation

// MARK: - 设备音量 / 亮度观察者协议 (原定义于 SJDeviceVolumeAndBrightness.h, 属本块)

/// 设备音量 / 亮度变化观察者
///
/// 注: 原 ObjC 为 @optional 方法的非正式协议; Swift 中通过 @objc optional 表达, 选择器保持一致:
///   - device:onVolumeChanged:
///   - device:onBrightnessChanged:
@objc(SJDeviceVolumeAndBrightnessObserver)
@MainActor public protocol SJDeviceVolumeAndBrightnessObserver: NSObjectProtocol {
    @objc optional func device(_ device: SJDeviceVolumeAndBrightness, onVolumeChanged volume: Float)
    @objc optional func device(_ device: SJDeviceVolumeAndBrightness, onBrightnessChanged brightness: Float)
}

// MARK: - 设备音量 / 亮度全局管理

/// 设备音量与亮度的全局管理者 (单例)
///
/// - 通过 KVO 监听 `UIScreen.brightness` 与 `AVAudioSession.outputVolume`。
/// - 设置 volume 时通过隐藏的 MPVolumeView 内部 UISlider 改变系统音量。
/// - 设置 brightness 时直接修改 `UIScreen.main.brightness`。
///
/// 并发: 类整体在 @MainActor 上闭环 (UIKit / MPVolumeView / UIScreen 均需主线程访问)。
/// KVO 回调可能在任意线程触发, 因此 observeValue 方法标注 nonisolated, 在内部切回主线程,
/// 与原 ObjC 版 (dispatch_sync 到主队列) 行为等价。
@MainActor
@objc(SJDeviceVolumeAndBrightness)
public final class SJDeviceVolumeAndBrightness: NSObject {

    @objc(shared)
    public static let shared = SJDeviceVolumeAndBrightness()

    /// 系统音量视图 (隐藏的 MPVolumeView, 用于改变系统音量并屏蔽系统 HUD)
    @objc public private(set) var sysVolumeView: UIView

    @objc public var volume: Float {
        get { _volume }
        set { setVolumeValue(newValue) }
    }

    @objc public var brightness: Float {
        get { _brightness }
        set { setBrightnessValue(newValue) }
    }

    // MARK: 内部状态

    private var _volume: Float = 0
    private var _brightness: Float = 0

    private let mObservers = NSHashTable<SJDeviceVolumeAndBrightnessObserver>.weakObjects()
    private weak var mSysVolumeSlider: UISlider?

    private let mScreen: UIScreen
    private let mSession: AVAudioSession

    private var mBrightnessSetterLocked = false
    private var mVolumeSetterLocked = false

    // KVO context (用稳定指针区分 keyPath)
    private nonisolated(unsafe) static let kBrightnessContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    private nonisolated(unsafe) static let kVolumeContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    private override init() {
        mScreen = UIScreen.main
        mSession = AVAudioSession.sharedInstance()

        let maxOffset = max(mScreen.bounds.width, mScreen.bounds.height) + 100
        sysVolumeView = MPVolumeView(frame: CGRect(x: -maxOffset, y: -maxOffset, width: 0, height: 0))

        super.init()

        mScreen.addObserver(self, forKeyPath: "brightness",
                            options: [.initial, .new, .old],
                            context: Self.kBrightnessContext)
        mSession.addObserver(self, forKeyPath: "outputVolume",
                             options: [.initial, .new, .old],
                             context: Self.kVolumeContext)

        for subview in sysVolumeView.subviews {
            if String(describing: type(of: subview)) == "MPVolumeSlider" {
                mSysVolumeSlider = subview as? UISlider
                break
            }
        }
    }

    deinit {
        // 移除 KVO; deinit 为 nonisolated, 此处仅做与原 ObjC dealloc 等价的注销操作。
        mScreen.removeObserver(self, forKeyPath: "brightness", context: Self.kBrightnessContext)
        mSession.removeObserver(self, forKeyPath: "outputVolume", context: Self.kVolumeContext)
    }

    // MARK: 观察者管理

    @objc(addObserver:)
    public func addObserver(_ observer: SJDeviceVolumeAndBrightnessObserver) {
        mObservers.add(observer)
    }

    @objc(removeObserver:)
    public func removeObserver(_ observer: SJDeviceVolumeAndBrightnessObserver) {
        mObservers.remove(observer)
    }

    // MARK: setter 实现

    private func setVolumeValue(_ value: Float) {
        var volume = value
        if volume.isNaN || volume.isInfinite { return }

        if volume < 0.0 { volume = 0.0 }
        else if volume > 1.0 { volume = 1.0 }

        if volume != _volume {
            mVolumeSetterLocked = true
            _volume = volume
            mSysVolumeSlider?.setValue(volume, animated: false)
            _onVolumeChanged()
        }
    }

    private func setBrightnessValue(_ value: Float) {
        var brightness = value
        if brightness.isNaN || brightness.isInfinite { return }

        if brightness < 0.0 { brightness = 0.0 }
        else if brightness > 1.0 { brightness = 1.0 }

        if brightness != _brightness {
            mBrightnessSetterLocked = true
            _brightness = brightness
            UIScreen.main.brightness = CGFloat(brightness)
            _onBrightnessChanged()
        }
    }

    // MARK: KVO

    // KVO 回调可能在任意线程触发 (尤其 AVAudioSession.outputVolume), 故声明 nonisolated,
    // 内部根据线程切回主线程, 与原 ObjC 版 dispatch_sync(main) 行为等价。
    public override nonisolated func observeValue(forKeyPath keyPath: String?,
                                                  of object: Any?,
                                                  change: [NSKeyValueChangeKey: Any]?,
                                                  context: UnsafeMutableRawPointer?) {
        let isVolume = (context == Self.kVolumeContext)
        let isBrightness = (context == Self.kBrightnessContext)
        guard isVolume || isBrightness else { return }
        let newValue = (change?[.newKey] as? NSNumber)?.floatValue ?? 0

        if Thread.current.isMainThread {
            MainActor.assumeIsolated {
                self._onValueChange(isVolume: isVolume, isBrightness: isBrightness, newValue: newValue)
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    self._onValueChange(isVolume: isVolume, isBrightness: isBrightness, newValue: newValue)
                }
            }
        }
    }

    private func _onValueChange(isVolume: Bool, isBrightness: Bool, newValue: Float) {
        if isVolume {
            if !mVolumeSetterLocked {
                _volume = newValue
                _onVolumeChanged()
            }
            mVolumeSetterLocked = false
        } else if isBrightness {
            if !mBrightnessSetterLocked {
                _brightness = newValue
                _onBrightnessChanged()
            }
            mBrightnessSetterLocked = false
        }
    }

    // MARK: 回调分发

    private func _onVolumeChanged() {
        guard mObservers.count > 0 else { return }
        for observer in mObservers.allObjects {
            observer.device?(self, onVolumeChanged: _volume)
        }
    }

    private func _onBrightnessChanged() {
        guard mObservers.count > 0 else { return }
        for observer in mObservers.allObjects {
            observer.device?(self, onBrightnessChanged: _brightness)
        }
    }
}

