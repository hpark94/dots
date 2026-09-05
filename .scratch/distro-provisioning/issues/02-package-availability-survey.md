# 02 Program roster and package availability survey

**Type:** `research` (AFK, resolved by a `/research` subagent)

**Status:** claimed

**Blocked by:** None, can start immediately

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Which programs does this repo actually require, and for each one, how is it
installed on Fedora and on Ubuntu 26.04?

**Facts only. This ticket chooses nothing.** The choices are
[04 Where the package sets live](04-package-set-form.md) and
[06 What the configs must stop assuming](06-config-assumptions.md), which this
unblocks.

### Build the roster from the repo, not from memory

Every program this repo invokes, derived from the tracked files:
`.config/sway/config` (`exec` and `bindsym` lines), `.config/waybar/`,
`.local/scripts/` (all of them), `.zshrc`, `.aliases.sh`, `.shell_functions.sh`,
`.envs.sh`, `.tmux.conf`, and the nvim config's external tool calls. Separate
out what `.config/mise/config.toml` already provides: mise-managed tools are
installed by `bootstrap.sh` and are not a packaging question.

### For each program in the roster, establish

1. **Fedora**: package name, in the base repositories or not. If not: COPR, RPM
   Fusion, an upstream `.repo`, an upstream binary, or Flathub.
2. **Ubuntu 26.04**: package name, in main/universe or not. If not: PPA, an
   upstream `.deb`, an upstream binary, or Flathub. Note where the package
   exists but is materially older than Fedora's.
3. **Flatpak**: is there a Flathub application id? Relevant because the map has
   already ruled that Flatpak, never snap, is the fallback for anything outside
   the base repositories.
4. **Absent entirely**: say so plainly. That is the most valuable finding, since
   it forces a decision rather than a package name.

Known interesting cases, to be confirmed rather than assumed: `ghostty`,
`librewolf`, `satty` (installed by hand into `/usr/local/bin` on the Ubuntu
machine, owned by no package), `protonvpn`, `swaync`, `cliphist`, `autotiling`,
`imv` (its config ships in this repo but the program is not installed on the
Ubuntu machine), `lxpolkit`, `fcitx5` and its input-method packages.

### Sources

Primary only where one exists: the distributions' own package databases
(`packages.fedoraproject.org`, `packages.ubuntu.com`), Flathub, and each
project's own installation documentation. Quote verbatim. Where a fact can be
checked on this machine (`apt-cache policy`, `dpkg -S`, `flatpak search`), check
it here and say so.

### Output

`.scratch/distro-provisioning/research/02-package-availability.md`, one table
row per program, with `Status: facts only`.
