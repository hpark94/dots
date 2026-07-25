# 02 — Role-keyed remote tmux accent

**What to build:** A Headless machine's tmux status bar is visually distinguishable from the
Desktop's at a glance, replacing the one useful thing the now-deleted `.tmux.remote.conf` provided.
The accent is decided fresh every time the tmux color fragment is generated — including when a
Headless machine's own render step regenerates it — so it can never go stale across detaching and
reattaching through a different client, the way the deleted file's once-evaluated branch could.

**Blocked by:** `theme-switch` Role gate + render-only entry point (ticket 05 in the
theme-switch-expansion ticket set) — this ticket needs the Role-reading capability that one adds to
`theme-switch`.

**Status:** ready-for-agent

- [ ] `theme-switch`'s tmux color generator reads the machine's own Role and, when the Role is
      Headless, swaps the existing accent color (currently one palette slot used consistently across
      the status bar's window-status, current-window, active-pane, and left/right status accents) to a
      different, already-existing palette slot. The Desktop's accent is unchanged.
- [ ] No new Canonical Palette role is introduced — the swap reuses an existing slot.
- [ ] Manually verified: a Desktop's tmux status bar keeps its normal accent; a Headless machine's tmux
      status bar (generated via the render-only entry point) shows the distinct accent, in both light
      and dark Theme Mode.
- [ ] Manually verified: detaching and reattaching a Headless machine's tmux session, including through
      a different client, never shows the wrong accent — there is no cached decision to go stale.
- [ ] `theme-switch.bats` gains coverage for the tmux generator confirming the accent resolves to the
      normal slot for a `desktop` Role Marker and the distinct slot for a `headless` one, for both
      palettes.

**Further Notes:** See `.scratch/clipboard-rewire/spec.md`, Implementation Decisions → "The remote
status bar accent becomes Role-keyed, not file-gated." This ticket and the theme-switch-expansion
ticket set's Headless push both touch `theme-switch`'s tmux generator — implement this one after the
Role gate ticket lands, using the same Role-reading code it introduces rather than adding a second copy.
