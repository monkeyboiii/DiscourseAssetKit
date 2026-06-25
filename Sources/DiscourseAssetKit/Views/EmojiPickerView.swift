//
//  EmojiPickerView.swift
//  DiscourseAssetKit
//
//  Created by Haotian Lu on 2/4/26.
//

import SwiftUI

public struct EmojiPickerView: View {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// Number of `EmojiSkinTone.allCases` entries unlocked for the user,
        /// counted from index 0. Tones at index >= `tonesUnlocked` render as
        /// locked swatches and route taps to `onLockedToneTap`.
        public var tonesUnlocked: Int

        /// Tint colors for *locked* tones, parallel to indices
        /// `tonesUnlocked..<EmojiSkinTone.allCases.count`. `lockedToneTints[0]`
        /// tints the first locked tone, etc.
        public var lockedToneTints: [Color]

        /// Called when a locked tone swatch is tapped. The Int is the 0-based
        /// locked-tone index — `0` is the first tone above `tonesUnlocked`.
        public var onLockedToneTap: (@MainActor @Sendable (Int) -> Void)?

        /// Per-group ordered cap arrays oriented from the *current tier upward*.
        /// Index 0 = items unlocked at the user's current tier.
        /// Index 1 = additionally unlocked one tier up.
        /// `nil` at any position means unlimited from that band onward.
        /// Group IDs absent from the dictionary are fully unlocked.
        public var groupBands: [String: [Int?]]

        /// Tint colors for *locked* bands, parallel to `groupBands` array
        /// positions starting at index 1. `bandTints[0]` tints items in the
        /// first locked band (i.e., items requiring +1 tier upgrade).
        public var bandTints: [Color]

        /// Called when a locked emoji is tapped. The Int is the 0-based locked
        /// band index — 0 means the first locked band (current tier + 1), etc.
        public var onLockedEmojiTap: (@MainActor @Sendable (Int) -> Void)?

        public init(
            tonesUnlocked: Int = EmojiSkinTone.allCases.count,
            lockedToneTints: [Color] = [],
            onLockedToneTap: (@MainActor @Sendable (Int) -> Void)? = nil,
            groupBands: [String: [Int?]] = [:],
            bandTints: [Color] = [],
            onLockedEmojiTap: (@MainActor @Sendable (Int) -> Void)? = nil
        ) {
            self.tonesUnlocked = tonesUnlocked
            self.lockedToneTints = lockedToneTints
            self.onLockedToneTap = onLockedToneTap
            self.groupBands = groupBands
            self.bandTints = bandTints
            self.onLockedEmojiTap = onLockedEmojiTap
        }

        public static let `default` = Configuration()
    }

    // MARK: - Properties

    @Binding var selection: String?
    @Bindable var store: EmojiPickerStore
    let configuration: Configuration

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    @State private var searchText = ""
    @State private var activeCategoryId = EmojiGroup.recents.id
    @State private var lastNonSearchCategoryId = EmojiGroup.recents.id
    @State private var recentIds: [String] = []
    @State private var previewItem: EmojiItem?
    @State private var previewWorkItem: DispatchWorkItem?
    @State private var lastPreviewDismissTime: Date = .distantPast
    @State private var lastCategoryChangeTime: Date = .distantPast
    @State private var selectedTone: EmojiSkinTone = EmojiTonePreference.current

    @State private var scrollProxy: ScrollViewProxy?
    private let scrollCoordinateSpace = "emoji-picker-scroll"

    public init(selection: Binding<String?>, store: EmojiPickerStore, configuration: Configuration = .default, initialSearch: String = "") {
        self._selection = selection
        self.store = store
        self.configuration = configuration
        // Seed the search field so a caller can open the picker pre-filtered to a
        // term (e.g. an in-progress `:shortcode` the user was typing). Empty by
        // default, so the picker opens on the grouped/recents view as before.
        _searchText = State(initialValue: initialSearch)
        // Clamp the persisted tone preference to the user's unlocked range so a
        // post-downgrade picker doesn't display a tone the user can't use.
        let initialTone = EmojiTonePreference.current
        let toneIdx = EmojiSkinTone.allCases.firstIndex(of: initialTone) ?? 0
        if toneIdx >= configuration.tonesUnlocked {
            let clampedIdx = max(configuration.tonesUnlocked - 1, 0)
            _selectedTone = State(initialValue: EmojiSkinTone.allCases[clampedIdx])
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            VStack(spacing: DesignTokens.Spacing.lg) {
                topBar

                HStack(spacing: DesignTokens.Spacing.lg) {
                    CategoryRailView(
                        categories: categories,
                        activeCategoryId: $activeCategoryId,
                        lastNonSearchCategoryId: $lastNonSearchCategoryId,
                        searchText: $searchText,
                        selectedTone: selectedTone,
                        scrollToCategory: scrollToCategory
                    )
                    Divider()
                    contentArea
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            )

            if let previewItem {
                EmojiPreviewOverlay(item: previewItem, tone: selectedTone)
            }
        }
        .onAppear {
            reloadRecents()
        }
        .onChange(of: searchText) { _, _ in
            if trimmedSearch.isEmpty {
                scrollToCategory(lastNonSearchCategoryId)
            } else {
                lastNonSearchCategoryId = activeCategoryId
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            searchPill
                .frame(maxWidth: .infinity)
            TonePickerButton(
                selectedTone: $selectedTone,
                tonesUnlocked: configuration.tonesUnlocked,
                lockedToneTints: configuration.lockedToneTints,
                onLockedTap: configuration.onLockedToneTap
            )
        }
    }

    private var searchPill: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
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
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    if trimmedSearch.isEmpty {
                        groupedContent
                    } else {
                        resultsContent
                    }
                }
                .padding(.trailing, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .coordinateSpace(name: scrollCoordinateSpace)
            .onPreferenceChange(SectionHeaderPreferenceKey.self) { values in
                guard trimmedSearch.isEmpty else { return }
                updateActiveCategory(from: values)
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
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
                    .padding(.horizontal, DesignTokens.Spacing.xs)
            } else {
                emojiGrid(items: recentsItems)
            }
        }
    }

    private var resultsContent: some View {
        let results = store.search(searchText)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if results.isEmpty {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
            } else {
                emojiGrid(items: results)
            }
        }
    }

    private func sectionHeader(title: String, id: String, showsClear: Bool) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
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

    // MARK: - Emoji Grid

    private func emojiGrid(items: [EmojiItem]) -> some View {
        let columns = [GridItem(.adaptive(minimum: DesignTokens.Picker.minCellSize), spacing: DesignTokens.Spacing.md)]
        let lockedBands = lockedBandByItemId
        let tints = configuration.bandTints
        return LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
            ForEach(items) { item in
                let lockBand = lockedBands[item.id]
                let lockTint: Color? = {
                    guard let lockBand else { return nil }
                    return tints.indices.contains(lockBand) ? tints[lockBand] : nil
                }()
                Button {
                    guard Date().timeIntervalSince(lastPreviewDismissTime) > 0.3 else { return }
                    if let lockBand {
                        configuration.onLockedEmojiTap?(lockBand)
                        return
                    }
                    var name = item.baseName
                    if item.tonable && selectedTone != .default {
                        name += selectedTone.suffix
                    }
                    selection = name
                    EmojiRecents.push(item.id)
                    reloadRecents()
                    dismiss()
                } label: {
                    EmojiAsyncCell(item: item, size: DesignTokens.Picker.emojiSize, tone: selectedTone)
                        .frame(width: DesignTokens.Picker.minCellSize, height: DesignTokens.Picker.minCellSize)
                        .contentShape(Rectangle())
                        .opacity(lockBand != nil ? 0.35 : 1.0)
                        .overlay(alignment: .bottomTrailing) {
                            if lockBand != nil {
                                DiscourseIconView(icon: .lock, size: 10, color: .white)
                                    .padding(3)
                                    .background(
                                        Circle().fill((lockTint ?? .gray).opacity(0.95))
                                    )
                                    .overlay(
                                        Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5)
                                    )
                            }
                        }
                }
                .buttonStyle(EmojiCellButtonStyle())
                .accessibilityLabel(Text(lockBand != nil
                    ? "\(Self.prettyName(item.baseName)), locked"
                    : Self.prettyName(item.baseName)))
                .accessibilityAddTraits(.isImage)
                .accessibilityHint(Text(lockBand != nil ? "Double tap to upgrade" : "Double tap to select"))
                .onLongPressGesture(
                    minimumDuration: 0.9,
                    maximumDistance: 40,
                    pressing: { isPressing in
                        if isPressing {
                            let work = DispatchWorkItem { previewItem = item }
                            previewWorkItem = work
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
                        } else {
                            previewWorkItem?.cancel()
                            previewWorkItem = nil
                            if previewItem?.id == item.id {
                                previewItem = nil
                                lastPreviewDismissTime = Date()
                            }
                        }
                    },
                    perform: {}
                )
            }
        }
    }

    // MARK: - Data Helpers

    private var categories: [EmojiGroup] {
        if recentIds.isEmpty {
            return store.groups
        }
        return [EmojiGroup.recents] + store.groups
    }

    private var recentItems: [EmojiItem] {
        recentIds.compactMap { store.itemsById[$0] }
    }

    /// Maps an item ID → 0-based locked band index. Items absent from the map
    /// are unlocked. Band index k corresponds to `configuration.bandTints[k]`.
    private var lockedBandByItemId: [String: Int] {
        guard !configuration.groupBands.isEmpty else { return [:] }
        var locked: [String: Int] = [:]
        for group in store.groups {
            guard let bands = configuration.groupBands[group.id],
                  let items = store.itemsByGroup[group.id] else { continue }
            for (i, item) in items.enumerated() {
                guard let bandIdx = Self.lockedBandIndex(for: i, in: bands) else { continue }
                locked[item.id] = bandIdx
            }
        }
        return locked
    }

    /// Returns the locked-band index (0-based) for an item at position `index`
    /// in a group whose band caps are `bands`. Returns `nil` if unlocked.
    private static func lockedBandIndex(for index: Int, in bands: [Int?]) -> Int? {
        guard !bands.isEmpty, let currentCap = bands[0], index >= currentCap else {
            return nil
        }
        // Locked. Find the smallest k >= 1 where the item fits.
        for k in 1..<bands.count {
            if let cap = bands[k] {
                if index < cap { return k - 1 }
            } else {
                return k - 1   // nil = unlimited from this band onward
            }
        }
        // Past every cap and no nil terminator — clamp to last band.
        return max(bands.count - 2, 0)
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

    static func prettyName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }

    // MARK: - Scroll Tracking

    private func scrollToCategory(_ id: String) {
        scrollProxy?.scrollTo(id, anchor: .top)
    }

    private func updateActiveCategory(from values: [String: CGFloat]) {
        guard !values.isEmpty else { return }
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
            let now = Date()
            guard now.timeIntervalSince(lastCategoryChangeTime) > 0.25 else { return }
            lastCategoryChangeTime = now
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                activeCategoryId = nextActive
                lastNonSearchCategoryId = nextActive
            }
        }
    }
}

// MARK: - Tone Picker

private struct TonePickerButton: View {
    @Binding var selectedTone: EmojiSkinTone
    let tonesUnlocked: Int
    let lockedToneTints: [Color]
    let onLockedTap: (@MainActor @Sendable (Int) -> Void)?
    @State private var showPicker = false

    private var anyLocked: Bool {
        tonesUnlocked < EmojiSkinTone.allCases.count
    }

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            if let img = EmojiResolver.resolvedImage(for: .emojiClap, tone: selectedTone) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: DesignTokens.Picker.toneIndicatorSize, height: DesignTokens.Picker.toneIndicatorSize)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(anyLocked ? "Skin tone options, more to unlock" : "Skin tone options"))
        .overlay(alignment: .bottomTrailing) {
            if anyLocked {
                DiscourseIconView(icon: .unlockKeyhole, size: 12, color: .primary)
                    .padding(2)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .popover(isPresented: $showPicker, arrowEdge: .top) {
            toneSwatches
                .presentationCompactAdaptation(.popover)
        }
    }

    private var toneSwatches: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(EmojiSkinTone.allCases.enumerated()), id: \.element) { idx, tone in
                let lockBand: Int? = idx >= tonesUnlocked ? idx - tonesUnlocked : nil
                let lockTint: Color? = {
                    guard let lockBand else { return nil }
                    return lockedToneTints.indices.contains(lockBand) ? lockedToneTints[lockBand] : nil
                }()
                Button {
                    if let lockBand {
                        showPicker = false
                        onLockedTap?(lockBand)
                    } else {
                        selectedTone = tone
                        EmojiTonePreference.current = tone
                        showPicker = false
                    }
                } label: {
                    ZStack {
                        if let img = EmojiResolver.resolvedImage(for: .emojiClap, tone: tone) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: DesignTokens.Picker.toneSwatchSize, height: DesignTokens.Picker.toneSwatchSize)
                                .opacity(lockBand != nil ? 0.35 : 1.0)
                        }

                        if lockBand != nil {
                            Circle()
                                .fill((lockTint ?? .gray).opacity(0.65))
                                .frame(width: DesignTokens.Picker.toneSwatchSize, height: DesignTokens.Picker.toneSwatchSize)
                            DiscourseIconView(icon: .lock, size: 12, color: .white)
                        } else if tone == selectedTone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(tone == .default || tone == .light ? .black : .white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(lockBand != nil ? "\(tone.accessibilityLabel), locked" : tone.accessibilityLabel))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}

// MARK: - Preview Overlay

private struct EmojiPreviewOverlay: View {
    let item: EmojiItem
    let tone: EmojiSkinTone

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
            VStack(spacing: DesignTokens.Spacing.md) {
                EmojiAsyncCell.syncImage(item: item, size: DesignTokens.Picker.previewEmojiSize, tone: tone)
                Text(EmojiPickerView.prettyName(item.baseName))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(DesignTokens.Spacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            )
        }
        .transition(.opacity)
    }
}

// MARK: - Category Rail

private struct CategoryRailView: View {
    let categories: [EmojiGroup]
    @Binding var activeCategoryId: String
    @Binding var lastNonSearchCategoryId: String
    @Binding var searchText: String
    let selectedTone: EmojiSkinTone
    let scrollToCategory: (String) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(categories, id: \.id) { group in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            activeCategoryId = group.id
                            lastNonSearchCategoryId = group.id
                        }
                        if !searchText.isEmpty {
                            searchText = ""
                        }
                        scrollToCategory(group.id)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isCategoryActive(group.id) ? Color.accentColor : Color(.systemGray5))
                            if let img = EmojiResolver.resolvedImage(for: group.discourseIcon, tone: selectedTone) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: DesignTokens.Picker.railIconSize, height: DesignTokens.Picker.railIconSize)
                            }
                        }
                        .frame(width: DesignTokens.Picker.railButtonSize, height: DesignTokens.Picker.railButtonSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(group.displayName))
                    .accessibilityHint(Text("Double tap to jump to category"))
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .frame(width: DesignTokens.Picker.railButtonSize)
    }

    private func isCategoryActive(_ id: String) -> Bool {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return activeCategoryId == id
        }
        return lastNonSearchCategoryId == id
    }
}

// MARK: - Supporting Types

private struct EmojiCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
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
