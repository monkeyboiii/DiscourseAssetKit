//
//  EmojiGroup.swift
//  DiscourseAssetKit
//

public struct EmojiGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let iconSystemName: String
    public let discourseIcon: DiscourseEmoji
    
    public init(id: String, displayName: String, iconSystemName: String, discourseIcon: DiscourseEmoji) {
        self.id = id
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.discourseIcon = discourseIcon
    }
}

extension EmojiGroup {
    public static let recents = EmojiGroup(
        id: "recents",
        displayName: "Recents",
        iconSystemName: "star",
        discourseIcon: .emojiStar
    )

    public static let canonicalOrder: [String] = [
        "smileys_&_emotion",
        "people_&_body",
        "animals_&_nature",
        "food_&_drink",
        "travel_&_places",
        "activities",
        "objects",
        "symbols",
        "flags"
    ]
}
