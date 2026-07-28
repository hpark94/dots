# Per-app strategy for theme switching, not a uniform mechanism

A single script must flip ghostty, foot, tmux, fzf, bat, nvim, and sway between light and dark. Each app has a genuinely different reload story: foot and tmux support live updates (signals / `set-option` against a running server), sway supports live `swaymsg` calls, but ghostty has no CLI/signal reload (keybind or restart only), nvim's colorscheme is picked once at startup, and env-var-driven tools (`fzf`, `bat`) only update newly-started shells.

Rather than forcing one uniform mechanism, each app gets the strategy that matches its actual capability:

- **foot, tmux, sway**: generated, gitignored config fragments (`~/.local/state/theme/`) included/sourced by the tracked config, plus a live signal/command for instant effect on already-running instances.
- **ghostty**: generated, gitignored include fragment containing just a theme name (no signal/CLI reload exists); applied on next window or restart.
- **nvim**: reads the shared Theme Mode state file directly at startup — no generated fragment needed, since Lua can read a file.
- **bat, fzf**: driven by env vars (`BAT_THEME`, `FZF_DEFAULT_OPTS`) exported from a generated shell snippet sourced by `.zshrc`/`.bashrc`; applied on next shell. (Already-open shells were promoted from next-launch to live by ADR-0003, via a prompt hook that re-sources the snippet; the per-app shape here is unchanged.)
- **nvim and bat** additionally get hand-authored Selected Themes (mirroring nvim's existing semantic HSL palette) instead of being derived from the flat 16-color Canonical Palette, since syntax highlighting needs more semantic roles than 16 ANSI slots provide.

A fourth shape was added later, when the roster grew to waybar, swaync, fuzzel and zathura (see
`.scratch/portable-dotfiles/issues/07-theme-switch-app-roster.md`). It strengthens rather than
weakens the thesis above, because it is an app whose actual capability is to need nothing from us:

- **waybar**: **pull**, not push. waybar subscribes to the XDG desktop portal's
  `org.freedesktop.appearance` and, when started without `-s`, prefers `style-dark.css` /
  `style-light.css` over `style.css`, re-reading on every change. The `color-scheme` write that
  `apply_gtk` already performs is therefore the whole integration: no signal, no apply step, no
  `theme-switch` code. Its two stylesheets are tracked and carry structure only, each importing a
  Generated Config fragment that carries the colors, which means the generator writes **both** modes
  on every switch rather than only the current one, since waybar and not the script chooses.
- **swaync** and **zathura** are ordinary push apps (`swaync-client -rs`, D-Bus `SourceConfig`), and
  **fuzzel** needs no reload at all: it is spawned per invocation and exits, so its `include` is
  always read fresh.

Note this sits close to, but does not cross, the deliberate exclusion of "auto-following the
desktop/OS light-dark preference." The portal value waybar reads is written by our own `apply_gtk`,
so switching remains an explicit user action; waybar merely learns about it by subscription instead
of by signal. Nothing follows an external or scheduled source.

delta, the git pager, was wired in later as another next-launch include-fragment app,
the same shape as ghostty and fuzzel. `theme-switch` writes a gitignored `delta.gitconfig`
fragment naming the mode's bat syntax theme (`hp_light` / `hp_dark`), and the tracked
`.gitconfig.shared` `[include]`s it. delta has no persistent instance to signal; git spawns
it fresh per invocation, so the next diff is always current with no apply step. lazygit
inherits this by using delta as its own pager, and re-themes on its next diff too. This also
keeps the tracked/generated split intact: delta rides bat's already-tracked `hp_*` Selected
Themes, and only the gitignored fragment is generated.

All Generated Config fragments live outside the tracked dotfiles tree (gitignored under `~/.local/state/theme/`) so `git status` stays clean after every switch. Only the Canonical Palette source files and the hand-authored Selected Themes are tracked in git.

Considered and rejected: forcing every app through one uniform "generate a file and reload" pipeline. This would have meant either accepting stale/dirty git diffs on tracked configs (ghostty, nvim, bat, .zshrc) on every switch, or inventing fake reload mechanisms (simulated keypresses, nvim RPC sockets) for apps that don't need them.
