# 01 — `note` core: config, Role gate, and note creation

**What to build:** A full replacement of `.local/scripts/note` that creates notes correctly on a
Desktop machine, refuses cleanly on a Headless one, and reads its vault location from a small JSON
config instead of a sourced bash file. From the user's perspective: `note -z "title"` creates a
correctly-slugged zettel (including non-ASCII titles) in the vault root; `note -d [N]` creates
today's/an offset day's daily note; `note -sn`/`note -sl` create/reopen a scratch note; `note -x`
creates a Xournal++ asset; running any of these on a machine whose Role Marker says `headless` (or is
missing/malformed) refuses with a clear error instead of creating anything. `.local/scripts/scratch`
and `.config/notes/config.sh` are deleted outright, fully superseded by this ticket.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `.local/scripts/note` opens with `set -euo pipefail`, has a `usage()` function printing one-line
      usage to stderr for `-h`/an argument error, and every error is `Error: ...` on stderr with a
      non-zero exit (per the script-conventions decisions linked in Further Notes).
- [ ] The script `export`s its own locale (`LC_ALL="${NOTE_LOCALE:-C.UTF-8}"`) before any character-class
      matching, and its slug function is locale-aware bash (no `python3`): lowercase, strip outside
      `[[:alnum:] -]`, trim, collapse runs of spaces/hyphens to one hyphen.
- [ ] The note-type table is parallel associative arrays keyed by type (template, whether a title is
      required, whether the type copies verbatim), not a delimited-record table.
- [ ] `-z TITLE` creates `<slug>.md` from `default.md` in the vault root; refuses with a clear error if
      no title is given.
- [ ] `-d [N]` creates `<YYYYMMDD>.md` from `daily.md`, where `N` is a signed day offset from today
      (default `0`).
- [ ] `-sn` creates the next scratch note (`scratch-<max+1>.md`); `-sl` reopens the last one
      (`scratch-<max>.md`); both from `scratch.md`.
- [ ] `-x` creates `assets/note_<timestamp>.xopp` from `xpp_template.xopp`, verbatim-copied (no
      substitution).
- [ ] Every note write is write-then-rename (substitute into `.partial`, then `mv` into place) so a
      failed substitution never leaves a zero-byte note.
- [ ] All template placeholders are `{{name}}`-shaped. `default.md`, `daily.md`, and `scratch.md` are
      updated accordingly (`scratch.md`'s bare-word `id` becomes `{{id}}`); `code.md`, `recipe.md`,
      `review.md`, and `todo.md` are deleted.
- [ ] At startup, before touching the filesystem, the script calls a `read_role` function matching the
      canonical contract (path `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role`, whitespace-stripped,
      exact-word match against `desktop`/`headless`, one hard error on anything else) and refuses on
      `headless` or a Role-read failure.
- [ ] The script reads `.config/notes/config.json` once at startup via one `jq` call
      (`jq -er '.vault // empty'`), hard-erroring by name if the key is absent or empty, and expands a
      leading `~` itself.
- [ ] `.config/notes/config.json` exists, tracked, containing `{"vault": "~/Sync/vault"}`.
- [ ] `.config/notes/config.sh` and `.local/scripts/scratch` are deleted.
- [ ] `.local/scripts/tests/note.bats` exists and covers: the slug function against ASCII, Korean,
      German, and Japanese input, and that `LC_ALL=C` in the parent environment does not defeat the
      script's own locale export; each of `-z`/`-d [N]`/`-sn`/`-sl`/`-x` producing the expected path and
      file under a scratch vault; `-z`'s and a missing-template path's failure modes (non-zero exit,
      nothing on stdout); `read_role` against a present/absent/malformed/whitespace-padded Marker file.

**Further Notes:** See `.scratch/notetaking-rewrite/spec.md` for full context, including the
`read_role` function body (Implementation Decisions → "Role Marker read"), the JSON config shape, and
the prototype reference at `.scratch/portable-dotfiles/prototype/note` (a decision reference, not code
to copy verbatim — it has no Role gate, no JSON config, and no bats coverage).
