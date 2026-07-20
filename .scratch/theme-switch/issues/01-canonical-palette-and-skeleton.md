# 01 — Canonical palette + `theme-switch` skeleton

**What to build:** The foundational Canonical Palette files and the `theme-switch` script skeleton — mode resolution, state persistence, and the switch notification — with no app integrations wired up yet. Running `theme-switch dark`/`light`/`toggle` should work end-to-end at the level of "the Theme Mode is now persisted and I got a notification," even though no app reacts to it yet.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] `.config/theme/hp_dark.sh` and `.config/theme/hp_light.sh` exist, git-tracked, each defining `color0`..`color15`, `bg`, `fg`, `selection_bg`, `selection_fg`, matching the existing `hp_dark`/`hp_light` hex values already used by ghostty and foot today.
- [ ] `.local/scripts/theme-switch` exists as a sourceable function library (`resolve_mode`, `write_state`, notify) plus a thin `main()` guarded so that sourcing the file for tests doesn't execute it.
- [ ] `theme-switch dark` / `theme-switch light` set the Theme Mode state file (default `$XDG_STATE_HOME/theme/mode`) to the literal string `dark`/`light`.
- [ ] `theme-switch toggle` reads the existing state file and flips to the opposite mode; if no state file exists yet, it picks a sensible default.
- [ ] Each invocation fires `notify-send "Theme" "Switched to <mode> mode"`.
- [ ] `$XDG_STATE_HOME/theme/` (or its default path) is added to `.gitignore` so generated artifacts never show up as untracked/dirty.
- [ ] A test framework (bats or equivalent — pick whatever fits the existing toolchain in `.config/mise/config.toml`) is set up, with tests for `resolve_mode` covering: explicit `dark`, explicit `light`, `toggle` from an existing state file, and `toggle` with no existing state file.
