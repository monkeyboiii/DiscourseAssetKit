//
//  EmojiImageCache.swift
//  DiscourseAssetKit
//

import os
import SwiftUI
import UIKit

/// Centralized emoji image loader with NSCache.
///
/// Flat PNGs in `Resources/Emojis/` are bundled via `.copy()` (no actool).
/// `UIImage(contentsOfFile:)` has no system cache, so we maintain our own.
///
/// Two tiers: decoded source PNGs (cost-bounded) and per-size resized bitmaps
/// (count-bounded) so `EmojiText` re-renders never repeat a CoreGraphics resize.
/// See DAK_EMOJITEXT_PERF_PLAN.md (umbrella root) for the F23/F48 rationale.
///
/// Three access patterns:
/// - `image(named:)` — **sync**, file I/O + decode on caller thread. Use for non-scroll contexts.
/// - `cachedImage(named:)` — **sync**, cache-only O(1) check, no file I/O.
/// - `loadImageAsync(named:)` — **async**, file I/O + decode on background thread. Use in scroll contexts.
public enum EmojiImageCache: Sendable {
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()
    nonisolated(unsafe) private static let resizedCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 512
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()
    #if DEBUG
    private static let logger = Logger(subsystem: "DiscourseAssetKit", category: "EmojiImageCache")
    /// Test hook: increments on every actual renderer pass (resized-cache miss).
    nonisolated(unsafe) static var debugResizeCount = 0
    #endif

    /// Synchronous load — file I/O + decode on caller thread.
    static func image(named assetName: String) -> UIImage? {
        let key = assetName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        #endif
        guard let url = Bundle.module.url(forResource: assetName, withExtension: "png", subdirectory: "Emojis"),
              let img = UIImage(contentsOfFile: url.path)?.preparingForDisplay() else {
            return nil
        }
        cache.setObject(img, forKey: key, cost: pixelCost(of: img))
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.trace("sync load '\(assetName)' in \(elapsed, format: .fixed(precision: 2))ms")
        #endif
        return img
    }

    /// Cache-only check — no file I/O, O(1).
    public static func cachedImage(named assetName: String) -> UIImage? {
        cache.object(forKey: assetName as NSString)
    }

    /// Async load — file I/O + decode on background thread, caches result.
    public static func loadImageAsync(named assetName: String) async -> UIImage? {
        let key = assetName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        #endif
        let img = await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.module.url(forResource: assetName, withExtension: "png", subdirectory: "Emojis"),
                  let img = UIImage(contentsOfFile: url.path)?.preparingForDisplay() else {
                return nil as UIImage?
            }
            return img
        }.value
        guard let img else { return nil }
        cache.setObject(img, forKey: key, cost: pixelCost(of: img))
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.trace("async load '\(assetName)' in \(elapsed, format: .fixed(precision: 2))ms")
        #endif
        return img
    }

    /// Resized-bitmap lookup — one renderer pass per unique (asset, size), O(1) after.
    static func resizedImage(named assetName: String, size: CGFloat) -> UIImage? {
        let key = "\(assetName)|\(size)" as NSString
        if let cached = resizedCache.object(forKey: key) {
            return cached
        }
        guard let base = image(named: assetName) else { return nil }
        let resized = base.resized(to: CGSize(width: size, height: size))
        #if DEBUG
        debugResizeCount += 1
        #endif
        resizedCache.setObject(resized, forKey: key, cost: pixelCost(of: resized))
        return resized
    }

    private static func pixelCost(of image: UIImage) -> Int {
        Int(image.size.width * image.scale * image.size.height * image.scale * 4)
    }
}

// MARK: - UIImage Scaling

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - DiscourseEmoji .image (replaces generated xcassets version)

extension DiscourseEmoji {
    public var image: Image {
        if let uiImage = EmojiImageCache.image(named: self.rawValue) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "questionmark.square")
    }
}
