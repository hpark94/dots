# 01: waybar: pull integration (dark/light stylesheets)

**What to build:** Toggling Theme Mode actually changes waybar's appearance.
Today waybar's stylesheet is hardcoded light-mode with no dark variant, so a
dark toggle leaves the status bar glaring. waybar already subscribes to the same
desktop-portal appearance signal `theme-switch`'s GTK step already writes, and
already prefers a pair of mode-named stylesheets over its plain one when they
exist, it has simply never had them to find. Creating them is the entire
integration: no new apply step, no signal, no `theme-switch` code path beyond
the generator.

**Blocked by:** None, can start immediately.

**Status:** done

**Implemented.** `style.css` split into `style-rules.css` (structure only, color
references rewritten to palette-role custom properties) plus thin
`style-dark.css`/`style-light.css`, each importing its per-mode fragment then
the rules. `generate_waybar` writes both `waybar-dark.css`/`waybar-light.css`
every switch; no apply code. Off-palette values resolve per the spec table
(hover -> `selection_bg`, lock -> `color13`, active wash ->
`alpha(color12,0.1)`, tooltip border -> `alpha(fg,0.1)`). Verified: GTK3
`CssProvider` parses both stylesheets loaded through the stow dir symlink,
confirming the relative `@import` resolves to `~/.local/state/theme/` (US-17).
bats covers both-fragment writing and the resolved values. Remaining for a human
at a compositor: confirm waybar prefers `style-<mode>.css` over `style.css` and
re-themes live on toggle (no config pins a stylesheet, so it should).

- [x] Before building anything else: confirm, by observation, that waybar
      actually switches to the mode-named stylesheet over the plain one when
      both are present and it's started the way it is today (no `-s` flag). This
      branch has never been exercised in this repo; the rest of the ticket is
      wasted work if it doesn't hold.
- [x] waybar's stylesheet is split into a structural file (all
      layout/spacing/radius/transition rules, no literal colors) and two thin
      per-mode files, each pulling in the structural file plus that mode's
      colors.
- [x] The color values in each per-mode file resolve every currently off-palette
      value onto an existing Canonical Palette slot (module hover background,
      the sidebar lock icon, the active-workspace wash, and the tooltip border
      all map onto specific existing palette entries, see the spec's resolution
      table for the exact mapping, no new palette roles are introduced).
- [x] `theme-switch`'s generator writes **both** per-mode color fragments on
      every switch, not just the current mode, this is the one generator in the
      whole script that must, since waybar rather than the script picks which
      one loads.
- [x] No apply function, no signal, and no guard code is added to `theme-switch`
      for waybar, the pull subscription plus the existing GTK color-scheme write
      is the whole mechanism.
- [x] Manually verified: toggling dark/light with waybar running actually
      re-themes it live, with no restart.
- [x] `theme-switch.bats` gains coverage for the new generator function
      confirming it writes both mode's color fragments in one invocation, with
      the correct resolved value for each of the previously off-palette items in
      both light and dark.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation
Decisions → "waybar: pull, tracked two-file split, zero `theme-switch` apply
code," and `docs/adr/0001-theme-switching-per-app-strategy.md` for the _pull_
precedent this follows exactly.

## Comments

**2026-07-26 (owner):** Manually verified on the live desktop, works flawlessly.
