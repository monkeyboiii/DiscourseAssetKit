//
//  EmojiPickerStore.swift
//  DiscourseAssetKit
//

import SwiftUI
import Observation
import os.log

private let pickerLog = Logger(subsystem: "DiscourseAssetKit", category: "EmojiPickerStore")

@MainActor
@Observable
public final class EmojiPickerStore {
    private let repo: EmojiMetadataRepository

    public var groups: [EmojiGroup] = []
    public var itemsByGroup: [String: [EmojiItem]] = [:]
    public var allItems: [EmojiItem] = []
    public var itemsById: [String: EmojiItem] = [:]

    public init(repo: EmojiMetadataRepository) {
        self.repo = repo
        rebuildFromDiskOrBundle()
        startListeningForUpdates()
    }

    public func rebuildFromDiskOrBundle() {
        do {
            let data = try repo.loadBestAvailableData()
            let decoded = try repo.decode(data)
            rebuild(from: decoded)
        } catch {
            pickerLog.error("Failed to load cached emoji data: \(error.localizedDescription). Falling back to bundle.")
            // Cache may be corrupted — delete it and retry with bundled data
            repo.deleteCacheFile()
            do {
                let data = try repo.loadBestAvailableData()
                let decoded = try repo.decode(data)
                rebuild(from: decoded)
            } catch {
                pickerLog.fault("Failed to load bundled emoji data: \(error.localizedDescription). Picker will be empty.")
                groups = []
                itemsByGroup = [:]
                allItems = []
                itemsById = [:]
            }
        }
    }

    /// Foreground refresh: throttled, then rebuild if updated.
    public func refreshForegroundIfStale(minInterval: TimeInterval = 60 * 30) async {
        let res = await repo.refreshRemoteIfStale(minInterval: minInterval)
        if res.kind == .updated {
            rebuildFromDiskOrBundle()
        }
    }

    public func search(_ rawQuery: String) -> [EmojiItem] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Check if query is a Unicode emoji character
        if let shortcode = EmojiResolver.shortcodeForUnicode(trimmed) {
            let base = shortcode.split(separator: ":").first.map(String.init) ?? shortcode
            let canonical = EmojiResolver.canonicalize(base)
            if let item = allItems.first(where: { $0.baseName == canonical }) {
                return [item]
            }
        }

        let q = Self.normalizeQuery(rawQuery)
        guard !q.isEmpty else { return [] }

        return allItems
            .filter { $0.searchBlob.contains(q) }
            .sorted { lhs, rhs in
                let ln = lhs.baseName == q ? 0 : 1
                let rn = rhs.baseName == q ? 0 : 1
                if ln != rn { return ln < rn }
                return lhs.baseName < rhs.baseName
            }
    }

    // MARK: - Private

    private func startListeningForUpdates() {
        NotificationCenter.default.addObserver(
            forName: .emojiMetadataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildFromDiskOrBundle()
            }
        }
    }

    private func rebuild(from decoded: [String: [EmojiJSONEntry]]) {
        var tmpItemsByGroup: [String: [EmojiItem]] = [:]
        var tmpAll: [EmojiItem] = []

        for (groupKey, entries) in decoded {
            for entry in entries {
                let assetName = DiscourseEmoji.sanitizeShortcodeToAssetName(":\(entry.name):")
                guard let emoji = DiscourseEmoji.fromRawValue(assetName) else { continue }

                let extraAliases = EmojiAliasTable.canonicalToAliases[entry.name] ?? []
                let allAliases = entry.searchAliases + extraAliases
                let blob = Self.makeSearchBlob(name: entry.name, aliases: allAliases)
                let item = EmojiItem(
                    id: assetName,
                    emoji: emoji,
                    baseName: entry.name,
                    groupId: groupKey,
                    tonable: entry.tonable,
                    aliases: entry.searchAliases,
                    url: entry.url,
                    searchBlob: blob
                )

                tmpItemsByGroup[groupKey, default: []].append(item)
                tmpAll.append(item)
            }
        }

        let knownOrder = EmojiGroup.canonicalOrder
        let knownSet = Set(knownOrder)
        let orderedKnown = knownOrder.filter { tmpItemsByGroup.keys.contains($0) }
        let orderedUnknown = tmpItemsByGroup.keys.filter { !knownSet.contains($0) }.sorted()
        let groupIds = orderedKnown + orderedUnknown

        groups = groupIds.map { gid in
            EmojiGroup(
                id: gid,
                displayName: Self.prettyGroupName(gid),
                iconSystemName: Self.groupIconSystemName(gid),
                discourseIcon: Self.groupDiscourseIconName(gid)
            )
        }

        for (gid, items) in tmpItemsByGroup {
            tmpItemsByGroup[gid] = items.sorted { $0.baseName < $1.baseName }
        }

        itemsByGroup = tmpItemsByGroup
        allItems = tmpAll
        itemsById = Dictionary(
            tmpAll.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func makeSearchBlob(name: String, aliases: [String]) -> String {
        let parts = ([name] + aliases)
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .joined(separator: " ")
        return normalizeQuery(parts)
    }

    private static func normalizeQuery(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func prettyGroupName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .split(separator: " ")
            .map { w in
                if w == "&" { return "&" }
                return w.prefix(1).uppercased() + w.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func groupIconSystemName(_ id: String) -> String {
        switch id {
        case "smileys_&_emotion": return "face.smiling"
        case "people_&_body":     return "hand.wave"
        case "animals_&_nature":  return "pawprint"
        case "food_&_drink":      return "takeoutbag.and.cup.and.straw"
        case "travel_&_places":   return "globe.europe.africa"
        case "activities":        return "gamecontroller"
        case "objects":           return "lightbulb"
        case "symbols":           return "at"
        case "flags":             return "flag"
        default:                  return "circle.grid.3x3"
        }
    }

    private static func groupDiscourseIconName(_ id: String) -> DiscourseEmoji {
        switch id {
        case "smileys_&_emotion": return .emojiGrinningFace
        case "people_&_body":     return .emojiWavingHand
        case "animals_&_nature":  return .emojiMonkey
        case "food_&_drink":      return .emojiGrapes
        case "travel_&_places":   return .emojiGlobeShowingEuropeAfrica
        case "activities":        return .emojiJackOLantern
        case "objects":           return .emojiGlasses
        case "symbols":           return .emojiAtmSign
        case "flags":             return .emojiChequeredFlag
        default:                  return .emojiRedQuestionMark
        }
    }
}

public extension EmojiPickerStore {
    /// Convenience factory — pass your Discourse forum base URL.
    static func make(forumBaseURL: URL) -> EmojiPickerStore {
        let config = EmojiMetadataRepository.Config(
            endpoint: forumBaseURL.appendingPathComponent("emojis.json"),
            bundledResourceName: "emojis",
            bundledResourceExt: "json",
            cacheFileName: "emojis.remote.json"
        )
        return EmojiPickerStore(repo: EmojiMetadataRepository(config: config))
    }
}
