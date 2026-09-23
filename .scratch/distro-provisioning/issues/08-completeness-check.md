# 08 A completeness check for a machine

**Type:** `grilling`

**Status:** resolved

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

## Answer

### 1. What it asserts: a mixture, and the table already carries the key

Per row: `command -v` on the first column where the row has a command, the
package manager on the distro column where the first column carries `-`. A `-`
in both is a row this machine has nothing to check, and section 6 says what the
report does with it.

**The package query asks for the installed state and not merely for a known
name**, which matters on one side only:

```sh
rpm -q "${name}" >/dev/null 2>&1
dpkg-query -W -f='${db:Status-Status}' "${name}" 2>/dev/null
```

`dpkg` keeps a removed package in its database as `deinstall ok config-files`,
so a query satisfied by the name alone certifies a portal or an IM module as
present after it has been removed. That is this ticket's own failure mode,
reached through the one probe that was supposed to close it.

Every outcome is named, because `set -euo pipefail` makes an unhandled one abort
the run at the first ordinary missing package:

- `rpm -q`: zero is installed, nonzero is missing. It documents no third case,
  so it gets none.
- `dpkg-query`: zero with `installed` is present, zero with anything else is
  missing, and **1**, no matching package, is missing too. **2** is a fatal
  error in the query itself and is a refusal in section 7's sense, exit 2,
  because a query that broke says nothing about the machine.

Both are captured and neither is allowed to print. A missing package is an
ordinary result here, so every call is guarded rather than left to `set -e`.

This is the "mixture keyed per entry" the ticket's item 1 asked about, and **its
cost to [04](04-package-set-form.md) is zero**. The ticket priced a kind marker
that the package set would have to carry alongside each name; 04 already built
that marker without calling it one. The `-` in the first column is the key, and
it is there because 04 needed it for a different reason, to say that a row
leaves no command on `PATH`.

The consequence is worth writing down, because it looks like a loose end and is
not: **a `-` in a package column never causes a skip on its own.** 04 named
three cases for that marker. Two of them, `ffmpeg` on Fedora and `satty` on
Ubuntu, have a real command in the first column, so they are checked by
`command -v` and the marker is never read. Only `sway-systemd` on Ubuntu carries
`-` in both, and that is the single row the check passes over. So the Ubuntu
satty tarball from [05](05-install-route-and-manual-steps.md) section 8, which
no package database on that machine can speak for, is covered by section one
without anything being added for it.

**The package manager is chosen by a Capability Probe, not by reading the
distro.** `command -v rpm` and `command -v dpkg`, which is a probe in
`CONTEXT.md`'s sense and therefore leaves ADR-0011 intact: the ban is on reading
which distribution this is, not on asking which tools are here.

Giving the `-` rows purpose-built probes instead was refused on 04's own
argument rather than a new one. `/usr/libexec/sway-systemd`, the `.portal`
files, `python3 -c 'import i3ipc'` and the zathura plugin path are paths, the
paths are distro-keyed, and 04 refused the first column a path for exactly that
reason: it re-imports into the check the divergence the two package columns
exist to absorb.

### 2. Where it lives, and how it is run

`completeness-check.sh` at the repo root, beside `bootstrap.sh`, with its own
line in `.stow-local-ignore` after the pattern that file already sets:

```
# completeness-check.sh is run by path from the clone root, never symlinked
# into $HOME: it reads packages/, which stow does not deploy.
^/completeness-check\.sh$
```

**Not stowed, and the reason is in the data it reads.** It reads
`packages/roster.md` and `packages/flatpak.txt`, and 04 put `^/packages` in
`.stow-local-ignore`, so those files exist only in the clone. A stowed check
would have to find the clone from a symlink, which means `readlink -f` on
`${BASH_SOURCE[0]}` because `dirname` on a stow symlink answers the link's
directory and not the target's. No script under `.local/scripts/` does that
today, and the whole benefit would be typing the name without a path.

It is also the right side of the same line 05 already drew: the install lines
run out of the working tree, and this is their counterpart.

**No arguments and no flags.** There is exactly one question to ask.

Structured as functions behind the source guard `theme-switch:544` already uses,
`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`, so the bats suite calls individual
functions instead of driving the whole script against a faked environment on
every case. The suite is `.local/scripts/tests/completeness-check.bats`, beside
the others even though the script it covers sits at the root, because
`bootstrap.bats` is already there on the same terms.

### 3. The boundary: three sections, and what decides membership

The ticket's item 3 asked for the line between "the packages are present" and
"the machine is configured". It is two rules, and the second one applies only to
paths.

> **Membership, for a candidate for section three: nothing else on this machine
> would notice the absence.**
>
> **For a path, additionally: a tracked file names it.**

**The rule governs section three and nothing else**, which is the part worth
saying out loud. Sections one and two have their membership already:
[04](04-package-set-form.md) decided it, every row of `packages/roster.md` and
every line of `packages/flatpak.txt`, and a promised program is checked whether
or not its absence is loud. `sway` missing is about as loud as a machine gets
and it is still checked, because [06](06-config-assumptions.md) stage 1 forbids
probing a promise away and the hole in the packaging is the thing being looked
for. Section three is the one that had no list, because
[05](05-install-route-and-manual-steps.md) section 10 deleted the checklist, so
it is the one that needed a rule.

The first rule is what keeps `bootstrap.sh`'s own output out. The Role Marker,
the theme fragments, the mise toolchain, the tmux and nvim and zinit plugins are
all produced by a script whose every step guards itself and which is safe to
re-run by its own header. Re-running `bootstrap.sh` is a cheaper and more honest
check of bootstrap's output than a second program asserting it from outside, and
a second assertion would be a copy that can disagree with the thing it copies.

The same rule is what puts the manual steps in. After
[05](05-install-route-and-manual-steps.md) section 10 deleted the per-machine
checklist, nothing else stands between a manual step that quietly stopped
happening and nobody noticing.

The second rule exists because the first one alone would have the check
inventing paths. [05](05-install-route-and-manual-steps.md)'s roster lists "the
KeePassXC database in its place", and no tracked file in this repo names a
`.kdbx` path anywhere: `git grep -i kdbx -- ':!.scratch'` exits 1. `git grep`
rather than `rg`, because the claim is about tracked files and because `rg`
without `--hidden` never enters `.config/` or `.local/`, which is where the
answer would have been. A check that guessed one would report a correct machine
as incomplete, which is the failure this ticket exists to prevent, arriving from
the other direction. So the database is not checked, and it is not checked for a
stated reason rather than by taste.

**Presence, never correctness.** The ticket's own words are "is everything that
should be here actually here", and the check answers exactly that. It asserts
that a file is where it should be and never questions the program that should
have put it there; it never asks whether protonvpn is logged in or whether
fcitx5 has been configured for a language.

Three sections, in the order the install route produces them: the roster, the
Flatpaks, the manual steps.

**The Flatpak section is `flatpak info <id>` per line of
`packages/flatpak.txt`**, and deliberately not `flatpak list --system`.
[05](05-install-route-and-manual-steps.md) section 6 installs them system wide,
so a system-scoped query would match the documented route exactly, and it was
refused all the same: the check asserts presence and not installation scope, and
reporting a user-installed Obsidian as missing is precisely the false report
this ticket exists to prevent. Where `flatpak` itself is absent, the section's
entries read as not checkable in section 6's third classification rather than as
missing, because `flatpak` has a roster row of its own and section one has
already named it. That is what separates it from `busctl` in section 5: `busctl`
is on no roster row, so nothing else would report its absence, which is why that
one is a refusal instead.

### 4. Section three, item by item

Five entries, each with the tracked file that admits it under the second rule:

| Entry                                                    | Probe                  | Named by                              |
| -------------------------------------------------------- | ---------------------- | ------------------------------------- |
| `~/Sync`                                                 | directory exists       | `.config/sway/config:6`               |
| `~/projects`                                             | directory exists       | `.local/scripts/tmux-sessionizer:18`  |
| `~/Sync/.pictures/wallpaper/frieren.jpg`                 | file exists            | `.config/sway/config:6`               |
| `Include ~/.config/ssh/config.shared` in `~/.ssh/config` | the line is there      | `.config/ssh/config.shared:5`         |
| the hwdb charge-limit override                           | file exists, section 5 | [07](07-battery-threshold-keybind.md) |

**The wallpaper file and not the `mkdir` is the entry that carries Syncthing**,
exactly as 05 section 4 put it: the directory is the prerequisite of pairing,
and Sway waits on the pairing. Nothing creates that file by hand, so its
presence is evidence that the pairing happened, which is as close to the pairing
as an assertion about presence is allowed to come: the check reads the file and
asks Syncthing nothing. Both are listed anyway, because a missing `~/Sync` and a
missing wallpaper inside an existing `~/Sync` are two different situations and
the report should not collapse them.

**`texlab` was weighed and dropped, on the same rule as the login shell below.**
[04](04-package-set-form.md) section 7 makes it a pinned
`cargo install --git ... --tag` that runs after `bootstrap.sh`, so no roster row
collects it, and that looked like a hole for section three to fill.
[06](06-config-assumptions.md) had already settled it the other way: where the
step has not been run, nvim starts six language servers instead of seven, an
editor without its language server is not mistakable for one with it, and
`:checkhealth lsp` names the missing binary to anyone who asks. Something else
on this machine notices, so the first rule excludes it. The correction it forces
on 04 stands regardless and is section 10's: that is a contradiction inside 04
between its first clause and its section 7, and it was never contingent on 08
checking the program.

**The login shell was weighed and dropped.** `chsh` is a step no tracked file
sets, so it looked like a candidate, but a machine that is still in bash after
login notices immediately and loudly: the prompt is wrong and none of the zsh
configuration is live. The first rule excludes it.

**The list lives in the script, as a copy of five values.** The Q7 rule says
when a path is admitted, not where its value comes from at runtime, so it stays
a membership rule. Reading them out of their own files would mean two parsers
for shell and sway's config syntax, which is more machinery than the problem. A
third file under `packages/` holding five lines would be a data file with one
reader, which `AGENTS.md` refuses. The cost is real and accepted: change the
wallpaper path in the sway config and the check keeps asserting the old one.
That is the reverse drift of section 8, and it is out of scope there for the
same reason.

### 5. The battery threshold, and the word that keeps it from being an exception

[07](07-battery-threshold-keybind.md) handed this over as a candidate and left
the decision here. It is taken, with a qualification that 07's own measurement
forces.

07 section 6 established from the driver rather than from a machine that the
EliteBook's `hp-wmi` exposes neither threshold attribute, which is why that
machine gets a paragraph in `docs/install.md` rather than a ticket of its own;
the ZenBook is the one whose UPower answers `ChargeThresholdSupported` true. The
tracked script 07 section 4 specifies,
`.config/sway/scripts/battery-charge-limit`, is deployed to the EliteBook like
anywhere else and refuses there. A check that asserted the threshold
unconditionally would therefore report a correct EliteBook as incomplete, so the
capability is read first.

**The device is enumerated, never named**, which is 07's rule and not a new one:
a hard-coded `battery_BAT0` could refuse on the EliteBook because the battery is
named differently there, and that would be a lie about the hardware rather than
a statement about it.

```sh
busctl --system call org.freedesktop.UPower /org/freedesktop/UPower \
    org.freedesktop.UPower EnumerateDevices
```

Then the device whose `ChargeThresholdSupported` is true. 07 measured that
exactly one of five enumerated devices answers true on the ZenBook and that
`GetDisplayDevice` is a dead end, so the property is its own filter and no
second test is needed. No such device means the line reads
`battery charge limit: not supported on this machine`, because the EliteBook is
not meant to carry the override at all.

**Where one is found, what is asserted is the file and not the threshold.** 07
section 3 names it exactly, `/etc/udev/hwdb.d/61-battery-local.hwdb`, in a
world-readable location, so `[ -f ]` settles it without root and section 3's
guarantee stays absolute with no entry needing an exception. Comparing
`ChargeEndThreshold` against the `CHARGE_LIMIT=_,60` that file sets was the
first shape and is wrong twice over: it asserts a value rather than an artifact,
and it does not even establish the artifact, because UPower persists the state
in `<state_dir>/charging-threshold-status` and re-applies it at coldplug, so 60
survives the file's removal. The check would then certify a machine whose
documented step has been undone.

UPower is therefore read for the capability and never for the value, which is
also why nothing here has to know that the shipped default is 75/80.

**The roster gains no third marker**, which is what this decision is actually
about: 04's table is untouched, and the completeness verdict stays binary,
complete or not, which is what exit 1 answers. What does gain a third value is
the per-entry classification the report needs, present, missing, or neither, and
section 6 counts all three so that the sum goes out. That third value is one
classification with two producers, this machine and section 1's skipped row,
rather than two exceptions.

**A missing `busctl` is a refusal and not a finding.** 07 measured that it ships
inside `systemd` on both distros, the one package neither of them can be
without, so it needs no roster row; it still gets a precondition check on
`PATH`, which `AGENTS.md` mandates and which 07 decided for the keybind script
on the same grounds. Classifying its absence as an unchecked entry would report
a broken check as a statement about the machine, and that is the confusion of
categories this whole ticket exists to prevent. It joins section 7.

### 6. The report

On stdout, in both outcomes. The caller is a human with a question, and silence
does not distinguish "nothing is missing" from "the script did not run".

Per section: the missing named, the present counted, and the sum accounted for.

```
roster:         58 present, 1 not checkable here, 2 missing
                ghostty, xdg-desktop-portal-wlr
flatpaks:       2 present
manual steps:   4 present, 1 not supported on this machine
```

A full list with a mark against every entry was refused: seventy lines of noise
in the case that almost always holds.

**The sum going out is the part that matters.** `58 + 1 + 2` has to equal the
row count, so a row that was never looked at cannot hide behind a green report.
That is why section 1's skipped row and section 5's unsupported machine are
counted out loud instead of passed over.

**One closing line pointing at `docs/install.md`, and no remedy per entry.**
This is [04](04-package-set-form.md)'s decision inherited rather than a new one:
04 refused a fourth roster column naming the install route, because it would be
a second copy of what 05 writes anyway and two copies drift. A remedy printed
beside each miss is that same second copy, in shell instead of Markdown.

Exit 1 when anything is missing. This does not weaken
[14](../../portable-dotfiles/issues/14-script-conventions.md)'s fail-loudly
rule: a finding is the script's output, not the script's failure. The script's
own failures are section 7.

### 7. The four refusals

stderr and exit 2, per the convention, for all four:

- **No Role Marker.** There is no Role to check against, and `CONTEXT.md` says a
  machine without a Marker should fail at a command rather than in every shell.
  This is that command.
- **A Headless machine.** The roster is Desktop by 04's own header sentence, so
  there is nothing here a Headless machine is meant to have. Reading the Marker
  is legitimate precisely because this is invoked by hand, which is the only
  code `CONTEXT.md` lets near it. It is a precondition check in
  [06](06-config-assumptions.md)'s sense: it refuses, it does not adapt.
- **Both package managers present, or neither.** The check cannot tell which
  column speaks for this machine, and a guessed column is the silent wrong
  answer the whole ticket is built against.
- **No `busctl` on `PATH`.** Section 5 has the argument: a tool the check itself
  needs is the check's own precondition, never a finding about the machine.

The exact route out of the **third** of these was weighed and not built:
`rpm -qf` against a file both distributions certainly have answers by ownership
rather than by presence, and is exact even where both managers are installed. It
is a mechanism for a case nobody has, and `AGENTS.md` names that under YAGNI.
Recorded so the next reader does not derive it again and take it for an
oversight.

### 8. What it deliberately does not do

- **`packages/optional.md` is not read.** [06](06-config-assumptions.md) created
  that file exactly so that nothing would promise what is in it, and the check
  asserts what the roster promises. Reporting "optional, not installed" would
  remind a machine that consciously declined ProtonVPN of that decision on every
  run, which is how a report stops being read. The absence is already handled,
  by 06's stage two and by `.config/sway/config`'s own answer.
- **It does not check the repo against itself.** The reverse rot, someone adding
  a call to a tracked file and forgetting the roster row, leaves the check
  honestly green on a machine that really does have everything the roster
  promises. Catching it would mean parsing every tracked file and telling a
  command invocation from a word in three languages, which is a repo lint with a
  different input domain, not this. It goes to the map's **Out of scope**.
- **It installs nothing and changes nothing.** Its only outputs are a report and
  an exit status.

### 9. Whether it runs anywhere but by hand, and the argument's third outing

**By hand only. `bootstrap.sh` does not call it.**

This is the same argument for the third time, and that is the reason to trust
it. `bootstrap.sh:11` says of itself that every step runs identically for both
Roles, and the roster is Desktop. A call from the end of `bootstrap.sh` would
therefore either report a complete Headless machine as missing sixty packages,
or force into `bootstrap.sh` the Role branch it refuses to have.
[04](04-package-set-form.md) kept the Flatpaks out on this argument and
[05](05-install-route-and-manual-steps.md) kept `font-install` out on it; 05
section 5 already noted that the tempting alternative reason, that bootstrap
avoids the network, is false. A third case landing on the same reason is worth
recording, because it is now a property of `bootstrap.sh` rather than three
separate judgements.

### 10. Corrections outward

- **[04](04-package-set-form.md) gains no `texlab` row, against its own first
  clause.** `.config/nvim/lua/core/lsp.lua:7` names `texlab`, so clause one
  would put it in the roster, and 04 section 7 simultaneously made it a manual
  `cargo install` that the install line must not touch. The two cannot both
  hold. It is resolved here in favour of the manual step: no roster row, and by
  section 4 no entry in section three either, so `texlab` is checked nowhere and
  [06](06-config-assumptions.md) already said why that is the right answer. 09
  carries this, because it is visible in neither 04 nor 05.
- **[05](05-install-route-and-manual-steps.md) gains a closing line** in
  `docs/install.md` naming `completeness-check.sh` as the last thing the route
  says.
- **`AGENTS.md` gains one row** in its Commands section.
- **`README.md` gains nothing**, per 05 section 9 and the map's Notes.
- **The map's Out of scope gains the repo lint** from section 8.
- **`CONTEXT.md` gains one term**, section 11, specified here and written by
  [09](09-spec-and-build-tickets.md) with the build, like 01's and 06's entries
  before it.

**No ADR.** That the check probes the package manager instead of reading the
distro is a consequence of ADR-0011 rather than a second decision, and that it
runs by path out of the clone has a precedent sitting in `.stow-local-ignore`
already. Neither would surprise a future reader who has read those two.

### 11. The `CONTEXT.md` entry, specified and not written

Under **Deployment**, after **Capability Probe**:

**Completeness Check**:\
The answer to "is everything that should be here actually here", asked of one
machine, by a human, and by nothing else: `completeness-check.sh`, run by path
out of the clone because the package set it reads is not deployed. It asserts
**presence and never correctness**, so it reports that `~/Sync` exists and never
that Syncthing has paired. Its package sections take their membership from the
package set, every promised name, loud absence or not; its third section, the
manual steps, has a rule of its own, that nothing else on the machine would
notice the absence, which is what keeps `bootstrap.sh`'s own output out of it:
that script guards every step and is safe to re-run, so re-running it is the
cheaper and more honest check of what it produced. For a path there is a second
half, that a tracked file names it, which is why the wallpaper is checked and
the KeePassXC database is not. Deliberately neither a second `bootstrap.sh`,
since it installs nothing and changes nothing, nor a lint of the repo against
itself, since a roster missing a row leaves it honestly green.\
_Avoid_: doctor, health check, audit, verify (each names a habit borrowed from
another tool rather than the question this one asks)
