//
//  IconCatalogSheet.swift
//  DakDemo
//

import SwiftUI
import DiscourseAssetKit

struct IconCatalogSheet: View {
    @State private var searchText = ""

    private var filtered: [DiscourseIcon] {
        if searchText.isEmpty { return DiscourseIcon.allCases }
        return DiscourseIcon.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                    ForEach(filtered, id: \.self) { icon in
                        VStack(spacing: 4) {
                            DiscourseIconView(icon: icon, size: 20, color: .primary)
                            Text(icon.rawValue)
                                .font(.system(size: 8))
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Filter by name")
            .navigationTitle("Icons (\(DiscourseIcon.allCases.count))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    IconCatalogSheet()
}
