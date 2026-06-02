//
//  AVAsset+SJAVMediaExport.swift
//  SJVideoPlayer
//
//  Created by 畅三江 on 2018/2/2.
//  Copyright © 2019 畅三江. All rights reserved.
//
//  Swift 6.3 迁移: 由 AVAsset+SJAVMediaExport.{h,m} 转写, 行为与 ObjC 版严格等价.
//  - 预览图/导出/截图/GIF 生成均通过 AVAssetImageGenerator / AVAssetExportSession 实现.
//  - 内部生成器对象通过关联对象缓存(保持原 lazy 缓存语义).
//

@preconcurrency import AVFoundation
import UIKit
import ImageIO
import ObjectiveC
#if canImport(MobileCoreServices)
import MobileCoreServices
#endif
import UniformTypeIdentifiers

// MARK: - 预览图生成器

final class _SJAVAssetPreviewImagesGenerator: NSObject, @unchecked Sendable {
    private(set) weak var asset: AVAsset?
    private let imageGenerator: AVAssetImageGenerator

    init(asset: AVAsset) {
        self.asset = asset
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        super.init()
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true
    }

    private func sj_loadDuration(ofAsset completionHandler: @escaping (CMTime) -> Void) {
        guard let asset = asset else { return }
        if CMTimeCompare(.zero, asset.duration) != 0 {
            completionHandler(asset.duration)
        } else {
            asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
                guard let self = self, let asset = self.asset else { return }
                completionHandler(asset.duration)
            }
        }
    }

    func generatePreviewImages(maxItemSize itemSize: CGSize, count: UInt, completionHandler block: @escaping (AVAsset, [UIImage]?, Error?) -> Void) {
        assert(count != 0)
        cancel()
        nonisolated(unsafe) let block = block

        sj_loadDuration { [weak self] duration in
            guard let self = self, let asset = self.asset else { return }
            let secs = CMTimeGetSeconds(duration)
            let interval = secs / Double(count)
            var timesM: [NSValue] = []
            timesM.reserveCapacity(Int(count))
            for i in 0..<Int(count) {
                timesM.append(NSValue(time: CMTimeMakeWithSeconds(interval * Double(i), preferredTimescale: Int32(NSEC_PER_SEC))))
            }

            let m = NSMutableArray()
            self.imageGenerator.maximumSize = itemSize
            var imgs = Int(count)
            self.imageGenerator.generateCGImagesAsynchronously(forTimes: timesM) { [weak self] _, imageRef, _, result, error in
                guard let self = self, let asset = self.asset else { return }
                switch result {
                case .succeeded:
                    if let imageRef = imageRef {
                        let image = UIImage(cgImage: imageRef)
                        m.add(image)
                    }
                    imgs -= 1
                    if imgs != 0 { return }
                    nonisolated(unsafe) let asset = asset
                    nonisolated(unsafe) let m = m
                    DispatchQueue.main.async {
                        block(asset, (m as? [UIImage]) ?? [], nil)
                    }
                case .failed:
                    nonisolated(unsafe) let asset = asset
                    nonisolated(unsafe) let error = error
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cancel()
                        block(asset, nil, error)
                    }
                case .cancelled:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func cancel() {
        imageGenerator.cancelAllCGImageGeneration()
    }
}

// MARK: - 导出器

final class _SJAVAssetExporter: NSObject, @unchecked Sendable {
    private(set) weak var asset: AVAsset?
    private var exportSession: AVAssetExportSession?
    private var exportProgressRefreshTimer: Timer?

    init(asset: AVAsset) {
        self.asset = asset
        super.init()
    }

    func export(startTime: TimeInterval,
                duration secs1: TimeInterval,
                toFile fileURL: URL,
                presetName: String?,
                progress: ((AVAsset, Float) -> Void)?,
                success: ((AVAsset, AVAsset?, URL?, UIImage?) -> Void)?,
                failure: ((AVAsset, Error?) -> Void)?) {
        cancel()
        guard let asset = asset else { return }

        let endTime = startTime + secs1
        if endTime - startTime <= 0 {
            failure?(asset, NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["msg": "Error: Start time is greater than end time!"]))
            return
        }
        let preset = presetName ?? AVAssetExportPresetMediumQuality
        nonisolated(unsafe) let compositionM = AVMutableComposition()
        let audioTrackM = compositionM.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrackM = compositionM.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let cutRange = CMTimeRangeMake(start: CMTimeMakeWithSeconds(startTime, preferredTimescale: Int32(NSEC_PER_SEC)), duration: CMTimeMakeWithSeconds(endTime - startTime, preferredTimescale: Int32(NSEC_PER_SEC)))
        let assetAudioTrack = asset.tracks(withMediaType: .audio).first
        let assetVideoTrack = asset.tracks(withMediaType: .video).first
        do {
            if let assetAudioTrack = assetAudioTrack {
                try audioTrackM?.insertTimeRange(cutRange, of: assetAudioTrack, at: .zero)
            }
            if let assetVideoTrack = assetVideoTrack {
                try videoTrackM?.insertTimeRange(cutRange, of: assetVideoTrack, at: .zero)
            }
        } catch {
            NSLog("Export Failed: error = %@", error as NSError)
            failure?(asset, error)
            return
        }
        if let assetVideoTrack = assetVideoTrack {
            videoTrackM?.preferredTransform = assetVideoTrack.preferredTransform
        }

        try? FileManager.default.removeItem(at: fileURL)
        let exportSession = AVAssetExportSession(asset: compositionM, presetName: preset)
        self.exportSession = exportSession
        exportSession?.outputURL = fileURL
        exportSession?.shouldOptimizeForNetworkUse = true
        exportSession?.outputFileType = .mp4

        let timer = Timer.assetAdd_timer(withTimeInterval: 0.1, block: { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if let asset = self.asset {
                progress?(asset, self.exportSession?.progress ?? 0)
            }
        }, repeats: true)
        self.exportProgressRefreshTimer = timer
        RunLoop.current.add(timer, forMode: .common)
        timer.fireDate = Date(timeIntervalSinceNow: 0.1)

        nonisolated(unsafe) let progress = progress
        nonisolated(unsafe) let success = success
        nonisolated(unsafe) let failure = failure
        nonisolated(unsafe) let capturedExportSession = exportSession
        nonisolated(unsafe) let fileURL = fileURL
        exportSession?.exportAsynchronously { [weak self] in
            guard let self = self, let asset = self.asset else { return }
            switch capturedExportSession?.status {
            case .unknown, .waiting, .cancelled, .exporting, .none:
                break
            case .completed:
                nonisolated(unsafe) let image = compositionM.sj_screenshot(with: CMTime.zero)
                nonisolated(unsafe) let asset = asset
                DispatchQueue.main.async {
                    progress?(asset, 1)
                    success?(asset, compositionM, fileURL, image)
                }
            case .failed:
                nonisolated(unsafe) let asset = asset
                nonisolated(unsafe) let error = capturedExportSession?.error
                DispatchQueue.main.async {
                    failure?(asset, error)
                }
            @unknown default:
                break
            }

            if capturedExportSession?.status == .cancelled ||
                capturedExportSession?.status == .completed ||
                capturedExportSession?.status == .failed {
                self.cancel()
            }
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        exportProgressRefreshTimer?.invalidate()
        exportProgressRefreshTimer = nil
    }
}

// MARK: - 截图生成器

final class _SJAVAssetScreenshotGenerator: NSObject, @unchecked Sendable {
    let screenshotGenerator: AVAssetImageGenerator
    private(set) weak var asset: AVAsset?

    init(asset: AVAsset) {
        self.asset = asset
        self.screenshotGenerator = AVAssetImageGenerator(asset: asset)
        super.init()
        screenshotGenerator.requestedTimeToleranceBefore = .zero
        screenshotGenerator.requestedTimeToleranceAfter = .zero
        screenshotGenerator.appliesPreferredTrackTransform = true
    }

    func sj_screenshot(with time: CMTime) -> UIImage? {
        var actualTime = time
        guard let imgRef = try? screenshotGenerator.copyCGImage(at: time, actualTime: &actualTime) else { return nil }
        return UIImage(cgImage: imgRef)
    }

    func sj_screenshot(with t: TimeInterval, size: CGSize, completionHandler block: @escaping (AVAsset, UIImage?, Error?) -> Void) {
        screenshotGenerator.cancelAllCGImageGeneration()
        let time = CMTimeMakeWithSeconds(t, preferredTimescale: Int32(NSEC_PER_SEC))
        screenshotGenerator.maximumSize = size
        screenshotGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, imageRef, _, result, error in
            guard let self = self, let asset = self.asset else { return }
            if result == .succeeded {
                if let imageRef = imageRef {
                    block(asset, UIImage(cgImage: imageRef), nil)
                }
            } else if result == .failed {
                block(asset, nil, error)
            }
        }
    }

    func sj_cancelScreenshotOperation() {
        screenshotGenerator.cancelAllCGImageGeneration()
    }
}

// MARK: - GIF 写入器

final class _SJGIFCreator: NSObject, @unchecked Sendable {
    private(set) var firstImage: UIImage?
    private var destination: CGImageDestination?
    private let frameProperties: NSDictionary

    init(savePath: URL, imagesCount count: Int32, interval: TimeInterval) {
        var interval = interval
        if interval < 0.02 { interval = 0.1 }
        try? FileManager.default.removeItem(at: savePath)
        let gifType: CFString
        if #available(iOS 14.0, *) {
            gifType = UTType.gif.identifier as CFString
        } else {
            gifType = kUTTypeGIF
        }
        destination = CGImageDestinationCreateWithURL(savePath as CFURL, gifType, Int(count), nil)
        let fileProperties: NSDictionary = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: interval]]
        super.init()
        if let destination = destination {
            CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        }
    }

    func addImage(_ imageRef: CGImage) {
        if firstImage == nil { firstImage = UIImage(cgImage: imageRef) }
        if let destination = destination {
            CGImageDestinationAddImage(destination, imageRef, frameProperties as CFDictionary)
        }
    }

    func finalizeGIF() -> Bool {
        guard let destination = destination else { return false }
        let result = CGImageDestinationFinalize(destination)
        self.destination = nil
        return result
    }

    deinit {
        destination = nil
    }
}

// MARK: - GIF 生成器

final class _SJAVAssetGIFGenerator: NSObject, @unchecked Sendable {
    let generator: AVAssetImageGenerator
    private(set) weak var asset: AVAsset?
    var creator: _SJGIFCreator?

    init(asset: AVAsset) {
        self.asset = asset
        self.generator = AVAssetImageGenerator(asset: asset)
        super.init()
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.appliesPreferredTrackTransform = true
    }

    func sj_generateGIF(beginTime: TimeInterval,
                        duration: TimeInterval,
                        imageMaxSize size: CGSize,
                        interval: Float,
                        toFile fileURL: URL,
                        progress progressBlock: @escaping (AVAsset, Float) -> Void,
                        success successBlock: @escaping (AVAsset, UIImage, UIImage) -> Void,
                        failure failureBlock: @escaping (AVAsset, Error) -> Void) {
        cancelGenerateGIFOperation()
        var interval = interval
        if interval < 0.02 { interval = 0.1 }
        var count = Int32(ceil(duration / Double(interval)))
        var timesM: [NSValue] = []
        for i in 0..<Int(count) {
            timesM.append(NSValue(time: CMTimeMakeWithSeconds(beginTime + Double(i) * Double(interval), preferredTimescale: Int32(NSEC_PER_SEC))))
        }
        generator.maximumSize = size
        self.creator = _SJGIFCreator(savePath: fileURL, imagesCount: count, interval: TimeInterval(interval))
        let all = count
        nonisolated(unsafe) let progressBlock = progressBlock
        nonisolated(unsafe) let successBlock = successBlock
        nonisolated(unsafe) let failureBlock = failureBlock
        generator.generateCGImagesAsynchronously(forTimes: timesM) { [weak self] _, imageRef, _, result, error in
            guard let self = self, let asset = self.asset else { return }
            switch result {
            case .succeeded:
                if let imageRef = imageRef {
                    self.creator?.addImage(imageRef)
                }
                nonisolated(unsafe) let asset = asset
                let progressValue = 1 - Float(count) * 1.0 / Float(all)
                DispatchQueue.main.async {
                    progressBlock(asset, progressValue)
                }
                count -= 1
                if count != 0 { return }
                let ok = self.creator?.finalizeGIF() ?? false
                nonisolated(unsafe) let image = Self.getImage(try? Data(contentsOf: fileURL), scale: UIScreen.main.scale)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let asset = self.asset else { return }
                    if !ok {
                        let error = NSError(domain: NSCocoaErrorDomain, code: -1, userInfo: ["msg": "Generate Gif Failed!"])
                        failureBlock(asset, error)
                    } else {
                        progressBlock(asset, 1)
                        if let image = image, let firstImage = self.creator?.firstImage {
                            successBlock(asset, image, firstImage)
                        }
                        self.creator = nil
                    }
                }
            case .failed:
                self.generator.cancelAllCGImageGeneration()
                nonisolated(unsafe) let error = error
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let asset = self.asset, let error = error else { return }
                    failureBlock(asset, error)
                }
            case .cancelled:
                break
            @unknown default:
                break
            }

            if result == .cancelled {
                self.creator = nil
            }
        }
    }

    func cancelGenerateGIFOperation() {
        generator.cancelAllCGImageGeneration()
    }

    // ref: YYKit UIImage(YYAdd)
    static func getImage(_ data: Data?, scale: CGFloat) -> UIImage? {
        guard let data = data else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        if count <= 1 {
            return UIImage(data: data, scale: scale)
        }

        var frames = [Int](repeating: 0, count: count)
        let oneFrameTime = 1.0 / 50.0 // 50 fps
        var duration: TimeInterval = 0
        var gcdFrame = 0
        for i in 0..<count {
            let delay = cgImageSourceGetGIFFrameDelay(source, index: i)
            duration += delay
            var frame = Int(lrint(delay / oneFrameTime))
            if frame < 1 { frame = 1 }
            frames[i] = frame
            if i == 0 {
                gcdFrame = frames[i]
            } else {
                var frame = frames[i]
                var tmp = 0
                if frame < gcdFrame {
                    tmp = frame; frame = gcdFrame; gcdFrame = tmp
                }
                while true {
                    tmp = frame % gcdFrame
                    if tmp == 0 { break }
                    frame = gcdFrame
                    gcdFrame = tmp
                }
            }
        }
        if gcdFrame == 0 { gcdFrame = 1 }
        var array: [UIImage] = []
        for i in 0..<count {
            guard let imageRef = CGImageSourceCreateImageAtIndex(source, i, nil) else { return nil }
            let width = imageRef.width
            let height = imageRef.height
            if width == 0 || height == 0 { return nil }

            let alphaInfo = CGImageAlphaInfo(rawValue: imageRef.alphaInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
            var hasAlpha = false
            if alphaInfo == .premultipliedLast ||
                alphaInfo == .premultipliedFirst ||
                alphaInfo == .last ||
                alphaInfo == .first {
                hasAlpha = true
            }
            var bitmapRaw = CGImageByteOrderInfo.order32Host.rawValue
            bitmapRaw |= hasAlpha ? CGImageAlphaInfo.premultipliedFirst.rawValue : CGImageAlphaInfo.noneSkipFirst.rawValue
            let space = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: bitmapRaw) else { return nil }
            context.draw(imageRef, in: CGRect(x: 0, y: 0, width: width, height: height)) // decode
            guard let decoded = context.makeImage() else { return nil }
            let image = UIImage(cgImage: decoded, scale: scale, orientation: .up)
            let max = frames[i] / gcdFrame
            for _ in 0..<max {
                array.append(image)
            }
        }
        return UIImage.animatedImage(with: array, duration: duration)
    }

    // ref: YYKit UIImage(YYAdd)
    static func cgImageSourceGetGIFFrameDelay(_ source: CGImageSource, index: Int) -> TimeInterval {
        var delay: TimeInterval = 0
        if let dic = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] {
            if let dicGIF = dic[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                var num = dicGIF[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
                if (num?.doubleValue ?? 0) <= Double(Float.ulpOfOne) {
                    num = dicGIF[kCGImagePropertyGIFDelayTime] as? NSNumber
                }
                delay = num?.doubleValue ?? 0
            }
        }
        if delay < 0.02 { delay = 0.1 }
        return delay
    }
}

// MARK: - AVAsset 扩展(对外 @objc API)

@objc public extension AVAsset {
    // - preview images -
    @objc(sj_generatePreviewImagesWithMaxItemSize:count:completionHandler:)
    func sj_generatePreviewImages(maxItemSize itemSize: CGSize,
                                  count: UInt,
                                  completionHandler block: @escaping (AVAsset, [UIImage]?, Error?) -> Void) {
        sj_imagesGenerator.generatePreviewImages(maxItemSize: itemSize, count: count, completionHandler: block)
    }

    @objc(sj_cancelGeneratePreviewImages)
    func sj_cancelGeneratePreviewImages() {
        let generator = objc_getAssociatedObject(self, &AssociatedKeys.imagesGenerator) as? _SJAVAssetPreviewImagesGenerator
        generator?.cancel()
    }

    // - export -
    /// preset name default is `AVAssetExportPresetMediumQuality`.
    @objc(sj_exportWithStartTime:duration:toFile:presetName:progress:success:failure:)
    func sj_export(startTime secs0: TimeInterval,
                   duration secs1: TimeInterval,
                   toFile fileURL: URL,
                   presetName: String?,
                   progress progressBlock: ((AVAsset, Float) -> Void)?,
                   success successBlock: ((AVAsset, AVAsset?, URL?, UIImage?) -> Void)?,
                   failure failureBlock: ((AVAsset, Error?) -> Void)?) {
        sj_assetExporter.export(startTime: secs0, duration: secs1, toFile: fileURL, presetName: presetName, progress: progressBlock, success: successBlock, failure: failureBlock)
    }

    @objc(sj_cancelExportOperation)
    func sj_cancelExportOperation() {
        let exporter = objc_getAssociatedObject(self, &AssociatedKeys.assetExporter) as? _SJAVAssetExporter
        exporter?.cancel()
    }

    // - screenshot -
    @objc(sj_screenshotWithTime:)
    func sj_screenshot(with time: CMTime) -> UIImage? {
        return sj_screenshotGenerator.sj_screenshot(with: time)
    }

    @objc(sj_screenshotWithTime:completionHandler:)
    func sj_screenshot(with time: TimeInterval,
                       completionHandler block: @escaping (AVAsset, UIImage?, Error?) -> Void) {
        sj_screenshot(with: time, size: .zero, completionHandler: block)
    }

    @objc(sj_screenshotWithTime:size:completionHandler:)
    func sj_screenshot(with time: TimeInterval,
                       size: CGSize,
                       completionHandler block: @escaping (AVAsset, UIImage?, Error?) -> Void) {
        sj_screenshotGenerator.sj_screenshot(with: time, size: size, completionHandler: block)
    }

    @objc(sj_cancelScreenshotOperation)
    func sj_cancelScreenshotOperation() {
        let generator = objc_getAssociatedObject(self, &AssociatedKeys.screenshotGenerator) as? _SJAVAssetScreenshotGenerator
        generator?.sj_cancelScreenshotOperation()
    }

    // - GIF -
    /// interval: The interval at which the image is captured, Recommended setting 0.1f.
    @objc(sj_generateGIFWithBeginTime:duration:imageMaxSize:interval:toFile:progress:success:failure:)
    func sj_generateGIF(beginTime: TimeInterval,
                        duration: TimeInterval,
                        imageMaxSize size: CGSize,
                        interval: Float,
                        toFile fileURL: URL,
                        progress progressBlock: @escaping (AVAsset, Float) -> Void,
                        success successBlock: @escaping (AVAsset, UIImage, UIImage) -> Void,
                        failure failureBlock: @escaping (AVAsset, Error) -> Void) {
        sj_GIFGenerator.sj_generateGIF(beginTime: beginTime, duration: duration, imageMaxSize: size, interval: interval, toFile: fileURL, progress: progressBlock, success: successBlock, failure: failureBlock)
    }

    @objc(sj_cancelGenerateGIFOperation)
    func sj_cancelGenerateGIFOperation() {
        let generator = objc_getAssociatedObject(self, &AssociatedKeys.gifGenerator) as? _SJAVAssetGIFGenerator
        generator?.cancelGenerateGIFOperation()
    }
}

// MARK: - 关联对象 lazy 缓存

private extension AVAsset {
    enum AssociatedKeys {
        nonisolated(unsafe) static var imagesGenerator = 0
        nonisolated(unsafe) static var assetExporter = 0
        nonisolated(unsafe) static var screenshotGenerator = 0
        nonisolated(unsafe) static var gifGenerator = 0
    }

    var sj_imagesGenerator: _SJAVAssetPreviewImagesGenerator {
        if let generator = objc_getAssociatedObject(self, &AssociatedKeys.imagesGenerator) as? _SJAVAssetPreviewImagesGenerator {
            return generator
        }
        let generator = _SJAVAssetPreviewImagesGenerator(asset: self)
        objc_setAssociatedObject(self, &AssociatedKeys.imagesGenerator, generator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return generator
    }

    var sj_assetExporter: _SJAVAssetExporter {
        if let exporter = objc_getAssociatedObject(self, &AssociatedKeys.assetExporter) as? _SJAVAssetExporter {
            return exporter
        }
        let exporter = _SJAVAssetExporter(asset: self)
        objc_setAssociatedObject(self, &AssociatedKeys.assetExporter, exporter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return exporter
    }

    var sj_screenshotGenerator: _SJAVAssetScreenshotGenerator {
        if let generator = objc_getAssociatedObject(self, &AssociatedKeys.screenshotGenerator) as? _SJAVAssetScreenshotGenerator {
            return generator
        }
        let generator = _SJAVAssetScreenshotGenerator(asset: self)
        objc_setAssociatedObject(self, &AssociatedKeys.screenshotGenerator, generator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return generator
    }

    var sj_GIFGenerator: _SJAVAssetGIFGenerator {
        if let generator = objc_getAssociatedObject(self, &AssociatedKeys.gifGenerator) as? _SJAVAssetGIFGenerator {
            return generator
        }
        let generator = _SJAVAssetGIFGenerator(asset: self)
        objc_setAssociatedObject(self, &AssociatedKeys.gifGenerator, generator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return generator
    }
}
