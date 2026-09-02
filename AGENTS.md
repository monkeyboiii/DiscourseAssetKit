# AGENTS.md — DiscourseAssetKit

The repo contract. Everything else an agent needs is under `agents.d/` — shape and rules in the
harness's `playbook/agents-d.md`.

- Read `agents.d/memory/MEMORY.md` first: two facts, one of which changes how images are loaded.
- The why-doc is `agents.d/modules/DISCOURSE_ASSET_KIT_MODULE.md`; the open work is
  `agents.d/modules/ENHANCEMENT_PLAN.md`.
- This package **cannot be built on the Linux dev box** (no Xcode). Swift changes are
  compile-by-inspection; the operator builds on a Mac.
- The iOS app consumes this package **from GitHub via `Package.resolved`**, not by local path:
  a local edit changes nothing in the app until it is pushed and tagged.
- Never turn the emoji PNGs into an xcassets catalog (see memory).
- Surgical, simple, never invent a path — the harness `AGENTS.md` discipline applies here.
