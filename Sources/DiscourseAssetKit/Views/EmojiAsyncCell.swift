//
//  EmojiAsyncCell.swift
//  DiscourseAssetKit
//

import os
import SwiftUI

/// Async-loading emoji cell for use in scrollable grids.
///
/// Uses `.task(id:)` to load images off the main thread, eliminating
/// scroll hitches from synchronous file I/O during fast scrolling.
/// Cache hits resolve instantly (no placeholder flash).
public struct EmojiAsyncCell: View {
    public let item: EmojiItem
    public let size: CGFloat
    public let tone: EmojiSkinTone

    @State private var uiImage: UIImage?

    #if DEBUG
    private static let logger = Logger(subsystem: "DiscourseAssetKit", category: "EmojiAsyncCell")
    #endif

    public init(item: EmojiItem, size: CGFloat, tone: EmojiSkinTone) {
        self.item = item
        self.size = size
        self.tone = tone
    }

    private var resolvedName: String {
        if item.tonable && tone != .default {
            return "\(item.emoji.rawValue)_t\(tone.rawValue)"
        }
        return item.emoji.rawValue
    }

    public var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .task(id: resolvedName, priority: .userInitiated) {
            #if DEBUG
            let start = CFAbsoluteTimeGetCurrent()
            #endif
            let name = resolvedName
            // Sync cache check — instant for warm cache
            if let cached = EmojiImageCache.cachedImage(named: name) {
                uiImage = cached
                #if DEBUG
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                Self.logger.trace("cache hit '\(name)' in \(elapsed, format: .fixed(precision: 2))ms")
                #endif
                return
            }
            // Tone fallback: check base asset in cache
            if item.tonable && tone != .default,
               let cached = EmojiImageCache.cachedImage(named: item.emoji.rawValue) {
                uiImage = cached
                #if DEBUG
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                Self.logger.trace("cache hit (base fallback) '\(item.emoji.rawValue)' in \(elapsed, format: .fixed(precision: 2))ms")
                #endif
                return
            }
            // Async disk load — off main thread
            var img = await EmojiImageCache.loadImageAsync(named: name)
            if img == nil {
                img = await EmojiImageCache.loadImageAsync(named: item.emoji.rawValue)
            }
            if !Task.isCancelled {
                uiImage = img
            }
            #if DEBUG
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            Self.logger.trace("async load '\(name)' in \(elapsed, format: .fixed(precision: 2))ms")
            #endif
        }
    }
}

// MARK: - Sync cell image (for non-scroll contexts)

/// Synchronous emoji cell image for single-use contexts (preview overlay, etc).
@MainActor @ViewBuilder
func emojiCellImage(item: EmojiItem, size: CGFloat, tone: EmojiSkinTone) -> some View {
    if item.tonable && tone != .default,
       let tinted = EmojiResolver.resolvedImage(for: item.emoji, tone: tone) {
        Image(uiImage: tinted)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    } else {
        DiscourseEmojiView(emoji: item.emoji, size: size)
    }
}

// MARK: - Preview

#Preview("EmojiAsyncCell") {
    let store = EmojiPickerStore()
    let sampleItems = Array(store.allItems.prefix(20))

    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Async Cells (scroll-optimized)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(sampleItems) { item in
                    EmojiAsyncCell(item: item, size: 28, tone: .default)
                        .frame(width: 44, height: 44)
                }
            }

            Divider()

            Text("Sync Cells (comparison)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(sampleItems) { item in
                    emojiCellImage(item: item, size: 28, tone: .default)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding()
    }
}
