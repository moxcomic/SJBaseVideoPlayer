//
//  SJBaseVideoPlayerResourceLoaderBundle.swift
//  SJBaseVideoPlayer
//
//  SwiftPM(SWIFT_PACKAGE)集成时 Bundle.module 的容器定位辅助.
//  对应原 ResourceLoader 块第二文件: 在非 SwiftPM 环境也保证 Bundle.module 可用.
//

import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    /// 在非 SwiftPM 集成 (CocoaPods 静态库 / framework) 下提供与 SwiftPM 同名的 `Bundle.module`,
    /// 使资源定位代码两种集成方式共用一套写法.
    ///
    /// 优先返回 SJBaseVideoPlayer module 所在的 bundle (framework 集成下即 framework 自身;
    /// 静态库集成下为 mainBundle).
    static let module: Bundle = {
        return Bundle(for: SJBaseVideoPlayerResourceLoader.self)
    }()
}
#endif

