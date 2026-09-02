# skills

Repo-local skills for DiscourseAssetKit. None yet — nothing here can run on the Linux dev box
(no Xcode), so there is no build or test loop to script.

A skill is `<name>/SKILL.md` (+ optional `scripts/`) with frontmatter `name` (== the directory)
and `description` (ending in an `Args:` clause). Carry the repo in the name — `dak-<verb>` — because
the harness links every skill into one flat namespace (`dbx skills sync`) and renders the
description with `dbx skills list` / `dbx skills show NAME`.
