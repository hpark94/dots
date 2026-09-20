# 05 The install route and where the manual steps are written

**Type:** `grilling`

**Status:** resolved

**Blocked by:**
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md),
[04 Where the package sets live and in what form](04-package-set-form.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`README.md` today claims a fresh machine is four steps: install `git` and
`stow`, clone, export a token, run `bootstrap.sh`. That is false on a bare
distro install, where none of sway, waybar, foot, ghostty or the Flatpaks
exists, and the session will not even start.

What is the **real route**, in order, and where is it written?

### To settle

1. **The ordered route**, from a bare install to a working machine. Rough shape,
   to be corrected rather than accepted: enable the third-party sources the
   survey found, install the native package set, install the Flatpaks, clone,
   `bootstrap.sh`, then the steps only a human can do.
2. **The manual step roster.** Everything that stays a human action. Known so
   far: protonvpn login and network configuration (the opening idea called this
   out explicitly), Syncthing installation and pairing, **creating `~/Sync` and
   `~/projects` by hand** (both are Syncthing folders that nothing in this repo
   creates, and `.config/sway/config` points `$wallpaper` and `$screenshots`
   into the first while `tmux-sessionizer` searches the second), the GitHub
   token `bootstrap.sh` already demands, the KeePassXC database, fcitx5's own
   per-language configuration, the `Include ~/.config/ssh/config.shared` line
   that [12](../../portable-dotfiles/issues/12-ssh-config-ownership.md) decided
   is always manual, plus whatever [03](03-fedora-reference-inventory.md) turns
   up.
3. **Where `font-install` sits in the route.** Fonts are settled: the script
   plus the stowed `.config/fontconfig/`. What is open is only whether the route
   calls it before or after `bootstrap.sh`, and whether `bootstrap.sh` should
   call it at all. Note it needs `curl`, `unzip` and `fc-cache`, which makes it
   a step that depends on the package set having run.
4. **Where it lives.** `README.md`, a `docs/install/` set, one file per distro,
   or one file with per-distro sections? Note that `.stow-local-ignore` already
   keeps `docs/` out of `${HOME}`, and that `README.md` is the file a stranger
   reads first while this document is written for exactly one reader.
5. **What `README.md` will say.** Its current install section is wrong on a bare
   distro install. The rewrite is deliberately not this map's work, but this
   ticket must still decide what the new documents leave to `README.md`, so that
   the eventual rewrite is a transcription rather than another decision.
6. **How a manual step is written so it survives.** A step that is done once per
   machine and never again is a step whose instructions rot unnoticed. Is there
   a form that makes rot visible, for instance a checklist the operator ticks
   per machine, or is that over-engineering for two machines?

## Answer

### 1. One document, `docs/install.md`, and no new ignore line

One file, with the shared steps written once and the two distros appearing as
command blocks inside the step that differs. Roughly four fifths of the route is
shared, clone, token, `bootstrap.sh`, texlab and every per-machine manual step,
so two files would duplicate that and drift. The divergence sits where
[04](04-package-set-form.md) already put it: in the commands, not in the steps.

`docs/` rather than `packages/`, for the same reason 04 gave in reverse: this is
prose a person reads, and `packages/` holds data an install command reads.
`^/docs` is already in `.stow-local-ignore`, so unlike `packages/` this costs no
line there.

### 2. The route, in three phases, cut by what each one needs

```
Phase 1, changes the system, sudo per command rather than a root shell
 1. git clone <repo-url> ~/dots && cd ~/dots
 2. Enable the foreign sources: Terra, RPM Fusion, LibreWolf, ProtonVPN (Fedora)
    LibreWolf, ProtonVPN (Ubuntu)
 3. The native package set
 4. Fedora only: the ffmpeg swap
 5. Ubuntu only: satty from the pinned release
 6. Add the flathub remote, install packages/flatpak.txt system wide

Phase 2, prepares the home, before the first graphical login
 7. ~/dots/.local/scripts/font-install
 8. chsh -s "$(command -v zsh)"
 9. export GITHUB_TOKEN=<token>
10. ~/dots/bootstrap.sh desktop

Phase 3, needs a session
11. Log out, pick Sway at the greeter
12. cargo install --git https://github.com/latex-lsp/texlab --tag v5.26.0 --locked
```

**Phase 1 is not a root shell.** Every command in it except the clone carries
its own `sudo`, and the clone must not: under root, `~/dots` is `/root/dots`,
and cloning into the user's home as root leaves a root-owned working tree that
`bootstrap.sh` then stows from. The phases are cut by what each one needs, not
by who types it.

**The `cd` is part of step 1 and not an afterthought.** The two install lines
below and step 6 read `packages/roster.md` and `packages/flatpak.txt` relative
to the working directory, so a reader who clones and stays put gets two failures
that look like a broken repository.

The two install lines, handed here by 04 section 3:

```sh
sudo dnf install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $3); if ($3 !~ /^-*$/ && $3 != "fedora") print $3}' packages/roster.md | sort -u)
sudo apt install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $4); if ($4 !~ /^-*$/ && $4 != "ubuntu") print $4}' packages/roster.md | sort -u)
```

Step 4, from the survey and 04:

```sh
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
sudo dnf update @multimedia
```

Step 6. `flatpak install [OPTION...] [REMOTE] REF...` takes several refs in one
invocation, read from `man 1 flatpak-install` on the reference machine, so the
two ids go in one line:

```sh
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak install flathub $(cat packages/flatpak.txt)
```

**Step 11 comes before step 12, and that ordering is load-bearing.**
[04](04-package-set-form.md) put texlab after `bootstrap.sh` because it needs
mise's `rust`, and that is necessary but not sufficient: `activate_mise` changes
only bootstrap's own process, so the shell that ran step 10 still has no `cargo`
on its `PATH`. `.zshrc:17` and `.bashrc:22` are what activate mise, and they run
in a **new** shell, which is exactly what step 11 produces. So logging in is not
a cosmetic last line: it is the step that puts the toolchain in reach of step
12, and it also happens to be the only place that says the machine is now
entered a different way than it was installed. `mise exec rust -- cargo install`
would work in the old shell and was refused: it is a second mechanism for
something the route already has, and the reader has to log in anyway.

### 3. Two corrections to the shape this ticket proposed

**The clone comes first, not fourth.** The rough shape put source enablement and
the package set in front of the clone, and that cannot run: the install line
reads `packages/roster.md`, and the documented source steps are in the same
clone. Everything after step 1 reads out of the working tree.

**Nothing precedes the clone.** `git` is simply assumed present and is written
down nowhere. It stays a row in `packages/roster.md`, because `.zshrc` and
`bootstrap.sh` invoke it, so the package set installs it in step 3 regardless;
it is just not a step. A seed set in front of the clone was refused: it would be
a second package list, shorter and unmaintained. `stow` needs no earlier place
either, since nothing before `bootstrap.sh` calls it.

### 4. The per-machine roster, order free, after phase 3

```
- protonvpn: log in and configure the network
- Syncthing: install the package, enable the user unit, mkdir ~/Sync ~/projects,
  pair. Only then does Sway have its wallpaper.
- The KeePassXC database in its place
- fcitx5: its own per-language configuration
- Create ~/.ssh/config with Include ~/.config/ssh/config.shared
- Whatever 07 decides about the battery threshold appends here
```

Syncthing is not in the package set and this is not an oversight: no tracked
file invokes it, so 04's first clause keeps it out, and its installation is part
of this manual step rather than of step 3. The reference machine's form is a
user unit enabled against a `disabled` preset, per
[03](03-fedora-reference-inventory.md) section 7.

**`mkdir ~/Sync` is bound to Syncthing and not to Sway.**
`.config/sway/config:6` points `$wallpaper` at
`~/Sync/.pictures/wallpaper/frieren.jpg`, a **file** that only exists once
Syncthing has paired and run. The directory is the prerequisite of pairing; Sway
waits on the pairing, not on the `mkdir`. That is why the pair sits in this
roster together and not as a step in phase 2.

**Deliberately absent: the `docker` and `libvirt` group memberships.**
`.envs.sh` probes both with `_export_if_socket`, which makes their absence the
designed case rather than a hole, and 04's first clause keeps both out of the
package set. `wheel` likewise, because the install-time user lands in the admin
group on both distros.

### 5. `font-install` runs in phase 2, and `bootstrap.sh` does not call it

By path out of the clone, exactly as `bootstrap.sh` is run, after step 3 has
supplied its `curl`, `unzip` and `fc-cache` and before `bootstrap.sh`.

**`bootstrap.sh` calling it was refused on 04's argument, not on a new one.**
The script runs identically on both Roles by its own header at
`bootstrap.sh:11`, and fonts are a Desktop concern: calling `font-install` from
there would either put Nerd Fonts on a Headless machine or force into
`bootstrap.sh` the Role branch it refuses to have. This is the same shape as
04's refusal to install Flatpaks there, and it is worth recording that the two
land on the same reason, because the tempting reason, "bootstrap avoids the
network", is false of a script that pipes `https://mise.run` into a shell.

Putting it in phase 3 was refused for a smaller reason: phase 3 should hold what
genuinely cannot run earlier, and `font-install` can.

### 6. Flatpaks are system wide, matching the reference machine

`sudo flatpak remote-add` and `sudo flatpak install`, in phase 1 alongside the
package set. `--user` buys nothing here: 04 kept the Flatpaks out of
`bootstrap.sh` with the Role argument and not with the sudo argument, so
sudo-freedom wins back no ground, and the machine that works is system wide.

Measured on the ZenBook rather than assumed:
`flatpak remotes --columns=name,options` reports `flathub system`, and all seven
applications list `system` under
`flatpak list --columns=application,installation`. The remote was added by hand,
not by the spin: `/etc/flatpak/remotes.d/flathub.flatpakrepo` does not exist,
the remote lives in `/var/lib/flatpak/repo/config` (dated 2026-07-20), and no
installed package owns it. So step 6 is a real step on Fedora and not a
formality.

### 7. A foreign source is a link plus three facts, never a command

The map's "documented, never scripted" is read here as: **the document prints no
enablement command at all.** For each source it names the repository, the
package that comes out of it, and any deviation the reference machine shows,
then links the vendor's own install page, which is the thing that ages with the
vendor.

The three deviations 03 found that the vendor pages do not mention:

- **Terra** was enabled on the ZenBook as
  `dnf install --nogpgcheck --repofrompath terra,... terra-release`, the
  `--nogpgcheck` applying to the release RPM itself.
- **LibreWolf** is a bare `/etc/yum.repos.d/librewolf.repo` owned by no package,
  while the vendor's RHEL page today gives
  `dnf config-manager addrepo --from-repofile=https://repo.librewolf.net/librewolf.repo`.
  The machine predates the instruction; the document follows the page.
- **ProtonVPN** ships the GUI metapackage on both of its pages, while the binary
  `.config/sway/config` calls comes from `proton-vpn-cli`, which is in the same
  repository under its own name. Following the page verbatim installs the wrong
  package.

Honest about what this costs: the rot it guards against is almost entirely
ProtonVPN's, whose release RPM carries its version in the filename and whose two
sides have already diverged (Fedora 1.0.4, Debian 1.0.8). RPM Fusion and Terra
pin through `$(rpm -E %fedora)` and `$releasever` and would not age if written
out. The rule is kept whole anyway, because a rule with one exception per source
is not a rule, and because printing the command **and** the link puts two truths
in one file.

One detail a reader would otherwise report as a contradiction: ProtonVPN's own
Fedora command reads `/etc/fedora-release`. That does not violate ADR-0011,
because [01](01-name-the-distro-divergence.md) ends the ban at what stow
deploys, and this is a vendor command in a documented step.

### 8. satty on Ubuntu: pinned to v0.22.0, and the survey's URL has moved

```sh
curl -fsSL https://github.com/Satty-org/Satty/releases/download/v0.22.0/satty-x86_64-unknown-linux-gnu.tar.gz \
  | sudo tar -xz -C /usr/local/bin ./satty
```

**`./satty` is not cosmetic.** Proven in a scratch directory against the real
archive: the member is `./satty`, and `tar -xzf satty.tar.gz -C bin satty`
without the prefix fails with `tar: satty: Not found in archive`. The extracted
file is already mode 0755, so no `chmod +x` follows; the archive also carries a
`.desktop` file, a man page and six shell completions, all of which this step
deliberately drops, because `/usr/local/bin/satty` alone is what the Ubuntu
machine has.

**The pin is v0.22.0 because that is what Fedora already runs.**
`dnf repoquery --repo=terra satty` on the ZenBook answers `satty 0.22.0-1.fc44`,
and the GitHub release published 2026-08-03 is `v0.22.0`. So the pin makes the
two machines run the same satty rather than merely pinning each one to
something.

**Correction to [the survey](../research/02-package-availability.md):** it cites
`https://github.com/gabm/Satty`, and that repository has moved.
`curl -o /dev/null -w '%{http_code} %{redirect_url}'` against
`https://api.github.com/repos/gabm/Satty` answers `301`, and the release payload
reports the canonical name as `Satty-org/Satty`. The old URL still resolves
through the redirect; the document uses the new one. This does not change any of
the survey's conclusions, all of which still hold.

`cargo install satty` after `bootstrap.sh`, which would have made one category
of hand-built tools instead of two, was weighed and refused. satty is GTK4 plus
gtk4-layer-shell, and 03 section 8 found exactly `cairo`, `gdk-pixbuf2`, `gtk4`,
`libadwaita`, `libepoxy` and `gtk4-layer-shell` `-devel` packages on the
ZenBook, recorded there as build dependencies of something no longer
identifiable. That is most likely this build, and reproducing it would add those
six rows to `packages/roster.md` plus their Ubuntu counterparts. A pinned
tarball costs one URL.

### 9. What `README.md` will say

Its four steps are not wrong, they are **mislabelled**: clone, token,
`bootstrap.sh` is exactly right for a machine that already has its packages, and
wrong only for a bare install. So the section stays and is re-scoped rather than
deleted, which is what makes the eventual rewrite a transcription of two
sentences rather than a second decision:

- The intro and Key Highlights are untouched.
- The Installation section keeps its four steps and says they apply to a machine
  whose packages are already in place, whether that is a re-deploy, a retrofit
  of a machine set up by hand, or a fresh clone onto a machine this repo has run
  on before.
- One sentence points a bare distro install at `docs/install.md`.

Deleting the section outright was refused: `README.md` is the file a stranger
reads first, and it would leave no statement anywhere in it of how this repo
deploys.

### 10. Rot is [08](08-completeness-check.md)'s job, not a checklist's

No per-machine checklist, in the repo or under `templates/`. A ticked checklist
records what somebody did, and a completeness check records what is on the
machine; a step whose instructions have rotted gets ticked exactly as happily as
one that worked, so the artifact that is supposed to make rot visible is blind
to it by construction. With two machines it is also over-engineering.

**This deliberately moves weight onto 08**, and the move is the decision. 08 is
now the only thing standing between a manual step that silently stopped working
and nobody noticing, which raises what it has to cover: the per-machine roster
in section 4 is the list of things no package database can answer for, so 08
either reaches them or accepts that they are unchecked. That is 08's call, and
it should be made knowing that this ticket declined to build a second mechanism
for it.

### 11. Facts measured in passing

- **The login shell is set by nothing in this repo.** `getent passwd` on the
  ZenBook gives `/usr/bin/zsh`, and `grep -rn 'chsh|usermod.*-s|SHELL='` across
  the tracked shell files finds nothing. `zsh` is a roster row so the package
  arrives, `bootstrap.sh` stows `.zshrc` and drives zinit through zsh, and the
  machine still logs into bash until somebody runs `chsh`. That is step 8, and
  it was written down nowhere before this ticket.
- **The reference machine's greeter is `sddm`**, enabled, with
  `systemctl get-default` reporting `graphical.target`. Ubuntu's is `gdm3`. The
  session entry comes out of the package set on both sides per 03's section 9,
  so step 11 is a selection and not a manual step with content.
- **Flathub is not preconfigured on the Fedora Sway spin.** Evidence in
  section 6.

### What this hands the downstream tickets

- [06](06-config-assumptions.md): untouched. Its `~/.env` question is the one
  place that can still grow section 4's roster by a line, and this ticket did
  not pre-empt it. Step 8 is adjacent but not the same question: `chsh` decides
  which shell reads the files, while 06 decides what those files may assume.
- [07](07-battery-threshold-keybind.md): whatever it decides appends to section
  4's roster. Nothing here constrains the shape of that entry.
- [08](08-completeness-check.md): section 10 is the binding one. There is no
  checklist and there will be none, so 08 is the whole of the rot guard, and
  section 4's roster is the part of a machine that `packages/roster.md` cannot
  speak for.
