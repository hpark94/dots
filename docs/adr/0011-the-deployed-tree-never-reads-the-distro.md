# The deployed tree never reads the distro

This repo is installed on Fedora and on Ubuntu, and the two differ in how a
program is obtained: a package name (`bind-utils` versus `bind9-dnsutils`), a
third-party repository, Terra, for ghostty and satty on Fedora, an upstream
repository for librewolf and protonvpn, a Flatpak for obsidian and thunderbird,
and for satty on Ubuntu nothing but a release download. `CONTEXT.md` calls such
a difference a **Distro Fact**. The decision is where it may be expressed:

> How a program gets onto the machine is absorbed before deployment. Where
> deployed code has to adapt to what is on the machine afterwards, it probes.

No file that stow deploys into `${HOME}` reads `/etc/os-release` or branches on
the distribution. The difference lives in the package sets and the documented
install steps, which are distro-keyed by construction and stay in the clone,
kept out of `${HOME}` by `.stow-local-ignore` alongside `docs` and
`bootstrap.sh`. A human selects which part applies. What a machine ends up
having as a result, `imv-wayland` in place of `imv`, a missing `chafa`, is asked
of the program itself with a Capability Probe, because it is indistinguishable
from a program the operator chose not to install.

This is recorded as an ADR because it is implemented as an absence of code, and
an absence never explains itself. Adopting it cost nothing: at the time of
writing, a search of the tracked tree for `os-release` and `ID_LIKE` found only
prose.

## Considered Options

**A probe on the thing over reading `os-release` in deployed code.**
`.config/sway/config` is the model. It meets the `sway-systemd` divergence with
`test -f /usr/libexec/sway-systemd/session.sh` and falls back to
`dbus-update-activation-environment`. That stays right when Ubuntu eventually
packages `sway-systemd`, and it stays right on a Fedora machine where the
package is simply not installed. A branch on the distribution's name would be
wrong in both cases, because the name is a proxy for presence and never answers
the question that was actually asked. `bootstrap.sh` already behaves the same
way: `backup_skel` meets a distro difference in `/etc/skel` by moving aside
whichever of the names in `SKEL_FILES` exist as real files, rather than by
asking who put them there.

**A human selecting over an install artifact reading `os-release`.** The ban
ends at what stow deploys, so an install script branching on `/etc/os-release`
for itself would not have broken the first rule. It was refused on its own
grounds: the operator typing the command already knows which machine they are
sitting at, so the read adds no information, and it adds one silent wrong branch
on any distribution the package sets do not cover. The same reasoning already
keeps third-party sources documented rather than scripted.

**No Distro Marker.** The symmetry with the Role Marker is the mistake somebody
will otherwise make. The Role Marker exists because the Role is not
discoverable: no probe separates Desktop from Headless without going stale, as
in a cron job on a Desktop that probes as Headless. A distribution is
discoverable, so a marker would be a written copy of an answer that already
exists, and with nothing reading the distro it would have no reader at all. This
inherits the Role Marker's rule that only code a human explicitly invokes may
read it, in its strongest form: nothing reads the distribution's identity, and
the selection happens once, in a person's hands, before any of this repo runs.

## Consequences

- Where deployed code must adapt to what is installed, it uses a Capability
  Probe on the thing itself. Where the package set promises the program, only a
  precondition check is allowed, and that check refuses rather than adapts.
- Package sets and the install document are distro-keyed and repo-local. They
  are the one place a Distro Fact is written down.
- A vendor command quoted in a documented step is not a violation, even when it
  reads the distribution itself: ProtonVPN's setup reads `/etc/fedora-release`.
  The rule governs what this repo deploys and what its install artifacts do, not
  third-party commands a human runs by hand.
- A third distribution costs no decision here. Arch is out of scope, and this
  rule does not block it: it would need its own package set and steps, and no
  deployed file would change.
