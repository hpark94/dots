# 05 — Nvim integration

**What to build:** Wire neovim into the theme system by having its colorscheme selection read the shared Theme Mode state at startup, instead of being hardcoded.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [ ] `.config/nvim/lua/core/plugins/colorscheme.lua` reads the Theme Mode state file (same file/path `theme-switch` writes) at startup instead of hardcoding `vim.cmd.colorscheme("hp_light")`.
- [ ] If the state file is missing or contains an unrecognized value, nvim falls back to a sensible default mode rather than erroring.
- [ ] Verified manually: `theme-switch dark` then opening a new nvim instance shows the `hp_dark` colorscheme; `theme-switch light` then a new instance shows `hp_light`.
