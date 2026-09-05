# 04 Where the package sets live and in what form

**Type:** `grilling`

**Status:** open

**Blocked by:**
[01 Name the distro divergence](01-name-the-distro-divergence.md),
[02 Program roster and package availability survey](02-package-availability-survey.md),
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

The map has already settled that `bootstrap.sh` stays sudo-free and that
installing packages is a step in front of it. What remains is the **tracked
artifact**: what does the repo hold, and what does the operator do with it?

### To settle

1. **The shape.** One list per distro, or one list with per-distro annotations?
   Plain text pasted into a `dnf install`/`apt install` line, or a script the
   operator runs under sudo? A script is still sudo-free from `bootstrap.sh`'s
   point of view, so "copy-paste" and "a script" are both open.
2. **Where in the repo.** `.stow-local-ignore` decides whether a new top-level
   path is deployed into `${HOME}` or stays repo-local. Package sets are
   repo-local, so the ignore file has to grow a line; check that against `docs/`
   and `.scratch/`, which already sit there.
3. **The boundary rule.** What belongs in a package set and what is a manual
   step in [05](05-install-route-and-manual-steps.md)? The obvious candidate
   rule: anything installable with one command from a repository that is already
   enabled belongs in the set; anything that first requires enabling a foreign
   source, logging in, or answering a prompt is a manual step. Test that rule
   against the survey's actual findings rather than accepting it.
4. **Flatpaks.** A second set, or the same set with a marker? `flatpak install`
   needs no root for a `--user` install, which makes Flatpaks structurally
   different from native packages: they could in principle be the one packaging
   step `bootstrap.sh` is allowed to take. Decide whether that is wanted or
   whether the sudo-free rule is really a "no installing at all" rule.
5. **Names diverge, and not only package names.** The Ubuntu package `imv`
   installs its binary as `/usr/bin/imv-wayland`, so `dpkg -S` finds the package
   under the same name Fedora uses while `command -v imv` fails. A package set
   that lists names must say which kind of name it lists, because
   [08](08-completeness-check.md) reads that same list and a wrong answer there
   is a silent one.
6. **Ubuntu versus Fedora content.** The survey will show programs available on
   one side and not the other. Does a package set list a program the other
   distro cannot have, and if so how is that marked?
