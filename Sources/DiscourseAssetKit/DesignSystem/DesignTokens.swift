//
//  DesignTokens.swift
//  DiscourseAssetKit
//

import SwiftUI

/// Shared spacing, sizing, and radius constants for consistent UI.
enum DesignTokens {

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 16
    }

    // MARK: - Picker Sizing

    enum Picker {
        static let minCellSize: CGFloat = 44
        static let emojiSize: CGFloat = 28
        static let railButtonSize: CGFloat = 34
        static let railIconSize: CGFloat = 18
        static let toneSwatchSize: CGFloat = 30
        static let toneIndicatorSize: CGFloat = 32
        static let previewEmojiSize: CGFloat = 64
    }
}
