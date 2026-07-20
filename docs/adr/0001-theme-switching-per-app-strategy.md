# Per-app strategy for theme switching, not a uniform mechanism

A single script must flip ghostty, foot, tmux, fzf, bat, nvim, and sway between light and dark. Each app has a genuinely different reload story: foot and tmux support live updates (signals / `set-option` against a running server), sway supports live `swaymsg` calls, but ghostty has no CLI/signal reload (keybind or restart only), nvim's colorscheme is picked once at startup, and env-var-driven tools (`fzf`, `bat`) only update newly-started shells.

Rather than forcing one uniform mechanism, each app gets the strategy that matches its actual capability:

- **foot, tmux, sway**: generated, gitignored config fragments (`~/.local/state/theme/`) included/sourced by the tracked config, plus a live signal/command for instant effect on already-running instances.
- **ghostty**: generated, gitignored include fragment containing just a theme name (no signal/CLI reload exists); applied on next window or restart.
- **nvim**: reads the shared Theme Mode state file directly at startup — no generated fragment needed, since Lua can read a file.
- **bat, fzf**: driven by env vars (`BAT_THEME`, `FZF_DEFAULT_OPTS`) exported from a generated shell snippet sourced by `.zshrc`/`.bashrc`; applied on next shell.
- **nvim and bat** additionally get hand-authored Selected Themes (mirroring nvim's existing semantic HSL palette) instead of being derived from the flat 16-color Canonical Palette, since syntax highlighting needs more semantic roles than 16 ANSI slots provide.

All Generated Config fragments live outside the tracked dotfiles tree (gitignored under `~/.local/state/theme/`) so `git status` stays clean after every switch. Only the Canonical Palette source files and the hand-authored Selected Themes are tracked in git.

Considered and rejected: forcing every app through one uniform "generate a file and reload" pipeline. This would have meant either accepting stale/dirty git diffs on tracked configs (ghostty, nvim, bat, .zshrc) on every switch, or inventing fake reload mechanisms (simulated keypresses, nvim RPC sockets) for apps that don't need them.
