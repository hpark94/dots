Status: ready-for-agent

# Theme switching across dotfiles tooling

## Problem Statement

The dotfiles owner maintains matching dark/light color palettes by hand across ghostty, foot, tmux, fzf, bat, nvim, and sway, but each tool has its own ad hoc (or entirely absent) mechanism for switching between them. Some configs only have one mode wired up at all (ghostty's active theme, sway's hardcoded border colors), some have a dead commented-out alternative that's never applied (tmux's "Dark" block, `.zshrc`'s dark `FZF_DEFAULT_OPTS`), and there is no single place to see or change "what mode is currently active." Switching modes today means manually editing several tracked files and remembering which mechanism each one uses.

## Solution

A single script, `theme-switch`, flips a persisted global Theme Mode (`dark`/`light`) and updates all seven integration points using the strategy that fits each app's actual reload capability (see `docs/adr/0001-theme-switching-per-app-strategy.md`): live signal/command updates for foot, tmux, and sway; a generated include fragment for ghostty; a direct state-file read for nvim; and env-var-driven updates for bat and fzf. All apps read from one canonical palette source per mode. The script fires a desktop notification confirming the switch, is callable from the CLI with an explicit mode or a toggle, and is also bound to a sway keybind.

## User Stories

1. As the dotfiles owner, I want to run one command to switch every themed tool to dark mode, so that I don't have to manually edit multiple config files.
2. As the dotfiles owner, I want to run one command to switch every themed tool to light mode, so that I don't have to manually edit multiple config files.
3. As the dotfiles owner, I want a toggle command that flips to the opposite of whatever mode is currently active, so that I don't need to remember which mode I'm in to switch.
4. As the dotfiles owner, I want the current Theme Mode persisted somewhere durable, so that other tools/scripts can query "what mode is active" later.
5. As the dotfiles owner, I want a desktop notification confirming the switch happened and which mode it switched to, so that I get feedback that the script ran successfully.
6. As the dotfiles owner, I want foot's colors to update immediately in already-running foot windows, so that I don't have to close and reopen my terminal to see the new theme.
7. As the dotfiles owner, I want tmux's status bar and pane styling to update immediately across all attached clients, so that a long-running tmux session reflects the new theme without restarting tmux.
8. As the dotfiles owner, I want sway's window border colors to update immediately, so that focused/inactive window borders match the new theme without a sway reload.
9. As the dotfiles owner, I want ghostty to pick up the new theme automatically the next time I open a window, so that I don't have to hand-edit its config after switching.
10. As the dotfiles owner, I want neovim to pick up the new theme automatically the next time I start it, so that a fresh nvim session matches the rest of my desktop.
11. As the dotfiles owner, I want bat's syntax highlighting theme to switch with the rest of my tools, so that code I view in the pager doesn't clash visually with the new terminal theme.
12. As the dotfiles owner, I want the bat themes' syntax colors to visually match my neovim colorscheme's syntax colors, so that code looks consistent whether I'm viewing it in nvim or in a bat preview.
13. As the dotfiles owner, I want fzf's chrome colors (border, prompt, highlight, etc.) to switch with the rest of my tools, so that fzf popups (including fzf-tab completion) don't clash with the new terminal theme.
14. As the dotfiles owner, I want a single canonical palette file per mode that all the generated integrations read from, so that I only ever have to edit colors in one place per mode.
15. As the dotfiles owner, I want the switch script to never leave my tracked dotfiles dirty in git after a switch, so that `git status` stays clean regardless of which mode I'm in.
16. As the dotfiles owner, I want a sway keybind that triggers the toggle, so that I can switch themes without opening a terminal.
17. As the dotfiles owner, I want tmux's dark-mode styling to be derived strictly from the canonical dark palette rather than the stale bespoke colors currently commented out in `.tmux.conf`, so that tmux's dark mode is visually consistent with the rest of my dark-mode tools.
18. As the dotfiles owner, I want sway's `focused_inactive` border color to be derived from the canonical palette's muted-gray slot rather than the current bespoke gray, so that inactive window borders are consistent with the rest of the palette.
19. As the dotfiles owner, I want to invoke the switch script with an explicit mode argument, so that I can set a specific mode without needing to know or care what the current mode is.
20. As a future maintainer (or myself later), I want the color-generation logic to be testable without foot, tmux, sway, ghostty, or notify-send actually running, so that I can verify it in isolation and catch regressions before they hit my real dotfiles.

## Implementation Decisions

- **Canonical Palette**: two new git-tracked, shell-sourceable files, one per mode (e.g. `.config/theme/hp_dark.sh`, `.config/theme/hp_light.sh`), each defining `color0`..`color15`, `bg`, `fg`, `selection_bg`, `selection_fg`, matching the existing `hp_dark`/`hp_light` hex values already used by ghostty and foot today.
- **Theme Mode state**: a single state file (default `$XDG_STATE_HOME/theme/mode`, i.e. `~/.local/state/theme/mode`) containing the literal string `dark` or `light`. This file is the sole source of truth for "current mode" — consulted by `theme-switch toggle` and by nvim's `colorscheme.lua` at startup.
- **`theme-switch` script**: lives alongside the other scripts in `.local/scripts/`. Structured as a sourceable function library (`resolve_mode`, `generate_foot`, `generate_tmux`, `generate_sway`, `generate_ghostty`, `generate_shell_env`, `write_state`) plus a thin `main()` invoked only when run directly (`[[ "${BASH_SOURCE[0]}" == "$0" ]]` guard — see Testing Decisions). Accepts `dark`, `light`, or `toggle` as its argument.
- **Generated Config fragments**: written under `$XDG_STATE_HOME/theme/` (default `~/.local/state/theme/`) — one file per app needing generated content: foot colors block, tmux `set-option` fragment, sway `client.*` fragment, a ghostty fragment containing only a `theme = ` line, and a shell-env fragment exporting `FZF_DEFAULT_OPTS` and `BAT_THEME`. This directory is added to `.gitignore` so tracked dotfiles never show a diff after a switch.
- **Per-app wiring** (per ADR-0001):
  - `foot.ini` gets an `include` directive pointing at the generated foot-colors fragment, replacing the current inline `[colors-light]`/`[colors-dark]` blocks. The script also sends `SIGUSR1` (dark) / `SIGUSR2` (light) to any running foot process for live effect.
  - `.tmux.conf` gets a `source-file` directive pointing at the generated tmux fragment, replacing the current hardcoded "Light" block and commented-out "Dark" block. The script also runs the equivalent `tmux set-option` commands directly against a running tmux server for live effect, when one is running.
  - Sway config gets an `include` directive pointing at the generated sway fragment, replacing the current hardcoded `client.focused`/`client.focused_inactive` lines. The script also runs `swaymsg client.focused ...` / `client.focused_inactive ...` directly for live effect, when a sway session is running.
  - `.config/ghostty/config`'s `theme = "hp_light"` line is replaced with a `config-file` directive pointing at the generated ghostty fragment. No live-apply — next window or restart only.
  - `.config/nvim/lua/core/plugins/colorscheme.lua` reads the Theme Mode state file at startup instead of hardcoding `vim.cmd.colorscheme("hp_light")`, and selects `hp_dark`/`hp_light` accordingly.
  - `.config/bat/config` statically sets `--theme-light="hp_light"` and `--theme-dark="hp_dark"` (removing the current hardcoded `--theme="Coldark-Dark"`); the script exports `BAT_THEME=dark`/`light` in the generated shell-env fragment.
  - `.zshrc`/`.bashrc` source the generated shell-env fragment (`FZF_DEFAULT_OPTS`, `BAT_THEME`), replacing the currently hardcoded `FZF_DEFAULT_OPTS` line and its commented-out dark alternative.
- **New Selected Themes**: `hp_light.tmTheme` and `hp_dark.tmTheme` bat themes, hand-authored to mirror the semantic color roles already defined in the nvim lush themes (comment, string, keyword, number, type, function, etc.), with hex values computed directly from the HSL formulas in `lush_theme/lua/lush_theme/hp_light.lua` / `hp_dark.lua` (not re-derived by eye/screenshot — see Further Notes). Installed under bat's custom themes directory and registered via `bat cache --build`, a one-time setup step outside the switch script's per-invocation work.
- **Palette-mapping fixes**: tmux's dark-mode styling and sway's `client.focused_inactive` are generated strictly from canonical palette slots (tmux dark accent/mode-bg → `color4`/`bright4`; sway `focused_inactive` → `bright0`/`color8`), discarding the stale bespoke hex values currently present (`#5b9dc4`, `#2e4650` in the commented tmux block; `#595959` in sway).
- **Notification**: `notify-send "Theme" "Switched to dark mode"` (or `"light"`), fired once per invocation, no icon or urgency customization.
- **Sway keybind**: a new `bindsym` in sway config invoking `theme-switch toggle`.
- Live-vs-next-launch behavior per app is fixed as designed in ADR-0001 (foot/tmux/sway live; ghostty/nvim/bat/fzf next-launch) — not user-configurable.

## Testing Decisions

- No test framework currently exists in this repo; this is the first automated test suite for anything under `.local/scripts/`. `bats` (Bash Automated Testing System) is a reasonable default since it's the de facto standard for shell-script testing, but the implementing agent may pick an alternative if something more suitable is already available (check `.config/mise/config.toml`).
- Test only external behavior, at the seam agreed during grilling: `source theme-switch`, call the generator functions with a scratch output directory and a given Theme Mode, and assert on the exact written file contents (foot/tmux/sway/ghostty fragments, `FZF_DEFAULT_OPTS`/`BAT_THEME` values, state-file content) — not on internal helper implementation details.
- Cover both modes (`dark`, `light`) for every generator function, plus all three `resolve_mode` paths: explicit `dark`, explicit `light`, and `toggle` (reading an existing state file and producing the opposite mode, including the case where no state file exists yet).
- Do not attempt to automate the live-apply step (signals, `tmux set-option`, `swaymsg`) or the `notify-send` call — no branching logic to verify, and they depend on external processes being present. Verify these manually by running the script for real and observing foot/tmux/sway/notification behavior.
- No prior art exists in this repo for shell-script tests; this establishes the pattern for any future `.local/scripts/` testing.

## Out of Scope

- Sway's `unfocused`, `urgent`, and `placeholder` border colors — only `focused` and `focused_inactive` are currently defined and in scope.
- Any app not explicitly listed: waybar, rofi/wofi, mako/dunst (swaync itself), lock screen, GTK/Qt app theming, wallpaper.
- Auto-following the desktop/OS light-dark preference (e.g. ghostty's `theme = light:...,dark:...` auto-detection) or a time-of-day scheduler — switching is always an explicit user action (CLI or keybind).
- Live-switching already-open ghostty windows, already-running nvim sessions, or already-open shells' `FZF_DEFAULT_OPTS`/`BAT_THEME` — explicitly deferred per the next-launch decision.
- Any new palette roles beyond the existing 16 ANSI colors + bg/fg/selection — the tmux/sway bespoke values are dropped rather than preserved as new roles (e.g. no `accent_muted` or `mode_bg`).

## Further Notes

- `docs/adr/0001-theme-switching-per-app-strategy.md` records why each app gets a different integration strategy rather than one uniform mechanism — read before implementing.
- `CONTEXT.md` defines the vocabulary (Theme Mode, Canonical Palette, Generated Config, Selected Theme, Live-switchable app, Next-launch app) used throughout this spec.
- The bat `.tmTheme` hex-to-role mapping should mirror `lush_theme/lua/lush_theme/hp_light.lua` / `hp_dark.lua` as closely as the `.tmTheme` format allows. `.tmTheme` doesn't support a `gui`-style field, but does support per-scope `fontStyle: italic`, which should be used where the nvim theme uses `gui = "italic"` (e.g. comments, strings).
- `bat cache --build` must be (re-)run after the new theme files are added or changed; this is a one-time/per-edit setup step, not part of the switch script itself.
