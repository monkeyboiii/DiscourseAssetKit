//
//  EmojiJSONEntry.swift
//  DiscourseAssetKit
//

import Foundation

public struct EmojiJSONEntry: Decodable, Sendable {
    public let name: String
    public let tonable: Bool
    public let url: String
    public let group: String
    public let searchAliases: [String]

    enum CodingKeys: String, CodingKey {
        case name, tonable, url, group
        case searchAliases = "search_aliases"
    }
}
