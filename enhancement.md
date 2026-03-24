# DiscourseAssetKit — Enhancement Plans

> Architecture review conducted 2026-03-23. Completed items removed; only remaining work listed.

---

## Summary

| # | Enhancement | Priority | Complexity | Risk | Benefit |
|---|-------------|----------|------------|------|---------|
| 1 | ~~[Image Cache Layer](#1-image-cache-layer)~~ | ~~P0~~ | ~~Medium~~ | ~~Low~~ | ~~High~~ |
| 1b | [Size-Aware Resize Cache](#1b-size-aware-resize-cache) | P2 | Low (~20 lines) | Low | Medium |
| 2 | [Core Test Suite](#2-core-test-suite) | P0 | Medium (~250 lines) | Low | High |
| 3 | [Accessibility Improvements](#3-accessibility-improvements) | P1 | Low (~20 lines) | Low | Medium |
| 4 | [Lazy Static Table Initialization](#4-lazy-static-table-initialization) | P3 | High (~100+ lines) | Medium | Low |

**Recommended order:** 2 → 3 → 1b → 4 (only if profiling warrants)

---

## Completed (removed from plan)

- ~~O(1) Enum Lookup Dictionary~~ — done for both `DiscourseEmoji` and `DiscourseIcon`
- ~~Refactor Duplicated Tone Parsing~~ — `parseToneSuffix()` helper extracted
- ~~Structured Error Handling~~ — `os.Logger` added to `EmojiPickerStore` and `EmojiMetadataRepository`
- ~~Replace Deprecated UIScreen.main~~ — uses `GeometryReader` + `NotificationCenter`
- ~~Design System Constants~~ — `DesignTokens.swift` with spacing/radius/sizing tokens
- ~~EmojiCatalogPreview Full Display~~ — `.prefix(200)` removed, shows all emoji
- ~~Image Cache Layer~~ — `EmojiImageCache` with `NSCache` implemented as part of flat PNG migration (replaces `UIImage(named:in:.module)` which had system cache; `UIImage(contentsOfFile:)` does not)

---

## P0 — Critical

### 1b. Size-Aware Resize Cache

**Problem:** `EmojiText` creates a **new `UIGraphicsImageRenderer`** for every inline emoji on every render via `UIImage.resized(to:)`. Base image loading is now cached by `EmojiImageCache`, but the per-size resize still allocates each time.

**Solution:** Add a size-aware cache key (`"\(assetName)_\(width)x\(height)"`) to `EmojiImageCache` or a dedicated resize cache.

**Files:**
| File | Change |
|------|--------|
| `Emoji/EmojiImageCache.swift` | Add `resizedImage(named:size:)` with size-keyed cache |
| `Views/EmojiText.swift` | Replace `uiImage.resized(to:)` with cached variant |

**Complexity:** Low (~20 lines)
**Risk:** Low — additive
**Benefit:** Medium — eliminates per-render `UIGraphicsImageRenderer` allocations in `EmojiText`

---

### 2. Core Test Suite

**Problem:** Only an empty placeholder test exists. The resolver pipeline, lookup table consistency, tone parsing, search logic, and metadata decoding are all untested. Any refactoring (including enhancement 1) is risky without coverage.

**Solution:** Add focused test files covering core logic (not UI).

**Files:**
| File | Coverage |
|------|----------|
| `Tests/.../EmojiResolverTests.swift` (new) | Shortcode resolution, alias canonicalization, Unicode resolution, tone parsing, edge cases |
| `Tests/.../EmojiPickerStoreTests.swift` (new) | Search ranking, normalization, rebuild from bundled JSON |
| `Tests/.../LookupTableConsistencyTests.swift` (new) | Every alias resolves to a valid enum case; replacement table entries resolve; tonable entries exist |
| `Tests/.../DiscourseAssetKitTests.swift` | Replace placeholder |

**Complexity:** Medium (~250 lines across files)
**Risk:** Low — purely additive
**Benefit:** High — enables safe refactoring, catches generated data drift

---

## P1 — High Value

### 3. Accessibility Improvements

**Problem:**
- `DiscourseEmojiView` reads raw asset name (e.g., "emoji_motorcycle") to VoiceOver — basic label exists but not human-readable
- `DiscourseIconView` reads kebab-case (e.g., "bell-slash") — basic label exists but not human-readable
- `EmojiText` has **zero** accessibility — screen readers get no info about inline emoji
- `EmojiPickerView` grid items and category buttons lack accessibility labels/hints

**What's done:** Basic `.accessibilityLabel()` on `DiscourseEmojiView` and `DiscourseIconView`, plus labels on picker search/tone buttons.

**Remaining work:**
- Derive human-readable labels (strip `emoji_` prefix, replace `_`/`-` with spaces)
- Add `.isImage` trait to emoji/icon views
- Add `.accessibilityLabel()` to `EmojiText` inline emoji
- Add hints/labels for picker grid items and category rail

**Files:**
| File | Change |
|------|--------|
| `Views/DiscourseEmojiView.swift` | Human-readable label + `.isImage` trait |
| `Icon/DiscourseIconView.swift` | Human-readable label + `.isImage` trait |
| `Views/EmojiText.swift` | `.accessibilityLabel()` with readable text |
| `Views/EmojiPickerView.swift` | Grid item labels, category rail hints |

**Complexity:** Low (~20 lines remaining)
**Risk:** Low — additive modifiers only
**Benefit:** Medium — required for accessibility compliance

---

## P3 — Nice-to-Have

### 4. Lazy Static Table Initialization

**Problem:** `EmojiReplacementTable.swift` is a 3,457-line static dictionary literal (135 KB source). Compiled into a single initialization function that runs at first access. Could impact app launch if tables are accessed early.

**Solution:** Convert to binary plist loaded at runtime, or wrap in lazy computed property. Requires modifying Python generator.

**Files:**
| File | Change |
|------|--------|
| `discourse-assets/generate_emoji_lookups.py` | Output binary plist instead of Swift literal |
| `Emoji/EmojiReplacementTable.swift` | Load from resource instead of literal |

**Complexity:** High (~100+ lines across Python + Swift)
**Risk:** Medium — changes generation pipeline
**Benefit:** Low — only pursue if profiling confirms measurable launch impact

**Prerequisite:** Profile app launch to confirm this is a real bottleneck before investing.

---

## Architecture Strengths (No Changes Needed)

These areas are already well-designed:

- **Bundle.module usage** — consistent throughout, correct for SPM packages
- **Swift 6 concurrency** — `@MainActor`, `Sendable`, `async/await` all properly applied
- **Three-tier metadata fallback** — cached → bundled → remote with ETag/304
- **Atomic file writes** — corruption-safe with `replaceItemAt`
- **@Observable pattern** — modern Observation framework for picker state
- **Generated code separation** — clear boundary between hand-written and generated code
- **Resolution pipeline** — clean O(1) alias → sanitize → enum flow
- **O(1) enum lookups** — both `DiscourseEmoji` and `DiscourseIcon` use dictionary-backed lookup
