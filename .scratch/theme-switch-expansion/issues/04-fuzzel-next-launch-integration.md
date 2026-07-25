# 04 — fuzzel: next-launch integration

**What to build:** fuzzel launches with colors matching the current Theme Mode, updating on the next
switch with no reload logic needed at all, since it's spawned fresh per invocation and exits. If its
generated color fragment is ever missing, it falls back loudly to fuzzel's own built-in defaults
rather than silently serving stale colors from a leftover tracked block.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] The tracked color block in fuzzel's config is deleted outright (not shadowed or commented out).
- [ ] An include of a generated color fragment is added to fuzzel's default/main section, positioned so
      it isn't overridden by any other default-section setting (fuzzel's include applies in place, last
      assignment wins). A leading `~/` in the include path is fine — fuzzel supports it.
- [ ] The generated fragment's colors resolve from the Canonical Palette per mode (fuzzel already
      needs no new roles — every value it uses today is already an exact palette value).
- [ ] No apply function, no signal, and no guard code is added to `theme-switch` for fuzzel.
- [ ] Manually verified: launching fuzzel after a toggle shows the new mode's colors; renaming/removing
      the generated fragment causes fuzzel to fall back to its own built-in defaults rather than
      erroring or silently showing stale colors.
- [ ] `theme-switch.bats` gains coverage for the new generator function confirming the fragment's exact
      contents per mode.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "fuzzel:
next-launch, no reload needed."
