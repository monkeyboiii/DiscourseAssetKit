//
//  Icon+Init.swift
//  DiscourseAssetKit
//
//  Created by Haotian Lu on 3/23/26.
//

import SwiftUI

extension DiscourseIcon {
    /// O(1) raw-value lookup (vs the default O(n) linear scan over 347 cases).
    private static let rawValueLookup: [String: DiscourseIcon] = {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) })
    }()

    /// Fast O(1) lookup by raw value. Prefer this over `init(rawValue:)`.
    public static func fromRawValue(_ rawValue: String) -> DiscourseIcon? {
        rawValueLookup[rawValue]
    }

    /// Initialize DiscourseIcon from Discourse API string (e.g., "comment", "bell", "#comment")
    ///
    /// This initializer handles various string formats from the Discourse API:
    /// - Direct matches: "comment" → .comment
    /// - With # prefix: "#comment" → .comment (strips prefix)
    /// - Kebab-case: "bell-slash" → .bellSlash (converts to camelCase)
    ///
    /// - Parameter rawString: The icon identifier from Discourse API
    /// - Returns: A DiscourseIcon if the string can be matched, nil otherwise
    ///
    /// Examples:
    /// ```swift
    /// DiscourseIcon(rawString: "comment")      // → .comment
    /// DiscourseIcon(rawString: "#comment")     // → .comment
    /// DiscourseIcon(rawString: "bell-slash")   // → .bellSlash
    /// DiscourseIcon(rawString: "invalid")      // → nil
    /// ```
    public init?(rawString: String) {
        // Strip # prefix if present (from web selectors like "#comment")
        let cleaned = rawString.hasPrefix("#")
            ? String(rawString.dropFirst())
            : rawString

        // Try direct match first (handles icons already in camelCase)
        if let icon = DiscourseIcon.fromRawValue(cleaned) {
            self = icon
            return
        }

        // Convert kebab-case to camelCase for enum lookup
        // e.g., "bell-slash" → "bellSlash"
        let components = cleaned.components(separatedBy: "-")
        let camelCased = components.enumerated()
            .map { index, component in
                index == 0 ? component : component.capitalized
            }
            .joined()

        // Try camelCase version
        if let icon = DiscourseIcon.fromRawValue(camelCased) {
            self = icon
        } else {
            return nil
        }
    }
}
