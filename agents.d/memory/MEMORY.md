# DiscourseAssetKit memory index

Facts true **only** for this repo. Lazily loaded: read this index, then open only the fact you
need. One line per fact; the fact itself lives in its own file.

- [Emoji PNGs are flat files, never xcassets](flat-png-not-xcassets.md) — `Bundle.module.url(forResource:subdirectory:"Emojis")`; an asset catalog of 3,400 images blows up actool
- [The EmojiText perf plan is gone](emojitext-perf-plan-lost.md) — two source files cite `DAK_EMOJITEXT_PERF_PLAN.md (umbrella root)`; it lived in no repo; the decisions survive in `ENHANCEMENT_PLAN.md` §1/§1b and commit `e7f7b30`
