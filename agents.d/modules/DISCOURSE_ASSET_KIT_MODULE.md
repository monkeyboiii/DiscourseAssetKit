---
kind: why
status: current
summary: Discourse emoji + icon assets as an SPM package — 1,900+ emoji PNGs (flat files, not xcassets), 335+ icon PDFs, alias/Unicode lookup tables, SwiftUI display + picker views.
---

# DiscourseAssetKit

**Discourse emoji and icon assets as a reusable Swift package for iOS.**

**Swift Tools Version:** 6.2\
**Platform:** iOS 26+

---

## Overview

DiscourseAssetKit provides the complete Discourse emoji and icon asset pipeline for iOS apps. It bundles 1,900+ emoji PNGs (with skin tone variants), 335+ icon PDFs, lookup tables for alias/Unicode resolution, and SwiftUI views for display and picking.

Extracted from the [Dirt Bike Bros](https://github.com/monkeyboiii/dirtbikebros) iOS app to enable reuse across multiple Discourse-based clients.

### Key Characteristics

- **Type:** Swift Package (SPM)
- **Assets:** 3,400+ emoji PNGs (flat, bundled via `.copy()`), 335+ icon imagesets (xcassets)
- **Code:** ~12,300 lines Swift (10,900 auto-generated lookup tables + 1,400 hand-written)
- **Dependencies:** None (pure Swift + SwiftUI + UIKit)
- **Generation Scripts:** Python scripts in `discourse-assets/` submodule

---

## Codebase Structure

```
Sources/DiscourseAssetKit/
├── DiscourseAssetKit.swift            # Package entry / usage docs
├── DesignSystem/
│   └── DesignTokens.swift             # Spacing/radius/sizing tokens
├── Emoji/                             # Core emoji logic
│   ├── Emoji+Init.swift               # O(1) lookup + sanitize helpers
│   ├── EmojiImageCache.swift          # NSCache loader + .image property
│   ├── EmojiRecents.swift             # Recent usage tracking
│   ├── EmojiResolver.swift            # Shortcode/Unicode resolution
│   ├── EmojiSkinTone.swift            # Tone enum + persistence
│   ├── Generated/                     # AUTO-GENERATED — do not edit
│   │   ├── DiscourseEmoji.swift       # 1,904-case enum
│   │   ├── EmojiAliasTable.swift      # alias → canonical
│   │   ├── EmojiItemTable.swift       # Pre-computed EmojiItem/EmojiGroup data
│   │   ├── EmojiReplacementTable.swift # Unicode → shortcode
│   │   └── EmojiToneTable.swift       # Tonable emoji set
│   └── Store/
│       ├── EmojiGroup.swift           # Category grouping
│       ├── EmojiItem.swift            # Display model
│       └── EmojiPickerStore.swift     # @MainActor @Observable state
├── Icon/
│   ├── DiscourseIconView.swift        # SwiftUI view
│   ├── Generated/
│   │   └── DiscourseIcon.swift        # 347-case enum
│   └── Icon+Init.swift               # O(1) lookup helper
├── Views/
│   ├── DiscourseEmojiView.swift       # Single emoji display
│   ├── EmojiText.swift                # Inline emoji in text
│   └── EmojiPickerView.swift          # Full picker with search/tones
├── Previews/
│   ├── EmojiCatalogPreview.swift      # Browsable emoji grid
│   ├── EmojiPickerPreview.swift       # Picker demo preview
│   └── IconCatalogPreview.swift       # Browsable icon grid
└── Resources/
    ├── Emojis/                        # 3,400+ flat PNGs (bundled via .copy())
    └── DiscourseIcons.xcassets/       # 335+ icon imagesets (template PDFs)
```

### Demo App

```
DakDemo/                               # Minimal demo app using EmojiPickerView
├── DakDemo/
│   ├── DakDemoApp.swift
│   └── ContentView.swift              # Sheet-based emoji picker demo
└── DakDemo.xcodeproj/                 # Local package dependency on DiscourseAssetKit
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
| `EmojiImageCache` | `enum` (static) | `NSCache`-backed flat PNG loader |
| `EmojiPickerStore` | `@Observable class` | Picker state: groups, items, search |
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

// Image loading (tone-aware, NSCache-backed)
EmojiResolver.resolvedImage(for: .emojiWavingHand, tone: .dark)  // UIImage from cached flat PNG
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
@State var store = EmojiPickerStore()

EmojiPickerView(selection: $selection, store: store)
```

### Demo app

`DakDemo/` is a minimal Xcode project that demonstrates `EmojiPickerView` in a sheet. Open `DakDemo/DakDemo.xcodeproj` in Xcode — the local package dependency is already configured.

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

Assets and enums are generated by Python scripts in the `discourse-assets/` submodule. The main entry point is `emoji.sh`.

### Emoji generation (default — flat PNGs)

```bash
cd discourse-assets
bash emoji.sh
```

This runs four steps:
1. Download `emojis.json` + `data.js` from Discourse
2. `discourse_emojis.py` → download PNGs to `Emojis/` + generate `DiscourseEmoji.swift` enum
3. Copy flat PNGs to `Resources/Emojis/`
4. `generate_emoji_lookups.py` → alias, replacement, tone tables
5. `generate_emoji_items.py` → pre-computed `EmojiItemTable.swift`

### Emoji generation (legacy — xcassets)

```bash
cd discourse-assets
bash emoji.sh --legacy
```

Generates `DiscourseEmojis.xcassets/` with `.imageset` directories instead. The `--legacy` flag is passed through to `discourse_emojis.py --legacy`, which also generates the `.image` extension on the enum (for `Image(name, bundle: .module)` loading).

### Icon generation

```bash
cd discourse-assets
bash icon.sh
```

### What the scripts produce

| Script | Output | Count |
|--------|--------|-------|
| `discourse_emojis.py` | `Emojis/` flat PNGs + `DiscourseEmoji.swift` | 1,904 emoji + tone variants |
| `discourse_emojis.py --legacy` | `DiscourseEmojis.xcassets/` + enum with `.image` | same |
| `generate_emoji_lookups.py` | `EmojiAliasTable.swift`, `EmojiReplacementTable.swift`, `EmojiToneTable.swift` | ~5,900 lines |
| `generate_emoji_items.py` | `EmojiItemTable.swift` | ~2,000 lines |
| `discourse_sprite_icons.py` | `DiscourseIcons.xcassets/` + `DiscourseIcon.swift` | 347 icons |

**Never hand-edit generated files.** Regenerate from scripts instead.

---

## Architecture Patterns

### Flat PNG Loading (Emoji)

Emoji PNGs are bundled as flat files via `.copy("Resources/Emojis")` — **no `actool` compilation**. This avoids the memory explosion that xcassets caused with 3,400+ imagesets.

All emoji image loading goes through `EmojiImageCache`, which uses `Bundle.module.url(forResource:withExtension:subdirectory:"Emojis")` + `NSCache`.

Two bounded cache tiers (see `DAK_EMOJITEXT_PERF_PLAN.md` at the umbrella root for the F23/F48 rationale):
- **Decoded source PNGs** — `totalCostLimit` 64 MB, cost = pixel bytes.
- **Resized bitmaps** (internal, `resizedImage(named:size:)`) — `countLimit` 512 / 16 MB; one `UIGraphicsImageRenderer` pass per unique (asset, size). `EmojiText` renders through this tier via `EmojiResolver.resolvedResizedImage(for:tone:size:)`.

`EmojiText` additionally memoizes the built `Text` + VoiceOver string per (rawText, emojiSize) in a `@MainActor` 256-entry NSCache, with a no-emoji fast path (no ":", no Unicode Emoji-property scalar, no scalar from the table-derived exception set — ♡/☻ lack the Emoji property) that skips the pipeline entirely.

```swift
// Centralized loader (EmojiImageCache.swift)
EmojiImageCache.image(named: "emoji_wave")           // UIImage? (cached)

// Convenience property (EmojiImageCache.swift extension)
DiscourseEmoji.emojiWave.image                        // SwiftUI Image

// Tone-aware loading (EmojiResolver.swift)
EmojiResolver.resolvedImage(for: .emojiWave, tone: .dark)  // UIImage? (cached)
```

### Bundle.module (Icons)

Icon assets use `Bundle.module` via standard xcassets (335 icons — small enough for `actool`):

```swift
// Icons — still use xcassets for template rendering
Image(self.rawValue, bundle: .module)                 // DiscourseIcon.image
```

### Swift 6 Concurrency

- `EmojiPickerStore` is `@MainActor` (UI-bound `@Observable`)
- `EmojiRecents`, `EmojiTonePreference` static methods are `@MainActor`
- `EmojiImageCache` uses `nonisolated(unsafe)` for thread-safe `NSCache` static
- `PreferenceKey.defaultValue` uses `nonisolated(unsafe)` for Swift 6 compatibility

### Access Control

- **Public:** All types, views, inits, and methods consumers need
- **Private:** Preview views, helper extensions

---

## Development

### Building

```bash
# Package (library only)
cd DiscourseAssetKit
xcodebuild -scheme DiscourseAssetKit -destination 'generic/platform=iOS' build

# Demo app
xcodebuild -project DakDemo/DakDemo.xcodeproj -scheme DakDemo -destination 'generic/platform=iOS' build

# Or open in Xcode
open Package.swift           # package
open DakDemo/DakDemo.xcodeproj  # demo app
```

### Previews

Open the package in Xcode and navigate to any file with `#Preview`:

| Preview | File | Shows |
|---------|------|-------|
| Emoji Catalog | `Previews/EmojiCatalogPreview.swift` | Searchable grid of all 1,904 emoji |
| Icon Catalog | `Previews/IconCatalogPreview.swift` | Searchable grid of all 347 icons |
| Emoji Picker | `Previews/EmojiPickerPreview.swift` | Full picker with selection + debug info |
| Emoji View | `Views/DiscourseEmojiView.swift` | Shortcode, enum, and fallback display |
| Emoji Text | `Views/EmojiText.swift` | Inline shortcode + Unicode rendering |

### Known Warnings

These are pre-existing and non-blocking:
- `Text` concatenation deprecated in iOS 26 (use string interpolation) — affects `EmojiText`
- `file-image` asset name collision with `file` — cosmetic, from icon assets

### Adding New Emoji/Icons

1. Update `discourse-assets/assets/emojis.json` or `sprite.svg` from your Discourse instance
2. Run `cd discourse-assets && bash emoji.sh` (or `bash icon.sh`)
3. Build to verify

---

## Submodule

The `discourse-assets/` directory is a git submodule containing:
- Python generation scripts (`discourse_emojis.py`, `generate_emoji_lookups.py`, `generate_emoji_items.py`)
- Shell orchestrators (`emoji.sh`, `icon.sh`)
- Source data (`emojis.json`, `data.js`, `sprite.svg`)

```bash
# Update submodule
git submodule update --init --recursive
```

---

## File Quick Reference

| What | Where |
|------|-------|
| Package manifest | `Package.swift` |
| All emoji PNGs | `Sources/.../Resources/Emojis/` |
| All icon assets | `Sources/.../Resources/DiscourseIcons.xcassets/` |
| Image cache + loader | `Sources/.../Emoji/EmojiImageCache.swift` |
| Resolution logic | `Sources/.../Emoji/EmojiResolver.swift` |
| Picker UI | `Sources/.../Views/EmojiPickerView.swift` |
| State management | `Sources/.../Emoji/Store/EmojiPickerStore.swift` |
| Generation scripts | `discourse-assets/*.py` |
| Generation entry point | `discourse-assets/emoji.sh` |
| Demo app | `DakDemo/` |
