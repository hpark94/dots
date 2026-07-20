# 05 — Nvim integration

**What to build:** Wire neovim into the theme system by having its colorscheme selection read the shared Theme Mode state at startup, instead of being hardcoded.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [x] `.config/nvim/lua/core/plugins/colorscheme.lua` reads the Theme Mode state file (same file/path `theme-switch` writes) at startup instead of hardcoding `vim.cmd.colorscheme("hp_light")`.
- [x] If the state file is missing or contains an unrecognized value, nvim falls back to a sensible default mode rather than erroring.
- [x] Verified manually: `theme-switch dark` then opening a new nvim instance shows the `hp_dark` colorscheme; `theme-switch light` then a new instance shows `hp_light`.

## Comments

Verified via `nvim --headless -c 'lua print(vim.g.colors_name)' -c 'qa'` after `theme-switch dark`/`light`: prints `hp_dark`/`hp_light` respectively. Also verified the fallback path: missing state file and a garbage state-file value both fall back to `hp_light`.

Caught during review: the initial `os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")` fallback diverged from the shell script's `${XDG_STATE_HOME:-$HOME/.local/state}` in one edge case — bash's `:-` falls back on empty string too, but Lua's `or` only falls back on `nil`. Fixed to check for both `nil` and `""` explicitly so nvim and `theme-switch` agree on the resolved path in all cases.
