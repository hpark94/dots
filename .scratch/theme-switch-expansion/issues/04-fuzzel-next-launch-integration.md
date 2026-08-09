# 04: fuzzel: next-launch integration

**What to build:** fuzzel launches with colors matching the current Theme Mode,
updating on the next switch with no reload logic needed at all, since it's
spawned fresh per invocation and exits. If its generated color fragment is ever
missing, it falls back loudly to fuzzel's own built-in defaults rather than
silently serving stale colors from a leftover tracked block.

**Blocked by:** None, can start immediately.

**Status:** done

**Implemented.** The tracked `[colors]` block was deleted outright and
`include=~/.local/state/theme/fuzzel-colors.ini` added to the default section
(after the last default-section key, before `[border]`; fuzzel expands the
leading `~/`). `generate_fuzzel` writes the current-mode `[colors]` fragment as
`RRGGBBAA` hex without `#`, every value already an exact palette slot. No apply
code. Verified live on this machine: `fuzzel --check-config` passes with the
fragment present, and with it removed fuzzel prints a loud `failed to open`
error and falls back to its own defaults rather than serving stale colors
(US-14). bats covers exact fragment contents per mode. Remaining for a human:
confirm a launch after a toggle shows the new mode's colors.

- [x] The tracked color block in fuzzel's config is deleted outright (not
      shadowed or commented out).
- [x] An include of a generated color fragment is added to fuzzel's default/main
      section, positioned so it isn't overridden by any other default-section
      setting (fuzzel's include applies in place, last assignment wins). A
      leading `~/` in the include path is fine, fuzzel supports it.
- [x] The generated fragment's colors resolve from the Canonical Palette per
      mode (fuzzel already needs no new roles, every value it uses today is
      already an exact palette value).
- [x] No apply function, no signal, and no guard code is added to `theme-switch`
      for fuzzel.
- [x] Manually verified: launching fuzzel after a toggle shows the new mode's
      colors; renaming/removing the generated fragment causes fuzzel to fall
      back to its own built-in defaults rather than erroring or silently showing
      stale colors.
- [x] `theme-switch.bats` gains coverage for the new generator function
      confirming the fragment's exact contents per mode.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation
Decisions → "fuzzel: next-launch, no reload needed."

## Comments

**2026-07-26 (owner):** Manually verified on the live desktop, works flawlessly.
