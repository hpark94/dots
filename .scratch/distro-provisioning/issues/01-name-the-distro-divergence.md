# 01 Name the distro divergence

**Type:** `grilling`

**Status:** open

**Blocked by:** None, can start immediately

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`CONTEXT.md` names three kinds of divergence today, and a Fedora-versus-Ubuntu
difference is none of them:

- a **Role Fact** branches on the Role Marker, decided at install and true of
  the machine;
- a **Session Fact** is probed at runtime because it can differ between two
  sessions on the same machine;
- a **Capability Probe** asks whether something is present right now, so one
  shared executable can adapt instead of branching.

A distro difference is settled before the repo is even cloned, is true of the
machine forever, and is mostly not about what the machine _is_ but about how a
program **got there**: a different package name, a different repository, a
different path, or nothing at all because the program is unavailable.

What is this called, and what is the rule for where such a difference is allowed
to be expressed?

### To settle

1. **The term.** Is there a "Distro Fact", or is the whole point that the repo
   never learns which distro it is on and every difference is absorbed before
   deployment? Name it and write it into `CONTEXT.md`, or establish deliberately
   that no such term exists and say why.
2. **The seam.** Three places a difference can land: install time (a package
   set, or a documented step), runtime (a Capability Probe in a shared file), or
   nowhere at all (a config that must simply tolerate the program's absence).
   What decides which one? A rule, not a case list.
3. **Does anything read the distro?** `/etc/os-release` is the obvious source.
   Is there a single consumer, several, or none? If none, that has to survive
   the case of `.config/sway/config:12`, which already branches on a Fedora path
   (`/usr/libexec/sway-systemd/session.sh`) with a fallback, and does it as a
   file-existence probe rather than by asking the distro's name.
4. **The Role Marker precedent.**
   [13 How a script reads the Role Marker](../../portable-dotfiles/issues/13-role-marker-reader.md)
   established that only code a human explicitly invokes may read the Marker, so
   that a missing Marker fails at a command rather than on every login. Whatever
   this ticket names inherits that constraint or explicitly breaks it.

Update `CONTEXT.md` with whatever is settled. This ticket is the vocabulary
every later ticket on this map uses.
