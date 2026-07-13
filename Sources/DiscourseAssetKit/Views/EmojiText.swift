//
//  EmojiText.swift
//  DiscourseAssetKit
//
//  Renders text with inline Discourse emoji images for :shortcode: patterns.
//  Per-pass cost is memoized; see DAK_EMOJITEXT_PERF_PLAN.md (umbrella root).
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
        let render = cachedRender()
        render.text
            .accessibilityLabel(Text(render.accessibleText))
    }

    // MARK: - Render memoization

    /// Built `Text` + VoiceOver string for one (rawText, emojiSize); boxed for NSCache.
    private final class CachedRender {
        let text: Text
        let accessibleText: String
        init(text: Text, accessibleText: String) {
            self.text = text
            self.accessibleText = accessibleText
        }
    }

    @MainActor private static let renderCache: NSCache<NSString, CachedRender> = {
        let cache = NSCache<NSString, CachedRender>()
        cache.countLimit = 256
        return cache
    }()

    @MainActor
    private func cachedRender() -> CachedRender {
        if Self.isPlainText(rawText) {
            return CachedRender(text: Text(rawText), accessibleText: rawText)
        }
        // The size suffix is a single CGFloat description (no "|"), so keys parse
        // unambiguously from the right — no rawText collision is possible.
        let key = "\(rawText)|\(emojiSize)" as NSString
        if let cached = Self.renderCache.object(forKey: key) {
            return cached
        }
        let render = CachedRender(text: buildText(), accessibleText: accessibleDescription)
        Self.renderCache.setObject(render, forKey: key)
        return render
    }

    /// Scalars of replacement-table keys that lack the Unicode Emoji property
    /// (currently ♡ U+2661, ☻ U+263B) — the fast path must not skip them.
    /// Derived from the table so regeneration can't silently break the fast path.
    private static let nonEmojiPropertyKeyScalars: Set<Unicode.Scalar> = {
        var scalars = Set<Unicode.Scalar>()
        for key in EmojiReplacementTable.unicodeToShortcode.keys
        where !key.unicodeScalars.contains(where: { $0.properties.isEmoji }) {
            scalars.formUnion(key.unicodeScalars)
        }
        return scalars
    }()

    /// True when the pipeline cannot change the string: no ":" (shortcodes) and no
    /// scalar that any `EmojiReplacementTable.unicodeToShortcode` key contains
    /// (Emoji property + the exception set above; exhaustively asserted in tests).
    static func isPlainText(_ text: String) -> Bool {
        !text.contains(":") && !text.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji || nonEmojiPropertyKeyScalars.contains(scalar)
        }
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
    var accessibleDescription: String {
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
               let scaled = EmojiResolver.resolvedResizedImage(for: resolved.emoji, tone: resolved.tone, size: emojiSize) {
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
               let scaled = EmojiResolver.resolvedResizedImage(for: resolved.emoji, tone: resolved.tone, size: emojiSize) {
                // Flush pending plain text
                if !pending.isEmpty {
                    result = result + Text(pending)
                    pending = ""
                }
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
