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

    /// Swatch color shown in the tone picker UI
    public var swatchColor: Color {
        switch self {
        case .default:     return Color(red: 1.0, green: 0.8, blue: 0.25)     // emoji yellow
        case .light:       return Color(red: 0.99, green: 0.87, blue: 0.73)    // #FDDEB5
        case .mediumLight: return Color(red: 0.89, green: 0.73, blue: 0.55)    // #E3BA8C
        case .medium:      return Color(red: 0.72, green: 0.54, blue: 0.36)    // #B8895C
        case .mediumDark:  return Color(red: 0.55, green: 0.38, blue: 0.24)    // #8C613C
        case .dark:        return Color(red: 0.38, green: 0.24, blue: 0.14)    // #603D23
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
