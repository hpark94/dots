# 02 — Bat syntax themes (`hp_light` / `hp_dark`)

**What to build:** Two new hand-authored bat syntax-highlighting themes, `hp_light` and `hp_dark`, that visually match the existing nvim colorscheme rather than being derived from the flat 16-color terminal palette. Verifiable entirely standalone, independent of the `theme-switch` script.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] `hp_light.tmTheme` and `hp_dark.tmTheme` exist and are installed under bat's custom themes directory.
- [ ] Each scope's hex color is computed directly from the corresponding HSL formula in `lush_theme/lua/lush_theme/hp_light.lua` / `hp_dark.lua` — not eyeballed, not re-derived by screenshot/color-picker.
- [ ] Semantic roles mirror nvim's mapping: comment, string, keyword, number/boolean/float, type, function, constant, identifier/variable, operator, tag, and any other groups meaningfully present in the lush themes.
- [ ] Scopes where the nvim theme uses `gui = "italic"` (e.g. comments, strings) use `fontStyle: italic` in the corresponding `.tmTheme` scope.
- [ ] `bat cache --build` has been run so `--theme=hp_light` / `--theme=hp_dark` are available and render correctly.
- [ ] Verified manually: `bat --theme=hp_light <file>` and `bat --theme=hp_dark <file>` both render sensible, readable syntax highlighting for at least one real source file, and look visually consistent with the equivalent nvim colorscheme.
