# CLAUDE.md - DiscourseAssetKit

**Discourse emoji and icon assets as a reusable Swift package for iOS.**

**Last Updated:** 2026-03-23\
**Swift Tools Version:** 6.2\
**Platform:** iOS 26+

---

## Overview

DiscourseAssetKit provides the complete Discourse emoji and icon asset pipeline for iOS apps. It bundles 1,900+ emoji PNGs (with skin tone variants), 335+ icon PDFs, lookup tables for alias/Unicode resolution, and SwiftUI views for display and picking.

Extracted from the [Dirt Bike Bros](https://github.com/monkeyboiii/dirtbikebros) iOS app to enable reuse across multiple Discourse-based clients.

### Key Characteristics

- **Type:** Swift Package (SPM)
- **Assets:** 3,400+ emoji imagesets, 335+ icon imagesets
- **Code:** ~9,000 lines Swift (5,900 auto-generated lookup tables + 3,100 hand-written)
- **Dependencies:** None (pure Swift + SwiftUI + UIKit)
- **Generation Scripts:** Python scripts in `discourse-assets/` submodule

---

## Codebase Structure

```
Sources/DiscourseAssetKit/
├── DiscourseAssetKit.swift            # Package entry / usage docs
├── Emoji/                             # Core emoji logic (12 files)
│   ├── DiscourseEmoji.swift           # 1,904-case enum (generated)
│   ├── EmojiResolver.swift            # Shortcode/Unicode resolution
│   ├── EmojiPickerStore.swift         # @MainActor @Observable state
│   ├── EmojiMetadataRepository.swift  # JSON loading + remote refresh
│   ├── EmojiItem.swift                # Display model
│   ├── EmojiGroup.swift               # Category grouping
│   ├── EmojiSkinTone.swift            # Tone enum + persistence
│   ├── EmojiRecents.swift             # Recent usage tracking
│   ├── EmojiJSONEntry.swift           # JSON decoding model
│   ├── EmojiAliasTable.swift          # Generated: alias → canonical
│   ├── EmojiReplacementTable.swift    # Generated: Unicode → shortcode
│   └── EmojiToneTable.swift           # Generated: tonable emoji set
├── Icon/                              # Icon components (2 files)
│   ├── DiscourseIcon.swift            # 347-case enum (generated)
│   └── DiscourseIconView.swift        # SwiftUI view
├── Views/                             # Public UI components (4 files)
│   ├── DiscourseEmojiView.swift       # Single emoji display
│   ├── EmojiText.swift                # Inline emoji in text
│   ├── EmojiPickerView.swift          # Full picker with search/tones
│   └── EmojiPickerPreview.swift       # Picker demo preview
├── Previews/                          # Catalog browsers (2 files)
│   ├── EmojiCatalogPreview.swift      # Browsable emoji grid
│   └── IconCatalogPreview.swift       # Browsable icon grid
└── Resources/
    ├── DiscourseEmojis.xcassets/      # 3,400+ imagesets (base + tone)
    ├── DiscourseIcons.xcassets/       # 335+ imagesets (template PDFs)
    └── emojis.json                    # Bundled metadata from Discourse
```

---

## Public API

### Views

| View | Init | Purpose |
|------|------|---------|
| `DiscourseEmojiView` | `(emoji:size:)` or `(shortcode:size:)` | Display single emoji by enum or shortcode |
| `DiscourseIconView` | `(icon:size:color:)` | Display icon with template tinting |
| `EmojiText` | `(rawText:emojiSize:)` | Render text with inline `:shortcode:` and Unicode emoji |
| `EmojiPickerView` | `(selection:store:)` | Full picker: categories, search, recents, skin tones |

### Types

| Type | Kind | Purpose |
|------|------|---------|
| `DiscourseEmoji` | `enum` (1,904 cases) | All emoji asset names, `CaseIterable` |
| `DiscourseIcon` | `enum` (347 cases) | All icon asset names, `CaseIterable` |
| `EmojiResolver` | `enum` (static) | Shortcode → asset resolution pipeline |
| `EmojiPickerStore` | `@Observable class` | Picker state: groups, items, search |
| `EmojiMetadataRepository` | `class` | JSON loading from bundle + remote refresh |
| `EmojiItem` | `struct` | Emoji display model (name, group, aliases) |
| `EmojiGroup` | `struct` | Category (smileys, people, animals, etc.) |
| `EmojiSkinTone` | `enum` | Tone modifiers (default, light, medium, dark) |
| `EmojiRecents` | `enum` (static) | Recent emoji UserDefaults storage |
| `EmojiTonePreference` | `enum` (static) | Persisted tone preference |

### Resolution Pipeline

```
":racing_motorcycle:" → canonicalize → "motorcycle" → sanitize → "emoji_motorcycle" → DiscourseEmoji.emojiMotorcycle
```

```swift
// Shortcode → emoji
EmojiResolver.resolve("wave")                      // → .emojiWavingHand
EmojiResolver.resolveWithTone("+1:t3")             // → ResolvedEmoji(emoji, tone: .mediumLight)

// Unicode → emoji
EmojiResolver.resolveUnicode("😀")                 // → .emojiGrinningFace
EmojiResolver.resolveUnicodeWithTone("👍🏽")         // → ResolvedEmoji(emoji, tone: .medium)

// Image loading (tone-aware)
EmojiResolver.resolvedImage(for: .emojiWavingHand, tone: .dark)  // UIImage from asset catalog
```

---

## Consumer Integration

### Add as local package dependency

In Xcode: File → Add Package Dependencies → Add Local → select `DiscourseAssetKit/`

Or in the consuming app's `Package.swift`:
```swift
.package(path: "../DiscourseAssetKit")
```

### Basic usage

```swift
import DiscourseAssetKit

// Display emoji
DiscourseEmojiView(shortcode: "wave", size: 24)
DiscourseEmojiView(emoji: .emojiMotorcycle, size: 32)

// Display icon
DiscourseIconView(icon: .bell, size: 16, color: .red)

// Inline emoji in text
EmojiText(rawText: "Hello :wave: world 😀")

// Emoji picker
@State var selection: String?
@State var store = EmojiPickerStore.make(forumBaseURL: URL(string: "https://forum.example.com")!)

EmojiPickerView(selection: $selection, store: store)
```

### Restoring app-specific convenience inits

The package removed app-specific types. Add back in your app:

```swift
import DiscourseAssetKit

extension DiscourseEmojiView {
    init(with reaction: Reaction, size: CGFloat = 14) {
        self.init(shortcode: reaction.reactionValue, size: size)
    }
}
```

---

## Asset Generation

Assets and enums are generated by Python scripts in the `discourse-assets/` submodule.

### Emoji generation

```bash
cd discourse-assets

# 1. Fetch emoji metadata + download PNGs
python discourse_emojis.py \
    --json assets/emojis.json \
    --out ../Sources/DiscourseAssetKit/Resources/DiscourseEmojis.xcassets \
    --download \
    --swift ../Sources/DiscourseAssetKit/Emoji/DiscourseEmoji.swift

# 2. Generate lookup tables (alias, Unicode, tone)
python generate_emoji_lookups.py \
    --json assets/emojis.json \
    --out ../Sources/DiscourseAssetKit/Emoji/
```

### Icon generation

```bash
cd discourse-assets

python discourse_sprite_icons.py \
    --svg assets/sprite.svg \
    --out ../Sources/DiscourseAssetKit/Resources/DiscourseIcons.xcassets \
    --swift ../Sources/DiscourseAssetKit/Icon/DiscourseIcon.swift
```

### What the scripts produce

| Script | Output | Count |
|--------|--------|-------|
| `discourse_emojis.py` | `DiscourseEmojis.xcassets/` + `DiscourseEmoji.swift` | 1,904 emoji + tone variants |
| `generate_emoji_lookups.py` | `EmojiAliasTable.swift`, `EmojiReplacementTable.swift`, `EmojiToneTable.swift` | 5,900 lines |
| `discourse_sprite_icons.py` | `DiscourseIcons.xcassets/` + `DiscourseIcon.swift` | 347 icons |

**Never hand-edit generated files.** Regenerate from scripts instead.

---

## Architecture Patterns

### Bundle.module

All asset loading uses `Bundle.module` (SPM resource bundle), not `Bundle.main`:

```swift
// Correct (package)
Image(self.rawValue, bundle: .module)
UIImage(named: assetName, in: .module, compatibleWith: nil)
Bundle.module.url(forResource: "emojis", withExtension: "json")

// Wrong (would look in app bundle, not package bundle)
Image(self.rawValue)
UIImage(named: assetName)
Bundle.main.url(forResource: ...)
```

### Swift 6 Concurrency

- `EmojiPickerStore` is `@MainActor` (UI-bound `@Observable`)
- `EmojiRecents`, `EmojiTonePreference` static methods are `@MainActor`
- `EmojiMetadataRepository` is `Sendable` (no shared mutable state)
- Value types (`EmojiItem`, `EmojiGroup`, `EmojiSkinTone`, etc.) conform to `Sendable`
- `PreferenceKey.defaultValue` uses `nonisolated(unsafe)` for Swift 6 compatibility

### Access Control

- **Public:** All types, views, inits, and methods consumers need
- **Internal (default):** Generated lookup tables (`EmojiAliasTable`, `EmojiReplacementTable`, `EmojiToneTable`) — implementation details only used by `EmojiResolver` and `EmojiPickerStore`
- **Private:** Preview views, helper extensions

### Remote Refresh

`EmojiMetadataRepository` supports fetching updated emoji metadata from a Discourse server:

```
Bundled emojis.json (fallback) → Remote /emojis.json (cached to disk) → ETag/304 conditional refresh
```

Refresh is throttled (default 30 min) via `EmojiPickerStore.refreshForegroundIfStale()`.

---

## Development

### Building

```bash
# CLI build
cd DiscourseAssetKit
xcodebuild -scheme DiscourseAssetKit -destination 'generic/platform=iOS' build

# Or open in Xcode
open Package.swift
```

### Previews

Open the package in Xcode and navigate to any file with `#Preview`:

| Preview | File | Shows |
|---------|------|-------|
| Emoji Catalog | `Previews/EmojiCatalogPreview.swift` | Searchable grid of all 1,904 emoji |
| Icon Catalog | `Previews/IconCatalogPreview.swift` | Searchable grid of all 347 icons |
| Emoji Picker | `Views/EmojiPickerPreview.swift` | Full picker with selection + debug info |
| Emoji View | `Views/DiscourseEmojiView.swift` | Shortcode, enum, and fallback display |
| Emoji Text | `Views/EmojiText.swift` | Inline shortcode + Unicode rendering |

### Known Warnings

These are pre-existing and non-blocking:
- `Text` concatenation deprecated in iOS 26 (use string interpolation) — affects `EmojiText`
- `UIScreen.main` deprecated in iOS 26 — affects `EmojiPickerView` keyboard handling
- `file-image` asset name collision with `file` — cosmetic, from icon assets

### Adding New Emoji/Icons

1. Update `discourse-assets/assets/emojis.json` or `sprite.svg` from your Discourse instance
2. Run the appropriate generation script
3. Copy generated assets into `Resources/`
4. Copy generated Swift files into `Emoji/` or `Icon/`
5. Build to verify

---

## Submodule

The `discourse-assets/` directory is a git submodule containing:
- Python generation scripts
- Source data (`emojis.json`, `sprite.svg`)
- Asset generation reports

```bash
# Update submodule
git submodule update --init --recursive
```

---

## File Quick Reference

| What | Where |
|------|-------|
| Package manifest | `Package.swift` |
| All emoji assets | `Sources/.../Resources/DiscourseEmojis.xcassets/` |
| All icon assets | `Sources/.../Resources/DiscourseIcons.xcassets/` |
| Bundled metadata | `Sources/.../Resources/emojis.json` |
| Resolution logic | `Sources/.../Emoji/EmojiResolver.swift` |
| Picker UI | `Sources/.../Views/EmojiPickerView.swift` |
| State management | `Sources/.../Emoji/EmojiPickerStore.swift` |
| Generation scripts | `discourse-assets/*.py` |
