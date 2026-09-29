# 03: Screenshot keybinds become a tested script

**What to build:** Both screenshot keybinds still work: one hands the focused
output to satty, the other saves it as a timestamped PNG. When a program they
need is missing, they say so in a notification and do nothing, where today they
lose the screenshot silently.

**Blocked by:** None, can start immediately.

**Status:** done

- [x] One script under `.config/sway/scripts/`, named after the pattern of
      `battery-charge-limit` (the noun names the file), with a required verb:
      `edit` hands the focused output to satty, `save <dir>` writes a
      timestamped PNG into `<dir>`. Anything else is refused.
- [x] It follows the repo's script conventions (`set -euo pipefail`, validation,
      loud failure). Its precondition checks cover `swaymsg`, `jq`, `grim` and
      `satty` where they are needed. A refusal writes to stderr, calls
      `notify-send` and exits non-zero. It never probes a roster program away.
- [x] The save variant notifies on success as today, in English.
- [x] `.config/sway/config:124` and `:125` call the script by absolute path; the
      save binding passes `$screenshots` as `<dir>`. Nothing else in the file
      changes.
- [x] A bats suite in `.config/sway/scripts/tests/` stubs the external commands
      on `PATH` and covers both verbs, a bad or missing argument, and a refusal
      per missing program.
- [x] `AGENTS.md` lists the script under "Sway session scripts" and in the
      `bats` line of Commands.

**Further Notes:** Spec section "The Sway session sees only the system". The
reasoning is in
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
sections 4 to 6. `swipe-workspace-inc.sh` and `-dec.sh` are out of scope here.
