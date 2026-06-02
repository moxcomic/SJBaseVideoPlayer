//
//  SJRotationManager_iOS_16_Later.swift
//  SJVideoPlayer_Example
//
//  Created by 畅三江 on 2022/8/13.
//  Copyright © 2022 changsanjiang. All rights reserved.
//
//  说明: 原 SJRotationManager_iOS_16_Later.h/.m
//  - iOS 16+ 旋转实现: 用独立 window + setNeedsUpdateOfSupportedInterfaceOrientations 驱动方向切换,
//    transform/bounds/center 动画完成横竖屏视觉转场。
//  - SJRotationPortraitOrientationFixingWindow: 转回竖屏时临时置顶的修正窗口, 强制竖屏方向。
//

import UIKit

// MARK: - 竖屏方向修正窗口

@available(iOS 16.0, *)
@MainActor
final class SJRotationPortraitOrientationFixingWindow: UIWindow {

    static let shared: SJRotationPortraitOrientationFixingWindow = {
        let scene = UIApplication.shared.keyWindowCompat?.windowScene
            ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)
        if let scene {
            return SJRotationPortraitOrientationFixingWindow(windowScene: scene)
        }
        return SJRotationPortraitOrientationFixingWindow(frame: UIScreen.main.bounds)
    }()

    override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { /* no-op */ }
    }
}

// MARK: - iOS 16+ 旋转管理器

@available(iOS 16.0, *)
@MainActor
@objc(SJRotationManager_iOS_16_Later)
public class SJRotationManager_iOS_16_Later: SJRotationManager {

    private var _rotationFullscreenViewController: SJRotationFullscreenViewController?
    override var rotationFullscreenViewController: SJRotationFullscreenViewController {
        if _rotationFullscreenViewController == nil {
            _rotationFullscreenViewController = SJRotationFullscreenViewController()
        }
        return _rotationFullscreenViewController!
    }

    override func pointInside(_ point: CGPoint, with event: UIEvent?) -> Bool {
        true
    }

    public override func prefersStatusBarHidden(for viewController: SJRotationFullscreenViewController) -> Bool {
        false
    }

    @objc(supportedInterfaceOrientationsForWindow:)
    public override func supportedInterfaceOrientations(forWindow window: UIWindow?) -> UIInterfaceOrientationMask {
        if window === SJRotationPortraitOrientationFixingWindow.shared {
            return UIInterfaceOrientationMask(rawValue: 1 << UIInterfaceOrientation.portrait.rawValue)
        }
        if window === self.window {
            return UIInterfaceOrientationMask(rawValue: 1 << currentOrientation.rawValue)
        }
        return .portrait
    }

    override func onDeviceOrientationChanged(_ deviceOrientation: SJOrientation) {
        if allowsRotation() {
            rotateToOrientation(deviceOrientation, animated: true, complete: nil)
        }
    }

    override func rotateToOrientation(_ orientation: SJOrientation, animated: Bool, complete completionHandler: ((SJRotationManager) -> Void)?) {
        let fromOrientation = currentOrientation
        let toOrientation = orientation
        if fromOrientation == toOrientation {
            completionHandler?(self)
            return
        }

        setCurrentOrientation(orientation)
        rotationBegin()
        transitionBegin()

        let sourceWindow = superview?.window
        let sourceFrame = superview?.convert(superview?.bounds ?? .zero, to: sourceWindow) ?? .zero

        // prepare
        let screenBounds = UIScreen.main.bounds
        let maxSize = max(screenBounds.size.width, screenBounds.size.height)
        let minSize = min(screenBounds.size.width, screenBounds.size.height)

        guard let target = self.target else {
            // target 缺失则直接结束 (与原行为对齐, 原代码会向 nil 发消息)
            transitionEnd()
            rotationEnd()
            completionHandler?(self)
            return
        }

        target.autoresizingMask = []
        if fromOrientation == .portrait {
            target.frame = sourceFrame
            sourceWindow?.addSubview(target)
            target.layoutIfNeeded()

            if self.window.isHidden { self.window.makeKeyAndVisible() }
            setNeedsUpdateOfSupportedInterfaceOrientations()
        } else if toOrientation == .portrait {
            target.removeFromSuperview()
            target.bounds = CGRect(origin: .zero, size: CGSize(width: maxSize, height: minSize))
            target.center = CGPoint(x: minSize * 0.5, y: maxSize * 0.5)
            switch fromOrientation {
            case .portrait: break
            case .landscapeLeft:
                target.transform = CGAffineTransform(rotationAngle: .pi / 2)
            case .landscapeRight:
                target.transform = CGAffineTransform(rotationAngle: -.pi / 2)
            @unknown default: break
            }

            sourceWindow?.addSubview(target)
            _ = target.snapshotView(afterScreenUpdates: true)
            target.layoutIfNeeded()
            UIView.performWithoutAnimation {
                SJRotationPortraitOrientationFixingWindow.shared.makeKeyAndVisible()
                self.window.isHidden = true
                self.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }

        var rotationBounds = CGRect.zero
        var rotationCenter = CGPoint.zero
        var rotationTransform = CGAffineTransform.identity

        // bounds & center
        switch toOrientation {
        case .portrait:
            rotationBounds = CGRect(origin: .zero, size: sourceFrame.size)
            rotationCenter = CGPoint(x: sourceFrame.origin.x + rotationBounds.size.width * 0.5,
                                     y: sourceFrame.origin.y + rotationBounds.size.height * 0.5)
        case .landscapeRight, .landscapeLeft:
            rotationBounds = CGRect(origin: .zero, size: CGSize(width: maxSize, height: minSize))
            rotationCenter = fromOrientation == .portrait
                ? CGPoint(x: minSize * 0.5, y: maxSize * 0.5)
                : CGPoint(x: maxSize * 0.5, y: minSize * 0.5)
        @unknown default: break
        }

        // transform
        switch fromOrientation {
        case .portrait:
            switch toOrientation {
            case .portrait: break
            case .landscapeLeft:
                rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
            case .landscapeRight:
                rotationTransform = CGAffineTransform(rotationAngle: -.pi / 2)
            @unknown default: break
            }
        case .landscapeLeft:
            switch toOrientation {
            case .landscapeLeft: break
            case .portrait, .landscapeRight:
                rotationTransform = .identity
            @unknown default: break
            }
        case .landscapeRight:
            switch toOrientation {
            case .landscapeRight: break
            case .portrait, .landscapeLeft:
                rotationTransform = .identity
            @unknown default: break
            }
        @unknown default: break
        }

        UIView.animate(withDuration: 0.0, animations: { /* next */ }, completion: { [weak self] _ in
            guard let self, let target = self.target else { return }
            UIView.animate(withDuration: 0.3, animations: {
                target.bounds = rotationBounds
                target.center = rotationCenter
                target.transform = rotationTransform
                target.layoutIfNeeded()
            }, completion: { [weak self] _ in
                guard let self, let target = self.target else { return }
                target.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                if toOrientation == .portrait {
                    sourceWindow?.becomeKey()
                    SJRotationPortraitOrientationFixingWindow.shared.isHidden = true
                    self.superview?.addSubview(target)
                    target.transform = .identity
                    target.bounds = self.superview?.bounds ?? target.bounds
                    target.center = CGPoint(x: target.bounds.size.width * 0.5,
                                            y: target.bounds.size.height * 0.5)
                } else {
                    self.setNeedsUpdateOfSupportedInterfaceOrientations()
                    if target.superview != self.rotationFullscreenViewController.view {
                        self.rotationFullscreenViewController.view.addSubview(target)
                    }
                    target.transform = .identity
                    target.bounds = self.window.bounds
                    target.center = CGPoint(x: target.bounds.size.width * 0.5,
                                            y: target.bounds.size.height * 0.5)
                }
                target.layoutIfNeeded()
                self.transitionEnd()
                self.rotationEnd()
                completionHandler?(self)
            })
        })
    }

    private func setNeedsUpdateOfSupportedInterfaceOrientations() {
        UIApplication.shared.keyWindowCompat?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        self.window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

