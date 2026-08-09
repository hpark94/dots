Status: done

# theme-switch expansion: waybar/swaync/zathura/fuzzel roster, and Headless Theme Mode propagation

## Problem Statement

Three of the four apps this spec adds to `theme-switch` are not merely untheme,
they are actively wrong, and have been for months. `waybar` and `swaync`'s
stylesheets are hardcoded light-mode with no dark variant anywhere, so toggling
to dark leaves them glaring. `zathura` is wrong in the opposite direction:
`zathurarc` hardcodes the dark palette directly, so it is permanently dark
regardless of Theme Mode. `fuzzel` isn't wired in at all, despite 7 of its 7
colors already being exact palette values. Underneath all four, a `Headless`
machine (anything reached over SSH) never receives the Desktop's Theme Mode at
all: its rendered fragments and running tmux server are whatever they were left
at, or absent entirely, and `.tmux.conf`'s
`source-file ~/.local/state/theme/tmux-colors.conf` has no `-q` guard, so a
Headless machine with the dotfiles deployed and no state file (confirmed live on
`uni-cluster`) prints a missing-file error on every tmux start today.

This spec is the write-up of decisions already made across three tickets on the
[Portable dotfiles map](../portable-dotfiles/map.md):
[Theme reload and include capability survey](../portable-dotfiles/issues/03-theme-capability-survey.md),
[theme-switch app roster and palette roles](../portable-dotfiles/issues/07-theme-switch-app-roster.md),
and
[How Theme Mode reaches a Headless machine](../portable-dotfiles/issues/08-theme-mode-propagation.md).
It also folds in
[Who owns `~/.ssh/config`](../portable-dotfiles/issues/12-ssh-config-ownership.md),
see Further Notes for why, since that ticket was originally bucketed with a
different, not-yet-written spec.

The original `.scratch/theme-switch/spec.md` is left intact as the record of
what shipped; its Out of Scope line excluding "waybar, rofi/wofi, mako/dunst
(swaync itself), lock screen, wallpaper" and its exclusion of new palette roles
are both explicitly reopened by this spec (see Implementation Decisions for
which is overturned and which is upheld).

## Solution

`waybar` joins as a **pull** app: it already subscribes to the XDG desktop
portal's `org.freedesktop.appearance` (which `apply_gtk` already writes on every
switch) and already prefers `style-dark.css`/`style-light.css` over `style.css`,
it has simply never had them to find. Creating two tracked stylesheets, each
importing a per-mode Generated Config fragment, is the entire integration: no
new `theme-switch` code, no signal, no apply step. `swaync` and `zathura` join
as ordinary **push** apps (`swaync-client -rs`; D-Bus `SourceConfig()` per
running instance). `fuzzel` needs no reload mechanism at all, it is spawned
fresh per invocation, so its `include` is always read current. The Canonical
Palette does **not** grow: every off-palette value the survey found (four in
waybar, two in swaync) resolves onto an existing slot once traced to the rule
that actually uses it.

For Headless propagation: the Desktop pushes the persisted state file over SSH
and then invokes the same machine's own rendering half (`generate_*`/`apply_*`,
already Role-agnostic Capability Probes), rather than sending an environment
variable, one of the four target hosts (`uni-cluster`) structurally cannot
receive one, and a push needs nothing but a login. The mode is a machine fact,
not a per-connection one, so it is written to the remote's own state file and
survives disconnection, visible to a detached tmux server or a later cron job.
The push fires on two occasions: at toggle time, to every host with a
currently-live SSH `ControlMaster` socket, and at connect time, to catch a host
that was offline during a prior toggle. This requires `~/.ssh/config` to carry
`ControlMaster`/`ControlPersist`/`ControlPath`, which it does not today; the
generic, host-name-free part of that is added as a tracked, stowed fragment,
wired in by one manually-added `Include` line, never scripted, since it touches
a file this repo has never tracked before. A cold Headless machine (no state
file yet) renders light, silently, matching what nvim already does;
`.tmux.conf`'s missing `-q` guard is fixed as part of closing this gap.

## User Stories

1. As the dotfiles owner, I want waybar to switch to a dark stylesheet when I
   toggle dark mode, so that my status bar isn't glaring white text-on-white in
   an otherwise dark desktop.
2. As the dotfiles owner, I want waybar's dark/light switch to happen with no
   perceptible delay or extra step, so that it feels like part of the same
   toggle as everything else.
3. As the dotfiles owner, I want waybar's hover backgrounds, active-workspace
   wash, and tooltip border to use my existing palette rather than colors
   invented separately for waybar, so that the bar looks visually consistent
   with the rest of my themed tools.
4. As the dotfiles owner, I want the tooltip border's hardcoded translucent
   white replaced with a palette-derived value, so that it's actually visible
   against a light-mode tooltip instead of near-invisible.
5. As the dotfiles owner, I want swaync's notification center to switch to a
   dark stylesheet when I toggle dark mode, so that notifications don't stay
   glaring white at 2am.
6. As the dotfiles owner, I want swaync to re-theme immediately when I toggle,
   without needing to trigger a notification first, so that the switch feels
   instant like my other themed tools.
7. As the dotfiles owner, I want swaync's surfaces (hover, muted backgrounds,
   body text) to reuse existing palette roles rather than inventing new ones, so
   that the palette stays small and every app agrees on what "surface" and
   "text" mean.
8. As the dotfiles owner, I want zathura's chrome (background, statusbar,
   inputbar, completion, notifications, highlights) to follow Theme Mode instead
   of being permanently dark, so that reading a PDF in light mode doesn't force
   a dark chrome around a light page.
9. As the dotfiles owner, I want zathura's already-open windows to re-theme
   immediately on toggle, so that I don't have to close and reopen a document to
   see the new mode.
10. As the dotfiles owner, I want dark mode to darken PDF pages themselves
    (`recolor`) while light mode leaves them in their true colors, so that
    reading in the dark doesn't mean staring at a blinding white page.
11. As the dotfiles owner, I want my manual `i` (recolor toggle) keybind in
    zathura to keep working exactly as it does today, so that I can still
    override recolor for a specific document.
12. As the dotfiles owner, I want that manual recolor override to hold until my
    next theme switch (not persist forever, not reset on its own), so that its
    behavior is predictable.
13. As the dotfiles owner, I want fuzzel to launch with palette-matched colors
    that update on the next switch, so that my launcher matches the rest of my
    desktop without me maintaining a second color source.
14. As the dotfiles owner, I want fuzzel to fail loudly onto its own built-in
    defaults if its generated color fragment is ever missing, rather than
    silently serving stale colors from a leftover tracked block, so that a
    missing fragment is obvious rather than a quiet visual regression.
15. As the dotfiles owner, I want the Canonical Palette to stay at its current
    20 values rather than grow new roles for waybar/swaync, so that every app
    keeps drawing from the same small, well understood set of colors.
16. As the dotfiles owner, I want swaylock and swaybg to stay exactly as they
    are today, so that this expansion doesn't touch a lock screen or wallpaper
    that were never broken to begin with.
17. As the dotfiles owner, I want the relative `@import`/`include` paths in
    waybar's and zathura's tracked configs to keep resolving correctly through
    stow's symlinks, so that this works identically on a freshly-stowed machine
    as it does on my current one.
18. As a headless SSH user, I want a machine I reach only over SSH to render the
    same Theme Mode as my Desktop, so that tmux and any themed tooling there
    don't look stuck in whatever mode they happened to start in.
19. As the dotfiles owner, I want toggling the theme on my Desktop to
    immediately update tmux on any Headless machine I'm currently connected to,
    so that a long-running remote tmux session doesn't go stale the moment I
    flip modes locally.
20. As the dotfiles owner, I want a Headless machine that was offline during a
    toggle to catch up the moment I reconnect to it, so that I never have to
    remember to manually re-sync its theme.
21. As the dotfiles owner, I want the pushed Theme Mode to persist as a fact
    about the Headless machine itself, so that a detached tmux server or a cron
    job on that machine sees the current mode without my having to reconnect
    first.
22. As the dotfiles owner, I want the push to target only hosts I'm actually
    connected to right now (a live `ControlMaster` socket), so that toggling my
    theme never hangs waiting on an unreachable or sleeping machine.
23. As the dotfiles owner, I want a Headless machine with no Theme Mode yet
    (never pushed to, or reached by something other than my Desktop) to render
    light by default, so that its behavior matches what nvim already does in the
    same situation, rather than being undefined.
24. As the dotfiles owner, I want `.tmux.conf`'s theme include to stop erroring
    on a machine with no state file yet, so that a freshly-deployed Headless
    machine doesn't print a spurious error on every tmux start.
25. As the dotfiles owner, I want the SSH configuration needed for the push
    (`ControlMaster`/ `ControlPersist`/`ControlPath`) to be tracked and shared
    across machines without exposing my actual hostnames, usernames, or internal
    IPs in a public repo, so that I can publish this repo without leaking my
    private network layout.
26. As the dotfiles owner, I want wiring that generic SSH block into my real
    `~/.ssh/config` to be a one-time manual step I control, rather than
    something a script edits on my behalf, so that a file I've never let this
    repo touch before doesn't start being silently rewritten.
27. As a public user of this repo, I want the theme-switch expansion to work
    without needing to know anything about the original owner's specific SSH
    hosts, so that the SSH-push feature is usable on my own machines by forking
    and adding my own generic block.
28. As the dotfiles owner, I want the push mechanism to time out rather than
    hang if a host's control socket check or the push itself stalls, so that a
    flaky or newly-unreachable host never blocks my local theme toggle.
29. As the dotfiles owner, I want this expansion to leave ADR-0001's
    per-app-strategy thesis intact (a fitted strategy per app, not a uniform
    mechanism), so that future app additions keep following the same reasoning
    rather than reverting to a one-size-fits-all pipeline.
30. As the dotfiles owner, I want `CONTEXT.md`'s existing Live-switchable/pull
    vocabulary (already amended for waybar) to be the vocabulary this spec's
    implementation actually matches, so that the domain glossary and the shipped
    code never drift apart.

## Implementation Decisions

### The Canonical Palette does not grow

Stays at 20 values (16 ANSI + `bg`/`fg`/`selection_bg`/`selection_fg`). Every
off-palette value found by the survey resolves onto an existing slot:

**waybar** (4 values, 0 new roles):

| Value                   | Used by                    | Resolves to                |
| ----------------------- | -------------------------- | -------------------------- |
| `bg-hover #e5d9cd`      | module `:hover` background | `selection_bg` (`#e4ded7`) |
| `fg-lilac #babbf1`      | `#custom-lock` icon only   | `color13`                  |
| `rgba(153,209,219,0.1)` | active-workspace wash      | `alpha(@color12, 0.1)`     |
| `rgba(255,255,255,0.1)` | tooltip border             | `alpha(@fg, 0.1)`          |

**swaync** (2 values, 0 new roles): `accent #e5d9cd` snaps to `selection_bg`
like waybar's `bg-hover`. `bg_muted rgba(128,128,128,1)` (a mid-grey surface
used across notification bodies, buttons, sliders, and the volume widget)
collapses into `selection_bg` for surface and `fg` for text, matching waybar's
idiom rather than preserving a distinct muted-surface look. The three remaining
off-palette literals (shadows/washes) are derived with `alpha()`. This is a
deliberate, accepted cost: hover stops reading as visually distinct from a muted
surface, softened by `shade(@selection_bg, ~1.05)` on the hover case
specifically. `alpha()` is confirmed to parse correctly across the `@import`
boundary in both GTK 3 (waybar) and GTK 4 (swaync) on this host.

### waybar: pull, tracked two-file split, zero `theme-switch` apply code

- The current single `style.css` is split into a tracked `style-rules.css` (all
  structural rules: layout, spacing, radii, transitions, with every color
  reference rewritten to the shared custom property names below, no literal
  colors) plus two tracked, minimal `style-dark.css`/`style-light.css` files,
  each `@import`-ing `style-rules.css` and a Generated Config fragment holding
  that mode's `@define-color` values for `bg`, `fg`, `bg-hover` → mapped to
  `selection_bg`, and the palette slots named above.
- The switch script's generator writes **both** per-mode fragments on every
  switch (not just the current mode), because waybar, not the script, decides
  which stylesheet to load, per the _pull_ shape in ADR-0001 and `CONTEXT.md`'s
  **Generated Config** entry.
- No apply function, no signal, no `theme-switch` code path touches waybar at
  all beyond writing the two fragments. waybar already re-runs `getStyle` on
  every `org.freedesktop.appearance` change (which `apply_gtk` already performs)
  and already prefers `style-dark.css`/`style-light.css` over `style.css` when
  started without `-s` (confirmed: `sway_config.jsonc` is launched this way
  today).
- Verify first, before anything else in this ticket: waybar's two-file branch
  has never actually been exercised (only the `style.css` fallback path has ever
  run), so confirm the split stylesheet loads before treating the rest of the
  waybar work as done.

### swaync: push, one imported current-mode fragment

- `style.css` is rewritten to reference named custom properties (surface →
  `selection_bg`, text → `fg`, plus the existing red/green severity mappings
  already in place) sourced from one `@import`ed Generated Config fragment
  holding the current mode's values, replacing today's hardcoded light-only
  literals.
- Apply step: `swaync-client -rs`, which re-reads the user stylesheet. Unlike
  waybar, swaync has no portal awareness, so it must be pushed explicitly on
  every switch.
- `config.json` is untouched, it has no include mechanism and carries no color
  data today.

### zathura: push, generated fragment plus D-Bus `SourceConfig`

- `zathurarc`'s hardcoded color assignments (`default-bg`, `default-fg`,
  `statusbar-*`, `inputbar-*`, `notification-*`, `completion-*`, `highlight-*`,
  `recolor-lightcolor`, `recolor-darkcolor`, and `set recolor`) move out of the
  tracked file entirely and into a Generated Config fragment, included via
  `include ../../.local/state/theme/<fragment>` positioned after the tracked
  non-color settings (keybinds, window/scroll/font options stay tracked and
  unchanged). Note `~/`-relative includes are **not** supported by zathura's
  `include` directive, the relative path is required.
- Dark mode's fragment sets `recolor true` with
  `recolor-lightcolor`/`recolor-darkcolor` derived from the palette; light
  mode's fragment sets `recolor false`, leaving documents in true color.
- Apply step: for each running zathura process, invoke `SourceConfig()` on its
  `org.pwmt.zathura.PID-<pid>` D-Bus name (via `gdbus call`), which re-parses
  `zathurarc` and its include, repaints chrome, and re-renders pages.
  `SourceConfig` re-asserts whatever the fragment says about `recolor` on every
  switch, so a switch always resets any manual `i`-keybind override, this is a
  property of the mechanism, not a choice, since zathura exposes no way to read
  back the current `recolor` value to preserve it.
- The `i` keybind (`map i recolor`) is untouched; it keeps working exactly as
  today and holds until the next theme switch re-asserts the generated value.

### fuzzel: next-launch, no reload needed

- The tracked `[colors]` block is deleted outright (not shadowed) so a missing
  generated fragment fails loudly onto fuzzel's own built-in defaults instead of
  silently serving stale colors.
- An `include=~/.local/state/theme/<fragment>` line is added to the
  default/`[main]` section, placed after any other default-section keys, since
  `include` applies in place and last-assignment-wins. Fuzzel's `include` does
  accept a leading `~/`, unlike zathura's.
- No apply step and no signal: fuzzel is spawned fresh per invocation and exits,
  so its config (and thus its `include`) is always read current. This was
  confirmed by observation (fuzzel was not resident in memory after 23 hours of
  uptime despite its keybind existing).

### Role gate added to `theme-switch` itself

`theme-switch` gains the canonical Role Marker reader (same contract as pinned
for `note`: path `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role`,
whitespace-stripped, exact-word match, one hard error on anything else,
copy-pasted verbatim per the script-conventions decision, not shared via a
library). A normal invocation (`theme-switch dark|light|toggle`) now refuses
with that hard error when the Role is `headless`, the **deciding** half
(`resolve_mode`, `write_state`). The **rendering** half (`generate_*`,
`apply_*`) is unchanged and remains Role-agnostic, since every `apply_*` is
already a Capability Probe.

**Reconciliation with clipboard-rewire (`generate_tmux`'s Role-keyed accent).**
The [clipboard-rewire spec](../clipboard-rewire/spec.md) rebuilds the remote
status-bar accent _inside_ `generate_tmux`, making that one `generate_*`
function read the Role Marker to pick a palette slot. That is a deliberate,
narrow exception to "the rendering half remains Role-agnostic," and it must not
regress the gate-free render path: `generate_tmux`'s accent read has to
**tolerate a missing or unreadable Marker by falling back to the Desktop
(normal) accent**, not propagate the canonical `read_role`'s hard "no default
Role" error. Otherwise `--render` on a Marker-less machine, the cold Headless /
retrofit case this push exists for, and the explicit no-Marker case in the
render test below, would fail inside the render pipeline. This matches
`CONTEXT.md`'s Capability-Probe principle that the rendering path "stays correct
when the Role Marker is missing or wrong." When clipboard-rewire lands (it
sequences after this spec's Role gate), implement the accent read that way; the
render path stays genuinely gate-free.

### The Headless push

- **New entry point**: `theme-switch --render <mode>`, which skips the Role gate
  entirely and runs only `write_state` + every `generate_*` + every `apply_*`
  for the given mode. This is what the Desktop invokes over SSH against a
  Headless machine, the remote is rendering a mode it was told, not deciding
  one, so it must not hit the same-machine refusal a direct `theme-switch dark`
  would.
- **Channel**: no environment variable (one of four target hosts drops
  `SetEnv`/`SendEnv` entirely, and probing showed this splits cleanly by distro
  family with no reliable fix). The Desktop runs
  `ssh <host> '~/.local/scripts/theme-switch --render <mode>'`, a push over an
  ordinary SSH login, needing no server-side configuration on the target at all.
- **Granularity**: the pushed mode is a machine fact, written into the remote's
  own persisted state file, not a value scoped to the SSH session. It outlives
  the connection, so a detached tmux server or a later cron job on that machine
  sees it without being told again.
- **When it fires**:
  - On toggle, iterate the concrete (non-wildcard) `Host` entries in
    `~/.ssh/config`; for each, test `ssh -O check <host>` against a bounded
    timeout, and push only to hosts that report a live `ControlMaster` socket.
    This is the set where staleness is actually visible, never hangs on an
    unreachable host, and never wakes a sleeping machine.
  - At connect time, via a hook in `~/.ssh/config`'s generic block (see below)
    so a host that was offline during a prior toggle catches up the moment it's
    reached. **The exact hook (`LocalCommand` is the leading candidate, since it
    fires once per master) and the push's timeout bounds are implementation-time
    verification, not fixed here**, confirm against this SSH client's actual
    observed behavior rather than assuming the manual page's description holds,
    and ensure neither the toggle-time push nor the connect-time push can hang
    the caller on a stale or newly-unreachable host.
  - A connect-time push landing just after the remote shell has already sourced
    its (missing) state file is accepted as harmless: the one behavior that
    visibly matters, tmux, is hit directly by the push's own render step against
    the running tmux server, independent of shell startup timing.
- **The cold case**: a Headless machine with no state file (never pushed to, or
  reached by anything other than the Desktop) renders **light**, silently,
  matching nvim's existing fallback for a missing/unreadable/unrecognized state
  file. Writing a default state file at install time (further narrowing this
  window) is `bootstrap.sh`'s responsibility, out of scope here (see Out of
  Scope).
- **`.tmux.conf` fix**: its `source-file ~/.local/state/theme/tmux-colors.conf`
  line gains the `-q` flag it is missing today, matching the existing
  `[ -f ]`-guarded shell-env and nvim consumers. This is a live, present-day bug
  (confirmed erroring on every tmux start on a real Headless host with the
  dotfiles deployed and no state file), not a hypothetical this expansion
  introduces.

### `~/.ssh/config` gains a tracked, generic block (folds in ticket 12)

- A new tracked file, `.config/ssh/config.shared`, stowed normally, holds only a
  fully generic `Host *` block: `ControlMaster`, `ControlPersist`,
  `ControlPath`, and whatever connect-time push hook the implementation-time
  verification above settles on. No concrete hostname, IP, or username ever goes
  in this file.
- It is wired in by one **manually-added** `Include ~/.config/ssh/config.shared`
  line at the **bottom** of the real `~/.ssh/config`, never scripted, and never
  added by `bootstrap.sh` or any other install step. `man ssh_config` confirms
  first-obtained-value-wins (the opposite of `.gitconfig`'s include behavior),
  so a generic default must sit after every host-specific declaration, not
  before, which is exactly what "at the bottom" gives.
- The five real `Host` entries (`uni-cluster`, `work-pvm`, `work-tavm`,
  `ubuntu-server`, `vm-app`) never get tracked, full stop, including in
  genericized form, this is a public repo. Only the wildcard block is tracked.
- This Include is Desktop-only: the `ControlMaster` requirement lives entirely
  on the Desktop side of the push (it initiates the SSH connections), and it is
  never added to a machine like `uni-cluster` that already carries
  institution-managed SSH configuration nothing here should risk touching.

## Testing Decisions

- Extend the existing `.local/scripts/tests/theme-switch.bats` rather than
  create a new test file: this is the same script, same
  sourcing-plus-fake-`$XDG_*`-dirs pattern already established.
- `generate_waybar` gets bats coverage confirming it writes **both**
  `style-dark`/`style-light` Generated Config fragments on a single invocation
  (unlike every other `generate_*`, which writes only the current mode), and
  that each fragment's `@define-color` values match the resolution table above
  for both light and dark palettes.
- `generate_swaync`, `generate_zathura`, and `generate_fuzzel` each get coverage
  matching the existing `generate_foot`/`generate_tmux` pattern: call with a
  scratch output directory and each mode, assert on exact written file contents.
- `apply_swaync` and `apply_zathura` get the same guard-path smoke test as
  `apply_foot`/`apply_sway`/ `apply_gtk` ("does not error when
  `swaync-client`/`gdbus` is unavailable"), no attempt to verify the real IPC
  effect in bats, since that requires the actual app running.
- The Role gate addition to `theme-switch` gets `read_role` coverage over the
  present/absent/ malformed/whitespace-padded Marker cases, landing in
  `theme-switch.bats`.
- `theme-switch --render <mode>` gets a bats test confirming it writes state and
  runs the render pipeline **without** requiring `read_role` to succeed (e.g.
  with no Role Marker file present at all), proving the render path is genuinely
  gate-free. Once clipboard-rewire's Role-keyed `generate_tmux` accent lands,
  this test must still pass: with no Marker present, `generate_tmux` falls back
  to the Desktop accent (see the Role-gate reconciliation note above) rather
  than erroring, so `--render` stays gate-free.
- The SSH push itself (host enumeration, `ssh -O check`, the actual remote
  invocation, and whichever connect-time hook is chosen) gets no bats coverage,
  it depends on live SSH state and a reachable remote host, which is exactly the
  kind of external dependency `apply_*`'s existing guard-path-only precedent
  already excludes from automation. Verify it manually instead, against
  `ubuntu-server` only (this repo's established default target for exercising
  scripts over SSH, not the full host list): confirm a toggle updates that
  host's tmux live while a `ControlMaster` socket to it is open, confirm a cold
  connection (no prior push) renders light, and confirm neither push path hangs
  when the host is deliberately made unreachable mid-check.
- The real per-app visual effect (waybar/swaync/zathura/fuzzel actually
  re-theming) is verified manually, running `theme-switch dark`/`light` for real
  and observing each app, matching how the original theme-switch spec verified
  GTK app behavior, not automated in bats.

## Out of Scope

- **swaylock and swaybg.** swaylock sets zero colors today (no clash to repair,
  and no include mechanism, theming it would force a direct write into a tracked
  file, the shape ADR-0001 avoids everywhere else). swaybg's capability is one
  color or one image, and the current wallpaper is a photograph; whether it gets
  a per-mode wallpaper is a taste decision with no palette content, not a
  theming gap.
- **Any new Canonical Palette role.** Explicitly re-examined by this spec's
  source ticket and upheld, not overturned, see Implementation Decisions.
- **A default theme state file written at install/bootstrap time.** That narrows
  the Headless cold-case window further but is `bootstrap.sh`'s responsibility,
  covered by the separate roles/bootstrap/deployment spec (since written and
  done).
- **Automating the `~/.ssh/config` Include line.** Always a manual, one-time
  step per Implementation Decisions, no script, including `bootstrap.sh`, ever
  writes it.
- **Tracking the real `Host` entries in `~/.ssh/config`**, genericized or
  otherwise. Only the wildcard `ControlMaster`/`ControlPersist`/`ControlPath`
  block is tracked.
- **The clipboard tunnel and its `RemoteForward` entries.** A separate,
  not-yet-written spec
  ([What signal picks the clipboard backend](../portable-dotfiles/issues/09-clipboard-backend-signal.md))
  deletes those; this spec's SSH changes are purely additive to `~/.ssh/config`
  and don't touch them.
- **Pushing Theme Mode to every host in `~/.ssh/config` unconditionally**, or
  maintaining a second, separate opt-in host list. Both considered and rejected
  per Implementation Decisions.
- **An OSC 11 terminal-background query, or a pull over the (possibly
  soon-deleted) clipboard tunnel**, as alternate channels for the Headless push.
  Both considered and rejected in favor of the SSH push.
- **Auto-following the desktop/OS light-dark preference, or a scheduler.**
  Switching remains an explicit user action; waybar's portal subscription is a
  delivery mechanism for our own `apply_gtk` write, not a source of automatic
  switching.

## Further Notes

- **Why
  [Who owns `~/.ssh/config`](../portable-dotfiles/issues/12-ssh-config-ownership.md)
  is folded into this spec.** It was originally grouped with a separate
  "roles/bootstrap/deployment" spec at planning time, purely by topical
  proximity to other infra tickets. On closer reading, its tracked artifact (the
  generic `Host *` block) has exactly one consumer in the entire map: the
  Headless push this spec implements. Splitting it into a different spec would
  create a hard cross-spec dependency for no benefit, so it ships here instead.
  If the roles/bootstrap/deployment spec is written later, it should reference
  this one for SSH config rather than re-deciding it.
- `docs/adr/0001-theme-switching-per-app-strategy.md` already documents the
  _pull_ shape (added when ticket 07 was resolved), read it before implementing
  waybar's integration, since it's the precedent this spec's waybar section
  follows exactly.
- `CONTEXT.md`'s **Live-switchable app**, **Generated Config**, **Role**, **Role
  Marker**, and **Capability Probe** entries are already amended for this work
  (waybar's pull route, the per-mode Generated Config case), no further
  vocabulary changes are expected, only implementation.
- Per this repo's own testing convention, when a manual verification step needs
  a live SSH target, use `ubuntu-server` only, not the full host list.
- The swaync system-packaged CSS (loaded at the same priority, before the user
  stylesheet) was never read during research, if the rewrite drops rules rather
  than replacing values, check what the packaged CSS actually supplies by
  default before assuming a dropped rule has no effect.
- `zathura`'s `SourceConfig` re-applying `set recolor` on every call is
  inference from source reading, not direct observation (the live D-Bus method
  was confirmed present and introspectable, but not invoked, to avoid disrupting
  an open document during research). Confirm this directly during
  implementation.
