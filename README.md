# SJBaseVideoPlayer

[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-supported-brightgreen.svg)](https://swift.org/package-manager)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-blue.svg)](https://developer.apple.com/ios)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE.md)

可切换播放引擎的 iOS 视频播放核心 —— 以 `SJBaseVideoPlayer` 为主门面，封装播放控制、旋转/全屏、画中画、手势、音量亮度、截图导出、字幕弹幕、水印等能力，UI 控制层完全交由上层定制。

> 这是 [moxcomic/SJBaseVideoPlayer](https://github.com/moxcomic/SJBaseVideoPlayer) fork，由原作者 [畅三江](https://github.com/changsanjiang) 的 Objective-C 版本迁移而来。

---

## 已迁移到 Swift 6.3 + Swift Package Manager

本仓库已将原 Objective-C / CocoaPods 工程整体重写为 **Swift**，并改用 **Swift Package Manager** 分发：

- `Package.swift` 声明 `swift-tools-version:6.0`，目标 target 使用 `.swiftLanguageMode(.v6)`（Swift 6 严格并发模式）。
- 已在 **Swift 6.3 / Xcode 工具链**下编译验证通过（iOS 模拟器）。
- 默认播放引擎基于 **AVPlayer**（`SJAVMediaPlaybackController`）；播放控制器抽象为协议 `SJVideoPlayerPlaybackController`，可替换为自定义实现。

迁移要点（详见下文「从 ObjC/CocoaPods 版的破坏性变更」）：

- 整个 `SJBaseVideoPlayer` 类标注 `@MainActor`，所有 API 须在主线程访问。
- `@objc` 选择器与原 ObjC 保持一致，方便仍为 Objective-C 的上层调用。
- 布局由 Masonry 迁移为 **SnapKit**。
- `NS_OPTIONS` 类型（如 `SJOrientationMask`、`SJPlayerGestureTypeMask`）改为 Swift `OptionSet`，不再 `@objc` 暴露。

---

## 环境要求

- iOS 15.0 及以上
- Swift 6.3（或对应 Xcode 工具链）

## 依赖

通过 SPM 自动解析：

- [moxcomic/SJUIKit](https://github.com/moxcomic/SJUIKit)（`main` 分支）
- [SnapKit/SnapKit](https://github.com/SnapKit/SnapKit)（`5.7.0+`）

---

## 安装（Swift Package Manager）

### Xcode

`File > Add Package Dependencies...`，输入：

```
https://github.com/moxcomic/SJBaseVideoPlayer.git
```

依赖规则选择 **Branch → `main`**。

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/moxcomic/SJBaseVideoPlayer.git", branch: "main"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SJBaseVideoPlayer", package: "SJBaseVideoPlayer"),
        ]
    )
]
```

> `SJUIKit` 与 `SnapKit` 会作为传递依赖自动拉取，无需手动声明。

---

## 快速开始（Swift）

### 1. 创建播放器并加入视图

`SJBaseVideoPlayer` 全类 `@MainActor`，下列代码均运行在主线程。

```swift
import UIKit
import SnapKit
import SJBaseVideoPlayer

final class PlayerViewController: UIViewController {

    private let player = SJBaseVideoPlayer.player()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(player.view)
        player.view.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            // 16:9
            make.height.equalTo(player.view.snp.width).multipliedBy(9.0 / 16.0)
        }
    }
}
```

### 2. 设置资源进行播放

`URLAsset` 一经赋值默认会自动开始播放（`autoplayWhenSetNewAsset` 默认为 `true`）。

```swift
let url = URL(string: "https://example.com/sample.mp4")!
if let asset = SJVideoPlayerURLAsset(url: url) {
    player.urlAsset = asset            // ObjC 选择器仍为 `URLAsset`
}

// 也可指定起播位置（秒）
let asset = SJVideoPlayerURLAsset(url: url, startPosition: 30)
```

### 3. 监听状态与进度

通过 `playbackObserver` 注册回调（`SJPlaybackObservation`）：

```swift
let obs = player.playbackObserver
obs.timeControlStatusDidChangeExeBlock = { p in
    print("isPlaying:", p.isPlaying, "isPaused:", p.isPaused, "isBuffering:", p.isBuffering)
}
obs.currentTimeDidChangeExeBlock = { p in
    print("\(p.currentTime) / \(p.duration)")
}
obs.assetStatusDidChangeExeBlock = { p in
    if p.assetStatus == .failed { print("playback failed:", p.error as Any) }
}
obs.playbackDidFinishExeBlock = { p in
    print("finished:", p.finishedReason as Any)
}
```

也可监听对应的 `Notification`（如 `SJVideoPlayerPlaybackTimeControlStatusDidChangeNotification`、`SJVideoPlayerCurrentTimeDidChangeNotification` 等，`notification.object` 即播放器实例）。

### 4. 播放控制

```swift
player.play()
player.pause()
player.pauseForUser()          // 标记为用户主动暂停
player.replay()
player.refresh()               // 失败后重试
player.stop()

player.rate = 1.5              // 倍速
player.playerVolume = 0.8      // 播放器音量（非系统音量）
player.muted = true

// seek（秒）
player.seek(toTime: 60) { finished in
    print("seek finished:", finished)
}
```

### 5. 旋转 / 全屏

```swift
player.rotate()                                 // 自动在横竖屏间切换
player.rotate(.landscapeLeft, animated: true)   // 旋转到指定方向
print(player.isFullscreen, player.isRotating)

player.lockedScreen = true                      // 锁屏（锁定旋转/手势）
```

旋转需要在 App 层放行窗口方向。在 `AppDelegate` 中：

```swift
func application(_ application: UIApplication,
                 supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    SJRotationManager.supportedInterfaceOrientations(forWindow: window)
}
```

并在承载播放器的 VC 中转发生命周期：

```swift
override var shouldAutorotate: Bool { false }

override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    player.vc_viewDidAppear()
}
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    player.vc_viewWillDisappear()
}
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    player.vc_viewDidDisappear()
}
```

### 6. 竖屏全屏（不触发旋转）

```swift
player.fitOnScreen = true
player.setFitOnScreen(true, animated: true) { p in
    print("fit on screen:", p.fitOnScreen)
}
```

### 7. 画中画（PiP，iOS 14+）

画中画由播放控制器提供：

```swift
if player.playbackController.isPictureInPictureSupported() {
    player.playbackController.startPictureInPicture()
    // player.playbackController.stopPictureInPicture()
}

// 监听状态
player.playbackObserver.pictureInPictureStatusDidChangeExeBlock = { p in
    print("PiP status:", p.playbackController.pictureInPictureStatus)
}
```

### 8. 截图 / 导出

```swift
// 立即截取当前画面
let image = player.screenshot()

// 截取指定时间点
player.screenshot(withTime: 10) { p, image, error in
    // ...
}

// 导出片段
player.export(withBeginTime: 0, duration: 10, presetName: nil) { p, progress in
    print(progress)
} completion: { p, fileURL, thumbnail in
    print(fileURL)
} failure: { p, error in
    print(error)
}

// 生成 GIF
player.generateGIF(withBeginTime: 0, duration: 3) { p, progress in
} completion: { p, gif, thumbnail, filePath in
} failure: { p, error in
}
```

### 9. 字幕 / 弹幕 / 水印

```swift
// 字幕（仅 Swift 可见，详见破坏性变更说明）
player.subtitlePopupController.subtitles = items

// 弹幕
let danmaku = player.danmakuPopupController

// 水印（传入实现了 SJWatermarkView_Protocol 的视图）
player.watermarkView = myWatermarkView
```

---

## 公共 API 概览

主门面 `SJBaseVideoPlayer`（`@MainActor`，`@objc(SJBaseVideoPlayer)`）的能力按原 category 拆分到多个 `extension`：

| 分类 | 关键 API |
| --- | --- |
| 工厂 / 版本 | `player()`、`version()` |
| 视图 | `view`、`videoGravity`、`controlLayerDataSource`、`controlLayerDelegate` |
| 资源 | `urlAsset`（ObjC `URLAsset`）、`switchVideoDefinition(_:)`、`definitionSwitchingInfo` |
| 播放控制 | `play()`、`pause()`、`pauseForUser()`、`replay()`、`refresh()`、`stop()`、`seek(toTime:completionHandler:)` |
| 播放状态 | `assetStatus`、`timeControlStatus`、`isPlaying`/`isPaused`/`isBuffering`、`currentTime`、`duration`、`playableDuration`、`rate`、`playerVolume`、`muted`、`error` |
| 观察 | `playbackObserver`（`SJPlaybackObservation`） |
| 播放控制器 | `playbackController`（`SJVideoPlayerPlaybackController`，可替换引擎；含 PiP 接口） |
| 旋转 | `rotate()`、`rotate(_:animated:)`、`isFullscreen`、`isRotating`、`currentOrientation`、`lockedScreen`、`rotationManager`、`rotationObserver` |
| 竖屏全屏 | `fitOnScreen`、`setFitOnScreen(_:animated:)`、`onlyFitOnScreen`、`fitOnScreenManager` |
| 控制层 | `controlLayerNeedAppear()`、`controlLayerNeedDisappear()`、`controlLayerAppeared`、`controlLayerAppearManager` |
| 手势 | `gestureController`、`gestureRecognizerShouldTrigger`、`rateWhenLongPressGestureTriggered` |
| 音量亮度 | `deviceVolumeAndBrightnessController`、`disableVolumeSetting`、`disableBrightnessSetting` |
| 音频会话 | `audioSessionControlEnabled`、`setCategory(_:withOptions:)`、`setActiveOptions(_:)` |
| 截图 / 导出 | `screenshot()`、`screenshot(withTime:completion:)`、`export(...)`、`generateGIF(...)` |
| 字幕 / 弹幕 / 水印 | `subtitlePopupController`、`danmakuPopupController`、`watermarkView` |
| 弹出提示 | `textPopupController`、`promptingPopupController` |
| 网络 | `reachability`、`reachabilityObserver` |
| 生命周期 | `vc_viewDidAppear()`、`vc_viewWillDisappear()`、`vc_viewDidDisappear()`、`vc_isDisappeared` |

---

## 从 ObjC / CocoaPods 版的破坏性变更与迁移注意

- **安装方式**：由 CocoaPods（`pod 'SJBaseVideoPlayer'`）改为 SPM（`branch: "main"`）。
- **语言**：实现整体由 Objective-C 重写为 Swift，并启用 Swift 6 严格并发（`.swiftLanguageMode(.v6)`）。
- **主线程隔离**：`SJBaseVideoPlayer` 全类 `@MainActor`，所有属性/方法须在主线程访问；Swift 侧会做编译期检查。
- **`@objc` 选择器保留**：ObjC 调用方仍可使用原选择器，如 `URLAsset`（Swift 属性名 `urlAsset`）、`isMuted`、`isFitOnScreen`、`isLockedScreen` 等。
- **布局框架**：Masonry → **SnapKit**（`mas_makeConstraints` → `snp.makeConstraints`）。
- **OptionSet 类型不再 @objc**：`NS_OPTIONS`（如 `SJOrientationMask`、`SJPlayerGestureTypeMask`）改为 Swift `OptionSet`，无法 `@objc` 暴露；相关协议属性以 `UInt` rawValue 形式对 ObjC 可见。
- **字幕属性仅 Swift 可见**：`subtitlePopupController` 因依赖非 `@objc` 的类型（`SJTimeRange` / `SJSubtitleItem.range`）而无法 `@objc` 暴露，只能在 Swift 中使用。
- **协议类型采用 `any`**：诸如 `playbackController`、`rotationManager` 等返回值在 Swift 中以 `any SJ...Protocol` 形式表达。
- **SQLite3 → Codable**：内部播放记录等存储由 SQLite3 改为基于 `Codable` 的实现。

---

## License

MIT License。沿用原仓库授权，版权归原作者所有（Copyright © 2017 changsanjiang）。详见 [LICENSE.md](LICENSE.md)。
