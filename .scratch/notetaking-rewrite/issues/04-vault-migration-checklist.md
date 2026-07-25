# 04 — Vault migration checklist (operator, by hand)

**What to build:** Nothing agent-built. This ticket tracks the operator manually migrating the live
`~/Sync/vault` (658 notes) to the flat layout the rewritten `note` targets. It is a live Syncthing
folder shared with another device, so the rename is a sync event only the operator can sequence — no
automated migration script is written.

**Blocked by:** [01](01-note-core-config-role-gate-creation.md), [02](02-note-format-update.md), and
[03](03-nvim-cutover.md) — the deployed `note`, its config, and the nvim asset-link handling should
already target the flat layout and understand both asset-link forms before the live vault actually
moves.

**Status:** ready-for-human

- [ ] Confirm zero basename collisions across `daily/`, `zettelkasten/`, `scratch/`
      (`find daily zettelkasten scratch -maxdepth 1 -type f -printf '%f\n' | sort | uniq -d` prints
      nothing). If it prints anything, stop and resolve by hand.
- [ ] Settle the vault's state with the other Syncthing device before moving anything.
- [ ] Move `daily/*`, `zettelkasten/*`, `scratch/*` into the vault root; remove the three now-empty
      directories.
- [ ] Rewrite `../assets/` to `assets/` across every `.md` file in the vault, and rewrite the one
      path-style wikilink (`[[zettelkasten/pinned-todo|Todo-Liste]]`) to `[[pinned-todo|Todo-Liste]]`.
      Re-verify the reference count before running this — it was 436 references across 205 files at
      last survey, and the vault keeps receiving notes from another device in the meantime.
- [ ] Decide what to do with the vault's existing `templates/` and `.marksman.toml` (nothing in the
      rewritten `note` maintains or writes them any more) — keep or delete, operator's call.
- [ ] No `.obsidian/` changes needed — confirm its `daily-notes`/`templates` plugins still have no
      folder configured (already defaulting to the vault root).

**Further Notes:** See `.scratch/notetaking-rewrite/spec.md`, Implementation Decisions → "Vault
migration", and the original survey at
`.scratch/portable-dotfiles/issues/10-vault-flattening-migration.md`.
