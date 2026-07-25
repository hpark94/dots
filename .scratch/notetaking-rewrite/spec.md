Status: ready-for-agent

# Notetaking rewrite: `note`, its config, and the vault layout

## Problem Statement

`.local/scripts/note` is a 14-flag bash script whose flag dispatch is a boolean side-effect array,
whose seven note-type case arms are sixty lines of near-identical control flow wearing a four-column
table, and whose Korean/Unicode filename sanitizing depends on hardcoded codepoint ranges in a
`python3` shellout. It fails silently throughout: no `set -euo pipefail`, hardcoded `/tmp` scratch
files that collide between concurrent runs, and a `sed ... > file` pattern that leaves a zero-byte
note behind on a failed substitution. `scratch` is a second script that exists only to allocate an
id and re-shell out to `note`. Its shared config, `.config/notes/config.sh`, is a bash file that every
non-bash consumer pays a subprocess to read: nvim's `util.lua` runs `bash -c "source <path> && echo
$VAR"` on nearly every notetaking keystroke, and when that config is missing, the read fails **open**
rather than closed (`vim.startswith(path, "")` is true for every path in existence), so every markdown
buffer on the system would be treated as a note. The live vault also has a directory-based layout
(`daily/`, `zettelkasten/`, `scratch/`) that a flat rewrite cannot simply run against without a
one-time migration.

This spec is the write-up of decisions already made across three tickets on the [Portable dotfiles
map](../portable-dotfiles/map.md): [Restructure `note`: language and target
shape](../portable-dotfiles/issues/04-note-restructure-prototype.md), [Shape of the shared note
config](../portable-dotfiles/issues/06-shared-note-config-shape.md), and [Migrating the existing vault
to the flat layout](../portable-dotfiles/issues/10-vault-flattening-migration.md).

## Solution

`note` stays bash and drops its `python3` dependency entirely, using a locale-aware
`[[:alnum:]]`-based slug function instead of hardcoded Unicode ranges. Its roster shrinks from 14
flags to 7 (`-z`, `-d [N]`, `-sn`, `-sl`, `-x`, `-f`, `-u`); `scratch` is deleted outright and folds
into `-sn`/`-sl`; `yesterday`/`tomorrow` become the `-d` day-offset argument instead of separate types.
The vault goes flat: every note lives in the vault root, and only `assets/` and `templates/` keep
directories. The note-type table becomes parallel associative arrays rather than a delimited-record
table, so a malformed row fails loudly instead of being silently padded. `note` always prints the
created/found path to stdout and never opens an editor itself; the `--nvim-mode` flag is deleted.
`note` also becomes Desktop-only, refusing on a Headless machine rather than `mkdir -p`ing a vault
tree that syncs nowhere there, per [Name the split](../portable-dotfiles/issues/01-name-the-split.md)
and the canonical Role Marker reader pinned by [How a script reads the Role
Marker](../portable-dotfiles/issues/13-role-marker-reader.md) and [Conventions for the
`.local/scripts/` set](../portable-dotfiles/issues/14-script-conventions.md).

The shared config becomes one JSON file, `.config/notes/config.json`, holding a single `vault` key.
`note` reads it once at startup via `jq`; nvim's `util.lua` reads it once at `setup()` via
`vim.json.decode` and caches it, eliminating the per-lookup bash subprocess entirely. Both sides fail
**closed**: a missing, malformed, or empty config produces "not a note" (nvim) or a hard error (bash),
never "everything is a note." `.config/notes/config.sh` is deleted outright; nothing in it survives as
config, since `VAULT_*` derivations, `check_dirs`, `normalize_filename`, and `handle_exe` are all
either derived, dead with the flat vault, or gone with `--nvim-mode`.

The existing live vault (658 notes) migrates to the flat layout by hand, by the operator, as a
checklist rather than a script, because it is a live Syncthing folder shared with another device and
the rename is a sync event only the operator can sequence.

## User Stories

1. As the dotfiles owner, I want to create a new zettel with `note -z "title"`, so that a correctly
   slugged note appears in the vault root without me typing a path.
2. As the dotfiles owner, I want `note -z` to slug Korean, German, Japanese, and other non-ASCII
   titles correctly, so that my non-English note titles produce readable, non-colliding filenames.
3. As the dotfiles owner, I want today's daily note created with `note -d`, so that I don't have to
   remember the date format.
4. As the dotfiles owner, I want yesterday's and tomorrow's daily notes created with `note -d -1` and
   `note -d 1`, so that I can navigate adjacent daily notes without a separate flag per direction.
5. As the dotfiles owner, I want an arbitrary day offset via `note -d N`, so that I can jump to any
   daily note by relative day count, not just yesterday/today/tomorrow.
6. As the dotfiles owner, I want `note -sn` to create the next scratch note and `note -sl` to reopen
   the last one, so that I keep a lightweight scratch-note sequence without a separate `scratch`
   script.
7. As the dotfiles owner, I want `note -x` to create a new Xournal++ file under `assets/`, so that
   handwritten notes land in the vault the same way typed ones do.
8. As the dotfiles owner, I want `note -f` to run prettier over the vault, so that my notes stay
   consistently formatted.
9. As the dotfiles owner, I want `note -u` to rename a note to match its `# heading` and rewrite every
   wiki link that pointed at its old name, so that renaming a note in place doesn't leave dangling
   links.
10. As the dotfiles owner, I want `note -u` to never rename a daily note or a scratch note, so that a
    daily note whose heading looks like a title (e.g. a date) doesn't get renamed out of its reserved
    filename pattern.
11. As the dotfiles owner, I want `note -u` to refuse renaming any note onto a filename that matches
    the daily (`^[0-9]{8}\.md$`) or scratch (`^scratch-[0-9]+\.md$`) reserved pattern, so that a
    same-looking title can never silently collide with a daily or scratch note.
12. As the dotfiles owner, I want every dropped note type (`code`, `pinned`, `review`, `recipe`,
    `todo`, `sync`) to be gone from `note`, so that the script's surface matches what I actually use.
13. As the dotfiles owner, I want `note` to always print only the resulting path to stdout, with every
    other message on stderr, so that I can pipe its output (`nvim "$(note -z title)"`) without
    filtering.
14. As the dotfiles owner, I want `note` to refuse to run on a Headless machine with a clear error, so
    that I never accidentally create a vault tree on a machine whose vault syncs nowhere.
15. As the dotfiles owner, I want a shell function (`n`) that opens whatever path `note` prints in
    nvim, so that terminal note-taking is one keystroke without a `--nvim-mode` flag to remember.
16. As the dotfiles owner, I want template placeholders to be uniformly `{{name}}`-shaped, so that
    substituting one placeholder can never accidentally rewrite unrelated words elsewhere in the
    template.
17. As the dotfiles owner, I want a failed template substitution to never leave a zero-byte note
    behind, so that a `sed` failure can't silently destroy the note I was trying to create.
18. As the dotfiles owner, I want `note -u`'s working files to use `mktemp` rather than fixed `/tmp`
    paths, so that two concurrent runs (or a crash) can't collide or leave stale files behind.
19. As the dotfiles owner, I want the shared note config to be one small JSON file with a single
    `vault` path, so that I can see and edit my entire notetaking configuration in one place.
20. As the dotfiles owner, I want nvim to read that config once at startup rather than shelling out to
    bash on every notetaking action, so that `is_note()` and friends stay fast.
21. As the dotfiles owner, I want a missing, empty, or malformed note config to make every buffer read
    as "not a note" rather than "every buffer is a note," so that a broken config can't turn on
    notetaking keybinds and asset logic across my entire filesystem.
22. As the dotfiles owner, I want `.config/notes/config.json` tracked and stowed like any other config,
    so that a fresh machine has working notetaking config immediately after `stow .`, with no example
    file to copy first.
23. As a public user of this repo, I want the tracked `config.json` to already be a valid, worked
    example, so that I only need to change the `vault` path to make it mine.
24. As the dotfiles owner, I want a documented, precise checklist for migrating my existing 658-note
    vault to the flat layout, so that I can perform the migration myself, in sequence with the other
    Syncthing device, without losing notes or breaking asset links.
25. As the dotfiles owner, I want the migration checklist to verify zero basename collisions before
    touching anything, so that the migration stops and shows me the problem rather than silently
    merging two different notes.
26. As the dotfiles owner, I want the checklist to rewrite every `../assets/...` reference to
    `assets/...` (and the one path-style wikilink to a bare ref), so that asset links and the one
    directory-qualified wikilink still resolve after notes move into the vault root.
27. As the dotfiles owner, I want the `create_asset_link`/`delete_asset` nvim code to accept both the
    old `../assets/...` and the new `assets/...` link forms, so that a note synced from another device
    in the old form still works after my migration.

## Implementation Decisions

### `.local/scripts/note`

- Rewritten in bash, following the shape validated by the ticket's prototype
  (`.scratch/portable-dotfiles/prototype/note`, thrown away, not copied verbatim: it is a decision
  reference, not the shipped implementation).
- `set -euo pipefail`, per [Conventions for the `.local/scripts/`
  set](../portable-dotfiles/issues/14-script-conventions.md). A `usage()` function prints one-line
  usage to stderr on `-h`/an argument error; every error is `Error: ...` on stderr with a non-zero
  exit; no silent fallback on bad input.
- Sets its own locale before any character-class matching: `export LC_ALL="${NOTE_LOCALE:-C.UTF-8}"`.
  This is load-bearing, not cosmetic: under an inherited `LC_ALL=C`, `[[:alnum:]]` collapses to ASCII
  and a Korean-titled note's slug becomes the empty string, producing a hidden `.md` file that every
  subsequent Korean-titled note collapses into.
- Slug function is locale-aware bash, no `python3`: lowercase, strip everything outside
  `[[:alnum:] -]`, trim, collapse runs of spaces/hyphens to a single hyphen.
- The note-type table is parallel associative arrays keyed by type (template file, whether a title is
  required, whether the type is copied verbatim rather than substituted), not a delimited-record
  table. A missing cell is a lookup on an absent key (`${TEMPLATE[$type]:?}`), which fails loudly
  rather than being silently `read`-padded.
- Roster: `-z TITLE` (zettel, requires title), `-d [N]` (daily, `N` = signed day offset from today,
  default `0`), `-sn`/`-sl` (scratch new/last), `-x` (xournal asset), `-f` (format), `-u` (update).
  `--code`, `--pinned`, `--review`, `--recipe`, `--todo`, `--sync`, and the standalone `yesterday`/
  `tomorrow` types are deleted.
- Every note write is write-then-rename: substitute into a `.partial` file, then `mv` it into place,
  so a failed substitution never leaves a zero-byte note.
- All template placeholders are `{{name}}`-shaped (`{{title}}`, `{{date...}}`, `{{id}}`). No bare-word
  substitution (`s/id/.../g`, `s/language/.../g`) survives.
- `-u` (update): walks the vault root only (not recursively into `assets/`/`templates/`), excludes
  filenames matching `^[0-9]{8}\.md$` (daily) or `^scratch-[0-9]+\.md$` (scratch) from renaming, reads
  each note's first `# heading`, slugs it, and if the slug differs from the current filename, rewrites
  every `[[old#...]]`, `[[old|...]]`, `[[old]]`, and `.../old.md`-style reference across the vault
  before renaming the file. Refuses (skips with a stderr message) if the computed new name already
  exists, or if it matches the daily/scratch reserved pattern. Uses `mktemp` for its working sed
  script, not a fixed `/tmp` path.
- `-f` (format): runs `prettier --write` over the `*.md` files directly in the vault root.
- Desktop-only: at startup, calls the canonical Role Marker reader (see below) and hard-errors on
  `headless` before doing anything else, including before any `mkdir`.
- Reads `.config/notes/config.json` once at startup via one `jq` call
  (`jq -er '.vault // empty' "$config"`), hard-erroring (naming the file) if the key is absent or
  empty. Expands a leading `~` itself (`${v/#\~/$HOME}`), since JSON has no shell expansion.
- Creates `assets/` at the point of need rather than a `check_dirs` pre-flight; there is no more
  `check_dirs` and no side effect from merely reading config.

### Role Marker read (shared with `theme-switch`, not this spec's to change)

- `note` carries the canonical `read_role` function pinned by [How a script reads the Role
  Marker](../portable-dotfiles/issues/13-role-marker-reader.md) and [Conventions for the
  `.local/scripts/` set](../portable-dotfiles/issues/14-script-conventions.md), copy-pasted verbatim
  (not sourced from a shared library — there is none):

  ```bash
  read_role() {
      local marker="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role" role
      if ! role=$(<"$marker" 2>/dev/null); then
          role=""
      fi
      role="${role//[[:space:]]/}"
      case "$role" in
      desktop | headless)
          printf '%s' "$role"
          ;;
      *)
          echo "Error: ${marker} must contain exactly 'desktop' or 'headless'. Fix: printf '%s' desktop > ${marker} (or headless)." >&2
          return 1
          ;;
      esac
  }
  ```

  Path, whitespace-stripping, and exact-word matching may not drift from this contract; only the
  function name may be adjusted to fit `note`'s naming. Missing, unreadable, empty, or unrecognized
  Marker content are all one outcome: the error above, non-zero exit, no fallback.

### `.local/scripts/scratch`

- Deleted outright. Its two live behaviors (allocate next id, reopen last id) become `note -sn` /
  `note -sl`; its `rename`/`index` subcommands (dead weight, not in the operator's actual roster) are
  not carried forward.

### `.config/notes/config.sh` → `.config/notes/config.json`

- `.config/notes/config.sh` is deleted outright.
- `.config/notes/config.json` is created, tracked, and stowed like any other config (it is not a
  Write-Back Config in [Choose the deployment
  mechanism](../portable-dotfiles/issues/05-choose-deployment-mechanism.md)'s sense — nothing
  rewrites it). Contents:

  ```json
  {
    "vault": "~/Sync/vault"
  }
  ```

  One key. `~` is expanded by each consumer at read time (JSON has no shell expansion): bash
  `${v/#\~/$HOME}`, Lua `vim.fn.expand(v)`. The tracked file is itself the worked example; no separate
  `config.example.json` is created.
- Everything else currently in `config.sh` does not survive: `VAULT_ASSETS_PATH` and the vault's
  `templates/` are derived (`<vault>/assets`, not configured); `VAULT_DAILY_PATH`,
  `VAULT_SCRATCH_PATH`, `VAULT_ZETTEL_PATH` are gone with the flat vault; `SYNC_FOLDER_PATH` and
  `NOTIZEN_CONFIG_PATH` were internal intermediates never consumed elsewhere; `NOTIZEN_TEMPL_PATH` is
  a fixed `~/.config/notes/templates` location, not a user choice; `check_dirs`, `normalize_filename`,
  and `handle_exe` are gone with the flat vault, the python removal, and `--nvim-mode` respectively.

### `.config/notes/templates/`

- `default.md`, `daily.md`, `scratch.md`, and `xpp_template.xopp` are kept, with their placeholders
  updated to the uniform `{{name}}` form (`scratch.md`'s bare-word `id` placeholder becomes
  `{{id}}`).
- `code.md`, `recipe.md`, `review.md`, and `todo.md` are deleted along with their note types.
- `.marksman.toml` stops being copied into the vault by `note` (the `sync` operation that did this is
  gone); it stays only as a config file consulted by the `marksman` LSP wherever it is invoked from,
  unrelated to vault contents.

### nvim: `custom/notetaking/util.lua`

- `get_note_path`/`get_base_path`/`get_assets_path`'s `bash -c "source ... && echo $VAR"` subprocess
  is replaced by a single JSON read performed once, in `setup()`, and cached:

  ```lua
  if not vim.uv.fs_stat(path) then return nil end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  local ok2, cfg = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok2 or type(cfg) ~= "table" then return nil end
  if type(cfg.vault) ~= "string" or cfg.vault == "" then return nil end
  return vim.fn.expand(cfg.vault)
  ```

  (From [Shape of the shared note config](../portable-dotfiles/issues/06-shared-note-config-shape.md);
  inlined here because it encodes the fail-closed contract precisely.) Editing the config now requires
  an nvim restart to take effect — a deliberate trade against a bash subprocess firing on nearly every
  notetaking action.
- `is_in_vault()` gains a guard: `if not base or base == "" then return false end`, before the
  existing `vim.startswith` check. This is the fix for the fail-open bug: a missing/malformed/empty
  config now produces `nil`/`""` in a way that is distinguishable from a legitimate base path, whereas
  today's `vim.fn.system` failure and a legitimate empty read are indistinguishable, and
  `vim.startswith(path, "")` is true for every path in existence.
- `M.opts.paths.config_path` moves from `~/.config/notes/config.sh` to `~/.config/notes/config.json`
  (set in `custom/notetaking/init.lua`'s `default_opts`).
- `create_asset_link` changes its emitted form from `![[../%s]]` to `![[%s]]` (see vault migration,
  below).
- `delete_asset`'s line-matching pattern for an asset reference becomes tolerant of both
  `[[../assets/...]]`/`(../assets/...)` and `[[assets/...]]`/`(assets/...)`, since the vault is a
  Syncthing folder that can still receive a note written in the old form from another device after the
  migration.

### nvim: `custom/notetaking/core.lua` and `mappings.lua`

- `create_note` (`core.lua`) drops `--nvim-mode` from the command string it builds, since `note` no
  longer accepts that flag and always prints the path.
- `mappings.lua`'s `open_code`, `open_review`, `open_pinned`, `open_recipe`, `open_todo` keymaps
  (`<leader>noc`/`norv`/`nop`/`norc`/`not` and their `<leader>nl*` link variants) are deleted, along
  with the corresponding `M.open_code`/`open_review`/`open_pinned`/`open_recipe`/`open_todo` functions
  in `custom/notetaking/init.lua`, since their note types no longer exist.
- `<leader>ndy` (open_yesterday) and `<leader>ndt` (open_tomorrow) keep their keybinds and continue to
  call through `core.open_note`, but the mode string/argument they pass changes to express a day
  offset (`-1`/`1`) rather than a distinct `yesterday`/`tomorrow` note type, matching `note`'s new
  `-d [N]` shape.
- `custom/init.lua`'s `default_opts.commands` drops `scratch_cmd` (the `scratch` binary no longer
  exists).

### Terminal wrapper

- `.shell_functions.sh` gains `n() { nvim "$(note "$@")"; }`, replacing what `--nvim-mode` used to
  suppress: printing the path was always the correct interface, the flag only existed to make an
  editor launch conditional, and now `note` never launches an editor itself.

### Vault migration (data, not dotfiles; performed by the operator, not shipped as code)

This spec ships no migration code. `~/Sync/vault` is a live Syncthing folder shared with at least one
other device; a 658-file rename is a sync event that only the operator can sequence, so this ships as
a checklist for the operator to run by hand once the rewritten `note` and its config are deployed:

1. Confirm zero basename collisions across `daily/`, `zettelkasten/`, `scratch/`:
   `find daily zettelkasten scratch -maxdepth 1 -type f -printf '%f\n' | sort | uniq -d` must print
   nothing. If it prints anything, stop and resolve by hand — no automated merge or disambiguation.
2. Settle the vault's state with the other Syncthing device before moving anything.
3. Move `daily/*`, `zettelkasten/*`, `scratch/*` into the vault root; remove the three now-empty
   directories.
4. Rewrite `../assets/` to `assets/` across every `.md` file in the vault (436 references across 205
   files at last survey), and rewrite the single path-style wikilink,
   `[[zettelkasten/pinned-todo|Todo-Liste]]`, to `[[pinned-todo|Todo-Liste]]`.
5. Decide what to do with the vault's existing `templates/` and `.marksman.toml`: nothing in the
   rewritten `note` maintains or writes them any more (the `sync` operation that used to is gone), so
   they become plain vault data, the operator's to keep or delete.
6. No `.obsidian/` changes needed: its `daily-notes` and `templates` plugins have no folder configured
   and already default to the vault root, which is what the flat layout gives them.

Until this checklist is run, the deployed `note` targets the flat layout regardless of the live
vault's actual shape. This is an accepted, temporary disagreement: create paths (`-z`, `-d`, `-sn`,
`-sl`, `-x`) work correctly against a flat root either way, and only `-u` and `-f` walk the vault tree,
so they are the two flags that should not be run against the live vault until after the migration.

## Testing Decisions

- Test only external behavior: source `note` and call its functions directly with a scratch
  `VAULT_BASE_PATH`, a scratch `NOTIZEN_TEMPL_PATH` (copied from the real templates so type lookups are
  real), a fake `.config/notes/config.json`, and a fake
  `${XDG_CONFIG_HOME}/dotfiles/role` Role Marker file — the same sourcing-plus-fake-`$XDG_*`-dirs
  pattern `.local/scripts/tests/theme-switch.bats` already uses, per [Conventions for the
  `.local/scripts/` set](../portable-dotfiles/issues/14-script-conventions.md). Add
  `.local/scripts/tests/note.bats`.
- Cover with bats: the slug function against ASCII, Korean, German, Japanese, and mixed input, and
  specifically that `LC_ALL=C` in the parent environment does not defeat the script's own
  `export LC_ALL=C.UTF-8`; `-z`/`-d [N]`/`-sn`/`-sl`/`-x` each produce the expected path and file
  under a scratch vault; `-u`'s rename-by-heading behavior, including that it leaves a matching
  `[[old...]]` reference in another note correctly rewritten, that dailies and scratches are never
  touched, and that it refuses when the computed new name collides with an existing file or a reserved
  pattern; `-u`'s and `-z`'s failure paths (missing template, missing title) exit non-zero with nothing
  on stdout; `read_role` against a present/absent/malformed/whitespace-padded Marker file, matching the
  contract pinned in ticket 13.
- Do not test `-f` (format) beyond a guard-path smoke test ("does not error when prettier is absent"),
  per the existing `apply_foot`/`apply_sway`/`apply_gtk` precedent in `theme-switch.bats` — it is a
  bare external-command invocation with no branching logic to verify.
- nvim's `util.lua` config-read and `is_in_vault` fail-closed behavior get no automated test: no Lua
  test framework (plenary, busted, or otherwise) exists in this repo today, and this spec does not
  introduce one. Verify manually instead, the same way [Shape of the shared note config's
  answer](../portable-dotfiles/issues/06-shared-note-config-shape.md) did: exercise `get_base_path`
  and `is_in_vault` against a missing config, an empty config, a malformed config, and a valid config,
  and confirm the first three all yield "not in vault" for an arbitrary path (e.g. `/etc/passwd`)
  while the fourth correctly recognizes a path under the vault.
- The vault migration checklist is not automated and gets no test; it is run once, by hand, against
  live data (see Implementation Decisions). Step 1's collision check is the one piece of the checklist
  that is itself a verification command, and it is run for real against the live vault before any file
  moves, not simulated.

## Out of Scope

- **`paste_xournal` and `open_scratch` in `custom/notetaking/core.lua`, and their `mappings.lua`
  keybinds (`<leader>nx`, `<leader>nsn`, `<leader>nsl`).** [Restructure `note`'s
  answer](../portable-dotfiles/issues/04-note-restructure-prototype.md) explicitly deferred deeper
  nvim notetaking integration to a later session, as a nice-to-have rather than load-bearing for the
  Portable dotfiles map's destination. **This spec does not fix them, and they will break** the first
  time they're invoked after this spec ships: `paste_xournal` still calls `note --nvim-mode --xournal`
  (a flag `note` no longer accepts), and `open_scratch` still calls the now-deleted `scratch` binary.
  Whoever picks up nvim notetaking integration next must update or remove both, per that ticket's own
  note.
- **Actually migrating `~/Sync/vault`.** This spec ships the checklist; running it against live data is
  the operator's, by hand, not this spec's implementation work.
- **A general notetaking workflow redesign.** This spec is the rewrite already decided by the three
  linked tickets, not a broader rethink of how notes are organized, tagged, or linked.
- **Any change to `marksman` LSP configuration itself**, beyond `note` no longer copying
  `.marksman.toml` into the vault.
- **Standing up an nvim test framework** (plenary, busted, or otherwise) to cover `util.lua`. See
  Testing Decisions: this is verified manually instead.
- **The `-h`/usage-idiom and bats-coverage conventions for any other script in `.local/scripts/`**
  beyond `note` itself. [Conventions for the `.local/scripts/`
  set](../portable-dotfiles/issues/14-script-conventions.md) covers the set; this spec only applies it
  to `note`.

## Further Notes

- The prototype at `.scratch/portable-dotfiles/prototype/note` (run via
  `.scratch/portable-dotfiles/prototype/run`) validated the slug function, the parallel-array table
  shape, the write-then-rename discipline, and the flat-vault `-u` exclusion patterns end to end
  against a scratch vault. It is a decision reference, thrown away rather than promoted — the shipped
  script should follow its shape, not be a copy-paste of its contents, since the prototype does not
  include the Role Marker check, the JSON config read, or bats coverage.
- `CONTEXT.md`'s **Role**, **Role Marker**, and **Capability Probe** vocabulary (defined via [Name the
  split](../portable-dotfiles/issues/01-name-the-split.md) and amended by [How a script reads the Role
  Marker](../portable-dotfiles/issues/13-role-marker-reader.md)) applies directly to `note`'s new
  Desktop-only gating; read it before implementing the Role check.
- [Choose the deployment mechanism](../portable-dotfiles/issues/05-choose-deployment-mechanism.md)'s
  **Write-Back Config** concept is why `config.json` is tracked rather than given an untracked
  real-file-plus-example treatment: nothing rewrites it.
- The vault migration survey found 436 `../assets/` references across 205 files and exactly one
  path-style wikilink at the time it ran; re-verify these counts before running the checklist, since
  the live vault continues to receive notes (including from another Syncthing device) between now and
  whenever the migration actually happens.
