//
//  EmojiItem.swift
//  DiscourseAssetKit
//

import SwiftUI

public struct EmojiItem: Identifiable, Hashable, Sendable {
    public let id: String               // assetName (unique)
    public let emoji: DiscourseEmoji    // local asset whitelist
    public let baseName: String         // JSON "name"
    public let groupId: String
    public let tonable: Bool
    public let aliases: [String]
    public let url: String?
    public let searchBlob: String

    public var image: Image { emoji.image }

    public init(id: String, emoji: DiscourseEmoji, baseName: String, groupId: String, tonable: Bool, aliases: [String], url: String?, searchBlob: String) {
        self.id = id
        self.emoji = emoji
        self.baseName = baseName
        self.groupId = groupId
        self.tonable = tonable
        self.aliases = aliases
        self.url = url
        self.searchBlob = searchBlob
    }
}
