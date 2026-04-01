//
//  DiscourseEmojiView.swift
//  DiscourseAssetKit
//

import SwiftUI

public struct DiscourseEmojiView: View {
    private let assetName: String
    public var size: CGFloat = 14

    public var body: some View {
        Group {
            if let uiImage = EmojiImageCache.image(named: assetName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "questionmark.square")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(Self.humanReadableName(assetName)))
        .accessibilityAddTraits(.isImage)
    }

    private static func humanReadableName(_ assetName: String) -> String {
        var name = assetName
        if name.hasPrefix("emoji_") { name = String(name.dropFirst(6)) }
        return name.replacingOccurrences(of: "_", with: " ")
    }

    // MARK: - Initializers

    public init(emoji: DiscourseEmoji, size: CGFloat = 14) {
        self.assetName = emoji.rawValue
        self.size = size
    }

    /// shortcode w/ or w/o colon is both fine — resolves aliases automatically
    public init(shortcode: String, size: CGFloat = 14) {
        let canonical = EmojiResolver.canonicalize(shortcode)
        self.assetName = DiscourseEmoji.sanitizeShortcodeToAssetName(canonical)
        self.size = size
    }
}

#Preview {
    VStack(spacing: 12) {
        DiscourseEmojiView(emoji: .emojiMotorcycle, size: 40)
        DiscourseEmojiView(shortcode: ":grinning_face:", size: 40)
        HStack {
            DiscourseEmojiView(shortcode: "+1", size: 40)
            DiscourseEmojiView(shortcode: "-1", size: 40)
        }
        DiscourseEmojiView(shortcode: "xxx", size: 40)
    }
}
