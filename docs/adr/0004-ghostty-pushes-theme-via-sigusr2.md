# ghostty pushes the theme live via SIGUSR2

ADR-0001 classified ghostty as a Next-launch app on the finding that it "has no
CLI/signal reload (keybind or restart only)": already-open windows kept their
old colors until restarted. That was true of the ghostty in use when ADR-0001
was written, but ghostty 1.3.1 reloads its config on `SIGUSR2` and applies theme
and color changes to running surfaces (verified live on this machine). We
promote ghostty to Live-switchable via the **Push** route, the same shape as
foot, tmux, sway, swaync, and zathura. `generate_ghostty` already rewrites the
`theme = "hp_<mode>"` fragment (`~/.local/state/theme/ghostty-theme.conf`,
included by the tracked config) on every render; the only missing piece was
signalling running instances afterward. A new `apply_ghostty` in `theme-switch`
sends one `SIGUSR2` to running ghostty processes in the apply phase, and the
reload re-reads the freshly written fragment.

## Considered Options

**One signal (chosen) over foot's two.** foot preloads both palettes as its
`[colors]`/`[colors2]` blocks and selects between them with a per-mode signal
(`SIGUSR1` for dark, `SIGUSR2` for light), so `apply_foot` must pick the signal
from the mode. ghostty does not preload both modes: `generate_ghostty`
regenerates the single current-mode fragment on every render, so a single
mode-independent `SIGUSR2` that tells ghostty to re-read its config is enough.
`apply_ghostty` therefore takes `mode` only for call-site symmetry with the
other `apply_*` functions and does not branch on it.

**Push over remaining Next-launch.** Keeping ghostty Next-launch would leave
every open window stale until restarted, the exact gap ADR-0003 closed for
shells. With a working signal reload available, Push removes that lag for the
cost of one `pkill` in the apply phase, mirroring the app the roster already
treats as the Push archetype.

## Consequences

- `theme-switch` gains `apply_ghostty` and calls it in the render pipeline right
  after `apply_foot`. The generator is unchanged; it already wrote the fragment.
- ADR-0001's "ghostty has no CLI/signal reload" finding is superseded for
  ghostty 1.3.1 and later. The per-app-strategy thesis stands: ghostty simply
  moved from the include-fragment-only shape to the push shape as its actual
  capability grew.
- Not every ghostty option can change at runtime: options like
  `window-decoration` are fixed at startup, and ghostty logs a warning when a
  reload touches one. Theme and color settings are among the options ghostty
  does apply live, so the switch takes effect on open surfaces; the warning, if
  any, is benign.
