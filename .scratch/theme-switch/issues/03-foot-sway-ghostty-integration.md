# 03 — Foot + sway + ghostty integration

**What to build:** Wire foot, sway, and ghostty into `theme-switch`. Foot and sway update live in already-running instances; ghostty picks up the new theme on its next window (per ADR-0001, it has no live-reload hook). Also adds the sway keybind for toggling.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [x] `generate_foot` writes a foot colors fragment (mode-appropriate `[colors-light]`/`[colors-dark]` values sourced from the Canonical Palette) to the generated-config output directory; `foot.ini` includes it via `include`, replacing the current inline blocks.
- [x] Test: `generate_foot` produces the expected fragment content for both dark and light modes, given a scratch output directory.
- [x] `theme-switch` sends `SIGUSR1` (dark) or `SIGUSR2` (light) to any running foot process for live effect.
- [x] `generate_sway` writes a sway fragment with `client.focused` (`bright3`/`color11` — this already matches the palette exactly today, `#edbb9b` in light; correcting an earlier drafting error in this ticket that said "accent/`color4`") and `client.focused_inactive` (mapped to `bright0`/`color8`, replacing the old bespoke `#595959`) to the generated-config directory; sway config includes it via `include`, replacing the current hardcoded `client.focused`/`client.focused_inactive` lines.
- [x] Test: `generate_sway` produces the expected fragment content for both modes, given a scratch output directory.
- [x] `theme-switch` runs `swaymsg client.focused ...` / `client.focused_inactive ...` directly when a sway session is running, for live effect.
- [x] A new sway `bindsym` invokes `theme-switch toggle`.
- [x] `generate_ghostty` writes a fragment containing only a `theme = "hp_dark"` / `theme = "hp_light"` line; `.config/ghostty/config`'s `theme = "hp_light"` line is replaced with a `config-file` directive pointing at it.
- [x] Test: `generate_ghostty` produces the expected fragment content for both modes.
- [x] Verified manually: `theme-switch dark` recolors an already-open foot window and sway window borders immediately, and a newly opened ghostty window comes up in dark mode. The sway keybind triggers the same behavior.

## Comments

Discovered mid-implementation: `.config/theme/` (added in ticket 01) was never symlinked into `~/.config/theme` by the stow deployment — new top-level directories don't get picked up automatically by this repo's stow setup the way new files inside already-linked directories do. Fixed by manually creating the missing symlink (`~/.config/theme -> ../dots/.config/theme`), matching the existing pattern for `bat`/`foot`/`ghostty`. Worth remembering if a future ticket introduces another new top-level directory.
