//
//  EmojiText.swift
//  DiscourseAssetKit
//
//  Renders text with inline Discourse emoji images for :shortcode: patterns.
//

import SwiftUI

public struct EmojiText: View {
    public let rawText: String
    public var emojiSize: CGFloat = 18

    public init(rawText: String, emojiSize: CGFloat = 18) {
        self.rawText = rawText
        self.emojiSize = emojiSize
    }

    public var body: some View {
        buildText()
            .accessibilityLabel(Text(accessibleDescription))
    }

    private func buildText() -> Text {
        // Pass 1: Replace :shortcode: patterns
        let segments = replaceShortcodes(in: rawText)
        // Pass 2: Scan plain-text segments for Unicode emoji characters
        var result = Text("")
        for segment in segments {
            switch segment {
            case .image(let img):
                result = result + Text(Image(uiImage: img))
            case .text(let str):
                result = result + replaceUnicodeEmoji(in: str)
            }
        }
        return result
    }

    /// Builds a VoiceOver-friendly string: shortcodes and Unicode emoji become readable names.
    private var accessibleDescription: String {
        // Replace :shortcode: with readable name
        let pattern = /:([a-zA-Z0-9_+-]+(?::t[2-6])?):/
        var text = rawText
        while let match = text.firstMatch(of: pattern) {
            let code = String(match.output.1).split(separator: ":").first.map(String.init) ?? String(match.output.1)
            let readable = code.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
            text.replaceSubrange(match.range, with: readable)
        }
        // Replace Unicode emoji with their resolved names
        var result = ""
        for char in text {
            if let resolved = EmojiResolver.resolveUnicodeWithTone(String(char)) {
                var name = resolved.emoji.rawValue
                if name.hasPrefix("emoji_") { name = String(name.dropFirst(6)) }
                result += name.replacingOccurrences(of: "_", with: " ")
            } else {
                result.append(char)
            }
        }
        return result
    }

    // MARK: - Pass 1: Shortcode replacement

    private enum TextSegment {
        case text(String)
        case image(UIImage)
    }

    private func replaceShortcodes(in input: String) -> [TextSegment] {
        // Match :shortcode: or :shortcode:tN: (tone suffix, N = 2–6)
        let pattern = /:([a-zA-Z0-9_+-]+(?::t[2-6])?):/
        var segments: [TextSegment] = []
        var remaining = input[...]

        while let match = remaining.firstMatch(of: pattern) {
            let before = remaining[remaining.startIndex..<match.range.lowerBound]
            if !before.isEmpty {
                segments.append(.text(String(before)))
            }

            let fullShortcode = String(match.output.1) // e.g. "+1:t3" or "wave"
            if let resolved = EmojiResolver.resolveWithTone(fullShortcode),
               let uiImage = EmojiResolver.resolvedImage(for: resolved.emoji, tone: resolved.tone) {
                let scaled = uiImage.resized(to: CGSize(width: emojiSize, height: emojiSize))
                segments.append(.image(scaled))
            } else {
                segments.append(.text(":\(fullShortcode):"))
            }

            remaining = remaining[match.range.upperBound...]
        }

        if !remaining.isEmpty {
            segments.append(.text(String(remaining)))
        }

        return segments
    }

    // MARK: - Pass 2: Unicode emoji replacement

    private func replaceUnicodeEmoji(in input: String) -> Text {
        var result = Text("")
        var pending = ""

        for char in input {
            let str = String(char)
            if let resolved = EmojiResolver.resolveUnicodeWithTone(str),
               let uiImage = EmojiResolver.resolvedImage(for: resolved.emoji, tone: resolved.tone) {
                // Flush pending plain text
                if !pending.isEmpty {
                    result = result + Text(pending)
                    pending = ""
                }
                let scaled = uiImage.resized(to: CGSize(width: emojiSize, height: emojiSize))
                result = result + Text(Image(uiImage: scaled))
            } else {
                pending.append(char)
            }
        }

        if !pending.isEmpty {
            result = result + Text(pending)
        }

        return result
    }
}

// MARK: - UIImage Scaling

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        EmojiText(rawText: "React to posts :waving_hand: and share :heart: love")
        EmojiText(rawText: "No emojis here, just plain text.")
        EmojiText(rawText: ":motorcycle: Ride on! :+1:")
        EmojiText(rawText: "Unknown :xyznotreal: emoji fallback")
        EmojiText(rawText: "Unicode: Great post! 😀👍")
        EmojiText(rawText: "Mixed :wave: hello 😀 world :heart:")
    }
    .padding()
}
