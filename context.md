# EmojiPickerView Enhancement — Context for Swift Expert

**Target file:** `Sources/DiscourseAssetKit/Views/EmojiPickerView.swift`
**Platform:** iOS 18+ | Swift 6.2 | SwiftUI
**Package:** Pure Swift, zero external dependencies

---

## Project Overview

DiscourseAssetKit is an SPM library providing Discourse emoji/icon assets for iOS. It bundles 1,900+ emoji (3,400+ PNGs including skin tone variants) and 335+ icons, with SwiftUI views for display and picking.

Emoji PNGs are flat files loaded via `Bundle.module.url(forResource:withExtension:subdirectory:"Emojis")` — **not** xcassets (to avoid actool memory explosion at that scale).

---

## Dependency Graph

```
EmojiPickerView
├── EmojiPickerStore        — @MainActor @Observable, holds groups/items, provides search
├── EmojiItem               — struct: id, emoji, baseName, groupId, tonable, aliases, searchBlob
├── EmojiGroup              — struct: id, displayName, discourseIcon
├── EmojiResolver           — static methods: shortcode/Unicode resolution, tone-aware image loading
├── EmojiImageCache         — static NSCache<NSString, UIImage> loader (20 MB cap)
├── EmojiRecents            — static @MainActor UserDefaults storage (max 36 items)
├── EmojiTonePreference     — static @MainActor UserDefaults getter/setter
├── EmojiSkinTone           — enum: default, light(t2), mediumLight(t3), medium(t4), mediumDark(t5), dark(t6)
├── DiscourseEmojiView      — simple emoji display view (no tone support)
├── DiscourseEmoji          — 1,904-case enum (auto-generated, rawValue = asset name)
└── DesignTokens            — spacing/radius/sizing constants
```

---

## Key Types API

### EmojiPickerStore

```swift
@MainActor @Observable final class EmojiPickerStore {
    let groups: [EmojiGroup]                    // ordered categories
    let itemsByGroup: [String: [EmojiItem]]     // groupId -> items
    let allItems: [EmojiItem]                   // flat, ~1,900 items
    let itemsById: [String: EmojiItem]          // assetName -> item (O(1))

    init()                                      // loads from pre-computed table (~2ms)
    func search(_ rawQuery: String) -> [EmojiItem]  // fuzzy search on searchBlob
}
```

- Search supports Unicode input (e.g., "😀" resolves to shortcode first).
- Results sorted: exact prefix matches first, then alphabetical.
- Query normalization: lowercase, trim, underscores to spaces.

### EmojiItem

```swift
struct EmojiItem: Identifiable, Hashable, Sendable {
    let id: String              // assetName, e.g. "emoji_wave"
    let emoji: DiscourseEmoji   // enum case
    let baseName: String        // e.g. "wave", "waving_hand"
    let groupId: String         // category id
    let tonable: Bool           // supports skin tones?
    let aliases: [String]       // alternative shortcodes
    let searchBlob: String      // pre-computed "baseName alias1 alias2..."
    var image: Image { get }    // via EmojiImageCache
}
```

### EmojiGroup

```swift
struct EmojiGroup: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let discourseIcon: DiscourseEmoji   // emoji used as category icon

    static let recents = EmojiGroup(id: "recents", displayName: "Recents", discourseIcon: .emojiStar)
}
```

Note: `recents` is not in `store.groups` — it's injected dynamically in the picker when recent items exist.

### EmojiResolver (static)

```swift
enum EmojiResolver {
    static func resolve(_ shortcode: String) -> DiscourseEmoji?
    static func resolveWithTone(_ shortcode: String) -> ResolvedEmoji?
    static func resolveUnicode(_ char: String) -> DiscourseEmoji?
    static func resolvedImage(for emoji: DiscourseEmoji, tone: EmojiSkinTone) -> UIImage?
    static func isTonable(_ shortcode: String) -> Bool
    static func canonicalize(_ shortcode: String) -> String  // strips colons, resolves aliases
}

struct ResolvedEmoji {
    let emoji: DiscourseEmoji
    let tone: EmojiSkinTone
    let isTonable: Bool
}
```

- `resolvedImage(for:tone:)` tries tone-specific asset (e.g. `emoji_wave_t2`), falls back to base.
- Uses pre-generated lookup tables (alias, replacement, tone) — all O(1) dictionary lookups.

### EmojiImageCache (static)

```swift
enum EmojiImageCache: Sendable {
    static func image(named assetName: String) -> UIImage?
    // NSCache, 20 MB limit, loads from Resources/Emojis/*.png
    // Uses preparingForDisplay() for optimal rendering
}

extension DiscourseEmoji {
    var image: Image  // SwiftUI Image via cache, fallback: questionmark.square
}
```

### EmojiSkinTone

```swift
enum EmojiSkinTone: Int, CaseIterable, Identifiable, Sendable {
    case `default` = 0   // no modifier (yellow)
    case light = 2       // suffix ":t2"
    case mediumLight = 3 // suffix ":t3"
    case medium = 4      // suffix ":t4"
    case mediumDark = 5  // suffix ":t5"
    case dark = 6        // suffix ":t6"

    var suffix: String   // e.g. ":t3", or "" for default
}

enum EmojiTonePreference: Sendable {
    @MainActor static var current: EmojiSkinTone  // UserDefaults "emoji_skin_tone_v1"
}
```

### EmojiRecents (static, @MainActor)

```swift
enum EmojiRecents: Sendable {
    @MainActor static func load() -> [String]       // asset name IDs
    @MainActor static func push(_ assetName: String) // add/move to front, max 36
    @MainActor static func clear()
}
```

### DesignTokens

```swift
enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4, sm: 6, md: 8, lg: 12, xl: 16
    }
    enum CornerRadius {
        static let sm: CGFloat = 8, md: 14, lg: 16
    }
    enum Picker {
        static let minCellSize: CGFloat = 44   // adaptive grid min
        static let emojiSize: CGFloat = 28     // glyph in cell
        static let railButtonSize: CGFloat = 34
        static let railIconSize: CGFloat = 18
        static let toneSwatchSize: CGFloat = 30
        static let toneIndicatorSize: CGFloat = 32
        static let previewEmojiSize: CGFloat = 64
    }
}
```

---

## Current Picker Architecture

### Layout
- **Top bar:** search pill (TextField in Capsule) + tone indicator button (top-right)
- **Main area:** category rail (vertical ScrollView, left) | Divider | content scroll (ScrollViewReader, right)
- **Overlay:** long-press preview (ZStack overlay with material blur)

### Content Modes
1. **Grouped mode** (search empty): recents section (if any) + all category sections with headers
2. **Search mode** (search non-empty): flat "Results" section from `store.search()`

### Category Sync
- Scroll position tracked via `SectionHeaderPreferenceKey` (GeometryReader on each header)
- Active category = last header whose `minY <= 40` in scroll coordinate space
- Category rail highlights active with `matchedGeometryEffect` (accent color circle)
- Tapping a rail button calls `scrollProxy.scrollTo(id, anchor: .top)`
- Throttled: 0.15s debounce on category changes to prevent jitter

### Selection Flow
1. User taps emoji cell
2. Guard: skip if within 0.3s of preview dismiss
3. Build name: `baseName` + `selectedTone.suffix` (if tonable and non-default)
4. Set `selection = name`, push to recents, dismiss

### Long-Press Preview
- `onLongPressGesture(minimumDuration: 0.9, maximumDistance: 40)`
- `pressing` callback: start 0.35s delayed `DispatchWorkItem` to show preview
- Release cancels work item + clears preview if shown
- Preview overlay: large emoji (64pt) + pretty name on material blur background

### Skin Tones
- `selectedTone` persisted via `EmojiTonePreference`
- Top-right clap emoji button opens `.popover` with 6 tone swatches
- Affects: emoji grid cells (tonable items), category rail icons, preview, selection output

### Key Patterns
- All state is `@State` local to view (no store mutation from picker)
- `@Bindable var store` for `@Observable` integration
- `@FocusState` for search keyboard
- `@Namespace` for matched geometry animation on category highlight
- `scrollDismissesKeyboard(.interactively)` on content scroll
- `EmojiCellButtonStyle` — custom ButtonStyle with pressed highlight

---

## Concurrency Model

- `EmojiPickerStore` is `@MainActor @Observable`
- `EmojiRecents` / `EmojiTonePreference` static methods are `@MainActor`
- `EmojiImageCache` uses `nonisolated(unsafe)` for thread-safe `NSCache` static
- `SectionHeaderPreferenceKey.defaultValue` uses `nonisolated(unsafe)` (Swift 6 requirement)
- Image loading is synchronous (NSCache hit = fast, miss = disk read + `preparingForDisplay()`)

---

## Known Constraints

- **No async image loading** — all synchronous through NSCache. First loads hit disk.
- **Recents max 36** — hardcoded in `EmojiRecents.push()`.
- **Long-press uses DispatchWorkItem** — not structured concurrency.
- **Search is linear scan** over ~1,900 items (fast enough, but no indexing).
- **Category scroll sync** is one-way: scroll updates rail, but rail tap snaps scroll without animation feedback.
- **No accessibility for tone modifier** on grid cells — only base name announced.
- **Preview overlay captures all taps** — dismisses on any interaction but blocks underlying content.

---

## Build & Preview

```bash
# Build
xcodebuild -scheme DiscourseAssetKit -destination 'generic/platform=iOS' build

# Preview in Xcode
open Package.swift  # then navigate to Previews/EmojiPickerPreview.swift
```

Demo app at `DakDemo/DakDemo.xcodeproj` shows the picker in a sheet.
