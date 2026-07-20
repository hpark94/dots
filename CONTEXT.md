# Dotfiles Theming

Vocabulary for switching this repo's terminal/editor/WM tooling between light and dark color themes from a single script.

## Language

**Theme Mode**:
The global light/dark state (`dark` or `light`), persisted in one state file that is the source of truth for "what mode is currently active." Other tools may query it.
_Avoid_: color scheme, appearance

**Canonical Palette**:
The hand-maintained, git-tracked source of the 16 ANSI colors plus bg/fg/selection for a given Theme Mode — one shell-sourceable file per mode.
_Avoid_: theme file (ambiguous with Selected Theme)

**Generated Config**:
A derived, gitignored file the switch script writes from the Canonical Palette (or a fixed theme-name choice), which a tracked app config `include`s or `source`s. Regenerated on every switch; never hand-edited.
_Avoid_: cache, build output

**Selected Theme**:
A hand-authored, pre-built theme artifact that exists for both modes ahead of time (nvim colorscheme, bat syntax theme); switching means picking a name, not regenerating colors. Uses richer semantic roles (comment, string, keyword, type, function, ...) than the Canonical Palette's flat 16 slots.
_Avoid_: generated theme

**Live-switchable app**:
An app whose already-running instances pick up a Theme Mode change immediately: foot (`SIGUSR1`/`SIGUSR2`), tmux (`set-option` against the running server), sway (`swaymsg`).
_Avoid_: hot reload

**Next-launch app**:
An app that only picks up a Theme Mode change in new instances/sessions, because it has no live-reload hook without fragile extra infra: ghostty (keybind/restart only), nvim (colorscheme picked at startup), and shell-env-driven tools (fzf, bat) for already-open shells.
_Avoid_: static, cold
