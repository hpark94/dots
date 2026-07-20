# 04 — Tmux + shell-env (fzf + bat) integration

**What to build:** Wire tmux into `theme-switch` with live updates, and wire fzf's chrome colors and bat's mode selection through a shared generated shell-env fragment sourced by the shell startup files.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton; 02 — Bat syntax themes (the shell-env demo needs `hp_dark`/`hp_light` actually registered with bat)

**Status:** ready-for-agent

- [ ] `generate_tmux` writes a tmux fragment with `set-option` commands for status/window/message/mode styling, sourced strictly from Canonical Palette slots for both modes (dark accent → `color4`, dark mode-style bg → `bright4`, discarding the old bespoke `#5b9dc4`/`#2e4650`); `.tmux.conf` sources it via `source-file`, replacing the current hardcoded "Light" block and commented-out "Dark" block.
- [ ] Test: `generate_tmux` produces the expected fragment content for both modes, given a scratch output directory.
- [ ] `theme-switch` runs the equivalent `tmux set-option` commands directly against a running tmux server, when one is running, so all attached clients update live.
- [ ] `generate_shell_env` writes a fragment exporting `FZF_DEFAULT_OPTS` (mode-appropriate colors sourced from the Canonical Palette) and `BAT_THEME` (`dark`/`light`).
- [ ] Test: `generate_shell_env` produces the expected `FZF_DEFAULT_OPTS` and `BAT_THEME` values for both modes.
- [ ] `.zshrc` and `.bashrc` source the generated shell-env fragment, replacing the currently hardcoded `FZF_DEFAULT_OPTS` line and its commented-out dark alternative.
- [ ] `.config/bat/config` sets static `--theme-light="hp_light"` / `--theme-dark="hp_dark"` and no longer hardcodes `--theme="Coldark-Dark"`.
- [ ] `.config/bat/config` sets `--italic-text="always"` — the `hp_light`/`hp_dark` themes (ticket 02) encode italic comments/strings, but bat's own default (`--italic-text=never`) suppresses them regardless of theme; discovered while verifying ticket 02.
- [ ] Verified manually: `theme-switch dark` recolors tmux's status bar live across attached clients, and a newly opened shell shows both fzf's chrome and bat's syntax highlighting (including italics) in dark mode.
