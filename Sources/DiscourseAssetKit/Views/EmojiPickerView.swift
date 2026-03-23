//
//  EmojiPickerView.swift
//  DiscourseAssetKit
//
//  Created by Haotian Lu on 2/4/26.
//

import SwiftUI
import UIKit

public struct EmojiPickerView: View {
    @Binding var selection: String?
    @Bindable var store: EmojiPickerStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    @State private var searchText = ""
    @State private var activeCategoryId = EmojiGroup.recents.id
    @State private var lastNonSearchCategoryId = EmojiGroup.recents.id
    @State private var recentIds: [String] = []
    @State private var previewItem: EmojiItem?
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedTone: EmojiSkinTone = EmojiTonePreference.current
    @State private var showTonePicker = false

    @State private var scrollProxy: ScrollViewProxy?

    private let scrollCoordinateSpace = "emoji-picker-scroll"
    private let minCellSize: CGFloat = 44
    private let emojiSize: CGFloat = 28
    private let railButtonSize: CGFloat = 34
    private let railIconSize: CGFloat = 18

    public init(selection: Binding<String?>, store: EmojiPickerStore) {
        self._selection = selection
        self.store = store
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 12) {
                topBar

                HStack(spacing: 12) {
                    categoryRail
                    Divider()
                    contentArea
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            )

            if let previewItem {
                previewOverlay(previewItem)
            }
        }
        .onAppear {
            reloadRecents()
        }
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let target = lastNonSearchCategoryId
                scrollToCategory(target)
            } else {
                lastNonSearchCategoryId = activeCategoryId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenMaxY = UIScreen.main.bounds.maxY
            let overlap = max(0, screenMaxY - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .padding(.bottom, isSearchFocused ? keyboardHeight : 0)
        .animation(.easeOut(duration: 0.2), value: keyboardHeight)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            searchPill
                .frame(maxWidth: .infinity)
            topRightIndicator
        }
    }

    private var searchPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search by emoji name and alias...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var topRightIndicator: some View {
        Button {
            showTonePicker.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(selectedTone == .default ? Color(.systemGray5) : selectedTone.swatchColor)
                Image(systemName: "hand.wave")
                    .font(.system(size: 16))
                    .foregroundColor(selectedTone == .default ? .secondary : .white)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Skin tone options"))
        .popover(isPresented: $showTonePicker, arrowEdge: .top) {
            tonePickerContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var tonePickerContent: some View {
        HStack(spacing: 6) {
            ForEach(EmojiSkinTone.allCases) { tone in
                Button {
                    selectedTone = tone
                    EmojiTonePreference.current = tone
                    showTonePicker = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(tone.swatchColor)
                            .frame(width: 30, height: 30)

                        if tone == selectedTone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(tone == .default || tone == .light ? .black : .white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(toneAccessibilityLabel(tone)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func toneAccessibilityLabel(_ tone: EmojiSkinTone) -> String {
        switch tone {
        case .default:     return "Default"
        case .light:       return "Light skin tone"
        case .mediumLight: return "Medium-light skin tone"
        case .medium:      return "Medium skin tone"
        case .mediumDark:  return "Medium-dark skin tone"
        case .dark:        return "Dark skin tone"
        }
    }

    private var categoryRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(categories, id: \.id) { group in
                    Button {
                        activeCategoryId = group.id
                        lastNonSearchCategoryId = group.id
                        if !searchText.isEmpty {
                            searchText = ""
                        }
                        scrollToCategory(group.id)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isCategoryActive(group.id) ? Color.accentColor : Color(.systemGray5))
                            DiscourseEmojiView(emoji: group.discourseIcon, size: railIconSize)
                        }
                        .frame(width: railButtonSize, height: railButtonSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(group.displayName))
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: railButtonSize)
    }

    private var contentArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        groupedContent
                    } else {
                        resultsContent
                    }
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .coordinateSpace(name: scrollCoordinateSpace)
            .onPreferenceChange(SectionHeaderPreferenceKey.self) { values in
                guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                updateActiveCategory(from: values)
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !recentIds.isEmpty {
                recentsSection
            }

            ForEach(store.groups, id: \.id) { group in
                sectionHeader(title: group.displayName, id: group.id, showsClear: false)
                if let items = store.itemsByGroup[group.id] {
                    emojiGrid(items: items)
                }
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: EmojiGroup.recents.displayName,
                id: EmojiGroup.recents.id,
                showsClear: !recentIds.isEmpty
            )
            let recentsItems = recentItems
            if recentsItems.isEmpty {
                Text("No recent emojis yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                emojiGrid(items: recentsItems)
            }
        }
    }

    private var resultsContent: some View {
        let results = store.search(searchText)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if results.isEmpty {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                emojiGrid(items: results)
            }
        }
    }

    private func sectionHeader(title: String, id: String, showsClear: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            if showsClear {
                Button {
                    EmojiRecents.clear()
                    reloadRecents()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear recents"))
            }
        }
        .id(id)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SectionHeaderPreferenceKey.self,
                    value: [id: proxy.frame(in: .named(scrollCoordinateSpace)).minY]
                )
            }
        )
    }

    private func emojiGrid(items: [EmojiItem]) -> some View {
        let columns = [GridItem(.adaptive(minimum: minCellSize), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                Button {
                    var name = item.baseName
                    if item.tonable && selectedTone != .default {
                        name += selectedTone.suffix
                    }
                    selection = name
                    EmojiRecents.push(item.id)
                    reloadRecents()
                    dismiss()
                } label: {
                    emojiCellImage(item: item, size: emojiSize)
                        .frame(width: minCellSize, height: minCellSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EmojiCellButtonStyle())
                .accessibilityLabel(Text(prettyName(item.baseName)))
                .onLongPressGesture(
                    minimumDuration: 0.35,
                    maximumDistance: 20,
                    pressing: { isPressing in
                        if isPressing {
                            previewItem = item
                        } else if previewItem?.id == item.id {
                            previewItem = nil
                        }
                    },
                    perform: {}
                )
            }
        }
        .id(selectedTone)
    }

    @ViewBuilder
    private func emojiCellImage(item: EmojiItem, size: CGFloat) -> some View {
        if item.tonable && selectedTone != .default,
           let tinted = EmojiResolver.resolvedImage(for: item.emoji, tone: selectedTone) {
            Image(uiImage: tinted)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            DiscourseEmojiView(emoji: item.emoji, size: size)
        }
    }

    private func previewOverlay(_ item: EmojiItem) -> some View {
        ZStack {
            Color.black.opacity(0.2)
            VStack(spacing: 8) {
                emojiCellImage(item: item, size: 64)
                Text(prettyName(item.baseName))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            )
        }
        .transition(.opacity)
    }

    private var categories: [EmojiGroup] {
        if recentIds.isEmpty {
            return store.groups
        }
        return [EmojiGroup.recents] + store.groups
    }

    private var recentItems: [EmojiItem] {
        recentIds.compactMap { store.itemsById[$0] }
    }

    private func reloadRecents() {
        recentIds = EmojiRecents.load()
        if recentIds.isEmpty {
            if let firstGroup = store.groups.first {
                activeCategoryId = firstGroup.id
                lastNonSearchCategoryId = firstGroup.id
            }
        } else {
            activeCategoryId = EmojiGroup.recents.id
            lastNonSearchCategoryId = EmojiGroup.recents.id
        }
    }

    private func scrollToCategory(_ id: String) {
        scrollProxy?.scrollTo(id, anchor: .top)
    }

    private func isCategoryActive(_ id: String) -> Bool {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return activeCategoryId == id
        }
        return lastNonSearchCategoryId == id
    }

    private func updateActiveCategory(from values: [String: CGFloat]) {
        guard !values.isEmpty else { return }
        // Walk categories in document order; pick the last one whose header
        // has scrolled to or past the top (minY ≤ threshold).
        let threshold: CGFloat = 40
        let orderedIds = categories.map(\.id)
        var best: String?
        for id in orderedIds {
            guard let y = values[id] else { continue }
            if y <= threshold {
                best = id
            }
        }
        let nextActive = best ?? orderedIds.first(where: { values[$0] != nil }) ?? activeCategoryId
        if nextActive != activeCategoryId {
            activeCategoryId = nextActive
            lastNonSearchCategoryId = nextActive
        }
    }

    private func prettyName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }
}

private struct EmojiCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color(.systemGray4) : .clear)
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SectionHeaderPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { old, new in min(old, new) })
    }
}
