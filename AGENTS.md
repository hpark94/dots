# Standards for this repo

What code here is held to, whether you are writing it or reviewing it.

## Before you touch anything

Read `CONTEXT.md` for the vocabulary of this repo, and the ADRs under
`docs/adr/` that touch your area. Use the glossary's terms; do not drift to
synonyms it lists under _Avoid_. If your change contradicts an ADR, say so
instead of silently overriding it.

`.stow-local-ignore` keeps repo-local tooling and docs out of `${HOME}`; check
it before adding a file to the repo root.

## Commands

- `bootstrap.sh <desktop|headless>`: Stow, mise, plugins, theme. Idempotent;
  safe to re-run.
- `mise install`: Sync toolchain from `.config/mise/config.toml`.
- `bats .local/scripts/tests/` or `bats .local/scripts/tests/<test-file>.bats`:
  Run tests for bootstrap.sh, theme-switch, envs, fy, fp, delta-auto,
  tmux-sessionizer, caffeine, cltex, font-install, organize_flac,
  sway-start-on-workspace, ffd, frg, and fzf-preview.
- `nvim --headless '"+Lazy! sync' +qa`: Force nvim plugin sync.
- `theme-switch dark|light|toggle`: Desktop-only; decides and applies Theme
  Mode.
- `theme-switch --render dark|light`: Role-agnostic; applies a mode decided
  elsewhere.
- `fy <file>`: Copy a file reference (`file://` URI in `text/uri-list`) to the
  Wayland clipboard; pasteable via `fp`, in terminals, and into browser chats.
- `fp [dir]`: Paste file from Wayland clipboard to directory.
- `sway-start-on-workspace <workspace> <app_id> <command> [args...]`: Launch a
  command and move the first window it maps to that workspace, once.
- `ffd [-b] [tool] [flags...]`: Pick files with fzf and hand every selection to
  one invocation of the tool (`nvim` by default); `-b` detaches it.
- `frg [query...]`: Live ripgrep through fzf, opening the match in nvim at its
  line, or the whole selection as a quickfix list.
- `fzf-preview <path> [line]`: The Previewer behind every fzf preview window:
  eza for a directory, the image Render Ladder for an image, bat otherwise.

## Style

Enforceable formatting is the tools' job; judgment is yours.

### Shell

Write the least code that solves the task, but never drop these. They are not
optional:

- `set -euo pipefail` at the top.
- Quote every expansion: `"${var}"`, `"$@"`.
- Validate what you were given: required args present, paths exist, commands on
  PATH.
- Fail loudly: a message on stderr and a non-zero exit, never a silent fallback.

Everything else is YAGNI. Do not add config flags, indirection, retries, or
cases nobody asked for. If you think one is needed, say so at the plan-gate
instead of building it.

Brace every variable reference: `${HOME}`, `${XDG_CONFIG_HOME}`. Positionals and
specials stay bare: `$1`, `$@`, `$#`, `$?`. shellcheck's
`require-variable-braces` enforces exactly this; run it before you finish.

### Formatting

Run the formatter on what you touched before you finish. The config files are
authoritative; pass no formatting flags, or you disable them.

- Shell: `shfmt -w <file>`. Never pass `-i` or other format flags: shfmt only
  reads `.editorconfig` when none are given.
- Markdown: `prettier -w <file>` (`.prettierrc`: 80 columns,
  `proseWrap: always`).
- Lua: `stylua <file>`.
- JS, TS, JSON: `biome format --write <file>`.

The full filetype-to-formatter map is
`.config/nvim/lua/core/plugins/conform.lua`.

### Comments, prose, commits

- **Simplicity (YAGNI)**: build the simplest thing that solves the task. No
  abstraction, configurability, or cases nobody asked for. Propose beyond-scope
  ideas at the plan-gate instead of building them.
- **Minimal diffs**: change only what the task requires. Don't reformat
  untouched lines or rename in passing. Run the formatter only on touched
  regions, or keep formatter noise in a separate commit. Note incidental
  findings in your report.
- **Comments**: write self-explanatory code. Comment sparingly; when you do,
  explain the _why_, not the _what_.
- **Leave nothing behind**: no commented-out code, no debug prints, no dead
  code. Delete rather than comment out; the history is in git.
- **Language**: English for code, identifiers, comments, and commit messages.
  Converse in my language. Domain terms stay as the project uses them.
- **Commits**: `type(scope): description`, then a blank line and a body that
  tells the story of the change: what it adds, how it works, and why. No
  trailing `Co-Authored-By` lines.
- **Prose**: no em-dashes. Use commas, periods, semicolons, colons.
