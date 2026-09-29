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
- `./completeness-check.sh`: Desktop-only, run by path from the clone. Reports
  what the roster, the Flatpak list and the manual steps promise and this
  machine lacks; exit 1 if anything is missing. Changes nothing.
- `mise install`: Sync toolchain from `.config/mise/config.toml`.
- `bats .local/scripts/tests/ .config/sway/scripts/tests/` or
  `bats <tests-dir>/<test-file>.bats`: Run tests for bootstrap.sh,
  completeness-check, theme-switch, envs, fy, fp, delta-auto, tmux-sessionizer,
  caffeine, cltex, font-install, organize_flac, battery-charge-limit,
  screenshot, sway-start-on-workspace, wait-for-clock, wait-for-vpn, ffd, frg,
  fzf-preview, and the tmux config.
- `nvim --headless '+Lazy! sync' +qa`: Force nvim plugin sync.
- `theme-switch dark|light|toggle`: Desktop-only; decides and applies Theme
  Mode.
- `theme-switch --render dark|light`: Role-agnostic; applies a mode decided
  elsewhere.
- `fy <file>`: Copy a file reference (`file://` URI in `text/uri-list`) to the
  Wayland clipboard; pasteable via `fp`, in terminals, and into browser chats.
- `fp [dir]`: Paste file from Wayland clipboard to directory.
- `ffd [-b] [tool] [flags...]`: Pick files with fzf and hand every selection to
  one invocation of the tool (`nvim` by default); `-b` detaches it.
- `frg [query...]`: Live ripgrep through fzf, opening the match in nvim at its
  line, or the whole selection as a quickfix list.
- `fzf-preview <path> [line]`: The Previewer behind every fzf preview window
  whose candidates are paths: eza for a directory, the image Render Ladder for
  an image, bat otherwise.

### Sway session scripts

`.config/sway/scripts/` holds what only the sway config starts, by path and
never by name. It is deliberately off the PATH: none of it is meant to be typed.
`autotiling` is vendored third-party code; the others are this repo's own and
carry bats suites under `.config/sway/scripts/tests/`.

- `battery-charge-limit toggle|restore`: Turn the battery charge limit on or off
  through UPower, without sudo. `toggle` is the keybind and notifies; `restore`
  runs at session start and says nothing, so a forgotten full charge lasts until
  the next login at most.
- `screenshot edit | screenshot save <dir>`: Capture the focused output, into
  satty or as a timestamped PNG in `<dir>`. A missing program is refused with a
  notification, because a keystroke is a human waiting.
- `sway-start-on-workspace <workspace> <app_id> <command> [args...]`: Launch a
  command and move the first window it maps to that workspace, once.
- `wait-for-clock <command> [args...]`: Run a command once the system clock is
  synchronised, and after a minute either way. Guards `protonvpn connect`
  against a hardware clock that drifted while the machine was off, which makes a
  freshly issued certificate look not yet valid.
- `wait-for-vpn <command> [args...]`: Run a command once the VPN is up, or once
  NetworkManager reports a usable network on a machine without protonvpn. A VPN
  that never arrives falls back on that same verdict: the command still runs on
  a usable network, and is refused only when the network is down as well.

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
