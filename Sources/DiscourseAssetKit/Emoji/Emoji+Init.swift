//
//  DiscourseEmojiView.swift
//  DiscourseAssetKit
//
//  Created by Haotian Lu on 12/17/25.
//

import SwiftUI

extension DiscourseEmoji {
    /// O(1) raw-value lookup (vs the default O(n) linear scan over 1,904 cases).
    private static let rawValueLookup: [String: DiscourseEmoji] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) })
    }()

    /// Fast O(1) lookup by raw value. Prefer this over `init(rawValue:)`.
    public static func fromRawValue(_ rawValue: String) -> DiscourseEmoji? {
        rawValueLookup[rawValue]
    }

    /// reference logic in https://github.com/monkeyboiii/discourse-assets/blob/main/discourse_emojis.py#L52-L66
    public static func sanitizeShortcodeToAssetName(_ shortcodeWithColons: String) -> String {
        let colonSet = CharacterSet(charactersIn: ":")
        var shortcode = shortcodeWithColons.trimmingCharacters(in: colonSet)

        if shortcode == "+1" {
            shortcode = "plus_one"
        } else if shortcode == "-1" {
            shortcode = "minus_one"
        }

        shortcode = shortcode.replacingOccurrences(
            of: "[^A-Za-z0-9_]+",
            with: "_",
            options: .regularExpression
        )
        shortcode = shortcode.replacingOccurrences(
            of: "_+",
            with: "_",
            options: .regularExpression
        )

        let underscoreSet = CharacterSet(charactersIn: "_")
        shortcode = shortcode.trimmingCharacters(in: underscoreSet)

        if shortcode.isEmpty {
            shortcode = "unknown"
        }

        return "emoji_\(shortcode)"
    }

    public init?(shortcodeWithColons: String) {
        let canonical = EmojiResolver.canonicalize(shortcodeWithColons)
        guard let match = Self.fromRawValue(Self.sanitizeShortcodeToAssetName(canonical)) else { return nil }
        self = match
    }
}
