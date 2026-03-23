//
//  EmojiPickerPreview.swift
//  DiscourseAssetKit
//

import SwiftUI

private struct EmojiPickerDemoPreview: View {
    @State private var selection: String? = "grinning_face"
    @State private var isPresented = false
    @State private var store = EmojiPickerStore(
        repo: EmojiMetadataRepository(config: .init(
            endpoint: URL(string: "https://example.com/emojis.json")!,
            bundledResourceName: "emojis",
            bundledResourceExt: "json",
            cacheFileName: "emojis.remote.json"
        ))
    )

    var body: some View {
        VStack(spacing: 16) {
            Button {
                isPresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)

                    if let selection {
                        DiscourseEmojiView(shortcode: selection, size: 24)
                    } else {
                        Image(systemName: "face.smiling")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            debugInfo
        }
        .padding()
        .sheet(isPresented: $isPresented) {
            EmojiPickerView(selection: $selection, store: store)
                .presentationDetents([.medium, .large])
        }
    }

    private var debugInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let selection, let item = store.allItems.first(where: { $0.baseName == selection }) {
                Text("Group: \(groupName(for: item))")
                Text("Name: \(item.baseName)")
                Text("URL: \(item.url ?? "-")")
                Text("Aliases: \(item.aliases.isEmpty ? "-" : item.aliases.joined(separator: ", "))")
            } else {
                Text("Group: -")
                Text("Name: -")
                Text("URL: -")
                Text("Aliases: -")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupName(for item: EmojiItem) -> String {
        store.groups.first(where: { $0.id == item.groupId })?.displayName ?? item.groupId
    }
}

#Preview {
    EmojiPickerDemoPreview()
}
