//
//  SJBaseVideoPlayer+Network.swift
//  SJBaseVideoPlayerProject
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2018年 changsanjiang. All rights reserved.
//
//  对应原 ObjC category: SJBaseVideoPlayer (Network)。网络状态。
//

import UIKit

@MainActor
extension SJBaseVideoPlayer {

    ///
    /// 网络状态监测(null_resettable)
    ///
    @objc public var reachability: any SJReachability_Protocol {
        get {
            if let reachability = _reachability { return reachability }
            let reachability = SJReachability.shared
            _reachability = reachability
            _needUpdateReachabilityProperties()
            return reachability
        }
        set {
            _reachability = newValue
            _needUpdateReachabilityProperties()
        }
    }

    private func _needUpdateReachabilityProperties() {
        guard let reachability = _reachability else { return }

        let observer = reachability.getObserver()
        _reachabilityObserver = observer
        observer.networkStatusDidChangeExeBlock = { [weak self] r in
            guard let self = self else { return }
            self.controlLayerDelegate?.videoPlayer?(self, reachabilityChanged: r.networkStatus)
        }
    }

    ///
    /// 观察者
    ///
    @objc public var reachabilityObserver: any SJReachabilityObserver_Protocol {
        if let observer = _reachabilityObserverPublic { return observer }
        let observer = reachability.getObserver()
        _reachabilityObserverPublic = observer
        return observer
    }
}

