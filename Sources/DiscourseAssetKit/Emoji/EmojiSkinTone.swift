//
//  EmojiSkinTone.swift
//  DiscourseAssetKit
//

import SwiftUI

/// Discourse skin tone modifiers (t2–t6). Default means no modifier.
///
/// Tone-specific PNG assets are bundled in the asset catalog (e.g. "emoji_waving_hand_t2").
/// Use `EmojiResolver.resolvedImage(for:tone:)` to load the correct variant.
public enum EmojiSkinTone: Int, CaseIterable, Identifiable, Sendable {
    case `default` = 0   // no modifier — original yellow
    case light = 2       // :t2
    case mediumLight = 3 // :t3
    case medium = 4      // :t4
    case mediumDark = 5  // :t5
    case dark = 6        // :t6

    public var id: Int { rawValue }

    /// Discourse suffix appended to shortcode, e.g. ":t3"
    public var suffix: String {
        self == .default ? "" : ":t\(rawValue)"
    }

    /// Human-readable label for VoiceOver.
    public var accessibilityLabel: String {
        switch self {
        case .default:     "Default"
        case .light:       "Light skin tone"
        case .mediumLight: "Medium-light skin tone"
        case .medium:      "Medium skin tone"
        case .mediumDark:  "Medium-dark skin tone"
        case .dark:        "Dark skin tone"
        }
    }
}

// MARK: - Persistence

public enum EmojiTonePreference: Sendable {
    private static let key = "emoji_skin_tone_v1"

    @MainActor
    public static var current: EmojiSkinTone {
        get {
            let raw = UserDefaults.standard.integer(forKey: key)
            return EmojiSkinTone(rawValue: raw) ?? .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
