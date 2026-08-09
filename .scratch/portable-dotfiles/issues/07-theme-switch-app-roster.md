# 07 theme-switch app roster and palette roles

**Type:** `grilling`

**Status:** resolved

**Blocked by:**
[03 Theme reload and include capability survey](03-theme-capability-survey.md)

**Map:** [Portable dotfiles](../map.md)

## Question

Which remaining apps join `theme-switch`, how is each one classified and wired,
and does the Canonical Palette grow?

### Three decisions, one session

1. **The roster.** Of `fuzzel`, `waybar`, `swaync`, `zathura`, `swaylock`,
   `swaybg`, which are worth integrating? Not all of them necessarily are.
   `swaybg` sets a wallpaper from a single `$wallpaper` variable in
   `.config/sway/config`, which may be a per-mode image rather than a palette
   problem, and is a different kind of thing from a CSS stylesheet.
2. **Classification and mechanism per app**, in the existing vocabulary:
   Live-switchable or Next-launch, generated fragment or direct write, and which
   apply-step it gets. Driven by what [03](03-theme-capability-survey.md) found,
   not by preference.
3. **Whether the Canonical Palette gains roles.** Now sharp, because
   [the survey](03-theme-capability-survey.md) measured it. Four of six apps
   need nothing new; **all** pressure is waybar and swaync, and severity colors
   are **not** the gap (both stylesheets already resolve warning/critical to
   red/green, which are `color1`/`color2`). Exactly four roles are missing, all
   surfaces and borders: a hover/raised surface, a muted surface, an inverse
   text-on-surface, and a border color.

   The decision is genuinely open because of one measurement: waybar's
   `bg-hover` and swaync's `accent` were invented independently and are the
   **same** value `#e5d9cd`, which is a near-miss on the existing `selection_bg`
   `#e4ded7`. So "map onto existing slots and accept the squeeze" is a live
   option, not a strawman. Growing the palette touches every palette file and
   generator.

### This reopens two settled decisions

Both live in `.scratch/theme-switch/spec.md`, and reopening them is the point of
this ticket, not an accident. Read them before deciding, and record explicitly
which are being overturned:

- Its **Out of Scope** list names "waybar, rofi/wofi, mako/dunst (swaync
  itself), lock screen, wallpaper" as deliberately excluded.
- Its **Out of Scope** list also rules out "any new palette roles beyond the
  existing 16 ANSI colors
  - bg/fg/selection," on the grounds that tmux and sway's bespoke values were
    dropped rather than preserved as new roles.

Per `docs/agents/domain.md`, if the answer contradicts
`docs/adr/0001-theme-switching-per-app-strategy.md`, surface that explicitly
rather than silently overriding it.

### Start from the cheapest win

[The survey](03-theme-capability-survey.md) found that **waybar is already
Live-switchable and already reacting to `apply_gtk`'s `color-scheme` write on
every toggle**. It prefers `style-dark.css` / `style-light.css` over `style.css`
and only falls back because those files do not exist. Creating them is the whole
integration: no generator, no apply step, no signal. If the roster gets trimmed
for effort, waybar should be the last thing cut, not the first.

Note the knock-on for decision 3: because waybar re-reads CSS itself, its colors
could be hand-authored in two stylesheets rather than generated from the palette
at all. That is a third option alongside "map onto existing slots" and "grow the
palette," and it trades palette purity for not touching the generator. Worth
grilling rather than assuming.

### Not this ticket

Whether Theme Mode propagates to remote sessions. That is still fog on the map,
and it depends on [01](01-name-the-split.md), not on this roster. Every app here
is host only.

## Answer

### 1. The roster: waybar, swaync, fuzzel, zathura

`swaylock` and `swaybg` are out.

The survey split the six sharply. waybar and swaync are the two apps that are
actually _wrong_: both stylesheets are hardcoded light-mode with no dark variant
anywhere, so a dark toggle leaves them glaring. zathura is wrong in the opposite
direction, which this ticket found while wiring it: `zathurarc:19-20` hardcodes
`#100e11`/`#e9e6e2`, the **dark** palette, so zathura is permanently dark while
waybar and swaync are permanently light. Three of the four in-roster apps are
stuck at one end of a toggle that has existed for months. fuzzel is the cheap
fourth: 7/7 of its colors are already exact palette values, and it needs no
reload mechanism at all.

`swaylock` sets **zero** colors today, so it is stock, so there is no clash to
fix: theming it is new work, not a repair. It also has no include mechanism (its
config file is a list of `--flag` lines), which would force a direct write into
a tracked file, the one shape ADR-0001 avoids everywhere else. `swaybg` is not a
palette problem wearing a theming costume: its capability is one color or one
image, and the current wallpaper is a photograph, so the real question there is
"is there a per-mode wallpaper", which is a taste decision with no palette
content.

### 2. The Canonical Palette does not grow

**No new roles. It stays at 20 values.** The spec's "no new palette roles beyond
the existing 16 ANSI colors + bg/fg/selection" exclusion is **upheld**, not
overturned, which is the opposite of what this ticket expected when it was
written.

The survey named four missing roles. Tracing every off-palette value to the rule
that uses it dissolves all four:

**waybar** (4 off-palette values, 0 new roles needed):

| Value                   | Used by                                 | Resolution                                                                                                                                            |
| ----------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bg-hover #e5d9cd`      | module `:hover` background              | snap to `selection_bg` `#e4ded7`                                                                                                                      |
| `fg-lilac #babbf1`      | `#custom-lock`'s icon, and nothing else | `color13`. It is a Catppuccin lavender, foreign to this palette                                                                                       |
| `rgba(153,209,219,0.1)` | active workspace wash                   | `alpha(@color12, 0.1)` (`color12` is `#a4c7db`)                                                                                                       |
| `rgba(255,255,255,0.1)` | tooltip border                          | `alpha(@fg, 0.1)`. White is a light-mode-only assumption and is near-invisible on today's light tooltip, so this fixes a live bug, not just dark mode |

**swaync**: `accent #e5d9cd` is the _same_ value as waybar's `bg-hover` and
snaps to `selection_bg` likewise. The three literals are shadows and washes,
derivable with `alpha()`. That leaves exactly one genuine question,
`bg_muted rgba(128,128,128,1)`, a mid-grey surface carrying near-white
`text_light` across notification bodies, buttons, sliders and the volume widget.
Keeping that look costs **two** new roles whose dark values exist nowhere and
would have to be invented. Instead swaync's surfaces restyle to waybar's idiom:
surface `selection_bg`, text `fg`, both of which fall straight out of the
existing palette in both modes. The cost is honest: `bg_muted` and `accent`
collapse to one value, so hover stops reading as hover, and
`shade(@selection_bg, ~1.05)` covers that.

This turns on one fact this ticket verified rather than assumed. The survey had
tested `shade()` across an `@import` boundary but not `alpha()`. Executed here
against this host's parsers, with a control proving the harness detects errors:
`alpha(@color, 0.1)` used across the import boundary parses with **no errors in
both GTK 3 (waybar) and GTK 4 (swaync)**. Without `alpha()` the washes and
borders would have needed stored roles and the answer would have been different.

### 3. Classification and wiring

| App     | Class           | Route    | Mechanism                                                                                                                                                  |
| ------- | --------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| waybar  | Live-switchable | **pull** | tracked `style-dark.css` / `style-light.css`, each importing its own generated per-mode fragment plus a shared `style-rules.css`. No apply step, no signal |
| swaync  | Live-switchable | push     | `@import` of one current-mode fragment, plus `swaync-client -rs`                                                                                           |
| fuzzel  | Next-launch     | n/a      | `include=~/.local/state/theme/…`, no reload, one-shot process                                                                                              |
| zathura | Live-switchable | push     | `include ../../.local/state/theme/…`, plus D-Bus `SourceConfig`                                                                                            |

**waybar is a pull app, and that is the whole integration.** It subscribes to
`org.freedesktop.appearance`, which `apply_gtk` has already been writing on
every toggle, and prefers `style-dark.css`/`style-light.css` over `style.css`.
`theme-switch` contributes **no code**: no apply function, no signal, no guard.
The alternative considered was folding waybar into the uniform shape (one
`style.css`, one current-mode fragment, `SIGUSR2` to reload), which is more
observable and one file instead of three, but it means writing an apply step to
replace a mechanism that already works for free. Rejected.

The structural consequence, which is new to this design and is why
`CONTEXT.md`'s **Generated Config** entry needed amending: because _waybar_
picks the mode rather than the script, the generator must write **both** modes
on every switch and both must stay on disk. Every other integration writes only
the current mode.

**Relative includes survive stow's symlinks, verified.** Both waybar's CSS
`@import` and zathura's `include` resolve relative to the config file, and under
stow those config files are symlinks into `~/dots`
(`~/.config/waybar -> ../dots/.config/waybar`). If GTK canonicalized the
symlink, `../../.local/state/theme/` would resolve to
`~/dots/.local/state/theme/`, which does not exist, and a missing `@import`
target is a **hard** parse error. Tested against a synthetic symlinked tree:
**both GTK 3 and GTK 4 resolve through the symlink path, not the canonicalized
one**, with a negative control confirming the failure message names the path
actually attempted. This is the same trick `.config/ghostty/config:7` already
uses.

**fuzzel's include must come after the tracked `[colors]`.** `include` is only
valid in the default or `[main]` section, is applied in place, and last
assignment wins, so a fragment included above the tracked block would be
silently overwritten by it. `[colors]` currently sits at the end of the file.
Recommended shape is to delete the tracked `[colors]` block outright rather than
shadow it, so that a missing fragment fails loudly onto fuzzel's defaults
instead of quietly serving stale light colors. Path must be absolute or start
with `~/`. zathura's `include` needs the same after-the-tracked-values
placement, and notably does **not** support `~/`.

### 4. zathura's recolor: the Theme Mode sets it, `i` overrides until the next switch

`SourceConfig` re-parses the entire zathurarc, so whatever the fragment says
about `recolor` is re-asserted on every switch, and there is no way to read the
runtime value back (zathura exposes `documentinfo`/`filename` as D-Bus
properties, not settings). The script cannot preserve a manual toggle; it can
only choose what a switch resets it to.

**Dark mode writes `set recolor true`, light mode writes `false`**, with
`recolor-lightcolor` and `recolor-darkcolor` generated from the palette (they
are hardcoded dark today, like the chrome). Dark mode therefore darkens pages on
its own, which is the point. Light mode leaves documents in their true colors,
where recolor is near-identity anyway (retinting white to `#f9f7f6` and black to
`#4d4851`) while still costing the hue-mangling on figures that
`recolor-keephue` only partly softens. The `i` keybind keeps working exactly as
now and holds until the next theme switch.

`SourceConfig` was confirmed present on the live bus during this session
(`org.pwmt.zathura.PID-13652`, no args, returns `b`) by read-only introspection.
It was not invoked, to avoid touching an open document.

### 5. What this overturns, and what it does not

- **Overturned**: the shipped spec's Out of Scope line excluding "waybar,
  rofi/wofi, mako/dunst (swaync itself), lock screen, wallpaper". waybar and
  swaync are admitted, along with fuzzel and zathura which that line did not
  name. Lock screen and wallpaper stay out. Recorded as a pointer in
  `.scratch/theme-switch/spec.md`, which is otherwise left intact as the record
  of what shipped.
- **Upheld**: the "no new palette roles" exclusion, per section 2.
- **Not contradicted**: ADR-0001. Its thesis is per-app strategy over a uniform
  mechanism, and waybar is the strongest case it has, an app whose correct
  strategy is _nothing_. ADR-0001 is **extended** with pull as a fourth shape
  rather than amended in place.
- **Near-miss worth naming**: the spec also excludes "auto-following the
  desktop/OS light-dark preference", and waybar's path is literally a
  desktop-preference subscription. It resolves cleanly: the portal value is
  written by our own `apply_gtk`, so switching stays an explicit user action.
  Nothing follows an external or scheduled source.
- `CONTEXT.md` amended: **Live-switchable app** now distinguishes push from pull
  and lists all five push apps plus waybar; **Generated Config** now covers the
  per-mode case.

### Carried forward as implementation checks, not decisions

- **The waybar two-file branch has never been exercised.** The journal proves
  waybar receives the appearance change and re-runs `getStyle` on every past
  toggle, but it has never had a `style-dark.css` to find, so only the fallback
  path has ever run. Establish this first; the rest of the waybar work is
  worthless if it does not hold.
- **Whether `SourceConfig` re-applies `set recolor`** is inference from source,
  not observation.
- **swaync's packaged system CSS was never read.** It loads at the same priority
  before the user stylesheet, so what the user CSS actually has to override is
  uncharacterised. This matters only if the rewrite drops rules rather than
  replacing values.
