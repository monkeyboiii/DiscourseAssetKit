//
//  EmojiImageCache.swift
//  DiscourseAssetKit
//

import SwiftUI
import UIKit

/// Centralized emoji image loader with NSCache.
///
/// Flat PNGs in `Resources/Emojis/` are bundled via `.copy()` (no actool).
/// `UIImage(contentsOfFile:)` has no system cache, so we maintain our own.
enum EmojiImageCache: Sendable {
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

    static func image(named assetName: String) -> UIImage? {
        let key = assetName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = Bundle.module.url(forResource: assetName, withExtension: "png", subdirectory: "Emojis"),
              let img = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(img, forKey: key)
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
