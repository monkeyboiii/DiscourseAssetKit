//
//  ContentView.swift
//  DakDemo
//

import SwiftUI
import DiscourseAssetKit

struct ContentView: View {
    @State private var selection: String?
    @State private var showPicker = false
    @State private var store = EmojiPickerStore()

    var body: some View {
        VStack(spacing: 24) {
            Text("DiscourseAssetKit Demo")
                .font(.headline)

            if let selection {
                DiscourseEmojiView(shortcode: selection, size: 64)
                Text(":\(selection):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 64))
                    .foregroundStyle(.quaternary)
                Text("No emoji selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Emoji Picker") {
                showPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showPicker) {
            EmojiPickerView(selection: $selection, store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
}
