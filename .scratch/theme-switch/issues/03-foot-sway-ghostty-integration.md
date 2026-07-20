# 03 — Foot + sway + ghostty integration

**What to build:** Wire foot, sway, and ghostty into `theme-switch`. Foot and sway update live in already-running instances; ghostty picks up the new theme on its next window (per ADR-0001, it has no live-reload hook). Also adds the sway keybind for toggling.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [ ] `generate_foot` writes a foot colors fragment (mode-appropriate `[colors-light]`/`[colors-dark]` values sourced from the Canonical Palette) to the generated-config output directory; `foot.ini` includes it via `include`, replacing the current inline blocks.
- [ ] Test: `generate_foot` produces the expected fragment content for both dark and light modes, given a scratch output directory.
- [ ] `theme-switch` sends `SIGUSR1` (dark) or `SIGUSR2` (light) to any running foot process for live effect.
- [ ] `generate_sway` writes a sway fragment with `client.focused` (from the accent/`color4` family) and `client.focused_inactive` (mapped to `bright0`/`color8`, replacing the old bespoke `#595959`) to the generated-config directory; sway config includes it via `include`, replacing the current hardcoded `client.focused`/`client.focused_inactive` lines.
- [ ] Test: `generate_sway` produces the expected fragment content for both modes, given a scratch output directory.
- [ ] `theme-switch` runs `swaymsg client.focused ...` / `client.focused_inactive ...` directly when a sway session is running, for live effect.
- [ ] A new sway `bindsym` invokes `theme-switch toggle`.
- [ ] `generate_ghostty` writes a fragment containing only a `theme = "hp_dark"` / `theme = "hp_light"` line; `.config/ghostty/config`'s `theme = "hp_light"` line is replaced with a `config-file` directive pointing at it.
- [ ] Test: `generate_ghostty` produces the expected fragment content for both modes.
- [ ] Verified manually: `theme-switch dark` recolors an already-open foot window and sway window borders immediately, and a newly opened ghostty window comes up in dark mode. The sway keybind triggers the same behavior.
