//
//  EmojiRecents.swift
//  DiscourseAssetKit
//

import Foundation

public enum EmojiRecents: Sendable {
    private static let key = "emoji_recents_v1"
    private static let maxCount = 36

    @MainActor
    public static func load() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    @MainActor
    public static func push(_ assetName: String) {
        var arr = load()
        arr.removeAll { $0 == assetName }
        arr.insert(assetName, at: 0)
        if arr.count > maxCount { arr.removeLast(arr.count - maxCount) }
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @MainActor
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
