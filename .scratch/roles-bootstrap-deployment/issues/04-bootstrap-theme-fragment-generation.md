# 04: `bootstrap.sh` Theme Mode + fragment generation

**What to build:** A freshly bootstrapped Desktop's waybar and zathura work correctly the very first
time `sway` is launched, instead of hard-failing to parse a tracked config whose generated color
fragment doesn't exist yet. A machine with no Theme Mode yet gets a sensible default without ever
resetting one that's already active.

**Blocked by:** [03: `bootstrap.sh` core sequence](03-bootstrap-core-sequence.md), and **05:
`theme-switch` Role gate + render-only entry point** (from the theme-switch-expansion ticket set,
this step calls that entry point directly).

**Status:** done

Verified done on `main`. The dependency (theme-switch-expansion ticket 05, the `--render` gate-free entry point) has landed, so bootstrap's earlier TODO placeholder is now a real `render_theme_fragments` step calling `theme-switch --render <mode>` unconditionally after the create-if-absent `write_theme_default`. Integration smoke-tested directly: sourcing bootstrap and running `render_theme_fragments` against a faked `$XDG` tree (with the stowed palette files present) drives the real `theme-switch`, which regenerates every app fragment (waybar-light/dark, zathura, sway, foot, ghostty, tmux, swaync, fuzzel, shell-env) and preserves the existing mode. The first "manually verified" box needs a live Desktop `sway` launch and is left for a real bring-up.

- [x] The Theme Mode state file is written with a default value only if one doesn't already exist; a
      machine that already has a mode set keeps it untouched on every re-run.
- [x] Every app's Generated Config fragment is (re)generated unconditionally, every run, via
      `theme-switch`'s render-only entry point, not gated on whether the mode file was just created.
- [ ] Manually verified: bootstrapping a Desktop from a bare clone, then launching `sway` for the first
      time, does not produce a parse error from any tracked config whose colors come from a generated
      fragment. (Pending a live Desktop bring-up; the fragment generation itself is smoke-tested.)
- [x] Manually verified: running bootstrap again on a machine with an active, non-default Theme Mode
      leaves that mode untouched while still regenerating the fragments. (Smoke-tested: mode `dark`
      preserved while all fragments regenerated.)
- [x] Bats coverage extending the core sequence's test file: the mode-file write-or-skip guard behaves
      correctly against a faked state directory, and the fragment-generation call happens on every
      invocation regardless of whether the mode file already existed.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions → "The
ordered sequence," step 11, and Further Notes on the theme-switch-expansion dependency.
