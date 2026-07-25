# 03 Theme reload and include capability survey

**Type:** `research` (AFK, resolved by a `/research` subagent)

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

For each app `theme-switch` does not yet theme, what does its config format actually permit?

**Facts only. This ticket does not choose the roster.** That is
[theme-switch app roster and palette roles](07-theme-switch-app-roster.md), which this unblocks.

### Apps

`fuzzel`, `waybar`, `swaync`, `zathura`, `swaylock`, `swaybg`.

All six are present and wired into the running desktop: `.config/fuzzel/fuzzel.ini`,
`.config/waybar/{config.jsonc,style.css,sway_config.jsonc}`, `.config/swaync/{config.json,style.css}`,
`.config/zathura/zathurarc`, and `swaylock`/`swaybg` invoked from `.config/sway/config` lines 7, 18
and 25 off a shared `$wallpaper` variable.

### For each, establish

1. **Include or import.** Can the tracked config pull in a separate generated fragment, the way
   `foot.ini`, `.tmux.conf` and the sway config already do for `theme-switch`? Name the exact
   directive. If there is none, say so plainly, because that decides the whole integration shape.
2. **Live reload.** Is there a signal, IPC command, or config-watch? Start from what is already
   known: `.config/sway/config:70` binds `pkill -USR1 waybar`, so waybar reloads on `SIGUSR1`
   already. Confirm what that signal actually re-reads (JSON config, CSS, both).

   > **Corrected on resolution.** This was wrong, and asking for verification is what caught it.
   > `SIGUSR1` defaults to **toggle** (bar visibility), `SIGUSR2` to **reload**. Confirmed in
   > `man waybar` under both `on-sigusr1`/`on-sigusr2` and SIGNALS. That keybind hides your bar, it
   > does not reload it. See the Answer.
3. **Color roles the format needs.** This is the important one. The Canonical Palette is 16 ANSI
   slots plus `bg`/`fg`/`selection_bg`/`selection_fg`. waybar and swaync are **CSS**, which can want
   borders, hover states, and warning/critical severity colors that have no ANSI equivalent. Record
   what each stylesheet actually references today, and what a palette-driven version would need.
4. **Whether the app is even long-lived.** `fuzzel` is spawned fresh per invocation from a keybind,
   so it may need no reload mechanism at all and may be trivially correct once its config is
   generated. Verify rather than assume.

### Context to read first

`CONTEXT.md` for the Theme Mode / Canonical Palette / Generated Config / Live-switchable /
Next-launch vocabulary, and `docs/adr/0001-theme-switching-per-app-strategy.md` for why each app gets
a strategy fitted to its real reload capability rather than one uniform pipeline.

## Findings

[research/03-theme-capability.md](../research/03-theme-capability.md), written by a `/research`
subagent fired during the charting session. 851 lines, all six apps against all four points.

## Answer

Surveyed, and it overturned two of the three assumptions this ticket was written on.

**1. waybar is already Live-switchable, at zero cost, and has been all along.** sway starts it with
`-c` but no `-s`, so `Client::getStyle` takes its portal branch: it prefers `style-dark.css` /
`style-light.css` over `style.css`, and re-runs on every `org.freedesktop.appearance` change. That
is the exact key `apply_gtk` already writes. Verified independently of the research agent: the
running waybar (PID 2599) has logged `Received new appearance 'light'` / `'dark'` followed by a CSS
re-read on **every** past `theme-switch` toggle, and `strings` on the binary contains both
`style-light.css` and `style-dark.css`. It falls back to `style.css` only because those two files do
not exist. **Creating them is the entire integration.** No generator, no apply step, no signal.

**2. `pkill -USR1 waybar` does not reload waybar.** `SIGUSR1` defaults to toggle (visibility),
`SIGUSR2` to reload, per `man waybar`. `SIGUSR2` re-reads both the JSON config and the CSS. The
keybind at `.config/sway/config:70` hides the bar. Whether that is intentional is a question for the
owner, and it is not this map's business, but it should not be mistaken for a theming hook.

**3. The palette pressure is real but not where this ticket guessed.** Four of six apps need
nothing new: fuzzel (7/7 colors), zathura (19/21, the two exceptions being hardcoded translucent
search washes), swaylock and swaybg are all fully derivable from the existing 20 values. All
pressure comes from waybar and swaync, and **severity colors are not the gap** as this ticket
assumed: both stylesheets already resolve warning/critical to red/green, which are `color1`/`color2`.
The four roles actually missing are **surfaces and borders**:

- a **hover/raised surface**, where waybar's `bg-hover` and swaync's `accent` are independently
  invented but the *same* value `#e5d9cd`, and a near-miss on `selection_bg` `#e4ded7`
- a **muted surface**
- an **inverse text-on-surface**, where swaync's `text_light` equals `bg` in light mode by
  coincidence only
- a **border color**, currently hardcoded translucent white in waybar

Both stylesheets are also hardcoded light-mode today, with no dark variant anywhere.

**4. Include support splits three ways.** fuzzel has `include=`, but only in the default/`[main]`
section, applied in place, so it must come **after** the tracked `[colors]`. zathura has
`include <path>` (space separated) resolving relative to the config file's directory, which matches
the `../../.local/state/theme/` trick ghostty already uses, but `~/` silently does not work. swaync's
`config.json`, swaylock's config, and swaybg have **no include at all** (swaybg has no config file
whatsoever). Both CSS apps support `@import`, verified against this machine's GTK 3 and GTK 4
parsers, with a mandatory trailing semicolon that `waybar-styles(5)`'s own example omits.

**5. Two live reload paths nobody was using.** zathura exposes `SourceConfig()` on D-Bus
(`org.pwmt.zathura.PID-<pid>`), which re-parses zathurarc and its includes, repaints chrome and
re-renders pages. swaync has `swaync-client -rs`, which re-reads the user stylesheet, but has **no**
portal awareness (only `Adw.init()`), so unlike waybar it must be pushed explicitly. swaybg has no
signals, but sway's `spawn_swaybg()` tears down and respawns on `output ... bg`, so
`swaymsg output '*' bg ...` is a live path through the mechanism `apply_sway` already uses.

**6. Lifetimes confirmed by observation.** fuzzel was genuinely not running after 23h of uptime
despite its keybind, so it needs no reload mechanism at all. swaylock is likewise per-invocation.
waybar, swaync, zathura and swaybg are long-lived.

**Incidental finding, not this map's problem but worth knowing:** the host runs a **redundant**
swaybg. sway spawns an argv-less one because no `output bg` is declared, alongside the config's
`exec swaybg -i`.
