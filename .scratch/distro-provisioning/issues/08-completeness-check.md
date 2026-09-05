# 08 A completeness check for a machine

**Type:** `grilling`

**Status:** open

**Blocked by:**
[04 Where the package sets live and in what form](04-package-set-form.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`bootstrap.sh` exiting 0 says the script ran, not that the machine is finished.
The operator wants something that answers the other question: is everything that
should be here actually here? Graduated from the map's fog once the package set
became a tracked artifact for it to read.

### The hard part, and it is not the loop

Names diverge, and they diverge in more than one way. The Ubuntu package `imv`
installs its binary as `/usr/bin/imv-wayland`, so on this machine
`dpkg -S "$(command -v imv-wayland)"` answers `imv` while `command -v imv` finds
nothing. A check that probes binaries reports a missing program that is
installed; a check that probes package names has to ask a different package
manager on each distro and says nothing about whether the program is actually
reachable on `PATH`. Both failure directions are silent, which is exactly what
this check exists to prevent.

### To settle

1. **What it asserts.** Binaries on `PATH`, packages known to the package
   manager, Flatpak application ids, or a mixture keyed per entry? A mixture
   makes the package set carry a kind alongside each name, which is a cost
   [04](04-package-set-form.md) has to price.
2. **Where the truth lives.** The check should read the same tracked package set
   the install step uses, or the two drift and the check certifies a machine
   against a list nobody maintains. If the set cannot serve both, say why.
3. **What it does about Flatpaks and the manual steps.** Does it check that
   `~/Sync` and `~/projects` exist, that the Role Marker is written, that the
   theme fragments are rendered? There is a real boundary between "the packages
   are present" and "the machine is configured", and this ticket draws it rather
   than letting the script grow into a second `bootstrap.sh`.
4. **Its output.** Silent on success and a list of what is missing otherwise, or
   a report either way? It is run by a human who is asking a question, which
   argues for the report; every other script here follows the fail-loudly
   convention from
   [14](../../portable-dotfiles/issues/14-script-conventions.md).
5. **Whether it runs anywhere but by hand.** A check `bootstrap.sh` calls at the
   end would catch a half-installed machine at the moment it is created, but it
   would also make `bootstrap.sh` fail on a Headless machine that is complete by
   its own standards and installs no packages at all.
