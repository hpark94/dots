# 04 — Tmux + shell-env (fzf + bat) integration

**What to build:** Wire tmux into `theme-switch` with live updates, and wire fzf's chrome colors and bat's mode selection through a shared generated shell-env fragment sourced by the shell startup files.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton; 02 — Bat syntax themes (the shell-env demo needs `hp_dark`/`hp_light` actually registered with bat)

**Status:** ready-for-agent

- [x] `generate_tmux` writes a tmux fragment with `set-option` commands for status/window/message/mode styling, sourced strictly from Canonical Palette slots for both modes (dark accent → `color4`, dark mode-style bg → `bright4`, discarding the old bespoke `#5b9dc4`/`#2e4650`); `.tmux.conf` sources it via `source-file`, replacing the current hardcoded "Light" block and commented-out "Dark" block.
- [x] Test: `generate_tmux` produces the expected fragment content for both modes, given a scratch output directory.
- [x] `theme-switch` runs the equivalent `tmux set-option` commands directly against a running tmux server, when one is running, so all attached clients update live.
- [x] `generate_shell_env` writes a fragment exporting `FZF_DEFAULT_OPTS` (mode-appropriate colors sourced from the Canonical Palette) and `BAT_THEME` (`dark`/`light`).
- [x] Test: `generate_shell_env` produces the expected `FZF_DEFAULT_OPTS` and `BAT_THEME` values for both modes.
- [x] `.zshrc` and `.bashrc` source the generated shell-env fragment, replacing the currently hardcoded `FZF_DEFAULT_OPTS` line and its commented-out dark alternative.
- [x] `.config/bat/config` sets static `--theme-light="hp_light"` / `--theme-dark="hp_dark"` and no longer hardcodes `--theme="Coldark-Dark"`.
- [x] `.config/bat/config` sets `--italic-text="always"` — the `hp_light`/`hp_dark` themes (ticket 02) encode italic comments/strings, but bat's own default (`--italic-text=never`) suppresses them regardless of theme; discovered while verifying ticket 02.
- [x] Verified manually (partially — see Comments): `theme-switch dark`/`light` regenerate the tmux/shell-env fragments correctly and a scratch tmux server picks up the fragment's colors; `bat` with `BAT_THEME=dark`/`light` renders the right theme including italics on comments/strings. Live recolor of an already-attached tmux client on the real desktop session, and fzf chrome in a freshly opened interactive shell, weren't exercised from this sandbox — worth a quick manual spot-check.

## Comments

Verified in this sandbox: `theme-switch dark`/`light` regenerate `~/.local/state/theme/{tmux-colors.conf,shell-env.sh}` with values that match the previously-hardcoded light/dark blocks exactly; a scratch `tmux -f .tmux.conf` server sourcing the fragment picks up the generated `status-style`; `BAT_THEME=dark bat --color=always` renders `hp_dark` with italic comments/strings (confirmed via raw SGR `3` escape codes). Not exercised here (no interactive desktop session available): live recolor of an already-attached real tmux client via `apply_tmux`'s `tmux set-option`, and a freshly opened interactive zsh/bash shell picking up `FZF_DEFAULT_OPTS`/`BAT_THEME` from the sourced fragment. Both should work off the same code path already verified, but are worth a quick real-desktop spot-check per ticket 03's precedent.
