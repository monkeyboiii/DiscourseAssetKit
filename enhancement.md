# DiscourseAssetKit — Enhancement Plans

> Architecture review conducted 2026-03-23. Each enhancement is a self-contained, single-phase unit of work.

---

## Overall Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Code Quality | **A** | Clean naming, consistent patterns, good separation of concerns |
| Swift 6 Concurrency | **A+** | Proper `@MainActor`, `Sendable`, `async/await` throughout |
| Performance | **C+** | No image caching, O(n) enum lookup in hot paths, per-render image resizing |
| Accessibility | **D** | Raw asset names as labels, no hints/traits, `EmojiText` has none |
| Test Coverage | **F** | Empty placeholder — zero tests |
| Error Handling | **B** | Good structure, but silent failures in key paths |
| Design System | **C** | Only a hex color parser; magic numbers scattered |

---

## Summary

| # | Enhancement | Priority | Complexity | Risk | Benefit |
|---|-------------|----------|------------|------|---------|
| 1 | [O(1) Enum Lookup Dictionary](#1-o1-enum-lookup-dictionary) | P0 | Low (~20 lines) | Low | High |
| 2 | [Image Cache Layer](#2-image-cache-layer) | P0 | Medium (~70 lines) | Low | High |
| 3 | [Core Test Suite](#3-core-test-suite) | P0 | Medium (~250 lines) | Low | High |
| 4 | [Refactor Duplicated Tone Parsing](#4-refactor-duplicated-tone-parsing) | P1 | Low (~25 lines) | Low | Medium |
| 5 | [Accessibility Improvements](#5-accessibility-improvements) | P1 | Low (~35 lines) | Low | Medium |
| 6 | [Structured Error Handling](#6-structured-error-handling) | P1 | Low (~30 lines) | Low | Medium |
| 7 | [Replace Deprecated UIScreen.main](#7-replace-deprecated-uiscreenmain) | P2 | Low (~15 lines) | Low | Low–Med |
| 8 | [Design System Constants](#8-design-system-constants) | P2 | Low (~60 lines) | Low | Low–Med |
| 9 | [EmojiCatalogPreview Full Display](#9-emojicatalogpreview-full-display) | P2 | Low (~3 lines) | Low | Low |
| 10 | [Lazy Static Table Initialization](#10-lazy-static-table-initialization) | P3 | High (~100+ lines) | Medium | Low |

**Recommended order:** 1 → 3 → 2 → 4 → 6 → 5 → 7–9 → 10 (only if profiling warrants)

---

## P0 — Critical

### 1. O(1) Enum Lookup Dictionary

**Problem:** `DiscourseEmoji(rawValue:)` performs a linear scan through 1,904 cases. Called in hot paths: `EmojiResolver.resolve()` (every shortcode resolution), `EmojiPickerStore.rebuild()` (1,904× at init), and indirectly in `EmojiText`.

**Solution:** Add a static `[String: DiscourseEmoji]` dictionary built from `allCases`. Provide `static func fromRawValue(_:)` as the O(1) alternative.

**Files:**
| File | Change |
|------|--------|
| `Emoji/DiscourseEmoji.swift` | Add `rawValueLookup` dictionary + `fromRawValue()` method |
| `Emoji/EmojiResolver.swift` | Replace `DiscourseEmoji(rawValue:)` at lines 24, 103 |
| `Emoji/EmojiPickerStore.swift` | Replace `DiscourseEmoji(rawValue:)` at line 93 |

**Complexity:** Low (~20 lines) — highest ROI change in the package
**Risk:** Low — dictionary built from same `allCases` source of truth
**Benefit:** High — `rebuild()` drops from O(n²) to O(n); every `resolve()` goes from ~1,904 comparisons to O(1)

---

### 2. Image Cache Layer

**Problem:** Three distinct uncached image loading paths:
1. `DiscourseEmojiView` calls `UIImage(named:in:compatibleWith:)` every render (has system cache, but tone-aware loads bypass it)
2. `EmojiPickerView.emojiCellImage()` calls `EmojiResolver.resolvedImage()` in view builder for every grid cell during scroll
3. `EmojiText` creates a **new `UIGraphicsImageRenderer`** for every inline emoji on every render via `UIImage.resized(to:)` — the most severe issue

**Solution:** Add `NSCache<NSString, UIImage>` in `EmojiResolver` keyed by `"\(assetName)_t\(tone)_\(size)"`. Wrap `resolvedImage(for:tone:)` to check cache first. Add a size-aware variant. Update `EmojiText` to use cached pre-resized images.

**Files:**
| File | Change |
|------|--------|
| `Emoji/EmojiResolver.swift` | Add `NSCache`-backed `resolvedImage(for:tone:size:)` |
| `Views/EmojiText.swift` | Replace per-render `uiImage.resized(to:)` with cached variant |

**Complexity:** Medium (~70 lines)
**Risk:** Low — `NSCache` auto-evicts under memory pressure; no behavioral change
**Benefit:** High — eliminates per-render `UIGraphicsImageRenderer` allocations, smooth picker scrolling

---

### 3. Core Test Suite

**Problem:** Only an empty placeholder test exists. The resolver pipeline, lookup table consistency, tone parsing, search logic, and metadata decoding are all untested. Any refactoring (including enhancements 1, 2, 4) is risky without coverage.

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

### 4. Refactor Duplicated Tone Parsing

**Problem:** `resolveWithTone()` (lines 79–107) and `resolveUnicodeWithTone()` (lines 48–66) in `EmojiResolver.swift` contain nearly identical tone-suffix parsing logic: split on `:`, check for `t` prefix, parse integer, map to `EmojiSkinTone`. ~30 lines of duplication.

**Solution:** Extract `private static func parseToneSuffix(_:) -> (baseName: String, tone: EmojiSkinTone)` and call from both methods.

**Files:**
| File | Change |
|------|--------|
| `Emoji/EmojiResolver.swift` | Extract helper, simplify both methods |

**Complexity:** Low (~25 lines net)
**Risk:** Low — structural refactor, validated by Enhancement 3 tests
**Benefit:** Medium — eliminates subtle divergence risk between two tone-parsing paths

---

### 5. Accessibility Improvements

**Problem:**
- `DiscourseEmojiView` reads **"emoji_motorcycle"** to VoiceOver (line 25 — raw asset name)
- `DiscourseIconView` reads **"bell-slash"** (kebab-case, line 26)
- `EmojiText` has **zero** accessibility — screen readers get no info about inline emoji
- Missing `.accessibilityHint()`, `.accessibilityAddTraits(.isImage)` throughout

**Solution:** Derive human-readable labels (strip `emoji_` prefix, replace `_`/`-` with spaces). Add `.isImage` trait. Provide alt text for `EmojiText`.

**Files:**
| File | Change |
|------|--------|
| `Views/DiscourseEmojiView.swift` | Readable label + `.isImage` trait |
| `Icon/DiscourseIconView.swift` | Readable label + `.isImage` trait |
| `Views/EmojiText.swift` | `.accessibilityLabel()` with readable text |
| `Views/EmojiPickerView.swift` | Add hints for grid, category rail navigation role |

**Complexity:** Low (~35 lines)
**Risk:** Low — additive modifiers only
**Benefit:** Medium — required for accessibility compliance

---

### 6. Structured Error Handling

**Problem:**
- `EmojiPickerStore.rebuildFromDiskOrBundle()` (lines 26–35) silently swallows all errors and wipes state — a corrupted cache means zero emoji with no diagnostic
- `EmojiMetadataRepository.atomicWrite()` (line 140) uses `try? removeItem` before `moveItem` — if remove fails (e.g., file locked), `moveItem` crashes
- Cache directory creation at line 131 uses `try?` silently

**Solution:**
- Add `os.Logger` logging in catch blocks
- In `rebuildFromDiskOrBundle()`: if cached data fails, delete cache and retry with bundled before wiping state
- Replace remove+move with `FileManager.replaceItemAt(_:withItemAt:)`

**Files:**
| File | Change |
|------|--------|
| `Emoji/EmojiPickerStore.swift` | Logging + fallback-to-bundle retry |
| `Emoji/EmojiMetadataRepository.swift` | Fix `atomicWrite`, add logging |

**Complexity:** Low (~30 lines)
**Risk:** Low — improves resilience without changing happy path
**Benefit:** Medium — fixes a real potential crash, enables debugging

---

## P2 — Medium Value

### 7. Replace Deprecated UIScreen.main

**Problem:** `EmojiPickerView` uses `UIScreen.main.bounds.maxY` (line 79) for keyboard overlap calculation. Deprecated in iOS 26.

**Solution:** Use `GeometryReader` to capture the view's frame in global coordinate space, or read from the key window via connected scenes.

**Files:**
| File | Change |
|------|--------|
| `Views/EmojiPickerView.swift` | Replace `UIScreen.main` with geometry-based approach |

**Complexity:** Low (~15 lines)
**Risk:** Low — straightforward API migration
**Benefit:** Low–Medium — eliminates deprecation warning, multi-scene ready

---

### 8. Design System Constants

**Problem:** Magic numbers scattered throughout `EmojiPickerView`: spacing (4, 6, 8, 12, 16), corner radii (8, 14, 16), cell sizes (44, 28, 34, 18). Three different corner radii in one view. No shared constants across files.

**Solution:** Create a `DesignTokens` enum with spacing, radius, and sizing constants.

**Files:**
| File | Change |
|------|--------|
| `DesignSystem/DesignTokens.swift` (new) | Define spacing/radius/sizing constants |
| `Views/EmojiPickerView.swift` | Replace magic numbers with tokens |

**Complexity:** Low (~60 lines)
**Risk:** Low — no behavioral change
**Benefit:** Low–Medium — improves consistency and future theming

---

### 9. EmojiCatalogPreview Full Display

**Problem:** `EmojiCatalogPreview` shows only 200 of 1,904 emoji by default (`.prefix(200)` at line 12) but displays "1,904" in the title. Misleading. `LazyVGrid` already handles virtualization, so the limit is unnecessary.

**Solution:** Remove `.prefix(200)`. Show filtered count vs total in title.

**Files:**
| File | Change |
|------|--------|
| `Previews/EmojiCatalogPreview.swift` | Remove prefix limit, update title |

**Complexity:** Low (~3 lines)
**Risk:** Low — preview-only code
**Benefit:** Low — fixes misleading preview for dev/QA

---

## P3 — Nice-to-Have

### 10. Lazy Static Table Initialization

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
- **Atomic file writes** — prevents corruption on crash (needs minor fix in Enhancement 6)
- **@Observable pattern** — modern Observation framework for picker state
- **Generated code separation** — clear boundary between hand-written and generated code
- **Resolution pipeline** — clean O(1) alias → sanitize → enum flow (after Enhancement 1)
