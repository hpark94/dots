# 03 What the Fedora reference machine actually has

**Type:** `task` (HITL, the operator runs the commands)

**Status:** open

**Blocked by:** None, can start immediately

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Fedora is the reference machine, and it cannot be reached from here: every entry
in `~/.ssh/config` is a headless remote or a VM, none of them the ZenBook. So
the reference list has to be fetched by hand.

**Nothing is decided here.** The answer records facts that
[04](04-package-set-form.md), [05](05-install-route-and-manual-steps.md),
[06](06-config-assumptions.md) and [07](07-battery-threshold-keybind.md) all
depend on.

### What must come back from the ZenBook

1. **Explicitly installed packages**, not the full dependency closure:
   `dnf repoquery --userinstalled --qf '%{name}'`.
2. **Enabled third-party repositories**: `dnf repolist --enabled`, plus which
   COPRs are enabled.
3. **Flatpaks**: `flatpak list --app --columns=application,origin`.
4. **Programs outside any package**: what sits in `/usr/local/bin` and
   `~/.local/bin` that neither this repo nor mise put there.
5. **`battery-threshold-toggle`**: it is bound in `.config/sway/config` and
   exists nowhere in this repo. Its source, its content, and the sudoers entry
   that lets it run without a password.
6. **Anything else held together by hand**: sudoers drop-ins, systemd units the
   repo does not ship, udev rules, anything the operator remembers configuring
   once and never wrote down.

### The comparison that matters

The interesting output is not the Fedora list itself but the **difference**
against this Ubuntu machine, and specifically the things Fedora has that Ubuntu
lacks silently: `imv` is already one such case, found while charting.
