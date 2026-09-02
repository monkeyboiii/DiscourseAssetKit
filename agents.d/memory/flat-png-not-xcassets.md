---
name: flat-png-not-xcassets
description: Emoji PNGs are shipped as flat files under Resources/Emojis (Package.swift `.copy`) and loaded via Bundle.module.url(forResource:subdirectory:) — NOT as an xcassets catalog; do not "tidy" them into one.
metadata:
  type: project
---

`Package.swift` declares `.copy("Resources/Emojis")` for the 3,400+ emoji PNGs and
`.process("Resources/DiscourseIcons.xcassets")` only for the 335 icon PDFs. The split is
deliberate: an asset catalog at emoji scale makes `actool` explode in memory at build time.

**Why:** recorded in `modules/emoji-picker-context.md § Project Overview` ("flat files … **not**
xcassets (to avoid actool memory explosion at that scale)") and visible in `Package.swift:18-19`.

**How to apply:** load emoji with `Bundle.module.url(forResource:withExtension:subdirectory:"Emojis")`;
never add emoji to `DiscourseIcons.xcassets`; a PR that moves `Resources/Emojis` into a catalog is
wrong even if it builds on a fast Mac.
