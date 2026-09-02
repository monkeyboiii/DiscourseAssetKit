---
name: emojitext-perf-plan-lost
description: Sources/DiscourseAssetKit/Views/EmojiText.swift:6 and Emoji/EmojiImageCache.swift:17 cite DAK_EMOJITEXT_PERF_PLAN.md "(umbrella root)" — that file lived outside every repo and no longer exists; do not search for it.
metadata:
  type: project
---

Two live citations point at a document that was written at the DirtBikeX umbrella root (which is
not a git repo) and was never moved into this repo. `dbx graph` lists it as a phantom.

**What survives:** the F23/F48 rationale (memoized per-pass cost, bounded resize caches) is in
`agents.d/modules/ENHANCEMENT_PLAN.md` §1 (image cache, shipped) and §1b (size-aware resize
cache), and in the body of commit `e7f7b30` ("EmojiText: cache resized bitmaps + memoize render,
bound caches (F23/F48)").

**How to apply:** when next touching either file, rewrite the comment to cite
`agents.d/modules/ENHANCEMENT_PLAN.md § 1b` — or let `/module-doc retier` (harness Phase 1) do it.
Do not recreate the plan doc from memory.
