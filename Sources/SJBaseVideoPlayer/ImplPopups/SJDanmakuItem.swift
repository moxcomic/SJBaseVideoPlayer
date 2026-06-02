//
//  SJDanmakuItem.swift
//  Pods
//
//  Created by 畅三江 on 2019/11/12.
//
//  由 ObjC 版 SJDanmakuItem.h/.m 转换而来 (Swift 6.3)。
//

import Foundation
import UIKit

///
/// 弹幕条目。
///
/// 遵循 `SJDanmakuItem` 协议(定义在接口块 `SJDanmakuPopupControllerDefines`)。
///
@MainActor
public final class SJDanmakuItem: NSObject, SJDanmakuItem_Protocol {
    /// 弹幕文本内容
    public let content: NSAttributedString?
    /// 自定义弹幕视图
    public let customView: UIView?

    /// 用属性字符串初始化
    @objc public init(content: NSAttributedString) {
        self.content = content.copy() as? NSAttributedString
        self.customView = nil
        super.init()
    }

    /// 用自定义视图初始化
    @objc public init(customView: UIView) {
        self.content = nil
        self.customView = customView
        super.init()
    }
}

