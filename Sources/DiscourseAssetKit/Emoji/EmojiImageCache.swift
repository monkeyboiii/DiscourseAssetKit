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
/// Three access patterns:
/// - `image(named:)` — **sync**, file I/O + decode on caller thread. Use for non-scroll contexts.
/// - `cachedImage(named:)` — **sync**, cache-only O(1) check, no file I/O.
/// - `loadImageAsync(named:)` — **async**, file I/O + decode on background thread. Use in scroll contexts.
public enum EmojiImageCache: Sendable {
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()
    #if DEBUG
    private static let logger = Logger(subsystem: "DiscourseAssetKit", category: "EmojiImageCache")
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
        cache.setObject(img, forKey: key)
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
        cache.setObject(img, forKey: key)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.trace("async load '\(assetName)' in \(elapsed, format: .fixed(precision: 2))ms")
        #endif
        return img
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
