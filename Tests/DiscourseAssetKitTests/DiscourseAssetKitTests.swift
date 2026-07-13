import Testing
import UIKit
@testable import DiscourseAssetKit

// MARK: - EmojiText fast path

// @MainActor: EmojiText is wholly MainActor-inferred from its View conformance.
@Suite @MainActor struct EmojiTextFastPathTests {
    @Test func plainTextIsFastPathed() {
        #expect(EmojiText.isPlainText("No emojis here, just plain text."))
        #expect(EmojiText.isPlainText(""))
        #expect(EmojiText.isPlainText("多语言 plain text mit Umlauten äöü"))
    }

    @Test func shortcodeDefeatsFastPath() {
        #expect(!EmojiText.isPlainText("hello :wave: world"))
        #expect(!EmojiText.isPlainText("price: 100"))
    }

    @Test func unicodeEmojiDefeatsFastPath() {
        #expect(!EmojiText.isPlainText("Great post! 😀👍"))
        #expect(!EmojiText.isPlainText("tone 👍🏽"))
        #expect(!EmojiText.isPlainText("keycap 1️⃣"))
        #expect(!EmojiText.isPlainText("flag 🇨🇳"))
    }

    /// ♡ and ☻ are replacement-table keys WITHOUT the Unicode Emoji property —
    /// they must still defeat the fast path (via the derived exception set).
    @Test func nonEmojiPropertyKeysDefeatFastPath() {
        #expect(!EmojiText.isPlainText("I ♡ you"))
        #expect(!EmojiText.isPlainText("smile ☻"))
    }

    /// The load-bearing guarantee: the fast path may never skip a string the
    /// pipeline would transform. Every replacement-table key must defeat it.
    @Test func everyReplacementTableKeyDefeatsFastPath() {
        for key in EmojiReplacementTable.unicodeToShortcode.keys {
            #expect(!EmojiText.isPlainText(key), "fast path would skip \(key.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " "))")
        }
    }
}

// MARK: - Resized-bitmap cache

@Suite(.serialized) @MainActor struct ResizedCacheTests {
    @Test func sameAssetAndSizeResizesOnce() {
        #if DEBUG
        let before = EmojiImageCache.debugResizeCount
        let first = EmojiImageCache.resizedImage(named: "emoji_waving_hand", size: 17)
        let second = EmojiImageCache.resizedImage(named: "emoji_waving_hand", size: 17)
        #expect(first != nil)
        #expect(first === second)
        #expect(EmojiImageCache.debugResizeCount == before + 1)
        #endif
    }

    @Test func distinctSizesKeyDistinctly() {
        let small = EmojiImageCache.resizedImage(named: "emoji_waving_hand", size: 19)
        let large = EmojiImageCache.resizedImage(named: "emoji_waving_hand", size: 21)
        #expect(small != nil && large != nil)
        #expect(small !== large)
        #expect(small?.size == CGSize(width: 19, height: 19))
        #expect(large?.size == CGSize(width: 21, height: 21))
    }

    @Test func toneVariantsKeyDistinctly() {
        let base = EmojiResolver.resolvedResizedImage(for: .emojiWavingHand, tone: .default, size: 23)
        let toned = EmojiResolver.resolvedResizedImage(for: .emojiWavingHand, tone: .dark, size: 23)
        #expect(base != nil && toned != nil)
        #expect(base !== toned)
    }

    @Test func missingToneVariantFallsBackToBaseEntry() {
        let base = EmojiResolver.resolvedResizedImage(for: .emojiMotorcycle, tone: .default, size: 25)
        let toned = EmojiResolver.resolvedResizedImage(for: .emojiMotorcycle, tone: .dark, size: 25)
        #expect(base != nil)
        #expect(base === toned)
    }

    @Test func unknownAssetReturnsNil() {
        #expect(EmojiImageCache.resizedImage(named: "not_a_real_asset", size: 18) == nil)
    }
}

// MARK: - VoiceOver string parity (algorithm unchanged by the perf work)

@Suite @MainActor struct AccessibleDescriptionTests {
    @Test func shortcodeBecomesReadableName() {
        let view = EmojiText(rawText: "React :waving_hand: now")
        #expect(view.accessibleDescription == "React waving hand now")
    }

    @Test func toneSuffixIsStripped() {
        let view = EmojiText(rawText: "hi :waving_hand:t3:")
        #expect(view.accessibleDescription == "hi waving hand")
    }

    @Test func unknownShortcodeStillReadsAsWords() {
        let view = EmojiText(rawText: "Unknown :xyznotreal: emoji")
        #expect(view.accessibleDescription == "Unknown xyznotreal emoji")
    }

    @Test func unicodeEmojiBecomesResolvedName() {
        let view = EmojiText(rawText: "Great 😀")
        #expect(view.accessibleDescription == "Great grinning face")
    }

    @Test func plainTextIsUnchanged() {
        let view = EmojiText(rawText: "No emojis here, just plain text.")
        #expect(view.accessibleDescription == "No emojis here, just plain text.")
    }
}
