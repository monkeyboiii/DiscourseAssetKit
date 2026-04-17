//
//  ContentView.swift
//  DakDemo
//

import SwiftUI
import DiscourseAssetKit

struct ContentView: View {
    @State private var selection: String?
    @State private var showPicker = false
    @State private var showIcons = false
    @State private var showProfiler = false
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

            HStack(spacing: 12) {
                Button("Open Emoji Picker") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button("Open Icon Catalog") {
                    showIcons = true
                }
                .buttonStyle(.bordered)

                Button {
                    showProfiler.toggle()
                } label: {
                    Image(systemName: showProfiler ? "timer.circle.fill" : "timer")
                }
                .buttonStyle(.bordered)
                .tint(showProfiler ? .orange : nil)
            }
        }
        .padding()
        .sheet(isPresented: $showPicker) {
            ZStack(alignment: .bottom) {
                EmojiPickerView(selection: $selection, store: store)

                if showProfiler {
                    ProfilerView()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showProfiler)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showIcons) {
            ZStack(alignment: .bottom) {
                IconCatalogSheet()

                if showProfiler {
                    ProfilerView()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showProfiler)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
}
