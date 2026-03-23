//
//  EmojiResolver.swift
//  DiscourseAssetKit
//

import Foundation
import UIKit

/// Single point of shortcode resolution.
/// Handles alias canonicalization before asset name lookup.
public enum EmojiResolver {

    /// Resolve an alias to its canonical name.
    /// e.g. "racing_motorcycle" -> "motorcycle", "motorcycle" -> "motorcycle"
    public static func canonicalize(_ shortcode: String) -> String {
        let stripped = shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return EmojiAliasTable.aliases[stripped] ?? stripped
    }

    /// Full pipeline: shortcode -> canonical -> asset name -> DiscourseEmoji
    public static func resolve(_ shortcode: String) -> DiscourseEmoji? {
        let canonical = canonicalize(shortcode)
        let assetName = DiscourseEmoji.sanitizeShortcodeToAssetName(":\(canonical):")
        return DiscourseEmoji(rawValue: assetName)
    }

    // MARK: - Unicode Replacement

    /// Given a Unicode emoji character (e.g. "😀"), return the canonical shortcode or nil.
    public static func shortcodeForUnicode(_ char: String) -> String? {
        EmojiReplacementTable.unicodeToShortcode[char]
    }

    /// Given emoticon text like ":)", return canonical shortcode or nil.
    public static func shortcodeForEmoticon(_ text: String) -> String? {
        EmojiReplacementTable.emoticonToShortcode[text]
    }

    /// Resolve a Unicode emoji character to a DiscourseEmoji asset.
    public static func resolveUnicode(_ char: String) -> DiscourseEmoji? {
        guard let shortcode = shortcodeForUnicode(char) else { return nil }
        // Strip tone suffix if present (e.g. "+1:t2" -> "+1")
        let base = shortcode.split(separator: ":").first.map(String.init) ?? shortcode
        return resolve(base)
    }

    /// Resolve a Unicode emoji character, returning both asset and tone info.
    public static func resolveUnicodeWithTone(_ char: String) -> ResolvedEmoji? {
        guard let shortcode = shortcodeForUnicode(char) else { return nil }
        // Parse tone suffix: "+1:t2" -> base="+1", tone=.light
        let parts = shortcode.split(separator: ":", maxSplits: 2)
        let baseName = String(parts[0])
        let tone: EmojiSkinTone
        if parts.count >= 2, let toneStr = parts.last, toneStr.hasPrefix("t"),
           let toneNum = Int(toneStr.dropFirst()),
           let parsed = EmojiSkinTone(rawValue: toneNum) {
            tone = parsed
        } else {
            tone = .default
        }

        let canonical = canonicalize(baseName)
        guard let emoji = resolve(baseName) else { return nil }
        let isTonable = EmojiToneTable.tonableEmojis.contains(canonical)
        return ResolvedEmoji(emoji: emoji, tone: isTonable ? tone : .default, isTonable: isTonable)
    }

    // MARK: - Skin Tone Resolution

    /// Resolved emoji with optional skin tone information.
    public struct ResolvedEmoji: Sendable {
        public let emoji: DiscourseEmoji
        public let tone: EmojiSkinTone
        public let isTonable: Bool
    }

    /// Parse a shortcode that may contain a tone suffix (e.g. "+1:t3", "wave:t5")
    /// and resolve to a DiscourseEmoji + tone.
    public static func resolveWithTone(_ shortcode: String) -> ResolvedEmoji? {
        let stripped = shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":"))

        // Check for tone suffix: "name:tN" where N is 2–6
        let baseName: String
        let tone: EmojiSkinTone
        if let colonIdx = stripped.lastIndex(of: ":"),
           stripped[stripped.index(after: colonIdx)...].hasPrefix("t") {
            let suffix = stripped[stripped.index(after: colonIdx)...]  // "tN"
            if let toneNum = Int(suffix.dropFirst()),
               let parsed = EmojiSkinTone(rawValue: toneNum) {
                baseName = String(stripped[..<colonIdx])
                tone = parsed
            } else {
                baseName = stripped
                tone = .default
            }
        } else {
            baseName = stripped
            tone = .default
        }

        let canonical = canonicalize(baseName)
        let assetName = DiscourseEmoji.sanitizeShortcodeToAssetName(":\(canonical):")
        guard let emoji = DiscourseEmoji(rawValue: assetName) else { return nil }

        let isTonable = EmojiToneTable.tonableEmojis.contains(canonical)
        return ResolvedEmoji(emoji: emoji, tone: isTonable ? tone : .default, isTonable: isTonable)
    }

    // MARK: - Image Loading

    /// Load the appropriate emoji image for the given tone.
    /// Uses actual tone-specific PNG assets (e.g. "emoji_waving_hand_t2").
    /// Falls back to base asset if tone variant is missing.
    public static func resolvedImage(for emoji: DiscourseEmoji, tone: EmojiSkinTone) -> UIImage? {
        guard tone != .default else {
            return UIImage(named: emoji.rawValue, in: .module, compatibleWith: nil)
        }
        let toneAssetName = "\(emoji.rawValue)_t\(tone.rawValue)"
        return UIImage(named: toneAssetName, in: .module, compatibleWith: nil)
            ?? UIImage(named: emoji.rawValue, in: .module, compatibleWith: nil)
    }

    /// Check if a given canonical shortcode supports skin tones.
    public static func isTonable(_ shortcode: String) -> Bool {
        let canonical = canonicalize(shortcode)
        return EmojiToneTable.tonableEmojis.contains(canonical)
    }
}
