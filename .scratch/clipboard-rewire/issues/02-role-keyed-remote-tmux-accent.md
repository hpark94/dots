# 02: Role-keyed remote tmux accent

**What to build:** A Headless machine's tmux status bar is visually
distinguishable from the Desktop's at a glance, replacing the one useful thing
the now-deleted `.tmux.remote.conf` provided. The accent is decided fresh every
time the tmux color fragment is generated, including when a Headless machine's
own render step regenerates it, so it can never go stale across detaching and
reattaching through a different client, the way the deleted file's
once-evaluated branch could.

**Blocked by:** `theme-switch` Role gate + render-only entry point (ticket 05 in
the theme-switch-expansion ticket set), this ticket needs the Role-reading
capability that one adds to `theme-switch`.

**Status:** done

Landed on `main`. `theme-switch` gains a `tmux_accent_slot` helper that reads
the machine's own Role via the canonical `read_role` and resolves the accent
slot: `color4` (the existing Desktop accent) for every outcome except
`headless`, which swaps to `color1` (an existing slot, red, otherwise unused in
the tmux fragment). `tmux_option_pairs` threads that slot through
`window-status-style`, `window-status-current-style`'s background,
`display-panes-colour`, `status-left`, and `status-right`. The read is
fallback-safe by design (Headless is the only branch that switches; a missing,
empty, or unreadable Marker resolves to the Desktop accent) so the Role-agnostic
render half still produces a fragment on a Marker-less machine, per the spec's
Role-gate reconciliation note.

- [x] `theme-switch`'s tmux color generator reads the machine's own Role and,
      when the Role is Headless, swaps the existing accent color (the one
      palette slot, `color4`, used consistently across window-status,
      current-window background, display-panes, and the left/right status
      accents) to a different, already-existing palette slot. The Desktop's
      accent is unchanged. (Note: the original wording named
      `display-panes-active-colour` as an accent position, but that option is
      `color3`, not the accent, and is left untouched; the accent slot is
      `display-panes-colour`.)
- [x] No new Canonical Palette role is introduced, the swap reuses the existing
      `color1` slot.
- [x] Verified: a Desktop's tmux status bar keeps its normal `color4` accent; a
      Headless machine's tmux fragment (generated via the `--render` render-only
      entry point, against the real palette) shows the distinct `color1` accent
      in both light and dark Theme Mode. Confirmed live end to end:
      `--render dark` under a `headless` Marker emits `#d36969` in every accent
      position, under a `desktop` Marker emits `#69acd3`.
- [x] Verified by construction: the accent is resolved fresh on every
      `generate_tmux` (including the Headless push's render-only invocation)
      from the machine's own Role Marker, not from any cached per-session
      decision, so there is nothing that can go stale across a detach/reattach
      through a different client. (Not separately exercised against two live
      clients.)
- [x] `theme-switch.bats` gains coverage for the tmux generator confirming the
      accent resolves to the normal slot for a `desktop` Role Marker and the
      distinct slot for a `headless` one, for both palettes, plus the
      fallback-to-Desktop-accent path for a missing/empty/unreadable Marker.

**Further Notes:** See `.scratch/clipboard-rewire/spec.md`, Implementation
Decisions → "The remote status bar accent becomes Role-keyed, not file-gated."
This ticket and the theme-switch-expansion ticket set's Headless push both touch
`theme-switch`'s tmux generator, implement this one after the Role gate ticket
lands, using the same Role-reading code it introduces rather than adding a
second copy.
