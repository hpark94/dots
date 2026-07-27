# 04 Restructure `note`: language and target shape

> **Superseded 2026-07-27:** the notetaking rewrite is being re-grilled from scratch. The dedicated `.scratch/notetaking-rewrite/` spec and tickets were removed, and this ticket's decisions are kept only as historical input, no longer authoritative.

**Type:** `prototype` (HITL)

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

What should `note` look like after a rewrite, and does it stay bash?

"How should it be structured" is answered fastest by a cheap concrete sketch to react to, not by
discussing structure in the abstract. Build a rough one with `/prototype` and use it to drive the
conversation. The language question gets settled by the sketch rather than argued first.

### What is actually wrong with `.local/scripts/note` today

Read the file before sketching. The concrete problems:

- **Flag dispatch by side effect.** A 14-entry `MOD` associative array of booleans, set inside the
  argument loop, then counted afterwards to enforce "exactly 1 mod must be selected." The real
  constraint is that these are mutually exclusive subcommands, and the array is an expensive way to
  say that.
- **Seven near-identical case arms.** `--code`, `--pinned`, `--review`, `--recipe`, `--scratch`,
  `--todo`, `--zettel` differ only in title prefix, destination path, template file, and sed pattern.
  That is a four-column table wearing 60 lines of control flow.
- **Hardcoded temp files.** The `update` path writes `/tmp/renames.txt` and `/tmp/replace_refs.sed`
  at fixed paths. No `mktemp`, so two concurrent runs collide and a crash leaves them behind.
- **A `python3` shellout for `normalize_filename`**, living in `.config/notes/config.sh`, inside a
  bash script, to do a slugify that bash cannot do cleanly with the Unicode ranges involved
  (`äöüß`, Hangul syllables and jamo). This is the strongest single hint that bash may be the wrong
  host language.
- **Template substitution by `sed` pattern strings** built per arm and applied blind, with
  `2>/dev/null` swallowing failures.
- **Silent failure throughout.** No `set -euo pipefail`, and `mkdir`/`cp`/`rm` are routinely
  `2>/dev/null`.

### What the sketch needs to take a position on

1. **Language.** Stay bash, or move. If it moves, what runs it on a fresh machine, given `mise`
   already manages the toolchain and pins `uv`, `node`, `bun`, `go` and `rust`.
2. **The note-type table.** How the seven types are declared as data rather than branches.
3. **The `nvim-mode` seam.** Today `--nvim-mode` makes the script print a path instead of opening
   an editor, and `core.lua` consumes that via `io.popen` and a `gsub("%s+", "")`. Whether that
   stays the interface matters for the nvim side.
4. **Where config comes from**, at the level of "the script reads a config it does not define." The
   format itself is [Shape of the shared note config](06-shared-note-config-shape.md), which this
   ticket blocks, so do not settle the format here. Just do not design something that forecloses it.

### Out of bounds for this ticket

Do not rewrite the other scripts. Conventions for `.local/scripts/` as a set are still fog on the
map, and `note` is the one with enough substance to be worth a prototype on its own.

## Prototype

`.scratch/portable-dotfiles/prototype/`, run `./run`. Builds a scratch vault in `mktemp -d`, drives
every command, and prints the resulting flat vault. Touches no real vault, opens no editor.

## Answer

### It stays bash, and python goes away entirely

The python dependency existed for one reason: sanitizing Korean filenames. That reason is gone.
`config.sh:29` hardcodes **codepoint ranges** (`[^a-z0-9äöüß가-힣ㄱ-ㅎㅏ-ㅣ -]`), which is the fragile
way to do it. A locale-aware POSIX character class needs no ranges at all:

```bash
s="${1,,}"
s=$(printf '%s' "$s" | sed 's/[^[:alnum:] -]//g')
```

Verified against `한글 제목 테스트`, `Über die Größe`, `ㄱㅎ ㅏㅣ jamo`, `C++ & Rust: a comparison!`
and `日本語のノート`. It is also **strictly better than the python it replaces**: the hardcoded
ranges silently drop Japanese, Cyrillic and everything else not enumerated, while `[[:alnum:]]`
keeps them.

**One hard requirement this creates, and it is verified, not assumed.** POSIX character classes are
locale-dependent, so the script must **set its own locale** rather than inherit one:
`export LC_ALL="${NOTE_LOCALE:-C.UTF-8}"`. Measured behaviour of the slug function:

| `LC_ALL` | `한글 제목 테스트` | `Über die Größe` |
|---|---|---|
| `en_US.UTF-8` | `한글-제목-테스트` | `über-die-größe` |
| `C.UTF-8` | `한글-제목-테스트` | `über-die-größe` |
| `C` | *(empty string)* | `ber-die-gre` |
| `POSIX` | *(empty string)* | `ber-die-gre` |

Korean does not degrade under `LC_ALL=C`, it **disappears**. An empty slug makes the filename `.md`:
a hidden file with no name, into which *every* Korean-titled note collapses. German silently loses
`Ü`, `ö` and `ß`.

End-to-end against the prototype with `LC_ALL=C` in the parent environment, the guard holds and
produces `한글-제목-테스트.md` and `über-die-größe.md` correctly. With the guard defeated
(`NOTE_LOCALE=C`), two different Korean titles both resolved to a single `.md`.

`C.UTF-8` is present on this system, so it is a safe default and does not depend on `en_US.UTF-8`
being installed. **This is the single highest-risk line in the rewrite**: the failure is silent, it
only triggers in non-interactive contexts, and it destroys filenames rather than erroring.

### The table: parallel arrays, not delimited records

The first sketch used the obvious bash encoding, one `dest|template|prefix|...` record per type. It
is a trap. **A row with the wrong number of fields is silently padded by `read` and runs correctly**,
so a malformed row is indistinguishable from a good one. This is not hypothetical: the prototype
shipped `[zettel]` with 5 pipes where every other row had 6, it worked, and it was only found by
counting pipes afterwards.

Parallel associative arrays keyed by type fix it: a missing cell is a lookup on an absent key, which
`${TEMPLATE[$type]:?}` turns into a loud failure.

### The roster

Cut from 14 flags to 7, per the operator: only `-z`, `-f` and `-u` were actually in use.

| | flag | result |
|---|---|---|
| create | `-z TITLE` | `<slug>.md` |
| | `-d [N]` | `<YYYYMMDD>.md`, `N` = day offset |
| | `-sn` / `-sl` | `scratch-<next>.md` / `scratch-<max>.md` |
| | `-x` | `assets/note_<ts>.xopp` |
| operate | `-f` | prettier over the vault |
| | `-u` | rename by heading, rewrite wiki links |

**`yesterday` and `tomorrow` stop being types and become the `-d` argument.** They were never a
different *kind* of note, only a different date, so `<leader>ndy` and `<leader>ndt` survive as
`-d -1` and `-d 1` without costing an option.

**Dropped: `code`, `pinned`, `review`, `recipe`, `todo`, and `sync`.** This deletes 10 nvim keymaps
(`mappings.lua:53-89`) and 4 templates. **`scratch` the script is deleted outright**; it was only an
id allocator (`scratch-<N>.md`, max+1 or max) wrapping `note -sc`, so it folds in as two flags.

### The vault goes flat

Every note lives in the vault root. Only `assets/` and `templates/` keep directories.

This works because **scratch and daily notes are already self-identifying by filename**
(`scratch-3.md`, `20260722.md`), so they never needed directories to be told apart.

**But it breaks `update`, which must now discriminate by pattern rather than path.** Today
`note:228-229` excludes dailies with `! -path "${VAULT_DAILY_PATH}/*"`. With no `daily/` there is no
path to exclude, and a daily note's heading is `# 22.07.2026`, so `update` would happily rename
`20260722.md` to `22072026.md`. The prototype excludes on `^[0-9]{8}\.md$` and
`^scratch-[0-9]+\.md$` instead, and the run confirms dailies and scratches survive an `-u`.

### The nvim seam: no mode flag, stdout is the path

**`note` always prints the path and never opens anything.** The `--nvim-mode` flag is deleted.

Printing the path on stdout was never the hack it felt like; it is the correct interface, the same
one `mktemp` and `git rev-parse` use. What was odd is that it was *conditional*: the flag existed
only to suppress an editor launch that the primary caller never wants. The alternatives are all
worse, in particular recomputing the name in Lua, which would duplicate the slug rules in a language
whose `string.lower` is ASCII-only and cannot lowercase `Ü`.

The discipline that makes this correct: **stdout carries the path and nothing else, every message
goes to stderr.** Confirmed in the run, where `note -u 2>/dev/null` prints nothing at all.

Consequences: `core.lua:16,23` drop `--nvim-mode` from the format string, and terminal use gets a
wrapper in `.shell_functions.sh`, roughly `n() { nvim "$(note "$@")"; }`.

### Other fixes the sketch picked up

- **All placeholders become `{{name}}`.** Today templates mix `{{title}}` with the bare words
  `language` and `id`, substituted by per-type sed pattern strings, so `s/language/…/g` rewrites the
  tag *and* both code fences, and `s/id/…/g` would rewrite any word containing "id".
- **Write-then-rename.** `sed … > "$filename" 2>/dev/null` truncates before `sed` runs, so a failed
  substitution leaves a **zero-byte note**. Writing to `.partial` and `mv`-ing makes that impossible.
- **`mktemp` for the update script**, replacing hardcoded `/tmp/renames.txt` and
  `/tmp/replace_refs.sed`, which collide between concurrent runs and survive a crash.
- Three bugs found while reading, listed for the implementation spec: `note:216` is missing a `$`
  (`rm marksman` deletes a file named `marksman` in `$PWD`), `note:181-184` assigns `title="Untitled"`
  then unconditionally `exit 1`, and `MOD[tomorrow]`/`MOD[yesterday]` are never set true so their
  arms at `note:180` are dead.

### Nvim side, deferred rather than missed

`core.lua` has four `--nvim-mode` call sites, not the two named above: `create_note` (`:16,23`,
already covered), `paste_xournal` (`:168`, calls `note --nvim-mode --xournal`, needs the same flag
drop), and `open_scratch` (`:204`, calls `M.opts.commands.scratch_cmd`, i.e. the `scratch` binary
this ticket deletes outright). Live keybinds at `mappings.lua:98,105,108`. **Explicitly deferred, not
resolved here**: the operator has scoped nvim notetaking integration to a later session, since it is
now a nice-to-have rather than load-bearing for this map's destination. Whoever picks it up must
update or remove `paste_xournal` and `open_scratch` alongside the `note`/`scratch` rewrite, or both
break silently the first time they're invoked.

### Follow-on

- [10](10-vault-flattening-migration.md): how the existing vault migrates to the flat layout, and
  what maintains `templates/` inside it now that `sync` is gone.
- [06](06-shared-note-config-shape.md) is unblocked. `note` staying bash means its
  `jq`-versus-native-parse trade stands rather than dissolving.
