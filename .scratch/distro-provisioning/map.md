# Map: From a clone to a working Desktop on Fedora and Ubuntu

**Label:** `wayfinder:map`

## Destination

A decided route for taking either real Desktop machine, the Fedora ZenBook and
the Ubuntu EliteBook, from a bare distro install to a working machine: which
programs a Desktop needs, how each one is installed on each distro, what stays
manual and where that is written down, and what the existing configs must stop
assuming. Reached when all of that is settled and written up as implementable
specs. Nothing is built here.

## Notes

- **Domain:** personal dotfiles, single context. Read `CONTEXT.md` first, above
  all Role, Role Fact, Session Fact and Capability Probe.
- **The preceding map is settled and is not reopened.**
  [`portable-dotfiles`](../portable-dotfiles/map.md) decided the Role split,
  stow as the deployment mechanism, and `bootstrap.sh`. This map starts where
  that one stopped: it never asked which distro the machine runs.
- **Planning only.** Tickets resolve decisions; the building happens afterwards
  through the normal `.scratch/<feature>/spec.md` + `issues/` flow. Deciding
  what a document must say is planning; writing that document is not.
- **Fedora is the reference.** The ZenBook is the machine that works; the
  EliteBook is the copy with holes. Where the two disagree about what a complete
  machine has, Fedora is right until a ticket says otherwise.
- **`bootstrap.sh` stays sudo-free.** Package installation is a step in front of
  it, never a step inside it. This keeps the bats suite runnable without root
  and keeps `bootstrap.sh` usable on a Headless machine.
- **Flatpak, never snap.** A snap is an Ubuntu-only answer that Fedora cannot
  reproduce, so it would create a per-distro special case by construction.
- **Third-party sources are documented, never scripted.** A script that adds
  foreign repositories and GPG keys is the one piece that fails quietly and
  changes the system underneath you.
- **Headless installs no packages at all.** There is usually no sudo on those
  machines, so the whole packaging question is a Desktop question.
- **`~/Sync` and `~/projects` are created by hand.** Both are Syncthing folders.
  Nothing in this repo creates them, and several things point into them, so
  their creation is a documented manual step.
- **The input method stays fcitx5.** It is the one that works under sway, so no
  ticket weighs alternatives; only its packaging and configuration are open.
- **Fonts are `font-install` plus a stowed `.config/fontconfig/`.** Settled, so
  fonts are a step in the install route rather than a decision.
- **`README.md` is not rewritten by this map.** It is renewed once the work is
  built, or on explicit command.
- **Skills:** `/grilling` and `/domain-modeling` by default, `/research` for the
  survey.
- **Style:** no em dashes. Conversation in German, everything written down in
  English.

## Decisions so far

<!-- one line per resolved ticket: gist plus link. Zoom the link for detail. -->

- [The install route and where the manual steps are written](issues/05-install-route-and-manual-steps.md):
  one file, `docs/install.md`, shared steps once and the two distros as command
  blocks inside the step that differs. The route is **three phases cut by what
  each one needs**, and the ticket's own rough shape was out of order: **the
  clone comes first**, because the install line reads `packages/roster.md` and
  the source steps live in the same tree, and **nothing precedes it**, `git`
  being assumed and written down nowhere. A foreign source is **a link plus
  three facts and no command**, which costs the copy-paste and buys one rule
  instead of one exception per vendor. Two steps existed nowhere before:
  **`chsh`**, because the login shell is set by no tracked file, and logging in
  to Sway, which turns out to be load-bearing rather than cosmetic because it is
  what puts mise's toolchain on the `PATH` for the texlab build after it.
  `font-install` runs in phase 2 and `bootstrap.sh` does not call it, on
  [04](issues/04-package-set-form.md)'s Role argument rather than a new one;
  Flatpaks are system wide, and satty on Ubuntu is a pinned tarball. `README.md`
  keeps its four steps, re-scoped to a machine that already has its packages.
  **No checklist**: rot is [08](issues/08-completeness-check.md)'s job alone,
  and section 10 says what that now obliges it to cover.

- [Where the package sets live and in what form](issues/04-package-set-form.md):
  the artifact is `packages/roster.md`, one flat Markdown table of
  `binary | fedora | ubuntu`, beside `packages/flatpak.txt` for application ids,
  both repo-local behind a new `^/packages` line in `.stow-local-ignore`. The
  set lists the **roster and not the machine**, plus a second clause for what
  the toolchain needs to build: four rows, where Fedora's `development-tools`
  turns out to hold no compiler at all and `c-development` is the real
  counterpart to `build-essential`. The boundary rule has **two sides and the
  split is the verb**: enabling a source is
  [05](issues/05-install-route-and-manual-steps.md)'s, installing out of it is
  the set's, and anything that is not a plain package install is a manual step.
  A third side, "mise owns it", was dropped when its only candidate left:
  **`texlab` is a pinned `cargo install --git ... --tag` that runs after
  `bootstrap.sh`**, chosen over the `github:` backend, which pins just as well,
  and over `cargo:texlab`, which is stale at 4.3.2. `bootstrap.sh` installs no
  Flatpaks either, so packaging stays in front of it without exception. Measured
  in passing: the ZenBook has no `g++`, and its only C++ compiler is the
  untracked LLVM tarball that also supplies clangd.

- [What the Fedora reference machine actually has](issues/03-fedora-reference-inventory.md):
  the inventory, taken on the ZenBook itself, so the ticket's premise that the
  machine is unreachable is gone. Four things in it change what the open tickets
  face: only `dnf history` separates the live ISO's packages from this machine's
  own, **Terra** is a fifth source the survey never queried and is where `satty`
  and `ghostty` come from, `clangd` and `texlab` come from no package at all
  here, and the battery threshold is four artifacts rather than one. Read it
  before [04](issues/04-package-set-form.md),
  [05](issues/05-install-route-and-manual-steps.md),
  [06](issues/06-config-assumptions.md) or
  [07](issues/07-battery-threshold-keybind.md).

- [Program roster and package availability survey](issues/02-package-availability-survey.md):
  the roster is derived from the tracked files and priced on both distros in
  [the survey](research/02-package-availability.md). The `imv` case is a class,
  not a quirk: **27 rows where the package name does not name the binary or the
  two distros disagree**, which is the whole difficulty of
  [08](issues/08-completeness-check.md) in one table. `satty` has **no
  repository route on either distro**, Flathub included. `texlab` and `ghostty`
  reverse the map's premise by being in Ubuntu's universe and in no Fedora
  repository, so on Fedora the terminal itself is a third-party source. Fedora's
  `zathura` installs **without a PDF backend** because the backend is a Suggests
  there and a Depends on Ubuntu. Ubuntu's `thunderbird` is a snap transition
  stub, which the Flatpak-never-snap rule rules out by construction. Found in
  passing: `slurp` is invoked nowhere in the repo, and `jq` is called from the
  login session while mise owns it, which moved to
  [06](issues/06-config-assumptions.md) as a `PATH` assumption.

- [Name the distro divergence](issues/01-name-the-distro-divergence.md): a
  Fedora-versus-Ubuntu difference is a **Distro Fact**, the far end of the
  spectrum the other three terms sit on: it **never reaches a deployed file**.
  The seam has **two places and not three**: how a program gets onto the machine
  is absorbed before deployment into the package sets and the documented steps,
  and where deployed code has to adapt to what is on the machine afterwards it
  uses a **Capability Probe**. The third candidate, "tolerate the absence", is a
  judgment about what a failure costs and belongs to
  [06](issues/06-config-assumptions.md) rather than a place. Nothing reads
  `/etc/os-release`, confirmed by grep and now a rule; the ban ends at what stow
  deploys, so install artifacts are distro-keyed but **a human selects them**,
  and reading `os-release` inside one was refused too. **No Distro Marker**,
  explicitly, because unlike the Role a distribution is discoverable and the
  copy would have no reader. The `CONTEXT.md` entry and **ADR-0011
  `the-deployed-tree-never-reads-the-distro`** are specified here and written
  with the build.

## Not yet specified

In scope, but not yet sharp enough to ticket. Graduates as the frontier
advances.

Empty. The four patches charted here were all settled in the same session:
`~/Sync` and `~/projects` and the fcitx5 and font steps became input to
[05](issues/05-install-route-and-manual-steps.md), and the completeness check
graduated into [08](issues/08-completeness-check.md).

## Out of scope

Beyond the destination. Never graduates; returns only if the destination is
redrawn, and then as a fresh effort.

- **Arch.** Named in the opening idea, ruled out while naming the destination:
  no Arch machine exists to verify anything against, so every Arch decision
  would be a guess. Decisions here should not actively block a third distro, but
  none of them is made for one.
- **Package installation on Headless machines.** No sudo there, so nothing to
  decide.
- **Keeping the machines in sync over time.** Drift detection between two
  machines that were both installed correctly is a different problem from
  installing them.
- **macOS, containers and ephemeral devboxes**, inherited from
  [`portable-dotfiles`](../portable-dotfiles/map.md).
- **Implementing any decision this map makes.** Planning only, per Notes.
- **Rewriting `README.md`.** Its install section is wrong on a bare distro
  install, and [05](issues/05-install-route-and-manual-steps.md) decides what
  replaces it, but the rewrite itself waits for the build or for an explicit
  command.
