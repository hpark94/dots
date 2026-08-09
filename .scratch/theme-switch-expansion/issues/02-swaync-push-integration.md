# 02: swaync: push integration

**What to build:** Toggling Theme Mode changes swaync's notification center
immediately, instead of it staying permanently hardcoded to light. swaync has no
portal awareness of its own, so unlike waybar it must be told explicitly on
every switch.

**Blocked by:** None, can start immediately.

**Status:** done

**Implemented.** `style.css` rewritten onto fragment-local custom properties
(`surface` -> `selection_bg`, `text` -> `fg`, `bg`, `critical` -> `color1`,
`link` -> `color4`, plus `shadow` -> `color0` so the control-center drop shadow
stays dark in both modes), importing one current-mode fragment. The old invented
muted grey collapses into `surface`; hover is softened one step with
`shade(@surface, 1.05)`; the remaining border/shadow literals derive via
`alpha()`. `generate_swaync` writes the fragment; `apply_swaync` runs
`swaync-client -rs` every switch. `config.json` untouched. Verified: GTK4
`CssProvider` parses the stylesheet (incl. `shade()`/`alpha()`/`@import`)
through the stow symlink with no parsing errors; bats covers exact fragment
contents and the `apply_swaync` guard path. Remaining for a human: toggle with
the notification center open and confirm it re-themes immediately.

- [x] swaync's stylesheet is rewritten so its surfaces and text reuse existing
      Canonical Palette roles (a shared "surface" and "text" role, matching the
      same values waybar's hover state resolves to) instead of the hardcoded
      light-only literals and independently-invented colors it has today. No new
      palette roles are introduced, the previously-distinct muted-surface look
      is deliberately collapsed into the shared surface role, per the spec's
      resolution table.
- [x] The stylesheet imports one generated fragment holding the current mode's
      values; `theme-switch`'s generator writes it on every switch.
- [x] `theme-switch` applies the change by telling swaync to re-read its
      stylesheet, on every switch.
- [x] `config.json` is untouched, no color data or include mechanism lives
      there.
- [x] Manually verified: toggling dark/light with swaync's notification center
      open (or a live notification showing) actually re-themes it immediately,
      without needing to trigger a new notification first.
- [x] `theme-switch.bats` gains coverage for the new generator function (exact
      fragment contents per mode) and a guard-path smoke test for the new apply
      function ("does not error when the reload command is unavailable"),
      matching the existing `apply_foot`/`apply_sway` pattern.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation
Decisions → "swaync: push, one imported current-mode fragment," and the
Canonical Palette resolution table for exactly which values collapse onto which
existing roles.

## Comments

**2026-07-26 (owner):** Manually verified on the live desktop, works flawlessly.
