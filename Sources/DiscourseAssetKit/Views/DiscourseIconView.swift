//
//  DiscourseIconView.swift
//  DiscourseAssetKit
//

import SwiftUI

public struct DiscourseIconView: View {
    public let icon: DiscourseIcon
    public var size: CGFloat
    public var color: Color

    public init(icon: DiscourseIcon, size: CGFloat = 14, color: Color = .secondary) {
        self.icon = icon
        self.size = size
        self.color = color
    }

    public var body: some View {
        icon.image
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityLabel(Text(icon.rawValue.replacingOccurrences(of: "-", with: " ")))
            .accessibilityAddTraits(.isImage)
    }
}
