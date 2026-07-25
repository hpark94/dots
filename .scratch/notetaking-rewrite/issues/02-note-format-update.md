# 02 — `note -f`/`-u`: format and update, with the reserved-pattern guard

**What to build:** The two maintenance operations on the flat vault. `note -f` runs prettier over the
vault root. `note -u` renames any note whose `# heading` no longer matches its filename, rewriting
every wiki-style and path-style reference to the old name across the vault, while leaving daily and
scratch notes untouched and refusing to rename any note onto a filename that would collide with an
existing file or with the daily/scratch reserved patterns.

**Blocked by:** [01 — `note` core: config, Role gate, and note creation](01-note-core-config-role-gate-creation.md).

**Status:** ready-for-agent

- [ ] `-f` runs `prettier --write` over the `*.md` files directly in the vault root (not recursively
      into `assets/`/`templates/`).
- [ ] `-u` walks the vault root only, excludes filenames matching `^[0-9]{8}\.md$` (daily) and
      `^scratch-[0-9]+\.md$` (scratch) from renaming.
- [ ] For each remaining note, `-u` reads the first `# heading`, slugs it, and if the slug differs from
      the current filename: rewrites every `[[old#...]]`, `[[old|...]]`, `[[old]]`, and
      `.../old.md`-style reference across the vault, then renames the file.
- [ ] `-u` refuses (skips with a stderr message, does not rename) when the computed new name already
      exists as a different file, or when it matches the daily/scratch reserved pattern.
- [ ] `-u`'s working sed script uses `mktemp`, not a fixed `/tmp` path.
- [ ] `.local/scripts/tests/note.bats` gains coverage: a rename-by-heading case where another note's
      `[[old...]]` reference is correctly rewritten to the new name; confirmation that a daily note and
      a scratch note are never touched by `-u` even when their heading looks like a title; refusal on a
      pre-existing-filename collision; refusal on a rename that would produce a daily/scratch-shaped
      filename.
- [ ] `-f` gets a guard-path smoke test only ("does not error when prettier is absent"), matching the
      `apply_foot`/`apply_sway`/`apply_gtk` precedent in `theme-switch.bats` — no branching logic to
      verify beyond that.

**Further Notes:** See `.scratch/notetaking-rewrite/spec.md`, Implementation Decisions → "`note -u`
(update)" and Testing Decisions.
