//
//  EmojiGroup.swift
//  DiscourseAssetKit
//

public struct EmojiGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let discourseIcon: DiscourseEmoji

    public init(id: String, displayName: String, discourseIcon: DiscourseEmoji) {
        self.id = id
        self.displayName = displayName
        self.discourseIcon = discourseIcon
    }
}

extension EmojiGroup {
    public static let recents = EmojiGroup(
        id: "recents",
        displayName: "Recents",
        discourseIcon: .emojiStar
    )
}
