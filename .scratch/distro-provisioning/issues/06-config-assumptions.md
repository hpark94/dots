# 06 What the configs must stop assuming

**Type:** `grilling`

**Status:** resolved

**Blocked by:**
[01 Name the distro divergence](01-name-the-distro-divergence.md),
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Installing the right packages fixes the machine that is missing them. It does
not fix a config that assumes a program which the other distro cannot have at
all, or a path that exists on one machine only. Which of the repo's assumptions
have to go, and by which rule?

The known cases, all found while charting, on the Ubuntu machine:

- **`imv`** is installed on the Ubuntu machine, but as `/usr/bin/imv-wayland`:
  the package carries Fedora's name while the binary does not, so
  `command -v imv` fails on a machine that has it. Nothing in the repo calls
  `imv` by name today, which is the only reason this has stayed invisible.
- **`satty`** sits in `/usr/local/bin` and belongs to no package.
- **`protonvpn connect --p2p`** is exec'd unconditionally at sway start.
  `wait-for-vpn` already treats protonvpn as a Capability Probe, so the repo
  contradicts itself: one file assumes the program, another handles its absence.
- **`fcitx5 -d`**, **`lxpolkit`**, **`swaybg`**, **`cliphist`** are likewise
  exec'd unconditionally.
- **`jq` is mise-managed but called from the login session**, by
  `.config/sway/config`, both `.config/sway/scripts/*.sh` and
  `sway-start-on-workspace`, none of which has run `mise activate`. Found by
  [02](02-package-availability-survey.md), which excluded it as a packaging
  question precisely because it is a `PATH` assumption.
- **`chafa`, `kitten`, `metaflac` and `texlab`** are configured for and absent
  on the Ubuntu machine. `fzf-preview` degrades quietly to `bat` for every
  image, `organize_flac` aborts at its guard, nvim enables an LSP that never
  starts: three different answers to the same situation, in one repo.
- **`$monitor`** is an Iiyama serial number, and
  [`machine-independent-sway`](../../machine-independent-sway/spec.md) already
  decided that pointing at absent hardware is harmless. That precedent is the
  one to argue with: when is a broken `exec` harmless, and when is it a hole?

### To settle

1. **The rule.** For each assumption: absorb it into the package set so it
   becomes true, guard it with a Capability Probe, or leave it to fail because
   failing is harmless. What decides? A `sway exec` that fails costs nothing
   visible; a keybind that fails costs a keystroke and silence.
2. **Silent failure.** `machine-independent-sway` fixed a screenshot keybind
   that failed silently and lost the screenshot. The same shape probably repeats
   here. Which of the cases above fail silently, and does that change the answer
   for them?
3. **Whether a guard belongs in sway's config at all.** Sway's config language
   has no conditionals; the only guard available is moving the `exec` behind a
   shell script, which is what `wait-for-vpn` and `sway-start-on-workspace`
   already are. Multiplying one-line wrapper scripts is a cost, and this ticket
   should decide how much of it is acceptable rather than accepting it per case.

## Answer

### 1. The rule: the roster decides first, and it promises a Desktop

Two stages, and the first one is not about the case at all.

> **Stage 1.** What `packages/roster.md` promises is never probed away.\
> **Stage 2.** For what the roster does not promise, a probe is added only where
> the absence would be mistaken for success; otherwise the thing fails and the
> failure stands.

Stage 1 is the one that does the work. [04](04-package-set-form.md) made the
roster a tracked promise about what a machine has, and a probe placed around a
promised program turns a packaging hole into a silent degradation, which is
exactly the failure [08](08-completeness-check.md) exists to catch. A probe
there does not make the machine work, it makes the machine's incompleteness
invisible.

Stage 2 replaces the cost test the ticket proposed. Cost measures how much the
failure hurts; it does not measure whether anyone notices, and unnoticed is the
failure mode this repo has already been bitten by once. A session `exec` that
dies leaves a visible hole: no wallpaper, no bar, no tray. A command
substitution that fails inside a pipeline hands the next program a wrong
argument, and that program runs and produces a plausible wrong result. The
screenshot keybind in
[`machine-independent-sway`](../../machine-independent-sway/spec.md) was the
second shape, and section 6 below finds it here again, unfixed, for a different
reason.

**The Role clause.** The roster promises a **Desktop** machine. The map's Notes
put no packages on a Headless machine at all, so on Headless the roster promises
nothing, and stage 1 has nothing to stand on. The rule therefore reads:

> Stage 1 binds code that runs on Desktop only: `.config/sway/config`, the
> waybar modules, `.config/sway/scripts/`. Code that also runs on a Headless
> machine, which is everything under `.local/scripts/`, may not invoke the
> roster's promise and keeps adapting to what it finds.

This costs no new vocabulary: the Role is already the term for "true of the
machine however you reached it".

The ticket's nvim case falls out here. `lua/core/lsp.lua` enables seven servers
on both Roles, and six of them, `bashls`, `lua_ls`, `marksman`, `pyright`,
`ts_ls` and now `clangd`, come from `.config/mise/config.toml`, which is
Role-independent by construction. `texlab` is the seventh, and
[04](04-package-set-form.md) made it a pinned `cargo install --git ... --tag`
running after `bootstrap.sh`. That step needs mise's `rust` and nothing else, so
it is not a Desktop step: it runs on a Headless machine the same way, for a
person who writes LaTeX there. [05](05-install-route-and-manual-steps.md) lists
it in the Desktop route because that is the route it writes, not because the
Role bounds it. Where it has not been run, nvim starts six servers and not the
seventh, and that is left to stand: an editor without its language server is not
mistakable for one with it, and `:checkhealth lsp` names the missing binary to
anyone who asks. No probe enters the Lua.

The Role clause is also why `fzf-preview`'s Render Ladder survives unchanged.
`ffd`, `frg` and fzf-tab run in every shell on every Role, so `chafa` is a
Desktop promise and a Headless unknown at the same time, and the ladder's floor
is the correct answer to the unknown.

### 2. A Capability Probe adapts; a precondition check refuses

`AGENTS.md` requires of every script: "Validate what you were given: required
args present, paths exist, **commands on PATH**." Read naively, stage 1 above
deletes those checks. It does not, and the reason is that `CONTEXT.md` currently
has one term doing two jobs.

- A **precondition check** refuses. `require bat` in `fzf-preview`,
  `check_installation metaflac` in `organize_flac`, `command -v jq` in
  `sway-start-on-workspace` all print to stderr and exit. The script's behaviour
  does not change; it only does not happen. This is what `AGENTS.md` mandates,
  and stage 1 does not touch it.
- A **Capability Probe** adapts. `command -v chafa || return 1` picks a
  different renderer and carries on; `wait-for-vpn`'s two `gate_open`
  definitions wait for a different condition and carry on. The script produces a
  result either way, and which result depends on what it found.

Stage 1 forbids the second around a promised program, never the first.

The `CONTEXT.md` entry for **Capability Probe** should say so. Its current text,
"a runtime test for whether something is present right now ... letting one
shared executable adapt itself instead of branching on Role", already leans that
way but admits `command -v jq` in `sway-start-on-workspace` under the same
words, and that one is an abort. Two sentences to append to the entry, plus one
`_Avoid_` line:

```markdown
A Probe adapts: the code carries on and produces a different result. A check
that prints and exits is a precondition check, which `AGENTS.md` requires of
every script and which this term does not name. Where the roster promises the
program, only the precondition check is allowed: a Probe there would hide a
packaging hole that the completeness check exists to find.\
_Avoid_: ... , a `command -v` that exits (that is a precondition check, which
`AGENTS.md` requires of every script)
```

This is specified here and written with the build, like
[01](01-name-the-distro-divergence.md)'s glossary entry.

### 3. What the roster promises, and the one optional tier

The roster promises **the whole documented route**, not just what a package
manager installs: `dnf` and `apt` lines, Flatpak application ids, the pinned
satty tarball, the `cargo install --git` for texlab. A roster that promised only
packages would certify a machine on which `satty` is missing as complete, which
is 08 reading a list that does not describe the machine.

One tier is carved out of that. **Optional** holds what a machine may
legitimately lack, today exactly one entry, `protonvpn`: it is a third-party
source, and `wait-for-vpn` already treats its absence as a normal state rather
than a fault. Optional means two things at once, and they are the same statement
from both ends: 08 does not report it missing, and deployed code **may** probe
it, because stage 1's promise does not cover it.

**The tier gets its own file, `packages/optional.md`**, same three columns as
the roster. A second table inside `packages/roster.md` was the first answer and
is wrong: [04](04-package-set-form.md)'s install line is
`awk -F'|' 'NF>4 {...}' packages/roster.md`, which reads **every** table row in
that file, so a second table would hand `proton-vpn-cli` to `dnf` and `apt` like
any other row, and on a machine whose owner skipped the ProtonVPN source the
whole package install would fail. That awk was proven against a fixture in 04
and should not be reopened to carry an exception. A fourth `optional` column
fails for the same reason and adds a column filled once in forty rows. Dropping
the entry entirely was refused as well: its per-distro package names have to
live somewhere, and 08 would not know which single thing it must not report.

**This is a correction to [05](05-install-route-and-manual-steps.md).** Its
phase 1 step 2 enables the ProtonVPN source on both distros as an unqualified
step, and its phase 3 roster already carries "protonvpn: log in and configure
the network". Under this decision the source step is marked optional, and it is
followed by an optional install line of its own, the same `awk` extraction
pointed at `packages/optional.md` instead. Enabling a source and installing out
of it stay two verbs, as [04](04-package-set-form.md) split them; the optional
tier only gets its own pair. Nothing else in the route changes.

The tier is held to one entry on purpose. "Optional" is the word that turns
every package a machine happens to lack into an intention.

### 4. The session environment: measured, and left alone

The ticket called `jq` a `PATH` assumption. It is, and the measurement shows the
assumption is larger than `jq`.

Sway is started by SDDM, not from a login shell:

```
$ ps -o pid,args -p $(ps -o ppid= -p $(pgrep -x sway))
/usr/libexec/sddm-helper --socket ... --start start-sway --user hpark
$ tr '\0' '\n' < /proc/$(pgrep -P $(pgrep -x sway) | head -1)/environ | grep ^PATH=
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
```

`/usr/share/sddm/scripts/wayland-session` re-executes itself as
`$SHELL --login`, the login shell is `/usr/bin/zsh`, and a zsh login shell reads
`/etc/zshenv`, `/etc/zprofile` and `~/.zprofile`, but not `.zshrc`, because it
is not interactive. `mise activate` and `source ~/.envs.sh` both sit in
`.zshrc`, and the repo ships neither `~/.zprofile` nor `~/.zshenv`. So the
session sees neither mise nor `~/.local/scripts`.

**The rule, and it is a decision not to change anything:**

> The Sway session sees only what the system installed. Everything this repo
> ships is invoked from it by absolute path, and no `~/.zprofile` or `~/.zshenv`
> is added to widen that.

The absolute paths in `.config/sway/config` stop being a workaround and become
the stated answer. A `~/.zprofile` was weighed and refused on two counts. The
mise shim costs 44.5 ms against `/usr/bin/jq`'s 3.7 ms, measured over 20 runs
each, and `sway-start-on-workspace` pays it two to three times per window event
inside its IPC loop, three instances deep, exactly during session start. And the
direction is wrong: mise is the toolchain you write code with, the session is
what must come up so that you can, and a half-finished `mise install` would then
cost the login rather than a shell.

An ordering argument was considered and dropped as false:
[05](05-install-route-and-manual-steps.md) puts `bootstrap.sh desktop` in phase
2, "before the first graphical login", so mise and its tools are in place by the
time a session exists. The refusal rests on the cost and the direction alone.

**`jq` therefore gets a roster row on both distros, and keeps its mise entry.**
Those are not two truths about one program, they are two suppliers for two
consumers: the roster supplies the Sway session, mise supplies the shell on both
Roles, and on a Headless machine, where nothing is installed by package manager
at all, mise is the only supplier there is. No consumer pins a version: the
scripts use `has()`, `--argjson` and `$ARGS.positional`, all of which predate jq
1.6, so drift between the two is harmless.

The row is not cosmetic. On the reference machine `jq` is present by accident:

```
$ dnf repoquery --installed --qf '%{name} reason=%{reason}\n' jq
jq reason=Dependency
$ dnf repoquery --installed --whatrequires jq
clevis, dracut-network, grimshot
```

Nothing asked for it. On a machine where none of those three is installed, the
screenshot keybinds lose their output silently and `sway-start-on-workspace`
refuses, taking KeePassXC, Thunderbird and Obsidian with it.

### 5. Loudness: the hole is the message

Stage 2 lets things fail, which is only defensible if a failure can be found. It
can. Sway's `exec` children inherit its stderr, and that lands in the journal
under each child's own name:

```
$ journalctl -b | grep -iE 'waybar|fcitx'
Sep 20 23:43:55 hpark waybar[2017]: Not charging
Sep 21 00:03:43 hpark fcitx5[2049]: I2026-09-21 ... Running autosave...
```

So no third clause is added to the rule. The unprompted signal is the visible
hole; `journalctl -b` is there for whoever goes looking.

`notify-send` has a narrower job, and `wait-for-vpn` already draws the line
where this ticket wants it: it notifies at session start, but only on the branch
where it **refused** to start Thunderbird after its gate stayed shut. The rule
is therefore not about keystrokes versus session start, it is about who decided:
**a guard that refuses to do something notifies, because the hole it leaves says
nothing about why it is there.** Something that merely died leaves a hole that
speaks for itself and goes to the journal. `swaybg` failing needs no message;
`wait-for-vpn` declining to launch a mail client does, and so does a screenshot
keybind that refuses.

This also dissolves the contradiction the ticket saw at `protonvpn`.
`wait-for-clock` validates its command and exits loudly (`wait-for-clock:26`);
`wait-for-vpn` probes `protonvpn` and adapts (`wait-for-vpn:56`). Under section
2 these are different acts, and under section 3 `protonvpn` is the one optional
entry, so both are correct as they stand. The repo does not contradict itself
here; it was two terms short of being able to say so.

### 6. The screenshot keybinds become a script

`.config/sway/config:124` and `:125` are the repo's only place where a promised
program's absence still produces a plausible wrong result:

```
bindsym $mainMod+Shift+S exec grim -o $(swaymsg -t get_outputs | jq -r '...') - | satty -f -
```

A missing `jq` empties the command substitution, `grim` receives a bare `-o`,
and the screenshot is gone with nothing said. That is the
`machine-independent-sway` shape exactly, and the fix there was to stop losing
the output silently.

The answer is not a one-line wrapper but **a tracked script under
`.config/sway/scripts/`**, with its bats suite beside the others in
`.config/sway/scripts/tests/`. That directory is `AGENTS.md`'s own answer for
"what only the sway config starts, by path and never by name", which is exactly
what this is; `.local/scripts/` would contradict both that rule and this
ticket's own Role clause, which counts everything there as Role-crossing. The
script follows the conventions
[14](../../portable-dotfiles/issues/14-script-conventions.md) fixed. Two reasons
beyond the guard: a pipeline of `swaymsg`, `jq`, `grim`, `satty`, `date` and
`notify-send` in a config line is untestable by construction, and the two
bindings differ only in destination, so they are one script with an argument
rather than two copies. Sway keeps calling it by absolute path, per section 4.

**What it does when something is missing, which is the ticket's silent-failure
question:** `jq`, `grim` and `satty` are roster rows, so stage 1 applies and the
script **refuses** rather than adapting: precondition checks at the top, as
`AGENTS.md` requires of every script. The refusal does not stop at stderr. A
keystroke is a human waiting for a result, and section 5 puts `notify-send`
exactly there, so the script notifies and exits non-zero. It is the second guard
of that kind in the repo, `wait-for-vpn` being the first, and they follow the
same rule for the same reason.

This is the ticket's third question answered: no wrapper scripts are multiplied,
because stage 1 removes the need for them everywhere else.

### 7. clangd and clang-format leave the 12 GB tarball

[03](03-fedora-reference-inventory.md) found `clangd` coming from a hand
extracted LLVM tarball whose `PATH` line lives in `~/.env`, a file `.envs.sh`
documents as "machine-local secrets only". What it costs:

```
$ du -sh ~/.local/llvm
12G     /home/hpark/.local/llvm
```

Two programs are actually wanted from it: `clangd`, which `lua/core/lsp.lua`
enables, and `clang-format`, which `conform.lua` runs for `c` and `cpp`. The
compiler is not one of them; [04](04-package-set-form.md) already puts the four
toolchain rows in the roster, `gcc`, `gcc-c++`, `make` and `glibc-devel` on
Fedora against `build-essential` on Ubuntu, having explicitly refused the
`c-development` group.

**Both move into `.config/mise/config.toml`**, which keeps them rootless and
therefore available on a Headless machine too:

```toml
"github:clangd/clangd" = "22.1.6"
"pypi:clang-format" = "23.1.1"
```

The `github:` backend is not a reversal of [04](04-package-set-form.md): it
refused that backend for `texlab` "as a choice, not as an impossibility",
because the reference machine was already on the cargo route. `clangd` has no
such history and no registry entry either, so the backend is chosen here on its
own merits.

clangd comes from the project's own release, which
[releases.md](https://github.com/clangd/clangd/blob/master/releases.md)
describes as "just a zip archive containing the `clangd` binary, and the clang
builtin headers", statically linked and needing glibc 2.18. mise's `github`
backend extracts the archive whole, so the builtin headers come along, where
`ubi` would extract the binary alone and lose them. `clang-format` has no
official standalone release, so it comes from
[clang-format-wheel](https://github.com/ssciwr/clang-format-wheel) at 1.9 MB,
where a third-party repackaging is proportionate.

Verified end to end in a scratch directory, with `~/.local/llvm` off the `PATH`
and every mise write redirected into the scratch (`MISE_DATA_DIR`,
`MISE_CACHE_DIR`, `MISE_STATE_DIR`, `MISE_CONFIG_DIR`), the live install count
unchanged at 41 before and after, and nvim run against a copy of the real config
under scratch `XDG_*` directories:

- installed size 220 MB plus 4.2 MB, against 12 GB;
- `clang-format` formats against the repo's own `.clang-format`, from the
  terminal and through conform inside nvim;
- clangd attaches to a `cpp` buffer (`attached=clangd`, `bin=clangd`) and
  reports real diagnostics.

**One condition, and it is what the tarball was also silently supplying.** With
only the clangd release present, a `#include <vector>` reports
`'vector' file not found`; pointing clangd at a C++ standard library turns the
same file into the one true complaint,
`No member named 'puhs_back' in 'std::vector<int>'`. The standard library is not
clangd's to carry:

```
$ rpm -q gcc-c++ libstdc++-devel
package gcc-c++ is not installed
package libstdc++-devel is not installed
```

The reference machine has `gcc` but no C++ standard library, and
`~/.local/llvm/.../include/c++/v1` is where clangd has been finding one. So
**the roster's `gcc-c++` and `glibc-devel` rows, and `build-essential` on
Ubuntu, are load-bearing for clangd**, not merely for building things, and that
is a note for [04](04-package-set-form.md) and
[05](05-install-route-and-manual-steps.md) rather than a new decision. The same
rows absorb the second thing the tarball was quietly supplying:
[04](04-package-set-form.md) recorded `clang++` from `~/.local/llvm/` as the
machine's only C++ compiler, and it goes with the tarball, which is precisely
what that ticket's `g++` row is for. `~/.local/llvm` and the `~/.env` `PATH`
lines go with the move.

### 8. What the rule changes, file by file

Stage 1 with its Role clause has a quiet consequence: **the repo already obeys
the rule.** Every adaptation in it is either on a Role-crossing script
(`fzf-preview`'s ladder) or around the one optional entry (`wait-for-vpn`'s
`protonvpn` branch), and every other `command -v` is a precondition check that
section 2 keeps. The rule's value is forward-looking: it refuses the next
exception, and it tells 08 what the roster must carry.

What does change:

- **`.config/mise/config.toml`**: `jq` stays; `"github:clangd/clangd"` and
  `"pypi:clang-format"` are added.
- **`packages/roster.md`**: gains a `jq` row.
- **`packages/optional.md`**: new, holding the optional tier's one entry,
  `protonvpn`, out of reach of 04's install line. Section 3 is a correction to
  [05](05-install-route-and-manual-steps.md), whose phase 1 source step is
  marked optional.
- **`CONTEXT.md`**: the **Capability Probe** entry gains the two sentences and
  the `_Avoid_` line specified in section 2, without which the distinction this
  whole rule rests on exists only in this ticket.
- **`.config/sway/config`**: the two screenshot bindings become one call to a
  new `.config/sway/scripts/` script. Nothing else in the file changes; the
  unconditional `exec`s for `lxpolkit`, `swaybg`, `fcitx5`, `waybar`, `swaync`
  and `cliphist` are correct under stage 1, and `$monitor` stays as
  `machine-independent-sway` left it, because a preference list naming absent
  hardware is inert rather than broken.
- **`.config/sway/scripts/`**: gains the screenshot script, and
  `.config/sway/scripts/tests/` its bats suite.
- **Untracked, on the reference machine**: `~/.local/llvm` is removed and the
  two `PATH` lines leave `~/.env`, restoring that file to the purpose `.envs.sh`
  states for it.
- **Nothing else.** `fzf-preview`, `organize_flac`, `sway-start-on-workspace`,
  `wait-for-clock` and `wait-for-vpn` are correct as they stand.

Noted and deliberately not taken on here, because it is a standards gap rather
than an assumption about what is installed:
`.config/sway/scripts/swipe-workspace-inc.sh` and its `dec` twin carry neither
`set -euo pipefail` nor a precondition check, and call `swaymsg` and `jq`
unguarded. `AGENTS.md` requires both of every script. It belongs in whatever
change next touches those two files.

The roster must carry what the Desktop session and the keybinds invoke, which
the survey already priced: `lxpolkit`, `swaybg`, `swayidle`, `swaylock`,
`fcitx5`, `waybar`, `swaync`, `cliphist`, `wl-clipboard`, `keepassxc`,
`flatpak`, `ghostty`, `thunar`, `fuzzel`, `librewolf`, `grim`, `satty`, `jq`,
`wpctl`, `brightnessctl`, `libnotify`, `blueman`, `playerctl`,
`nm-connection-editor`, `pavucontrol`, `htop`, plus `chafa`, `kitty-kitten`,
`flac` and `ffmpeg` for the scripts.

`imv` leaves this ticket. Nothing in the repo invokes it: `rg -l '\bimv\b'` over
the tree, excluding `.git` and `.scratch`, is empty, and `.config/imv/config` is
a config file rather than a call. The `imv` versus `imv-wayland` divergence is a
roster row and an [08](08-completeness-check.md) question about names, which is
where [02](02-package-availability-survey.md) already put its 27 siblings.
