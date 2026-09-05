# 07 The battery threshold keybind and its missing script

**Type:** `grilling`

**Status:** open

**Blocked by:**
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md),
[06 What the configs must stop assuming](06-config-assumptions.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`.config/sway/config` binds `Control+Alt+p` to `sudo battery-threshold-toggle`.
That program is in no package, is not in this repo, and does not exist on the
Ubuntu machine. It is the only place in the repo that calls `sudo`, and it is
the one keybind that is hardware-specific: the charge-threshold sysfs interface
differs between the ASUS ZenBook and the HP EliteBook, and a laptop that does
not expose one at all cannot have the feature in any form.

### To settle

1. **Does it come into the repo?** A tracked script under `.local/scripts/`
   would follow the conventions
   [14](../../portable-dotfiles/issues/14-script-conventions.md) already fixed,
   and would get bats coverage. Against that: it needs root, and everything else
   in that directory runs as the user.
2. **The sudoers entry.** A passwordless sudo rule is a manual, per-machine,
   root-owned change that no `bootstrap.sh` should make. If the script is
   tracked, its sudoers entry is a manual step for
   [05](05-install-route-and-manual-steps.md); if the script is not tracked,
   both are.
3. **The hardware difference.** One script probing sysfs for whichever interface
   is present, or genuinely different behaviour per machine? Fold in what
   [01](01-name-the-distro-divergence.md) settles: this is not a distro
   difference at all, it is a hardware difference, and it may need its own place
   in the vocabulary or may collapse into a Capability Probe.
4. **Or the keybind goes.** Deleting it is a real option and costs one keystroke
   that today does nothing on at least one of the two machines.
