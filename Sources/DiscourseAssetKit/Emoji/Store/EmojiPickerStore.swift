//
//  EmojiPickerStore.swift
//  DiscourseAssetKit
//

import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
public final class EmojiPickerStore {
    public var groups: [EmojiGroup] = []
    public var itemsByGroup: [String: [EmojiItem]] = [:]
    public var allItems: [EmojiItem] = []
    public var itemsById: [String: EmojiItem] = [:]

    private let logger = Logger(subsystem: "DiscourseAssetKit", category: "EmojiPickerStore")

    public init() {
        loadFromTable()
    }

    // MARK: - Search

    public func search(_ rawQuery: String) -> [EmojiItem] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Check if query is a Unicode emoji character
        if let shortcode = EmojiResolver.shortcodeForUnicode(trimmed) {
            let base = shortcode.split(separator: ":").first.map(String.init) ?? shortcode
            let canonical = EmojiResolver.canonicalize(base)
            if let item = allItems.first(where: { $0.baseName == canonical }) {
                logger.debug("Search: Unicode match '\(trimmed)' → \(item.baseName)")
                return [item]
            }
        }

        let q = Self.normalizeQuery(rawQuery)
        guard !q.isEmpty else { return [] }

        // searchBlob is computed from baseName + aliases; no need to store statically.
        let results = allItems
            .filter { $0.searchBlob.contains(q) }
            .sorted { lhs, rhs in
                let ln = lhs.baseName == q ? 0 : 1
                let rn = rhs.baseName == q ? 0 : 1
                if ln != rn { return ln < rn }
                return lhs.baseName < rhs.baseName
            }

        logger.debug("Search: '\(rawQuery)' → \(results.count) results")
        return results
    }

    // MARK: - Private

    private func loadFromTable() {
        var tmpItemsByGroup: [String: [EmojiItem]] = [:]
        var tmpAll: [EmojiItem] = []

        for tableGroup in EmojiItemTable.groups {
            guard let entries = EmojiItemTable.entries[tableGroup.id] else { continue }
            for entry in entries {
                guard let emoji = DiscourseEmoji.fromRawValue(entry.assetName) else { continue }
                let item = EmojiItem(
                    id: entry.assetName,
                    emoji: emoji,
                    baseName: entry.baseName,
                    groupId: tableGroup.id,
                    tonable: entry.tonable,
                    aliases: entry.aliases,
                    searchBlob: entry.searchBlob
                )
                tmpItemsByGroup[tableGroup.id, default: []].append(item)
                tmpAll.append(item)
            }
        }

        groups = EmojiItemTable.groups.compactMap { tableGroup in
            guard tmpItemsByGroup[tableGroup.id] != nil else { return nil }
            guard let discourseIcon = DiscourseEmoji.fromRawValue(tableGroup.discourseIconAsset) else { return nil }
            return EmojiGroup(
                id: tableGroup.id,
                displayName: tableGroup.displayName,
                discourseIcon: discourseIcon
            )
        }

        itemsByGroup = tmpItemsByGroup
        allItems = tmpAll
        itemsById = Dictionary(
            tmpAll.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        logger.info("Loaded \(self.groups.count) groups, \(self.allItems.count) emojis")
    }

    private static func normalizeQuery(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
