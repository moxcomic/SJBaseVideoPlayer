//
//  SJBaseVideoPlayerResourceLoader.swift
//  SJDeviceVolumeAndBrightnessController
//
//  Created by 畅三江 on 2017/12/10.
//  Copyright © 2017年 changsanjiang. All rights reserved.
//
//  Swift 6.3 迁移版本 (SJBaseVideoPlayer module)
//

import UIKit

/// 资源加载器: 从 SJBaseVideoPlayerResources.bundle 中按名加载 png 图片.
///
/// - 行为与 ObjC 版严格等价: 优先在类所在 bundle 内定位 `SJBaseVideoPlayerResources.bundle`,
///   图片以 scale=3.0 读取.
/// - SwiftPM(SWIFT_PACKAGE) 集成时, 资源由 `Bundle.module` 容器承载, 仍以 bundle 形式定位
///   `SJBaseVideoPlayerResources.bundle`.
@objc(SJBaseVideoPlayerResourceLoader)
public final class SJBaseVideoPlayerResourceLoader: NSObject {

    /// 资源 bundle (懒加载且只解析一次)
    private static let _bundle: Bundle? = {
        // 容器 bundle: SwiftPM 用 Bundle.module, 其他集成方式用类所在 bundle.
        #if SWIFT_PACKAGE
        let container = Bundle.module
        #else
        let container = Bundle(for: SJBaseVideoPlayerResourceLoader.self)
        #endif
        guard let path = container.path(forResource: "SJBaseVideoPlayerResources", ofType: "bundle") else {
            return nil
        }
        return Bundle(path: path)
    }()

    @objc public class var bundle: Bundle? {
        return _bundle
    }

    @objc(imageNamed:)
    public class func image(named name: String) -> UIImage? {
        if name.isEmpty { return nil }
        guard let path = bundle?.path(forResource: name, ofType: "png"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return UIImage(data: data, scale: 3.0)
    }
}

