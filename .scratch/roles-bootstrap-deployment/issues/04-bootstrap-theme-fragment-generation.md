# 04 — `bootstrap.sh` Theme Mode + fragment generation

**What to build:** A freshly bootstrapped Desktop's waybar and zathura work correctly the very first
time `sway` is launched, instead of hard-failing to parse a tracked config whose generated color
fragment doesn't exist yet. A machine with no Theme Mode yet gets a sensible default without ever
resetting one that's already active.

**Blocked by:** [03 — `bootstrap.sh` core sequence](03-bootstrap-core-sequence.md), and **05 —
`theme-switch` Role gate + render-only entry point** (from the theme-switch-expansion ticket set —
this step calls that entry point directly).

**Status:** ready-for-agent

- [ ] The Theme Mode state file is written with a default value only if one doesn't already exist; a
      machine that already has a mode set keeps it untouched on every re-run.
- [ ] Every app's Generated Config fragment is (re)generated unconditionally, every run, via
      `theme-switch`'s render-only entry point — not gated on whether the mode file was just created.
- [ ] Manually verified: bootstrapping a Desktop from a bare clone, then launching `sway` for the first
      time, does not produce a parse error from any tracked config whose colors come from a generated
      fragment.
- [ ] Manually verified: running bootstrap again on a machine with an active, non-default Theme Mode
      leaves that mode untouched while still regenerating the fragments.
- [ ] Bats coverage extending the core sequence's test file: the mode-file write-or-skip guard behaves
      correctly against a faked state directory, and the fragment-generation call happens on every
      invocation regardless of whether the mode file already existed.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions → "The
ordered sequence," step 11, and Further Notes on the theme-switch-expansion dependency.
