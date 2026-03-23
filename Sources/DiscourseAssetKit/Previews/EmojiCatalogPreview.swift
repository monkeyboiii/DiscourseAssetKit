//
//  EmojiCatalogPreview.swift
//  DiscourseAssetKit
//

import SwiftUI

private struct EmojiCatalogPreview: View {
    @State private var searchText = ""

    private var filtered: [DiscourseEmoji] {
        if searchText.isEmpty { return Array(DiscourseEmoji.allCases) }
        return DiscourseEmoji.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 8) {
                    ForEach(filtered, id: \.self) { emoji in
                        VStack(spacing: 4) {
                            emoji.image
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(emoji.rawValue.replacingOccurrences(of: "emoji_", with: ""))
                                .font(.system(size: 7))
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Filter by asset name")
            .navigationTitle("Emoji Catalog (\(filtered.count)/\(DiscourseEmoji.allCases.count))")
        }
    }
}

#Preview("Emoji Catalog") {
    EmojiCatalogPreview()
}
