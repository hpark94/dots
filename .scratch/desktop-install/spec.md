Status: ready-for-agent

# Desktop install: from a bare Fedora or Ubuntu install to a working Desktop

## Problem Statement

The repo deploys onto a machine that already has its programs. `README.md`'s
four steps (packages, clone, token, `bootstrap.sh`) are right for a re-deploy
and wrong for a bare distro install: nothing says which programs a Desktop
needs, what they are called on each distro, which third-party sources supply
them, or which steps no script can take. The Fedora ZenBook works because it was
assembled by hand; the Ubuntu EliteBook is a copy with holes, and nothing can
tell a complete machine from an incomplete one.

Underneath that, the configs make assumptions nobody wrote down: the Sway
session sees only system packages yet calls a mise-managed `jq`, the screenshot
keybinds lose their output silently when `jq` is missing, the charge-limit
keybind calls a `sudo` script that is tracked nowhere, and clangd, clang-format
and clang-tidy come from a 12 GB LLVM tarball on a `PATH` line in `~/.env`.

This spec is the write-up of the map
[From a clone to a working Desktop on Fedora and Ubuntu](../distro-provisioning/map.md).
Every decision below is taken from one of its tickets, linked where it is used;
the reasoning stays there and is not repeated here.

## Solution

- A **package set** as repo-local data: `packages/roster.md` (one table,
  `binary | fedora | ubuntu`), `packages/optional.md` (the one optional entry)
  and `packages/flatpak.txt` (two application ids), none of them deployed.
- An **install document**, `docs/install.md`: one route in three phases, the two
  distros as command blocks inside the steps that differ, foreign sources as a
  link plus facts and never as a command, and a list of per-machine steps.
- A **completeness check**, `completeness-check.sh`, run by hand out of the
  clone: it asserts presence, never correctness, of what the roster, the Flatpak
  list and the manual steps promise.
- Two **session scripts** under `.config/sway/scripts/` replacing inline
  pipelines and the only `sudo` in the repo: one for screenshots, and
  `battery-charge-limit`, which drives UPower over D-Bus without root.
- **clangd, clang-format and clang-tidy move into mise**, and the LLVM tarball
  leaves the reference machine.
- **Vocabulary**: Distro Fact, a sharper Capability Probe (a probe adapts, a
  precondition check refuses), Completeness Check, and ADR-0011
  `the-deployed-tree-never-reads-the-distro`.

## User Stories

1. As the dotfiles owner, I want to take either Desktop machine from a bare
   distro install to a working machine by following one document, so that a
   reinstall does not depend on what I remember.
2. As the dotfiles owner, I want the package names for both distros kept in one
   table next to the command each one supplies, so that the 27 cases where a
   package name does not name its binary are written down once.
3. As the dotfiles owner, I want to ask a machine whether it has everything the
   repo promises and get a short report with the missing entries named, so that
   a manual step that silently stopped working gets noticed.
4. As the dotfiles owner, I want the screenshot keybinds to tell me when they
   cannot work, so that a missing program never loses a screenshot silently.
5. As the dotfiles owner, I want to lift the battery charge limit before a trip
   with one keystroke and no password, and have it come back at the next login,
   so that a forgotten full-charge state does not wear the battery for months.
6. As the dotfiles owner, I want the C/C++ tooling nvim uses to come from the
   toolchain file, so that it is the same on every machine and a 12 GB tarball
   is not load-bearing.
7. As the dotfiles owner, I want deployed code never to ask which distro it runs
   on, so that a difference between distros is handled once, at install time, by
   a person.

## Implementation Decisions

Each subsection is a requirement set; the link names the map ticket that decided
it.

### Nothing deployed reads the distro

From
[Name the distro divergence](../distro-provisioning/issues/01-name-the-distro-divergence.md).

- No deployed file reads `/etc/os-release` or branches on the distro. The ban
  ends at what stow deploys: `packages/` and `docs/install.md` are distro-keyed,
  and a human selects which part applies. No install artifact reads `os-release`
  either. A vendor command quoted in a documented step (ProtonVPN's reads
  `/etc/fedora-release`) is not a violation.
- There is no Distro Marker.
- Where deployed code must adapt to what is installed, it uses a Capability
  Probe on the thing itself.
- **ADR-0011 `the-deployed-tree-never-reads-the-distro`** records this,
  including the two refused alternatives: reading `os-release` in deployed code,
  and reading it inside an install artifact. 01 specified its content, not its
  text: the decision and its grounds are 01 sections 2 to 5, and the ADR is
  written from those.
- **`CONTEXT.md`, under Deployment, next to Role Fact**, verbatim:

  ```markdown
  **Distro Fact**:\
  A difference between the distributions in how a program is obtained: the
  package name (`bind-utils` versus `bind9-dnsutils`), the repository it comes
  from, whether it needs a third-party source, or whether it can be had at all.
  Answered once, when a machine is installed, against whatever the archives hold
  that day, and the one kind of divergence that never reaches a deployed file:
  it is absorbed at install time into the package sets and the documented steps,
  both of which live outside what stow deploys, and a human picks which of them
  applies. Nothing reads `/etc/os-release`, and there is no Distro Marker:
  unlike the Role, a distribution is discoverable, so a written copy would be a
  second answer to a question that already has one, with no reader. What the
  machine ends up having as a result is not a Distro Fact: `imv-wayland` in
  place of `imv`, or a missing `chafa`, is a Capability Probe's question,
  indistinguishable from a program you simply did not install.\
  _Avoid_: Package Route (`satty` is in neither archive and is a Distro Fact all
  the same), Install Fact, distro detection, `ID_LIKE`
  ```

### A probe adapts, a precondition check refuses

From
[What the configs must stop assuming](../distro-provisioning/issues/06-config-assumptions.md),
sections 1 and 2.

- What `packages/roster.md` promises is never probed away. For anything else, a
  probe is added only where the absence would be mistaken for success.
- The roster promises a Desktop: this binds `.config/sway/config`, the waybar
  modules and `.config/sway/scripts/`. Everything under `.local/scripts/` runs
  on both Roles and keeps adapting to what it finds.
- Precondition checks (`AGENTS.md`'s "commands on PATH") stay everywhere.
- **`CONTEXT.md`, the Capability Probe entry** gains these two sentences at the
  end of its body, before `_Avoid_`:

  ```markdown
  A Probe adapts: the code carries on and produces a different result. A check
  that prints and exits is a precondition check, which `AGENTS.md` requires of
  every script and which this term does not name. Where the roster promises the
  program, only the precondition check is allowed: a Probe there would hide a
  packaging hole that the completeness check exists to find.\
  ```

  and its `_Avoid_` line becomes:

  ```markdown
  _Avoid_: feature detection, the distro's name (a proxy for presence, and a
  wrong one), a `command -v` that exits (that is a precondition check, which
  `AGENTS.md` requires of every script)
  ```

### The package set

From
[Where the package sets live and in what form](../distro-provisioning/issues/04-package-set-form.md),
with the corrections of 06, 07, 08 and this handoff.

- `packages/roster.md`: one flat Markdown table `binary | fedora | ubuntu`,
  sorted by the first column. Its header carries four statements: the set is
  Desktop; the first column is a command name, not a package name; a `-` in a
  package column means this install line does not install it, while a `-` in the
  first column means the row leaves no command on `PATH`; package names may
  repeat down a column.
- Membership: what the tracked files invoke, exactly as
  [the survey](../distro-provisioning/research/02-package-availability.md)
  derived it, plus the four toolchain rows (`gcc`, `g++`, `make`, and `-` for
  `glibc-devel`; `build-essential` on Ubuntu in all four). Not what the
  reference machine happens to have.
- Corrections that are in none of 04's text and must be applied:
  - **`jq`** gets a row on both distros and keeps its mise entry (06 section 4).
  - **`upower`** gets a row (07 section 8).
  - **`imv`** gets the row `imv-wayland | imv | imv`: the command both
    distributions ship (decided in this handoff; 06 had handed it on and 08 left
    it open).
  - **No `texlab` row** (08 section 10): it is a manual `cargo install`.
  - **No `protonvpn` row**: it lives in `packages/optional.md`.
  - **No clang tools rows**: they come from mise (see below).
  - No `slurp` and no `battery-threshold-toggle` row: nothing invokes either.
- `-` in the first column for `sway-systemd`, the two portals, the fcitx5 IM
  modules, `python3-i3ipc`, the zathura PDF backend and `glibc-devel`. `ffmpeg`
  on Fedora and `satty` on Ubuntu carry `-` in their package column.
- `packages/optional.md`: same three columns, one row,
  `protonvpn | proton-vpn-cli | proton-vpn-cli`, and a header saying that
  nothing promises what it lists (06 section 3).
- `packages/flatpak.txt`: `org.mozilla.thunderbird` and `md.obsidian.Obsidian`,
  one per line.
- `.stow-local-ignore` gains `^/packages`.
- The install lines, verbatim from 04 section 3 (the optional one is the same
  `awk` pointed at `packages/optional.md`):

  ```sh
  sudo dnf install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $3); if ($3 !~ /^-*$/ && $3 != "fedora") print $3}' packages/roster.md | sort -u)
  sudo apt install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $4); if ($4 !~ /^-*$/ && $4 != "ubuntu") print $4}' packages/roster.md | sort -u)
  ```

### The Sway session sees only the system

From
[What the configs must stop assuming](../distro-provisioning/issues/06-config-assumptions.md),
sections 4 to 6.

- No `~/.zprofile` or `~/.zshenv` is added. Everything the repo ships is called
  from the sway config by absolute path.
- The two screenshot bindings (`.config/sway/config:124` and `:125`) become one
  tracked script under `.config/sway/scripts/` with a bats suite in
  `.config/sway/scripts/tests/`. One argument selects the destination: satty, or
  a timestamped PNG in a directory the sway config passes (its `$screenshots`),
  with a success notification as today. The name follows the pattern 07 set for
  `battery-charge-limit`: the noun names the file, the verb is a required
  argument.
- It refuses rather than adapts when a roster program (`swaymsg`, `jq`, `grim`,
  `satty`) is missing: precondition checks at the top, message on stderr,
  `notify-send`, non-zero exit. A keystroke is a human waiting, so a refusal
  notifies.
- Its strings are English; the German "Gespeichert in" goes.
- Not in scope: `swipe-workspace-inc.sh` and `-dec.sh` (06 section 8 names their
  standards gap for whichever change next touches them).

### The charge limit without sudo

From
[The battery threshold keybind and its missing script](../distro-provisioning/issues/07-battery-threshold-keybind.md).

- `.config/sway/scripts/battery-charge-limit` with a required verb, and a bats
  suite that stubs `busctl` on `PATH`.
- The device is enumerated with `EnumerateDevices`, never named: the one whose
  `ChargeThresholdSupported` is true. None found is a refusal.
- `toggle` reads `ChargeThresholdEnabled` and calls `EnableChargeThreshold` with
  its inverse. It notifies on success, naming the new state, and on refusal.
- `restore` calls `EnableChargeThreshold true`. It never notifies.
- A refusal writes to stderr and exits non-zero on both verbs. `busctl` gets a
  precondition check; it ships in `systemd` and needs no roster row.
- The sway config:
  ```
  bindsym Control+Alt+p exec ~/.config/sway/scripts/battery-charge-limit toggle
  exec ~/.config/sway/scripts/battery-charge-limit restore
  ```
  replacing `bindsym Control+Alt+p exec sudo battery-threshold-toggle`.
- The persistent cap is a manual step, not repo code (see the install document).

### C/C++ tooling from mise

From
[What the configs must stop assuming](../distro-provisioning/issues/06-config-assumptions.md)
section 7, extended in this handoff to `clang-tidy`, which `nvim-lint.lua:15`
runs and which also came from the tarball.

- `.config/mise/config.toml` gains:
  ```toml
  "github:clangd/clangd" = "22.1.6"
  "pypi:clang-format" = "23.1.1"
  "pypi:clang-tidy" = "22.1.8"
  ```
- clangd needs a C++ standard library from the system. The roster's `gcc-c++`
  and `glibc-devel` rows (`build-essential` on Ubuntu) supply it.

### The install document

From
[The install route and where the manual steps are written](../distro-provisioning/issues/05-install-route-and-manual-steps.md),
with the corrections of 06 and 07.

- `docs/install.md`, one file. Shared steps are written once, and the distros
  appear as command blocks inside the steps that differ.
- Phase 1 changes the system, with `sudo` on each command except the clone, and
  no root shell: cloning as root leaves a root-owned working tree.
  1. `git clone <repo-url> ~/dots && cd ~/dots`. The `cd` is part of the step.
  2. Enable the foreign sources: Terra, RPM Fusion and LibreWolf on Fedora,
     LibreWolf on Ubuntu. **ProtonVPN, on both distros, is marked optional** and
     is followed by its own optional install line reading
     `packages/optional.md`.
  3. The native package set (the install line above).
  4. Fedora only: `sudo dnf swap ffmpeg-free ffmpeg --allowerasing` and
     `sudo dnf update @multimedia`.
  5. Ubuntu only: satty v0.22.0 from the pinned release, verbatim from 05
     section 8 (`Satty-org/Satty`, member `./satty`, into `/usr/local/bin`).
  6. Add the flathub remote and install `packages/flatpak.txt` system-wide, with
     the two commands from 05 section 2.
- Phase 2 prepares the home before the first graphical login: `font-install` by
  path, `chsh -s "$(command -v zsh)"`, `export GITHUB_TOKEN=<token>`,
  `~/dots/bootstrap.sh desktop`.
- Phase 3 needs a session: log in to Sway, then
  `cargo install --git https://github.com/latex-lsp/texlab --tag v5.26.0 --locked`.
  The document says why the login comes first: it is what puts mise's `cargo` on
  `PATH`.
- A foreign source is written as a link plus facts and never as a command (05
  section 7), with the three deviations: Terra's `--nogpgcheck` on the release
  RPM, LibreWolf's `.repo` against the vendor's current `addrepo` command, and
  ProtonVPN's page installing the GUI metapackage where the binary comes from
  `proton-vpn-cli`.
- Per-machine steps, in any order, after phase 3:
  - protonvpn, optional: log in and configure.
  - Syncthing: install, enable the user unit, `mkdir ~/Sync ~/projects`, pair.
    Sway's wallpaper appears only after that.
  - The KeePassXC database in its place.
  - fcitx5: per-language configuration.
  - `~/.ssh/config` with `Include ~/.config/ssh/config.shared`.
  - The charge limit, on a machine whose UPower reports
    `ChargeThresholdSupported`: create `/etc/udev/hwdb.d/61-battery-local.hwdb`
    holding
    ```
    battery:*:*:dmi:*
     CHARGE_LIMIT=_,60
    ```
    then `systemd-hwdb update` and
    `udevadm trigger -v /sys/class/power_supply/BAT0`.
- A short HP paragraph: `hp-wmi` exposes no threshold. Include the commands that
  settle this on an HP machine, from
  [the mechanism survey](../distro-provisioning/research/07-charge-threshold-mechanisms.md),
  section "Commands to settle it on the EliteBook".
- No per-machine checklist (05 section 10).
- The last line names `completeness-check.sh`.
- `README.md` (05 section 9): the intro and Key Highlights stay as they are. The
  Installation section keeps its steps and says they apply to a machine whose
  packages are already in place. One sentence points a bare distro install at
  `docs/install.md`.

### The completeness check

From
[A completeness check for a machine](../distro-provisioning/issues/08-completeness-check.md).

- `completeness-check.sh` at the repo root, run by path, with no arguments and
  no flags. `.stow-local-ignore` gains, verbatim:
  ```
  # completeness-check.sh is run by path from the clone root, never symlinked
  # into $HOME: it reads packages/, which stow does not deploy.
  ^/completeness-check\.sh$
  ```
- Functions behind the source guard `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`. The
  suite is `.local/scripts/tests/completeness-check.bats`.
- **Roster section**: per row, `command -v` on the first column. If the first
  column is `-`, the package column is queried instead: `rpm -q`, or
  `dpkg-query -W -f='${db:Status-Status}'` requiring `installed` (exit 1 means
  missing; exit 2 is a refusal). `-` in both columns means not checkable. The
  package manager is picked by a Capability Probe on `rpm` and `dpkg`, never by
  reading the distro.
- **Flatpak section**: `flatpak info <id>` per line, whatever the scope. If
  `flatpak` is absent, the entries are not checkable.
- **Manual-steps section**: exactly five entries, held in the script: `~/Sync`
  (directory), `~/projects` (directory),
  `~/Sync/.pictures/wallpaper/frieren.jpg` (file), the `Include` line in
  `~/.ssh/config`, and `/etc/udev/hwdb.d/61-battery-local.hwdb` (file). The last
  one only where an enumerated UPower device reports `ChargeThresholdSupported`;
  otherwise it counts as `not supported on this machine`. UPower is never read
  for the threshold value.
- Report on stdout in both outcomes, per section: the missing named, the present
  counted, the not checkable counted, adding up to the entry count. One closing
  line points at `docs/install.md`, with no remedy per entry. Exit 1 if anything
  is missing.
- Refusals, stderr and exit 2: no Role Marker, a Headless machine, both package
  managers present or neither, no `busctl` on `PATH`, and a `dpkg-query` exit 2.
- It does not read `packages/optional.md`, it changes nothing, and
  `bootstrap.sh` does not call it.
- **`CONTEXT.md`, under Deployment, after Capability Probe**, verbatim:

  ```markdown
  **Completeness Check**:\
  The answer to "is everything that should be here actually here", asked of one
  machine, by a human, and by nothing else: `completeness-check.sh`, run by path
  out of the clone because the package set it reads is not deployed. It asserts
  **presence and never correctness**, so it reports that `~/Sync` exists and
  never that Syncthing has paired. Its package sections take their membership
  from the package set, every promised name, loud absence or not; its third
  section, the manual steps, has a rule of its own, that nothing else on the
  machine would notice the absence, which is what keeps `bootstrap.sh`'s own
  output out of it: that script guards every step and is safe to re-run, so
  re-running it is the cheaper and more honest check of what it produced. For a
  path there is a second half, that a tracked file names it, which is why the
  wallpaper is checked and the KeePassXC database is not. Deliberately neither a
  second `bootstrap.sh`, since it installs nothing and changes nothing, nor a
  lint of the repo against itself, since a roster missing a row leaves it
  honestly green.\
  _Avoid_: doctor, health check, audit, verify (each names a habit borrowed from
  another tool rather than the question this one asks)
  ```

- `AGENTS.md` gains a row for it in Commands.

### Manual steps on the reference machine

Untracked and one-off: they touch no file in this repo, apply to the ZenBook
only, and are not part of `docs/install.md`, because a bare install has nothing
to remove.

- `~/.local/llvm` is removed and its two `PATH` lines leave `~/.env`, once mise
  supplies clangd, clang-format and clang-tidy (06 section 7).
- The four legacy charge-limit artifacts are removed by hand once the hwdb file
  is in place: `/usr/local/bin/battery-threshold-toggle`, its sudoers rule,
  `battery-threshold.service` and `/etc/battery-threshold-mode` (07 section 3;
  locations in 03 section 6).

## Testing Decisions

- Every new script gets a bats suite that stubs its external commands on `PATH`,
  following `wait-for-vpn.bats`. Nothing touches D-Bus, the package database or
  `/etc` for real.
- The install lines are checked against the real `packages/roster.md` and
  `packages/optional.md` after `prettier -w`: each yields the expected names per
  distro, and no header, separator or `-` leaks through.
- The mise move is proved in a scratch directory with `~/.local/llvm` off `PATH`
  and every mise directory redirected, as 06 section 7 did, now with clang-tidy
  running through nvim-lint as well.
- The keybind, `restore` and the hwdb step are verified live on the ZenBook in
  the migration ticket, not in a suite.

## Out of Scope

Carried over from the map's
[Out of scope](../distro-provisioning/map.md#out-of-scope): Arch, packages on
Headless, keeping machines in sync over time, a lint of the repo against its own
roster, macOS and containers. Also:

- Any further rewrite of `README.md` beyond 05 section 9's two sentences.
- The standards gap in `swipe-workspace-inc.sh` and `-dec.sh`.
- An EliteBook charge limit: `hp-wmi` offers none (07 section 6).

## Further Notes

- Linked inputs that decide nothing:
  [the survey](../distro-provisioning/research/02-package-availability.md) is
  the source for the roster's rows and names, with one correction: satty lives
  at `Satty-org/Satty` (05 section 8).
  [The reference inventory](../distro-provisioning/issues/03-fedora-reference-inventory.md)
  is the source for the ZenBook's legacy artifacts.
- Order: the package set comes before the completeness check and the install
  document, because both read `packages/roster.md`. The ZenBook migration comes
  last, because it removes what the new pieces replace.
