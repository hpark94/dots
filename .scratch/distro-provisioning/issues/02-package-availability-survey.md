# 02 Program roster and package availability survey

**Type:** `research` (AFK, resolved by a `/research` subagent)

**Status:** resolved

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

## Answer

[Program roster and package availability survey](../research/02-package-availability.md),
`Status: facts only`. The roster was derived from the tracked files, not from
memory: the sway config, both waybar configs and their scripts, all 18 scripts
in `.local/scripts/`, the shell files, `.tmux.conf`, `bootstrap.sh` and nvim's
external tools, with the 40 mise-managed tools excluded and listed by name.
Ubuntu facts were checked on this machine, Fedora facts against
`mdapi.fedoraproject.org` and `packages.fedoraproject.org`, upstream install
docs quoted verbatim.

The findings that force a decision:

- **The name divergence is a class, not an `imv` quirk.** 27 rows where naming
  the package does not name the binary, or where the two distros disagree:
  `swaync` is `SwayNotificationCenter` against `sway-notification-center`,
  `kitten` is `kitty-kitten` against `kitty`, `thunar` against `Thunar`,
  `ffmpeg-free` against `ffmpeg`, `fcitx5-configtool` does not exist on Ubuntu
  at all (`fcitx5-config-qt`), and Fedora's single `clang-tools-extra` is three
  packages on Ubuntu. Each row is a way for [08](08-completeness-check.md) to
  pass on a broken machine or fail on a sound one.
- **`satty` has no repository route on either distro**, and none on Flathub
  either. Binary, `.flatpak` bundle, `cargo install` or a COPR are the only
  ways, which is why it sits unowned in `/usr/local/bin` here.
- **`texlab` and `ghostty` reverse the premise**: both are in Ubuntu's universe
  and in no Fedora repository, so the reference machine is the one with the hole
  and on Fedora the terminal itself comes from a third-party source.
- **Fedora's `zathura` installs without a PDF backend**, because
  `zathura-pdf-poppler` is a Suggests there and a hard Depends on Ubuntu. Same
  package name, working viewer on one machine, viewer that opens nothing on the
  other, with vimtex as the caller.
- **Ubuntu's `thunderbird` is a snap transition stub** (`Pre-Depends: snapd`),
  so under the map's Flatpak-never-snap rule Ubuntu has no archive route, which
  is what the config's `flatpak run` already reflects.
- **Config ships, program absent** on this Ubuntu machine: `chafa` and `kitten`
  are both missing, so `fzf-preview`'s Render Ladder has no image rung at all
  and every image falls through to `bat`; `metaflac` is missing, so
  `organize_flac` aborts at its guard; `texlab` is missing, so nvim enables an
  LSP that never starts.
- **`jq` is mise-managed yet called from the login session**, by the sway
  config, both swipe scripts and `sway-start-on-workspace`, before any shell has
  run `mise activate`. A `PATH` assumption rather than a packaging one, so it
  moves to [06](06-config-assumptions.md).
- **`slurp` is not invoked anywhere in the repo**: `git grep -lI -- slurp`
  returns nothing, screenshots run `grim -o ... - | satty -f -`. It was in this
  ticket's confirm-list and does not belong in a package set.
