//
//  UIViewController+SJBaseVideoPlayerExtended.swift
//  SJBaseVideoPlayer
//
//  Created by 畅三江 on 2019/11/23.
//
//  Swift 6.3 转换: 保留 ObjC 选择器 setTransitionDuration:presentedAnimation:dismissedAnimation:.
//  自定义转场: 用关联对象持有转场 handler, 实现 present/dismiss 动画.
//

import UIKit
import ObjectiveC.runtime

///
/// 转场动画完成回调.
///
public typealias SJAnimationCompletionHandler = () -> Void
///
/// present 转场动画回调.
///
public typealias SJPresentedAnimationHandler = (UIViewController, @escaping SJAnimationCompletionHandler) -> Void
///
/// dismiss 转场动画回调.
///
public typealias SJDismissedAnimationHandler = (UIViewController, @escaping SJAnimationCompletionHandler) -> Void

private enum SJModalAction: UInt {
    case presented = 0
    case dismissed = 1
}

///
/// 模态转场处理器: 同时充当 transitioningDelegate 与 animatedTransitioning.
///
@MainActor
final class SJModalPresentationHandler: NSObject {
    weak var modalViewController: UIViewController? {
        didSet {
            modalViewController?.transitioningDelegate = self
            if #available(iOS 16.0, *) {
                modalViewController?.modalPresentationStyle = .custom
            } else {
                // https://github.com/changsanjiang/SJBaseVideoPlayer/pull/36
                // 16以下的系统, 如果当前界面是横屏,fitOn后是竖屏问题
                modalViewController?.modalPresentationStyle = .fullScreen
            }
        }
    }
    var transitionDuration: TimeInterval = 0
    var presentedAnimationHandler: SJPresentedAnimationHandler?
    var dismissedAnimationHandler: SJDismissedAnimationHandler?

    fileprivate var state: SJModalAction = .presented
}

extension SJModalPresentationHandler: UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch state {
        case .presented:
            let containerView = transitionContext.containerView
            if let toView = transitionContext.view(forKey: .to) {
                toView.frame = containerView.bounds
                toView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                containerView.addSubview(toView)
            }
            if let handler = presentedAnimationHandler, let vc = modalViewController {
                handler(vc, {
                    transitionContext.completeTransition(true)
                })
            }
        case .dismissed:
            if let handler = dismissedAnimationHandler, let vc = modalViewController {
                handler(vc, {
                    transitionContext.completeTransition(true)
                })
            }
        }
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        state = .presented
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        state = .dismissed
        return self
    }
}

private nonisolated(unsafe) var kSJModalHandlerKey: UInt8 = 0

@objc
public extension UIViewController {
    ///
    /// 设置转场时间, 设置呈现的动画及消失的动画
    ///
    @objc(setTransitionDuration:presentedAnimation:dismissedAnimation:)
    func setTransitionDuration(_ duration: TimeInterval,
                               presentedAnimation: @escaping SJPresentedAnimationHandler,
                               dismissedAnimation: @escaping SJDismissedAnimationHandler) {
        MainActor.assumeIsolated {
            var handler = objc_getAssociatedObject(self, &kSJModalHandlerKey) as? SJModalPresentationHandler
            if handler == nil {
                let newHandler = SJModalPresentationHandler()
                objc_setAssociatedObject(self, &kSJModalHandlerKey, newHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                handler = newHandler
            }
            handler?.modalViewController = self
            handler?.transitionDuration = duration
            handler?.presentedAnimationHandler = presentedAnimation
            handler?.dismissedAnimationHandler = dismissedAnimation
        }
    }
}

