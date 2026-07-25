# Theme reload and include capability survey

**Resolves:** [03 Theme reload and include capability survey](../issues/03-theme-capability-survey.md)

**Map:** [Portable dotfiles](../map.md)

**Date:** 2026-07-21

**Status:** facts only. This document does not choose the roster and does not decide whether the
Canonical Palette grows. That is
[07 theme-switch app roster and palette roles](../issues/07-theme-switch-app-roster.md).

## Scope and method

Six apps: `fuzzel`, `waybar`, `swaync`, `zathura`, `swaylock`, `swaybg`. For each, four questions
from the ticket: include directive, live reload signal, color roles the format needs, and whether
the app is long-lived.

Everything below was established from man pages installed on this host, from upstream source at the
exact version installed here, or by executing something against this machine. Where a claim rests on
reading source rather than observing behaviour, that is said explicitly.

Per repo style, no em dashes below.

### Versions on this host

All six are installed and all six are wired into the running sway session.

| App | Version | Man pages consulted |
| --- | --- | --- |
| fuzzel | 1.14.0 | `fuzzel(1)`, `fuzzel.ini(5)` |
| waybar | 0.15.0 | `waybar(5)`, `waybar-styles(5)`, `waybar-states(5)`, `waybar-battery(5)`, `waybar-temperature(5)`, `waybar-network(5)`, `waybar-bluetooth(5)` |
| swaync | 0.12.6 | `swaync(1)`, `swaync(5)`, `swaync-client(1)` |
| zathura | 2026.05.20 (girara 2026.02.04) | `zathura(1)`, `zathurarc(5)` |
| swaylock | 1.8.5 | `swaylock(1)` |
| swaybg | 1.2.2 | `swaybg(1)` |
| sway | 1.11 | `sway-output(5)` |

### What counts as primary here

| Source | How it was read |
| --- | --- |
| Man pages | `man` on this host, rendered with `col -bx` |
| waybar source | `Alexays/Waybar` at tag `0.15.0`: `src/main.cpp`, `src/client.cpp`, `src/bar.cpp`, `src/config.cpp`, `src/util/portal.cpp`, `src/util/css_reload_helper.cpp`, `include/bar.hpp`, `include/util/kill_signal.hpp` |
| waybar binary | `strings /usr/bin/waybar`, confirming the compiled-in option names and default-action messages |
| waybar behaviour | `journalctl --user -b`, reading what the running waybar (PID 2599) actually logged across this boot |
| swaync source | `ErikReider/SwayNotificationCenter` at tag `v0.12.6`: `src/functions.vala`, `src/swayncDaemon/swayncDaemon.vala`, `src/configModel/configModel.vala`, `src/main.vala` |
| zathura source | `pwmt/zathura` at tag `0.5.12`: `zathura/dbus-interface.c`, `zathura/config.c` |
| girara source | `pwmt/girara` at tag `0.4.5`: `girara/config.c`, `girara/session.c`, `girara/utils.c` |
| swaylock source | `swaywm/swaylock` at tag `v1.8.5`: `main.c` |
| swaybg source | `swaywm/swaybg` at tag `v1.2.2`: `main.c` |
| sway source | `swaywm/sway` at tag `1.11`: `sway/config/output.c`, `sway/commands/output.c`, `sway/config.c` |
| fuzzel source | `dnkl/fuzzel` at tag `1.14.0` on Codeberg: `config.c`, `main.c` |
| D-Bus interfaces | `gdbus introspect` against the running zathura and swaync on this host |
| GTK CSS | the GTK 3 and GTK 4 parsers installed here (GTK 4.22.4), driven through `Gtk.CssProvider` from python-gi, see [Appendix A](#appendix-a-gtk-css-behaviour-executed-not-inferred) |
| fuzzel config semantics | `fuzzel --check-config` run against synthetic configs in a scratch directory, see [Appendix B](#appendix-b-fuzzel-config-semantics-executed-not-inferred) |
| Process state | `ps`, `/proc/<pid>/cmdline` on this host, uptime roughly 23h36m at time of survey |

Nothing under `~/.config` or in the repo was modified. No D-Bus method with a side effect was called.

## Baseline

### The Canonical Palette is 20 values

`.config/theme/hp_light.sh` and `.config/theme/hp_dark.sh` each define exactly `color0` through
`color15`, plus `bg`, `fg`, `selection_bg`, `selection_fg`. There is no role named hover, border,
surface, warning, or critical. Any color an app needs that is not one of those 20 is either a new
role or a derived value.

### The three existing integration shapes, as prior art

`theme-switch` pairs a `generate_*` writer with an `apply_*` pusher, and every generated fragment
lands in `~/.local/state/theme/`. Three distinct shapes are already in use, and every app below
falls into one of them:

| Shape | Consumer | Directive in the tracked config |
| --- | --- | --- |
| Include an absolute-ish path, plus a signal | `foot.ini:16` | `include=~/.local/state/theme/foot-colors.ini` |
| Include a path relative to the config file | `.config/ghostty/config:7` | `config-file = ?../../.local/state/theme/ghostty-theme.conf` |
| Source at startup, plus a live push | `.tmux.conf:26`, `.config/sway/config:57` | `source-file ~/.local/state/theme/tmux-colors.conf`, `include ~/.local/state/theme/sway-colors.conf` |

Note ghostty's `?` prefix, which makes the include optional. Only ghostty has that. It matters below
because two of the six apps treat a missing include as an error.

## 1. fuzzel

### 1.1 Include: yes, `include=`, with two constraints

`fuzzel.ini(5)` documents it under `SECTION: main`:

> **include** Absolute path to configuration file to import.
>
> - The path must be an absolute path, or start with `~/`.
> - Multiple include directives are allowed, but only one path per directive.
> - Nested imports are allowed.

Two constraints the man page implies but does not spell out, both confirmed by executing
`fuzzel --check-config` (Appendix B):

- **`include` is only valid in the default or `[main]` section.** Placing it inside `[colors]` fails
  with `[colors].include: ... not a valid option: include`. The man page's remark that the default
  section "can also be explicitly named `[main]`, say if it needs to be reopened after any of the
  other sections" is exactly the escape hatch: a `[main]` header reopened after `[border]` parses
  cleanly.
- **Order decides who wins.** `config.c` handles `include` by calling `parse_config_file` on the
  included file inline, at the point the directive appears, into the same `struct config`. Keys are
  assigned as they are read, so the last assignment wins. A fragment included at the top of the file
  would be overwritten by the tracked `[colors]` block below it. The include has to come after the
  tracked settings.

**Missing fragment is survivable but noisy.** `config_load` sets `ret = !errors_are_fatal` on a
parse failure, and `main.c:2019` passes `errors_are_fatal = check_config`, which is false in a
normal run. So a missing include logs an error and fuzzel still starts on defaults. Under
`fuzzel --check-config` the same condition exits 1. There is no optional-include marker equivalent
to ghostty's `?`.

`~/` expansion is handled explicitly in `config.c` (`value[0] == '~' && value[1] == '/'`, joined
against `$HOME`). Anything else that is not absolute is rejected with `not an absolute path`.

### 1.2 Live reload: none, and none is needed

`fuzzel(1)` has no SIGNALS section. There is no signal, no IPC, and no config watch anywhere in the
manual or the source.

### 1.3 Color roles: 12 available, 7 set, all 7 already in the palette

`fuzzel.ini(5)` `SECTION: colors` defines twelve keys: `background`, `text`, `message`, `prompt`,
`placeholder`, `input`, `match`, `selection`, `selection-text`, `selection-match`, `counter`,
`border`. `.config/fuzzel/fuzzel.ini` sets seven of them, and every one is an exact light palette
value:

| Key | Value | Palette slot (light) |
| --- | --- | --- |
| `background` | `#f9f7f6ff` | `bg` |
| `text` | `#4d4851ff` | `color0` / `fg` / `selection_fg` |
| `match` | `#3a7292ff` | `color4` |
| `selection` | `#e4ded7ff` | `color7` / `color15` / `selection_bg` |
| `selection-text` | `4d4851ff` | `color0` / `fg` / `selection_fg` |
| `selection-match` | `#3a7292ff` | `color4` |
| `border` | `#edbb9bff` | `color11` |

Format is an RGBA quadruple in hex. `fuzzel(1)` COLORS says "without a leading `0x`"; both a
`#`-prefixed quoted form and a bare form parse without complaint, verified with `--check-config`.
The existing `selection-text="4d4851ff"` is missing its `#` and is accepted anyway, since the `#` is
optional rather than required.

**Palette gap: none.** The five unset keys (`message`, `prompt`, `placeholder`, `input`, `counter`)
are all ordinary foreground colors with obvious ANSI homes. fuzzel needs no new roles.

### 1.4 Long-lived: no

Confirmed. `fuzzel(1)` FILES documents
`$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock` as a "lock file, used to prevent multiple fuzzel
instances from running at the same time", which only makes sense for a one-shot process. On this
host, with a 23h36m session and `bindsym Control+Alt+r exec $menu` in `.config/sway/config:61`, `ps`
shows no fuzzel process at all. The ticket's assumption holds: fuzzel is spawned fresh per
invocation, so a generated fragment is correct the moment it is written.

## 2. waybar

### 2.1 Include: two separate mechanisms, and only one of them carries color

**JSON config include.** `waybar(5)` documents `include` (`typeof: string|array`). Paths go through
`wordexp`, so `~` expansion and globbing work (`src/config.cpp:tryExpandPath`). A missing file is a
warning only (`Unable to find resource file`), not an error.

The catch is precedence, and it runs opposite to every other include in this repo. `waybar(5)`:

> In case of duplicate options, the first defined value takes precedence, i.e. including file ->
> first included file -> etc.

`Config::mergeConfig` confirms it, with the comment `do not allow overriding value set by top or
previously included config`. An included fragment can only supply keys the tracked config leaves
unset. It cannot override.

This turns out not to matter for theming: **waybar's JSON config contains no colors at all.** Every
color is CSS.

**CSS import.** `waybar-styles(5)` documents `@import url("file:///etc/xdg/waybar/style.css")`. This
is plain GTK 3 CSS. Verified against the GTK 3 parser on this host (Appendix A): `@import` of both a
relative path and a `file://` absolute URL parses, `@define-color` in the imported file resolves in
the importing file, and `shade()` works across the boundary. Two caveats found by execution:

- **The trailing semicolon is mandatory.** The example in `waybar-styles(5)` omits it. GTK 3 rejects
  that form with `expected semicolon`. The man page's example, copied literally, does not parse.
- A missing import is a hard parse error (`Failed to import: ... No such file or directory`), but a
  reference to an undefined `@color` name is silently ignored. Failure modes are asymmetric.

### 2.2 Live reload: the ticket's stated fact is wrong, and there is a better path already running

**`pkill -USR1 waybar` does not reload waybar.** `.config/sway/config:70` binds it, but SIGUSR1's
default action is to toggle bar visibility, not to reload. Three independent confirmations:

- `waybar(5)` SIGNALS: "SIGUSR1: By default toggles the bar visibility (hides if shown, shows if
  hidden). SIGUSR2: By default reloads (resets) the bar."
- `include/util/kill_signal.hpp`:
  `const KillSignalAction SIGNALACTION_DEFAULT_SIGUSR1 = KillSignalAction::TOGGLE;` and
  `SIGNALACTION_DEFAULT_SIGUSR2 = KillSignalAction::RELOAD;`
- `strings /usr/bin/waybar` contains
  `Invalid string representation for on-sigusr1. Falling back to default mode (toggle).`

`src/bar.cpp` only overrides the default when `config["on-sigusr1"].isString()`. Neither
`.config/waybar/sway_config.jsonc` nor `.config/waybar/config.jsonc` sets `on-sigusr1` or
`on-sigusr2`, so both defaults hold. That keybind is a visibility toggle.

**What `reload` does re-read: both.** `handleUserSignal` sets `reload = true` and calls
`Client::reset()`, which quits the GTK loop. `main()` runs
`do { reload = false; ret = client->main(argc, argv); } while (reload);`, so `Client::main` is
re-entered, and it does `config.load(config_opt)` (the JSON) and then `getStyle` plus `setupCss`
(the CSS). A reload re-reads the JSON config and the stylesheet.

**`reload_style_on_change`.** Documented in `waybar(5)`, `typeof: bool`, default `false`. When on,
`CssReloadHelper::monitorChanges` walks the stylesheet, recursively collects every `@import` target,
and puts a `Gio::FileMonitor` on each, calling `setupCss` on
`FILE_MONITOR_EVENT_CHANGES_DONE_HINT`. Two limits worth recording:

- The import regex is
  `@import\s+(?:url\()?(?:"|')([^"')]+)(?:"|')\)?;` and requires the trailing semicolon.
- `findPath` resolves via `std::filesystem::exists` then `Config::findConfigPath`. A `file://` URL
  will parse in GTK but will **not** resolve here, so it would be imported and never watched. A
  plain path is required for the watch to work.

**The portal path, and it is already firing.** This is the most decision-relevant finding for
waybar. `Client::getStyle` takes an appearance branch whenever the `-s`/`--style` option is empty:

```
if (style.empty()) {
  switch (appearance.value_or(portal->getAppearance())) {
    case LIGHT: search_files.emplace_back("style-light.css"); ...
    case DARK:  search_files.emplace_back("style-dark.css");  ...
  }
  search_files.emplace_back("style.css");
  css_file = Config::findConfigPath(search_files);
}
```

and `Client::main` wires it to a live subscription:

```
portal->signal_appearance_changed().connect([&](waybar::Appearance appearance) {
  auto css_file = getStyle(style_opt, appearance);
  setupCss(css_file);
});
```

`src/util/portal.cpp` names the source exactly: bus `org.freedesktop.portal.Desktop`, interface
`org.freedesktop.portal.Settings`, namespace `org.freedesktop.appearance`, key `color-scheme`, with
a `SettingChanged` subscription. `include/util/portal.hpp` maps `DARK = 1`, `LIGHT = 2`.

That is the same key `theme-switch`'s existing `apply_gtk` already writes via
`gsettings set org.gnome.desktop.interface color-scheme`. Three checks on this host:

- `.config/sway/config:27` starts waybar as `waybar -c ~/.config/waybar/sway_config.jsonc`, with no
  `-s`. So `style_opt` is empty and the appearance branch is live.
- The portal is up and agrees with gsettings:
  `gsettings get org.gnome.desktop.interface color-scheme` returns `'prefer-light'`, and
  `org.freedesktop.portal.Settings.ReadOne("org.freedesktop.appearance", "color-scheme")` returns
  `uint32 2`, which is `LIGHT`.
- **The running waybar has been reacting to every `theme-switch` toggle all along.**
  `journalctl --user -b` for PID 2599 shows repeated pairs:

  ```
  waybar[2599]: [info] Received new appearance 'dark'
  waybar[2599]: [info] Using CSS file /home/hpark/.config/waybar/style.css
  waybar[2599]: [info] Received new appearance 'light'
  waybar[2599]: [info] Using CSS file /home/hpark/.config/waybar/style.css
  ```

  It falls back to `style.css` every time only because no `style-light.css` or `style-dark.css`
  exists. The signal, the subscription, and the stylesheet re-load are all already working. This is
  observed behaviour on the running system, not an inference.

So waybar has three usable reload routes: SIGUSR2, a CSS file watch behind
`reload_style_on_change`, and a portal-driven restyle that costs nothing extra because
`apply_gtk` already triggers it.

### 2.3 Color roles: 8 of 10 already in the palette, 2 are not, plus 2 literals

`.config/waybar/style.css` is GTK 3 CSS and defines ten colors at the top. Every value is a light
palette value or nothing:

| `@define-color` | Value | Palette slot (light) |
| --- | --- | --- |
| `bg` | `#f9f7f6` | `bg` |
| `bg-hover` | `#e5d9cd` | **no match** |
| `fg` | `#3a7292` | `color4` |
| `fg-green` | `#3a784c` | `color2` |
| `fg-red` | `#a63f3f` | `color1` |
| `fg-orange` | `#c36022` | `color3` |
| `fg-purple` | `#614096` | `color5` |
| `fg-dark` | `#4d4851` | `color0` / `fg` / `selection_fg` |
| `fg-blue` | `#4c5aa9` | `color6` |
| `fg-lilac` | `#babbf1` | **no match** |

Plus two literal colors written directly into rules, neither in the palette:

- `#workspaces button.active { background-color: rgba(153, 209, 219, 0.1); }`
- `tooltip { border: 1px solid rgba(255, 255, 255, 0.1); }`

And `background: transparent` on `#waybar` and on `#workspaces button`.

**What the stylesheet actually asks of a color system.** Beyond flat foregrounds:

- **A hover surface.** One `:hover` rule covers fourteen module selectors and sets exactly one
  color, `@bg-hover`. This is a raised-surface tint, not any ANSI slot.
- **A border color.** The tooltip border is a translucent white, which is a light-mode-only
  assumption and will read wrong on a dark background.
- **A low-alpha selection wash** for the active workspace button.
- **Severity and state classes**, which the module man pages confirm are real:
  `waybar-temperature(5)` gives `#temperature.warning` and `#temperature.critical`;
  `waybar-battery(5)` gives `#battery.<status>`, `#battery.<state>` and the whole-bar
  `window#waybar.battery-<state>`; `waybar-network(5)` gives `.disconnected`, `.disabled`,
  `.linked`, `.ethernet`, `.wifi`; `waybar-bluetooth(5)` gives `.off`, `.on`, `.connected`,
  `.discoverable` and more. `waybar-states(5)` explains that `warning` and `critical` are
  user-declared thresholds, and `sway_config.jsonc` declares
  `"battery": { "states": { "warning": 30, "critical": 15 } }`.

The severity colors are the easy part: the stylesheet already resolves warning and critical to
`@fg-red` and ok-ish states to `@fg-green`, which are `color1` and `color2`. Severity maps onto ANSI
cleanly. **The genuinely palette-less roles are the hover surface, the border, and the translucent
wash.**

### 2.4 Long-lived: yes

PID 2599, started with the session, running for the whole 23h36m uptime.

## 3. swaync

### 3.1 Include: none in the config, `@import` in the CSS

**`config.json` has no include or import directive.** `swaync(5)` is 877 lines and lists no
`include`, `import`, or `source` option. `src/configModel/configModel.vala` has no include handling:
`reload_config` resolves a single path via `Functions.get_config_path` and parses it. There is no way
for `.config/swaync/config.json` to pull in a fragment. That is a plain no.

**The CSS can import.** swaync 0.12.6 links `libgtk-4.so.1` and `libadwaita-1.so.0` (confirmed with
`ldd /usr/bin/swaync`), so its stylesheet is GTK 4 CSS. Verified against the GTK 4 parser on this
host (Appendix A): `@import url("...");` plus `@define-color` in the imported file parses with no
errors, for both a relative path and a `file://` absolute URL. Same semicolon requirement, same
asymmetric failure modes as GTK 3.

The user stylesheet path is fixed: `Functions.get_style_path` returns
`$XDG_CONFIG_HOME/swaync/style.css` unless `-s` is passed. There is no light/dark variant selection
of the kind waybar has.

### 3.2 Live reload: yes, via D-Bus, but it must be pushed

`swaync-client(1)`:

> `-R, --reload-config` Reload the config file
>
> `-rs, --reload-css` Reload the css file. Location change requires restart

Introspecting the running daemon on this host confirms the interface is real and live. Bus
`org.erikreider.swaync.cc`, object `/org/erikreider/swaync/cc`, interface
`org.erikreider.swaync.cc`, methods including `ReloadCss(out b result)` and `ReloadConfig()`.

What `ReloadCss` re-reads, from `src/swayncDaemon/swayncDaemon.vala`:

```
public bool reload_css () throws Error {
    bool result = Functions.load_css (style_path);
    return result;
}
```

and `Functions.load_css` calls `user_css_provider.load_from_path (user_css)` after re-resolving the
path. So it re-reads the user stylesheet from disk and swaps the provider. It does not touch the
JSON config; `ReloadConfig` does that separately and also re-runs `control_center.add_widgets ()`.

**No file watch and no portal path.** `configModel.vala` contains no `FileMonitor`. swaync calls
`Adw.init ()` and nothing else appearance-related: there is no `StyleManager`, no `color-scheme`
subscription, and no `org.freedesktop.appearance` handling anywhere in `main.vala`,
`functions.vala`, or `swayncDaemon.vala`. Unlike waybar, swaync will not notice `apply_gtk`. It
needs an explicit `swaync-client --reload-css` push.

### 3.3 Color roles: 6 of 8 already in the palette, 2 are not, plus 3 literals

`.config/swaync/style.css` defines eight colors:

| `@define-color` | Value | Palette slot (light) |
| --- | --- | --- |
| `bg_base` | `#f9f7f6` | `bg` |
| `bg_muted` | `rgba(128, 128, 128, 1)` | **no match** |
| `text_primary` | `#4d4851` | `color0` / `fg` / `selection_fg` |
| `text_light` | `#f9f7f6` | `bg` |
| `accent` | `#e5d9cd` | **no match** |
| `accent_active` | `#4d4851` | `color0` / `fg` / `selection_fg` |
| `critical` | `#a63f3f` | `color1` |
| `link` | `#3a7292` | `color4` |

Plus three literal colors in rules, none in the palette, all in `.control-center`:

- `border-top` and `border-left`: `rgba(164, 162, 167, 0.19)`
- `border-right` and `border-bottom`: `rgba(128, 127, 132, 0.145)`
- `box-shadow`: `0px 2px 3px rgba(0, 0, 0, 0.45)`

**What the stylesheet actually asks for.** Four things the palette has no name for:

- **A muted surface.** `@bg_muted` backs buttons, the notification body, sliders, the volume widget,
  and the mpris overlay. It is a mid grey with no palette equivalent.
- **Text on that muted surface.** `@text_light` is only used on `@bg_muted` and `@accent_active`
  backgrounds. In light mode it happens to equal `bg`, which hides the fact that it is an *inverse*
  role: in dark mode it will not be `bg`.
- **A hover accent.** `@accent` on `button:hover`, `.notification-background:hover`, and
  `.notification-default-action:hover`.
- **A pressed accent.** `@accent_active` on `button:active`.

Plus two translucent border colors and one shadow.

Severity is handled with `.notification.low`, `.notification.normal`, and `.notification.critical`,
and it maps onto the palette without help: low and normal use `@text_primary`, critical uses
`@critical`, which is `color1`.

**One notable coincidence.** `@accent` in swaync and `@bg-hover` in waybar are both `#e5d9cd`, the
same value, invented independently in two stylesheets for the same purpose. That is one shared
hover-surface role wanted by two apps, not two separate needs. It is also a near-miss on
`selection_bg`, which is `#e4ded7` in light mode: close, but not equal.

**One pre-existing oddity, recorded not fixed.**
`.notification.critical .notification-content image { color: @critical; }` paints the icon in
`@critical` on a `@critical` background. Worth knowing before anyone derives that rule from a
palette and assumes the result should be legible.

### 3.4 Long-lived: yes

PID 2600, started with the session by `.config/sway/config:28`, running for the whole uptime.

## 4. zathura

### 4.1 Include: yes, `include <path>`, space separated, no tilde

`zathurarc(5)`:

> **include - Including another config file**
>
> This commands allows one to include other configuration files. If a relative path is given, the
> path will be resolved relative to the configuration file that is currently processed.
>
> ```
> include another-config
> ```

girara implements it (`girara/config.c`), and the exact path rules matter:

```
if (g_path_is_absolute(argv[1]) == TRUE) {
  newpath = g_strdup(argv[1]);
} else {
  char* basename = g_path_get_dirname(path);
  char* tmp      = g_build_filename(basename, argv[1], NULL);
  newpath        = girara_fix_path(tmp);
  ...
}
```

Consequences:

- **Absolute paths work**, taken verbatim.
- **Relative paths resolve against the directory of the config file being parsed**, which for
  `~/.config/zathura/zathurarc` means `../../.local/state/theme/...` reaches
  `~/.local/state/theme/...`. This is exactly the relative-include trick `.config/ghostty/config:7`
  already uses.
- **`~/` does not work.** `g_path_is_absolute("~/x")` is false, so it takes the relative branch and
  becomes `/home/hpark/.config/zathura/~/x`. `girara_fix_path` only expands a `~` in position zero
  (`if (path[0] == '~')`), and by then it is not. A tilde include will silently resolve to a
  nonexistent path and log `failed to load`.
- Syntax is `include path`, space separated. Not `include=path`.
- Self-inclusion is detected and refused; a failed include is a warning, not fatal.

### 4.2 Live reload: yes, over D-Bus, and it re-renders

`zathura(1)` documents a D-Bus interface. Introspecting the running instance on this host
(PID 72403) shows bus `org.pwmt.zathura.PID-72403`, object `/org/pwmt/zathura`, interface
`org.pwmt.zathura`, with these among the methods:

```
ExecuteCommand(in s input, out b return);
SourceConfig(out b return);
SourceConfigFromDirectory(in s directory, out b return);
```

**What `SourceConfig` re-reads.** `zathura/dbus-interface.c`:

```
static void handle_source_config(zathura_t* zathura, GVariant* parameters,
                                 GDBusMethodInvocation* invocation) {
  config_load_files(zathura);
  ...
}
```

and `config_load_files` (`zathura/config.c`) re-parses the `XDG_CONFIG_DIRS` copies, the
`SYSCONFDIR` copy, and then `zathura->config.config_dir/zathurarc`. Since parsing goes through
girara's `config_parse`, the `include` directive is re-followed on every source.

**And the re-parse actually repaints, on both halves of the UI.** This needed checking rather than
assuming:

- **Chrome.** girara registers every chrome color with the `cb_color` callback
  (`girara_setting_add(session, "default-bg", "#000000", STRING, FALSE, ..., cb_color, NULL)`).
  `cb_color` calls `girara_template_set_variable_value` on the GTK CSS template, and
  `girara/session.c` connects that template's `changed` signal to `css_template_changed`, which
  re-evaluates the template and calls `gtk_css_provider_load_from_data`. Live.
- **Page content.** zathura's own `cb_color_change` (`zathura/config.c`) handles `recolor-lightcolor`
  and `recolor-darkcolor` by calling `zathura_renderer_set_recolor_colors_str`, and the function
  ends with `render_all(zathura)`. Live.

**Two caveats.**

- The bus name embeds the PID (`static const char DBUS_NAME_TEMPLATE[] = "org.pwmt.zathura.PID-%d";`),
  so anything driving this has to enumerate `org.pwmt.zathura.PID-*` names rather than address one
  fixed destination. zathura's own code does exactly that, matching on the
  `org.pwmt.zathura.PID` prefix.
- `config_load_files` does not reset settings to their defaults first. It re-applies whatever the
  files say, over the current state. A key that disappears from a generated fragment keeps its old
  value until zathura restarts. Fine if the generator always writes every key.

`ExecuteCommand` is a second, finer-grained route: it runs any `:` command, so
`set default-bg "#100e11"` can be pushed per-setting without touching files at all.

### 4.3 Color roles: 19 of 21 already in the palette, and the 2 exceptions are hardcoded literals

`.config/zathura/zathurarc` sets 21 color values, and unlike the other five apps it is currently
hardcoded to the **dark** palette:

| Setting | Value | Palette slot (dark) |
| --- | --- | --- |
| `default-bg`, `statusbar-bg`, `inputbar-bg`, `completion-bg`, `completion-highlight-bg`, `notification-error-fg`, `notification-warning-fg`, `notification-fg`, `recolor-lightcolor` | `#100e11` | `color0` / `bg` |
| `default-fg`, `statusbar-fg`, `inputbar-fg`, `completion-fg`, `notification-bg`, `recolor-darkcolor` | `#e9e6e2` | `fg` / `selection_fg` |
| `notification-error-bg`, `notification-warning-bg` | `#d36969` | `color1` / `color9` |
| `completion-highlight-fg` | `#59c076` | `color2` / `color10` |
| `highlight-fg` | `#69acd3` | `color4` / `color12` |
| `highlight-color` | `rgba(255, 255, 0, 0.2)` | **no match, literal** |
| `highlight-active-color` | `rgba(255, 0, 0, 0.2)` | **no match, literal** |

The two exceptions are the search-hit and active-search-hit washes, left at zathura's own yellow and
red defaults rather than themed. They are translucent overlays, so they are the same category of
value as waybar's and swaync's literals: a wash, not a palette slot.

`zathurarc(5)` states the accepted formats: "zathura supports HTML color codes and CSS3-style
`rgb(r,g,b)` and `rgba(r,g,b,a)` values", with the caution that a `#` must be quoted or escaped. The
tracked config already quotes.

**Palette gap: none for the chrome.** Every non-literal color is already a palette value. Note one
behavioural point for whoever writes the generator: the tracked config pairs dark chrome with
`set recolor false`, so page content is not currently inverted. Flipping to light mode is not just a
matter of swapping chrome colors, `recolor` and the `recolor-lightcolor`/`recolor-darkcolor` pair
carry the page-content half, and both of those are already palette values.

### 4.4 Long-lived: yes

PID 72403, running 10h42m at time of survey, on a PDF. Documents stay open for hours. This is the
one app in the set where a live reload is worth real money and where the mechanism happens to be the
richest.

## 5. swaylock

### 5.1 Include: none, though a config file does exist

`swaylock(1)` documents a config file, which the repo does not currently use:

> `-C, --config <path>` The config file to use. By default, the following paths are checked:
> `$HOME/.swaylock/config`, `$XDG_CONFIG_HOME/swaylock/config`, and `SYSCONFDIR/swaylock/config`.
> All flags aside from this one are valid options in the configuration file using the format
> `long-option=value`.

There is no include directive, and the parser makes it clear why. `main.c`:

```
while ((nread = getline(&line, &line_size, config)) != -1) {
  ...
  if (!*line || line[0] == '#') { continue; }
  char *flag = malloc(nread + 3);
  sprintf(flag, "--%s", line);
  char *argv[] = {"swaylock", flag};
  result = parse_options(2, argv, state, line_mode, NULL);
  ...
}
```

Each non-comment line is textually prefixed with `--` and fed to the same `getopt_long` table the
command line uses. A line `include=...` would become `--include=...` and be rejected as an unknown
option. There is no include, and there is no room for one in that design.

Note the practical alternative this opens up: because config lines and CLI flags are the same
namespace, a generated fragment could equally be a config file at
`$XDG_CONFIG_HOME/swaylock/config` or a set of flags in the sway config. Today it is neither.
`.config/sway/config:7` sets `set $lockcmd swaylock -f -i $wallpaper`, used at lines 22 and 66
(`before-sleep`, the 300s `swayidle` timeout, and the `Control+Alt+l` keybind). Neither
`~/.config/swaylock/` nor `~/.swaylock/` exists on this host, and neither is in the repo.

### 5.2 Live reload: no

`swaylock(1)` SIGNALS lists exactly one signal:

> `SIGUSR1` Unlock the screen and exit.

`main.c` installs exactly one handler, `sigaction(SIGUSR1, &sa, NULL)`. There is nothing else. This
does not matter, see 5.4.

### 5.3 Color roles: 29 options, all state variants of five widgets

`swaylock(1)` defines 29 color options. They are not 29 independent roles; they are five widget
parts crossed with the indicator states:

- Widget parts: `inside`, `ring`, `line`, `text`, `separator`, plus `key-hl` and `bs-hl` for the
  keypress and backspace highlights, plus `layout-bg`, `layout-border`, `layout-text` for the
  keyboard layout box, plus `-c/--color` for the background.
- States, applied as suffixes to `inside`, `ring`, `line`, `text`: none (idle), `-clear`,
  `-caps-lock`, `-ver` (verifying), `-wrong`. Plus `caps-lock-key-hl-color` and
  `caps-lock-bs-hl-color`.

Format is `rrggbb[aa]`, per the man page, alpha optional.

**Palette gap: arguably none, but this is where semantics do the work.** The states are
ok / in-progress / error, which map onto `color2` / `color4` / `color1` without inventing anything.
The point to record for the roster ticket is that swaylock needs *more distinct simultaneous colors*
than any other app here, so it is where a flat 16-slot palette gets stretched thinnest even though
no single value is unrepresentable.

### 5.4 Long-lived: no

swaylock is spawned per lock and exits on unlock. It is not running now. Like fuzzel, it is
trivially correct the moment its config or its flags are generated, and its lack of a reload signal
costs nothing.

## 6. swaybg

### 6.1 Include: no, and there is no config file at all

`swaybg(1)` documents four options and nothing else: `-c/--color <[#]rrggbb>`, `-i/--image <path>`,
`-m/--mode <mode>`, `-o/--output <name>`. There is no CONFIGURATION section, no FILES section, and no
mention of any config path.

Confirmed in `main.c` at v1.2.2: no `fopen`, no `getline`, no `XDG_CONFIG` reference anywhere. All
state comes from `getopt_long`. swaybg is configured only by its argv.

### 6.2 Live reload: none in swaybg, but sway can respawn it

`main.c` at v1.2.2 contains no `signal(`, no `sigaction`, and does not include `signal.h`. swaybg
has no signal handling whatsoever and no IPC. Once started, its background is fixed.

**Sway owns a swaybg of its own, and that one is live.** `sway/config/output.c` has
`spawn_swaybg(void)`, which builds an argv from the `output ... bg ...` entries and calls
`_spawn_swaybg`, and that function begins with:

```
if (config->swaybg_client != NULL) {
  wl_client_destroy(config->swaybg_client);
}
```

so it tears down the previous instance before forking a new one. `spawn_swaybg` is called from
`sway/commands/output.c:117` (`if (background && !spawn_swaybg())`) and from `sway/config.c:536`.
Since `sway/commands/output.c` is the `output` command handler, `swaymsg output '*' bg <path> fill`
respawns swaybg live, using exactly the `swaymsg` mechanism `apply_sway` already uses.

`sway-output(5)` gives the syntax:

> `output <name> background|bg <file> <mode> [<fallback_color>]`
>
> `output <name> background|bg <color> solid_color`
>
> color should be specified as `#RRGGBB`. Alpha is not supported.

**Evidence on this host.** There are two swaybg processes, both children of sway (PID 2505):

- PID 2579, `/proc/2579/cmdline` is just `swaybg` with no arguments. This is sway's own instance,
  spawned with an empty option list because `.config/sway/config` declares no `output ... bg`.
- PID 2597, `swaybg -i /home/hpark/Sync/.pictures/wallpaper/frieren.jpg`. This is the one from
  `.config/sway/config:25`, `exec swaybg -i $wallpaper`.

So the current setup runs a redundant swaybg and leaves sway's own background mechanism unused. That
mechanism is the live one.

### 6.3 Color roles: exactly one

`-c/--color <[#]rrggbb>`, six hex digits, no alpha. Sway's `solid_color` form is the same. One
slot, any palette color, most obviously `bg`.

The larger point: swaybg is currently themed with a photograph
(`~/Sync/.pictures/wallpaper/frieren.jpg`), which is Theme Mode independent. Whether swaybg has
anything to theme at all is a roster question, not a capability question. Its capability is one
color or one image path, and nothing more.

**Palette gap: none.**

### 6.4 Long-lived: yes, but immutable

PID 2597 has run for the whole session. It is long-lived and it has no reload path of its own, which
is the worst combination in this set: the only ways to change it are to kill and restart it, or to
stop using it and let sway's `output bg` manage the background instead.

## Cross-cutting summary

### Include matrix

| App | Directive | Path rules | Missing file |
| --- | --- | --- | --- |
| fuzzel | `include=<path>` in the default or `[main]` section only | absolute or `~/` | error logged, still starts; fatal under `--check-config` |
| waybar (JSON) | `include` (string or array) | `wordexp`, so `~` and globs | warning only |
| waybar (CSS) | `@import url("...");` | relative to the importing file, or `file://` | hard parse error |
| swaync (JSON) | **none** | n/a | n/a |
| swaync (CSS) | `@import url("...");` | relative to the importing file, or `file://` | hard parse error |
| zathura | `include <path>`, space separated | absolute, or relative to the config file's directory. **not `~/`** | warning only |
| swaylock | **none** (config file exists, but every line is a `--flag`) | n/a | n/a |
| swaybg | **none** (no config file at all) | n/a | n/a |

### Reload matrix

| App | Mechanism | What it re-reads | Already wired? |
| --- | --- | --- | --- |
| fuzzel | none | n/a | not needed, one-shot |
| waybar | `SIGUSR2` (default action `reload`) | JSON config **and** CSS | no |
| waybar | `reload_style_on_change: true` | CSS plus every `@import` target, via file monitors | no, defaults to false |
| waybar | portal `org.freedesktop.appearance` / `color-scheme` | re-selects `style-dark.css` / `style-light.css` / `style.css` and reloads it | **yes, already firing on every `theme-switch` run** |
| swaync | `swaync-client -rs` = `ReloadCss()` | user CSS from disk | no |
| swaync | `swaync-client -R` = `ReloadConfig()` | JSON config, and rebuilds widgets | no |
| zathura | `org.pwmt.zathura.SourceConfig()` on `org.pwmt.zathura.PID-<pid>` | all zathurarc files plus their includes, repaints chrome and re-renders pages | no |
| zathura | `org.pwmt.zathura.ExecuteCommand(s)` | one `:` command, no file involved | no |
| swaylock | `SIGUSR1` unlocks and exits | nothing | not needed, one-shot |
| swaybg | none | nothing | `swaymsg output '*' bg ...` respawns sway's own swaybg instead |

### Lifetime

| App | Long-lived? | Evidence |
| --- | --- | --- |
| fuzzel | **no** | not running after 23h36m uptime despite a keybind; lock file design is single-instance |
| waybar | yes | PID 2599, whole session |
| swaync | yes | PID 2600, whole session |
| zathura | yes | PID 72403, 10h42m |
| swaylock | **no** | not running; spawned per lock, exits on unlock |
| swaybg | yes, but immutable | PID 2597, whole session, no reload path |

### The palette question, consolidated

Four of the six apps need **no new palette roles at all**:

| App | Colors it sets today | Already exact palette values | Gap |
| --- | --- | --- | --- |
| fuzzel | 7 | 7 | none |
| zathura | 21 | 19 | 2 hardcoded translucent search washes |
| swaylock | 0 set today, 29 available | n/a | none in principle; needs the most simultaneous distinct colors |
| swaybg | 1 available | n/a | none |

The pressure comes entirely from the two CSS-styled apps:

| App | `@define-color` count | Exact palette matches | Not in the palette |
| --- | --- | --- | --- |
| waybar | 10 | 8 | `bg-hover` `#e5d9cd`, `fg-lilac` `#babbf1` |
| swaync | 8 | 6 | `bg_muted` `rgba(128,128,128,1)`, `accent` `#e5d9cd` |

Plus five literal colors written inline, none in the palette: waybar's
`rgba(153, 209, 219, 0.1)` and `rgba(255, 255, 255, 0.1)`; swaync's `rgba(164, 162, 167, 0.19)`,
`rgba(128, 127, 132, 0.145)`, and `rgba(0, 0, 0, 0.45)`.

Deduplicating those into roles, the two stylesheets between them want:

1. **A hover / raised surface.** waybar's `bg-hover` and swaync's `accent` are the *same value*,
   `#e5d9cd`, arrived at independently. One role, two consumers. Near-miss on `selection_bg`
   (`#e4ded7`).
2. **A muted / sunken surface.** swaync's `bg_muted`, backing buttons, notification bodies, sliders,
   and the volume widget.
3. **Text on a non-`bg` surface.** swaync's `text_light`, which equals `bg` in light mode purely by
   coincidence and will not in dark mode. This is an inverse-foreground role.
4. **A border color.** Both stylesheets currently hardcode translucent greys or whites. waybar's is
   translucent *white*, which is a light-mode-only assumption.
5. **A shadow, and one or two low-alpha washes.** These may be derivable rather than stored.
6. **A pressed / active accent.** swaync's `accent_active`, which today is just `fg`, so this one may
   need no new value.

What does **not** need new roles, contrary to the ticket's framing: **severity colors**. Both
stylesheets already resolve warning and critical to red and green, which are `color1` and `color2`,
and waybar's state classes are declared thresholds in `sway_config.jsonc`, not colors. Severity maps
onto ANSI slots cleanly. The roles the palette genuinely lacks are **surfaces and borders**, not
severities.

One more fact for the roster ticket: **both stylesheets are hardcoded light-mode today.** Every
value in both files is either a light palette value or a light-mode assumption. Neither has a dark
variant anywhere.

## Open questions and limits of this survey

- **The waybar portal path was verified live for the signal and the restyle, but not end to end for a
  two-file setup.** The journal proves waybar receives the appearance change and re-runs `getStyle`
  plus `setupCss` on every `theme-switch` toggle. It has never had a `style-dark.css` or
  `style-light.css` to find, so the branch that selects between them has been exercised only in its
  fallback. Creating those two files is the untested step. The source path is unambiguous, but this
  is inference, not observation.
- **Nothing was tested against a second monitor or a multi-bar waybar config.** `waybar(5)` notes
  that "for a multi-bar config, the include directive affects only current bar configuration
  object", and `reload` is documented as reloading "all waybars of current waybar process". Both
  configs here are single-object, so this did not come up.
- **swaync's packaged system CSS was not read.** `Functions.load_css` always loads a packaged
  stylesheet first at the same priority before the user one, so what the user CSS actually has to
  override is not fully characterised here. This matters only if a palette-driven rewrite drops
  rules rather than replacing values.
- **No D-Bus method with a side effect was called.** `SourceConfig` and `ReloadCss` were read in
  source and introspected, not invoked, to avoid touching the running desktop. Their behaviour is
  established from source, not from observation.
- **The `#e5d9cd` versus `selection_bg` `#e4ded7` near-miss was not resolved.** Whether the hover
  role should snap to `selection_bg` or become a genuinely new slot is a decision, not a fact.
- **Whether swaybg should be themed at all was not decided.** Its capability is one color or one
  image. The current wallpaper is a photograph, and the survey does not judge whether that should
  change per Theme Mode.

## Appendix A: GTK CSS behaviour, executed not inferred

Run against the GTK 3 and GTK 4 parsers installed on this host (GTK 4.22.4), by loading synthetic
files through `Gtk.CssProvider.load_from_path` from python-gi and capturing the `parsing-error`
signal. The fragment under test was:

```css
@define-color gen_bg #123456;
@define-color gen_fg #abcdef;
```

| Case | GTK 3 (waybar) | GTK 4 (swaync) |
| --- | --- | --- |
| `@import url("relative.css");` then `@gen_bg` used | no errors | no errors |
| `@import url("file:///abs/path.css");` then `@gen_bg` used | no errors | no errors |
| `@import` placed after other rules | no errors | no errors |
| `shade(@gen_bg, 1.2)` across the import boundary | no errors | no errors |
| `@import url("...")` **without** trailing semicolon | **error: `expected semicolon`** | not tested |
| `@import` of a nonexistent file | **error: `Failed to import: ... No such file or directory`** | **error, same message** |
| reference to an undefined `@color` name | **no error, silently ignored** | **no error, silently ignored** |
| deliberately invalid CSS (control) | error raised | error signalled |

The control case matters: it proves the harness detects errors at all, so the "no errors" rows are
meaningful rather than an artifact of a signal that never fires. Note that GTK 3 raises a `GError`
while GTK 4 emits the signal and continues, which is why the control row is phrased differently for
each.

## Appendix B: fuzzel config semantics, executed not inferred

Run with `fuzzel --check-config --config=<path>` against synthetic files in a scratch directory.
`--check-config` "verify[s] configuration and then exit[s] with 0 if ok, otherwise exit[s] with 1"
per `fuzzel(1)`, and opens no window.

| Case | Result |
| --- | --- |
| `include=` in the default section, followed by `[colors]` | exit 0 |
| `include=` inside a `[colors]` section | exit 1: `[colors].include: ... not a valid option: include` |
| `[main]` header reopened after `[border]`, then `include=` | exit 0 |
| `include=~/...` pointing at a nonexistent file | exit 1: `[main].include: ~/.local/state/theme/does-not-exist.ini: failed to open` (note the tilde was expanded before the open was attempted) |
| `background="#f9f7f6ff"` and `selection-text="4d4851ff"`, that is with and without `#`, both quoted | exit 0, both forms accepted |

The tilde case is the useful one: the error is `failed to open`, not `not an absolute path`, which
proves `~/` expansion happened. The `not an absolute path` error exists and is reachable, it is what
a bare relative path produces.
