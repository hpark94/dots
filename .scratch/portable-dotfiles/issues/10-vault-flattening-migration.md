# 10 Migrating the existing vault to the flat layout

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

[04](04-note-restructure-prototype.md) decided the vault goes flat: every note in the root, only
`assets/` and `templates/` keep directories. **How does the vault that exists today get there without
losing notes or breaking links?**

### The collision risk, which is the real problem

Today the vault is `daily/`, `zettelkasten/`, `scratch/`, `assets/`, `templates/`. Flattening merges
four namespaces into one, and **the directories were doing disambiguation work that filenames now
have to do alone**:

- Two notes with the same title in different directories become the same filename. There is nothing
  in the current layout stopping `zettelkasten/ideen.md` and `scratch/ideen.md` from coexisting.
- A zettel whose slug happens to look like a daily (`20260722`) or a scratch (`scratch-4`) would be
  picked up by the pattern rules `-u` now uses to *exclude* those types, and silently skipped
  forever after.

So the migration needs a collision policy, and the answer may feed back into whether the naming
scheme itself needs a discriminator.

### The other open pieces

1. **Wiki links that embed a path.** `[[name]]` links survive a flatten untouched, but
   `note:265-266` shows the update script also rewrites markdown-style links containing
   `/<ref>.md`. Any link written as a *path* rather than a bare ref breaks when the directory goes
   away. Needs a survey of what actually exists in the vault before deciding whether it matters.
2. **What maintains `templates/` inside the vault.** [04](04-note-restructure-prototype.md) dropped
   the `sync` operation, which is what copied `.config/notes/templates` into `${VAULT_BASE_PATH}` in
   the first place (`note:212-220`). If the vault still needs a `templates/`, something has to put it
   there: a restored sync, a symlink (which Syncthing and Obsidian may not follow), or a decision
   that `.config/notes/templates` is the only copy and the vault does not need one. Note the same
   code also copies `.marksman.toml` into the vault root.
3. **`.obsidian/`.** `note:222` excludes it from formatting, so the vault is an Obsidian vault.
   Obsidian stores per-vault state that may reference paths.
4. **Whether the migration is scripted or one-shot.** It runs once on one machine. A throwaway
   script that is reviewed and discarded may beat a permanent `note` subcommand, given
   [04](04-note-restructure-prototype.md) just cut the roster down specifically to remove options.

### What resolution must cover

The collision policy, what happens to path-style links, what `templates/` becomes, and whether any of
this ships as code or is done once by hand.

### Watch for scope

The vault is *data*, not dotfiles. This ticket exists because
[04](04-note-restructure-prototype.md)'s layout decision cannot be implemented without it, so keep it
to the migration. General notetaking workflow is not in this map.

## Answer

### The survey moved the ground: the assumed risk is empty, the surveyed one is the whole job

Measured against the live vault (658 notes: `daily` 271, `zettelkasten` 378, `scratch` 9):

| | |
|---|---|
| Basename collisions across the three merging directories | **zero** |
| Zettels whose filename matches `^[0-9]{8}\.md$` or `^scratch-[0-9]+\.md$` | **none** |
| Subdirectories inside the three | none |
| Non-`.md` files inside the three | none |
| **`../assets/` references** | **436** (349 `](../assets/…)`, 87 `[[../assets/…]]`) in 205 files |
| Note-to-note links carrying a path | **one**, `[[zettelkasten/pinned-todo\|Todo-Liste]]` |
| `../` pointing anywhere other than `assets/` | none |

So the collision problem this ticket was written around does not exist in the data, and the item it
listed as needing a survey is the actual work. The flatten does not break links between notes,
because Obsidian-style `[[name]]` refs never carried a path. It breaks **asset** links, in bulk,
because `../assets/x.png` from a note in the root resolves to `~/Sync/assets/`, outside the vault.

### 1. Collision policy: verify and refuse

No merge rule, no auto-disambiguation, and **no discriminator added to the naming scheme**. The
migration counts basenames first, and if any name would appear twice it stops and prints the pairs
for the operator to resolve by hand.

A permanent discriminator was rejected: it charges every filename forever for a case that has never
occurred, and it would partly undo what [04](04-note-restructure-prototype.md) bought by cutting the
roster. Auto-disambiguation was rejected because it is a rule with no test case, and a silently
renamed note is worse than a migration that stops and shows you why.

**Handed to the `note` implementation spec, not decided here:** `-u` renames by heading, so a future
zettel titled "20260722" would slug into a name the exclusion pattern then treats as a daily and skips
forever. The guard belongs in `note` (refuse to rename onto a reserved pattern), not in a one-shot
migration.

### 2. Asset links become `[[assets/…]]`, and the generator is the one place that decides

The vault is read in Obsidian, where an absolute path does not resolve, so the link must stay
vault-relative. With every note in the root, the file-relative path and the vault-root-relative path
are the same string, which is what makes `assets/x.png` stable. **Wikilink style is the chosen form**
per the operator: `![[assets/x.png]]`.

The `../` prefix is written in exactly one place and read in exactly one place, which is why this is
cheap:

- `util.lua:86` `create_asset_link` returns `![[../%s]]`, and becomes `![[%s]]`.
- `core.lua:133-134` `delete_asset` matches `../assets/` and nothing else. It becomes tolerant of
  both forms. The vault is a Syncthing folder with at least one other device writing into it
  (`scratch-mobile.md`, and the `Screenshot_*_FitoTrack.jpg` assets), so a note carrying the old form
  can arrive after the migration. One extra pattern keeps those working.

### 3. `templates/` inside the vault: nothing maintains it

`.config/notes/templates` is the only copy. `note` reads templates from there and never writes a
`templates/` directory into the vault, so the `sync` operation that
[04](04-note-restructure-prototype.md) deleted is not replaced by anything. The vault's existing
`templates/` and its `.marksman.toml` become plain vault data, the operator's to keep or delete;
Obsidian's template plugin can point at whatever survives. This also removes `check_dirs`'s reason to
exist: `note` creates `assets/` at the point of need and nothing else.

### 4. The migration is done by hand, by the operator, and ships as no code at all

**Decided by the operator during this session, and it supersedes the framing of open piece 4.**
Nothing automated touches `~/Sync/vault`. The reason is stronger than "it runs once": the vault is a
live Syncthing folder shared with at least one other device, so a 658-file rename is a sync event as
much as a filesystem one, and the operator is the only one who can sequence it against the other
device.

What this ticket therefore hands over is a checklist, not a script:

1. Confirm zero collisions (`find daily zettelkasten scratch -maxdepth 1 -type f -printf '%f\n' | sort | uniq -d`).
2. Settle the other Syncthing device before moving anything.
3. Move `daily/*`, `zettelkasten/*`, `scratch/*` into the vault root; remove the three empty directories.
4. Rewrite `../assets/` to `assets/` across all `.md` files (436 refs, 205 files), and the single
   `[[zettelkasten/pinned-todo|…]]` to `[[pinned-todo|…]]`.
5. Decide what happens to the vault's `templates/`, per section 3.

`.obsidian/` needs nothing: the only path references in it are `workspace.json`'s open-tab and
backlink state, which Obsidian rebuilds. `core-plugins.json` enables `daily-notes` and `templates`
with no folder configured, which means both already default to the vault root, and the flat layout is
what they were expecting all along.

### 5. What this hands to the implementation

With this resolved, the notetaking rewrite is fully specified across
[04](04-note-restructure-prototype.md), [06](06-shared-note-config-shape.md) and this ticket. Three
constraints belong to whoever builds it:

- **The rewrite targets the flat layout regardless of when the vault actually moves**, so between
  now and the migration the deployed `note` and the live vault disagree. Acceptable: the create paths
  work in a flat root either way, and only `-u` and `-f` walk the tree.
- **It is exercised against a throwaway vault, never `~/Sync/vault`.** Untracked, and stow-ignored so
  `stow .` cannot link it into `$HOME`.
- **The reserved-pattern guard** from section 1: `-u` must refuse to rename a note onto
  `^[0-9]{8}\.md$` or `^scratch-[0-9]+\.md$`.
