# 01 Name the distro divergence

**Type:** `grilling`

**Status:** resolved

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

## Answer

### 1. The term is Distro Fact, and it exists to forbid a branch

A Fedora-versus-Ubuntu difference is a **Distro Fact**. It joins the three terms
in `CONTEXT.md` as the far end of one spectrum, how close a difference is
allowed to get to running code: a Role Fact branches on a file the install
wrote, a Session Fact is probed once per connection, a Capability Probe is asked
at the moment of use, and a Distro Fact never reaches a file this repo deploys.

The entry to add to `CONTEXT.md` under Deployment, next to Role Fact:

```markdown
**Distro Fact**:\
A difference between the distributions in how a program is obtained: the package
name (`bind-utils` versus `bind9-dnsutils`), the repository it comes from,
whether it needs a third-party source, or whether it can be had at all. Answered
once, when a machine is installed, against whatever the archives hold that day,
and the one kind of divergence that never reaches a deployed file: it is
absorbed at install time into the package sets and the documented steps, both of
which live outside what stow deploys, and a human picks which of them applies.
Nothing reads `/etc/os-release`, and there is no Distro Marker: unlike the Role,
a distribution is discoverable, so a written copy would be a second answer to a
question that already has one, with no reader. What the machine ends up having
as a result is not a Distro Fact: `imv-wayland` in place of `imv`, or a missing
`chafa`, is a Capability Probe's question, indistinguishable from a program you
simply did not install.\
_Avoid_: Package Route (`satty` is in neither archive and is a Distro Fact all
the same), Install Fact, distro detection, `ID_LIKE`
```

and one line appended to **Capability Probe**'s `_Avoid_`:
`the distro's name (a proxy for presence, and a wrong one)`, in the same form in
which Session Fact already turns away "SSH check".

**Package Route** was the strongest rival name, and `satty` is where it breaks.
The survey found it in neither distribution's own archives and not on Flathub:
what is left is a prebuilt x86-64 binary, a `.flatpak` bundle file,
`cargo install`, or a personal COPR unrelated to the project. That is a Distro
Fact all the same, and the one that costs the most, but a name built on the word
route describes it badly, because what it forces is a choice among leftovers: a
file you download yourself, or a stranger's COPR that `dnf` will happily keep
updated and that nobody at the project has ever looked at.

### 2. The seam: two places, not three

The rule, and it is a rule rather than a case list:

> **How a program gets onto the machine is absorbed before deployment. Where
> deployed code has to adapt to what is on the machine afterwards, it probes.**

The first half is the Distro Fact: 27 rows of package-versus-binary naming, a
COPR for ghostty on Fedora, an upstream repository for librewolf and protonvpn,
a Flatpak for obsidian and thunderbird, and for satty nothing that either
distribution ships. None of it is visible to a deployed file.

The second half is already named, and the term is **Capability Probe**, not a
new one. `imv` versus `imv-wayland`, a missing `chafa` or `metaflac`, Fedora's
`zathura` without a PDF backend: these are indistinguishable from a program the
operator chose not to install, and the code must behave the same either way,
which is exactly what makes the distro's name the wrong question to ask.

The ticket offered a third place, "nowhere at all", the config that must simply
tolerate an absent program. **It is not a third place.** It answers a different
question: not where a difference belongs, but whether its failure costs
anything. `$monitor`'s Iiyama serial and an unconditional `exec protonvpn` are
both cases where something may be absent, and what to do about that, guard it,
install it away, or let it fail, is a judgment about what the failure costs. It
belongs to [06](06-config-assumptions.md), which is looking for exactly that
rule. Keeping it out of here keeps this ticket on vocabulary.

### 3. Nothing reads the distro, and the boundary of that "nothing"

`grep -rn "os-release\|ID_LIKE\|dnf\|apt-get\|apt \|pacman\|rpm -q\|dpkg"` over
the repo, excluding `.git` and `.scratch`, returns exactly one hit, and it is
prose in `CONTEXT.md:117`. The rule therefore costs nothing to adopt: it
describes the repo as it stands and stops the first exception from being
written.

`.config/sway/config:12` is not a surviving special case, it is the model. It
answers the `sway-systemd` divergence with `test -f` on the session script and
falls back to `dbus-update-activation-environment`. That is strictly better than
asking the distro's name, and for the ordinary reason: it stays right when
Ubuntu eventually packages `sway-systemd`, and it stays right on a Fedora
machine where the package is simply not installed. The distro's name never
answers the question that was actually asked.

**Where the ban ends:** at what stow deploys into `${HOME}`. Package sets and
documented steps are repo-local, kept out of `${HOME}` by `.stow-local-ignore`
alongside `docs`, `templates` and `bootstrap.sh` itself, and they are
distro-keyed by construction. **A human selects which one applies.** An install
artifact reading `/etc/os-release` and branching for itself was weighed and
rejected: the operator typing the command already knows which machine they are
sitting at, so the read adds no information, and it adds one silent wrong branch
on any distribution the lists do not cover. The map has already refused this
class of convenience once, in "third-party sources are documented, never
scripted".

This leaves [04](04-package-set-form.md) free: one file per distro or one
annotated file is still open there, and so is whether a set is pasted into a
command or run as a script under sudo. What this ticket fixes is only that
whatever it produces is chosen by a person and read by no deployed file.

`bootstrap.sh` already behaves this way without having a word for it:
`backup_skel` (`bootstrap.sh:68`) meets a distro difference in `/etc/skel` and
answers it by moving aside whichever of the five names in `SKEL_FILES`
(`bootstrap.sh:17`) exist as real files, rather than by asking who put them
there. Its header comment makes the same point about the other axis
(`bootstrap.sh:11`): "The Role is recorded, never branched on."

### 4. The Role Marker precedent is inherited, and tightened

[13 How a script reads the Role Marker](../../portable-dotfiles/issues/13-role-marker-reader.md)
allowed only code a human explicitly invokes to read the Marker, so that a
missing Marker fails at a command rather than on every login. A Distro Fact
inherits that constraint in its strongest form: nothing reads the distro's
identity, there is no marker to read instead, and the selection happens once, in
a person's hands, before any of this repo runs.

**There is no Distro Marker**, and the glossary says so explicitly, because the
symmetry with the Role Marker is the mistake somebody will otherwise make. The
Role Marker exists because the Role is _not_ discoverable: no probe separates
Desktop from Headless without walking into the staleness trap that
[13](../../portable-dotfiles/issues/13-role-marker-reader.md) documented, where
a cron job on a Desktop probes as Headless. A distribution is discoverable, so a
marker would be a written copy of an answer that already exists, and after
section 3 it would have no reader at all.

A by-product worth recording: this rule scales to a third distribution for free,
without any decision here being made for one. Arch stays out of scope per the
map, and the map's requirement that decisions not actively block it is met by
construction rather than by intent.

### 5. What this ticket specifies and does not write

Per the map's Notes, deciding what a document must say is planning and writing
it is not. Both artifacts below are specified here and produced when the work is
built, which also matches the repo's own history: the Roles vocabulary landed in
`60ad3f0 docs: expand CONTEXT.md and ADR-0001 with Roles vocabulary` on the same
day as `05e0d03 feat(bootstrap): add bootstrap.sh`, not during the map that
decided it.

- The `CONTEXT.md` entry and the `Capability Probe` `_Avoid_` line, verbatim in
  section 1.
- **ADR-0011, `the-deployed-tree-never-reads-the-distro`.** It earns an ADR by
  being surprising without context: the decision is implemented as an _absence_
  of code, and an absence never explains itself. A glossary entry says what
  holds; it does not record that `/etc/os-release` was considered and refused,
  nor why reading it inside an install artifact was refused too.

Holding both until the build also keeps them correctable:
[06](06-config-assumptions.md) walks the Distro-Fact-versus-Capability-Probe
line across a dozen real cases, and if a sentence here does not survive that, it
should be corrected in a ticket rather than in a committed glossary.

### What this hands the downstream tickets

- [04](04-package-set-form.md): the package set is the Distro Fact artifact, the
  place the divergence is absorbed. Its item 5 keeps its whole question. What
  this ticket adds is only the reason the question is sharp: a package name and
  a binary name answer different questions, and the 27 rows in the survey
  measure how far apart they run.
- [06](06-config-assumptions.md): all three of its options stand. A case can be
  made true by absorbing it into the package set, guarded with a Capability
  Probe, or left to fail. What this ticket fixes is only that none of the three
  is ever chosen by asking the distro's name.
- [08](08-completeness-check.md): a completeness check probes presence and never
  the distribution, for the same reason no other deployed code does.
