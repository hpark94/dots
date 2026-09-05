# Program roster and package availability survey

**Resolves:**
[02 Program roster and package availability survey](../issues/02-package-availability-survey.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

**Date:** 2026-09-05

**Status:** facts only. This document does not choose. The choices are
[04 Where the package sets live and in what form](../issues/04-package-set-form.md)
and
[06 What the configs must stop assuming](../issues/06-config-assumptions.md).

## Scope and method

### Where the roster comes from

The roster below is derived from the tracked files, not from memory. Read in
full for external program invocations: `.config/sway/config` (every `exec`,
`exec_always`, `bindsym`, `bindgesture` and `for_window` line),
`.config/sway/scripts/`, `.config/waybar/config.jsonc`,
`.config/waybar/sway_config.jsonc`, `.config/waybar/scripts/`, every executable
in `.local/scripts/`, `.config/notes/config.sh` (sourced by `note` and
`scratch`), `.zshrc`, `.aliases.sh`, `.shell_functions.sh`, `.envs.sh`,
`.tmux.conf`, `bootstrap.sh`, and the nvim config's external tool calls
(`lua/core/lsp.lua`, `lua/core/plugins/conform.lua`,
`lua/core/plugins/nvim-lint.lua`, `lua/core/plugins/vimtex.lua`). Config-only
packages are included where a tracked config file exists for a program
(`.config/imv/`, `.config/mpv/`, `.config/zathura/`, `.config/foot/`,
`.config/ghostty/`, `.config/fuzzel/`, `.config/satty/`, `.config/swaync/`,
`.config/xdg-desktop-portal/`).

### The two baselines

- **Fedora 44**, the newest current Fedora release. Both Fedora 43 and Fedora 44
  are `current` in
  [Bodhi's release list](https://bodhi.fedoraproject.org/releases/?state=current&rows_per_page=50),
  and 44 is the newer, so every Fedora fact below is `f44`.
- **Ubuntu 26.04.1 LTS (resolute)**, which is the machine this survey was run
  on: `PRETTY_NAME="Ubuntu 26.04.1 LTS"` in `/etc/os-release`.

### What counts as primary here

| Source                                     | How it was read                                                                                                                        |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Ubuntu package facts                       | `apt-cache policy`, `apt-cache search`, `apt-cache show`, `dpkg -S`, `dpkg -L`, `command -v` on this machine; commands given per claim |
| Ubuntu file lists for uninstalled packages | `packages.ubuntu.com/resolute/amd64/<pkg>/filelist`                                                                                    |
| Fedora package facts                       | `mdapi.fedoraproject.org/f44/pkg/<name>` and `/f44/files/<name>`, Fedora Infrastructure's own metadata API                             |
| Fedora "does this package exist at all"    | `packages.fedoraproject.org/search?query=<name>`, the Fedora Packages web app                                                          |
| Flathub                                    | `flatpak search <name>` against the `flathub` remote configured on this machine, and `flathub.org/api/v2/appstream/<app-id>`           |
| Upstream install routes                    | each project's own installation documentation, quoted verbatim                                                                         |
| RPM Fusion                                 | the repository's own package directory listing                                                                                         |

Two limits of the Fedora side, stated so nothing here is over-read. First, mdapi
answers for the newest build of a name across `release`, `updates` and
`updates-testing`; where the `repo` column below says `updates-testing`, an
older build of the same package sits in `release` or `updates`, and the package
is in the base repositories either way. Second, mdapi covers only Fedora's own
repositories, so a `NOT FOUND` there is evidence about Fedora proper and says
nothing about COPR, RPM Fusion or upstream.

### Excluded: what mise already installs

`bootstrap.sh` runs `mise install` against the tracked
`.config/mise/config.toml`, so these are not a packaging question and are not
surveyed. Excluded by that rule, in the order the file lists them: `ast-grep`,
`bat`, `eza`, `fd`, `fzf`, `jq`, `ripgrep` (`rg`), `tree-sitter`, `zoxide`,
`direnv`, `delta`, `bats`, `claude`, `codex`, `lazygit`, `neovim` (`nvim`),
`tmux`, `yazi`, `go`, `java`, `node`, `rust`, `bun`, `cmake`, `maven`, `ninja`,
`uv`, `biome`, `lua-language-server`, `marksman`, `shellcheck`, `shfmt`,
`stylua`, `bash-language-server`, `prettier`, `typescript-language-server`,
`yaml-language-server`, `black`, `pyright`, `ruff`.

`mise` itself is also excluded: `bootstrap.sh` installs it with
`curl https://mise.run | sh`, so it is an upstream installer on both distros
alike. The same goes for `zinit` (cloned by `.zshrc`) and `tpm` (cloned by
`bootstrap.sh`), which are git checkouts rather than packages.

One consequence of the exclusion is recorded rather than decided, because it
belongs to [06](../issues/06-config-assumptions.md): `jq` is mise-managed, and
`.config/sway/config` and both `.config/sway/scripts/*.sh` call it from a login
session, as does `.local/scripts/sway-start-on-workspace`, which fails loudly
with `jq not available` when the mise shims are not on the session's `PATH`.

## The survey

`Fedora 44` and `Ubuntu 26.04` name the **package**; the first column names the
**binary the repo actually invokes**. Where the two differ, the divergence is
collected again in
[Package name versus binary name](#package-name-versus-binary-name), because a
completeness check that probes the wrong one of the two fails silently.

### Session, compositor and desktop programs

| Binary invoked                       | Fedora 44 package                      | Ubuntu 26.04 package                            | Flathub                         |
| ------------------------------------ | -------------------------------------- | ----------------------------------------------- | ------------------------------- |
| `sway`, `swaymsg`                    | `sway` 1.11-3 (release)                | `sway` 1.11-3 (universe)                        | none found                      |
| `swaylock`                           | `swaylock` 1.8.6-1 (updates)           | `swaylock` 1.8.4-1 (universe)                   | none found                      |
| `swayidle`                           | `swayidle` 1.9.0-2 (release)           | `swayidle` 1.9.0-1 (universe)                   | none found                      |
| `swaybg`                             | `swaybg` 1.2.2-1 (updates-testing)     | `swaybg` 1.2.1-1build1 (universe)               | none found                      |
| `swaync`, `swaync-client`            | `SwayNotificationCenter` 0.12.5-1      | `sway-notification-center` 0.12.4-1             | none found                      |
| `waybar`                             | `waybar` 0.15.0-2 (updates)            | `waybar` 0.15.0-1 (universe)                    | none found                      |
| `fuzzel`                             | `fuzzel` 1.14.0-1 (release)            | `fuzzel` 1.12.0+ds-1build1 (universe)           | none found                      |
| `ghostty`                            | **not in Fedora**, COPR                | `ghostty` 1.3.0~us1-0ubuntu1.1 (universe)       | none found                      |
| `foot`                               | `foot` 1.26.1-1 (updates-testing)      | `foot` 1.25.0-1 (universe)                      | `page.codeberg.dnkl.foot`       |
| `librewolf`                          | **not in Fedora**, upstream `.repo`    | **not in Ubuntu**, upstream repo                | `io.gitlab.librewolf-community` |
| `thunar`                             | `Thunar` 4.20.9-1 (updates)            | `thunar` 4.20.7-1 (universe)                    | none found                      |
| `keepassxc`                          | `keepassxc` 2.7.12-1 (updates-testing) | `keepassxc` 2.7.10+dfsg1-2ubuntu1 (universe)    | `org.keepassxc.KeePassXC`       |
| `zathura`                            | `zathura` 2026.07.18-1 (updates)       | `zathura` 2026.02.09-1ubuntu1 (universe)        | `org.pwmt.zathura`              |
| `mpv`                                | `mpv` 0.41.0-5 (updates-testing)       | `mpv` 0.41.0-2ubuntu4 (universe)                | `io.mpv.Mpv`                    |
| `imv-wayland` / `imv`                | `imv` 5.0.1-1 (release)                | `imv` 5.0.1-3 (universe)                        | none found                      |
| `satty`                              | **absent everywhere**                  | **absent everywhere**                           | none found                      |
| `cliphist`                           | `cliphist` 0.7.0-1 (release)           | `cliphist` 0.5.0-1build1 (universe)             | none found                      |
| `lxpolkit`                           | `lxpolkit` 0.5.6-4 (release)           | `lxpolkit` 0.5.6-2ubuntu2 (universe)            | none found                      |
| `grim`                               | `grim` 1.5.0-3 (release)               | `grim` 1.4.0+ds-2build3 (universe)              | none found                      |
| `protonvpn`                          | **not in Fedora**, upstream repo       | **not in Ubuntu**, upstream repo                | `com.protonvpn.www`, unofficial |
| `fcitx5`                             | `fcitx5` 5.1.21-1 (updates)            | `fcitx5` 5.1.19-1 (universe)                    | none found                      |
| `brightnessctl`                      | `brightnessctl` 0.5.1-16 (release)     | `brightnessctl` 0.5.1-3.1build1 (universe)      | none found                      |
| `wpctl`                              | `wireplumber` 0.5.14-1 (updates)       | `wireplumber` 0.5.13-1ubuntu1 (main)            | none found                      |
| (session unit)                       | `sway-systemd` 0.4.1-4 (release)       | **absent**                                      | not applicable                  |
| `dbus-update-activation-environment` | `dbus-tools`                           | `dbus-bin` 1.16.2-2ubuntu4 (main)               | not applicable                  |
| `xdg-open`                           | `xdg-utils` 1.2.1-5 (release)          | `xdg-utils` 1.2.1-2ubuntu2 (main)               | not applicable                  |
| (screencast portal)                  | `xdg-desktop-portal-wlr` 0.8.4-1       | `xdg-desktop-portal-wlr` 0.8.1-1 (universe)     | not applicable                  |
| (file chooser portal)                | `xdg-desktop-portal-gtk` 1.15.3-3      | `xdg-desktop-portal-gtk` 1.15.3-2ubuntu1 (main) | not applicable                  |
| `battery-threshold-toggle`           | **no package anywhere**                | **no package anywhere**                         | not applicable                  |

### Waybar's module commands

| Binary invoked         | Fedora 44 package               | Ubuntu 26.04 package                          | Flathub    |
| ---------------------- | ------------------------------- | --------------------------------------------- | ---------- |
| `blueman-manager`      | `blueman` 2.4.6-7 (updates)     | `blueman` 2.4.4-1build1 (universe)            | none found |
| `playerctl`            | `playerctl` 2.4.1-12 (release)  | `playerctl` 2.4.1-3build1 (universe)          | none found |
| `nm-connection-editor` | `nm-connection-editor` 1.36.0-7 | `nm-connection-editor` 1.36.0-4ubuntu1 (main) | none found |
| `pavucontrol`          | `pavucontrol` 6.2-1 (updates)   | `pavucontrol` 6.1-1build1 (universe)          | none found |
| `htop`                 | `htop` 3.4.1-3 (release)        | `htop` 3.4.1-5build2 (main)                   | none found |

### Scripts in `.local/scripts/` and the shell files

| Binary invoked        | Fedora 44 package                   | Ubuntu 26.04 package                        | Called from                                   |
| --------------------- | ----------------------------------- | ------------------------------------------- | --------------------------------------------- |
| `wl-copy`, `wl-paste` | `wl-clipboard` 2.2.1^git20251124-2  | `wl-clipboard` 2.2.1-2build1 (universe)     | `fy`, `fp`, sway config, `.config/imv/config` |
| `chafa`               | `chafa` 1.18.2-1 (updates)          | `chafa` 1.18.1-1 (universe)                 | `fzf-preview` Render Ladder                   |
| `kitten`              | `kitty-kitten` 0.47.1-1 (updates)   | `kitty` 0.45.0-1build1 (universe)           | `fzf-preview` Render Ladder                   |
| `file`                | `file` 5.48-2 (updates-testing)     | `file` 1:5.46-5build2 (main)                | `fzf-preview`                                 |
| `systemd-inhibit`     | `systemd` 259.5-1                   | `systemd` 259.5-0ubuntu3.4 (main)           | `caffeine`, `.config/waybar/scripts/`         |
| `ffmpeg`              | `ffmpeg-free` 8.1.2-4 (updates)     | `ffmpeg` 7:8.0.1-3ubuntu2 (universe)        | `convert_flac`                                |
| `metaflac`            | `flac` 1.5.0-8 (release)            | `flac` 1.5.0+ds-5 (main)                    | `organize_flac`                               |
| `unzip`               | `unzip` 6.0-69 (release)            | `unzip` 6.0-29ubuntu1 (main)                | `font-install`                                |
| `fc-cache`            | `fontconfig` 2.17.0-4 (release)     | `fontconfig` 2.17.1-3ubuntu1 (main)         | `font-install`                                |
| `curl`                | `curl` 8.18.0-9 (updates)           | `curl` 8.18.0-1ubuntu2.4 (main)             | `font-install`, `bootstrap.sh`                |
| `notify-send`         | `libnotify` 0.8.8-1 (release)       | `libnotify-bin` 0.8.8-1 (main)              | `theme-switch`, sway config                   |
| `gsettings`, `gdbus`  | `glib2` 2.88.3-1 (updates)          | `libglib2.0-bin` (main)                     | `theme-switch`                                |
| `nmcli`               | `NetworkManager` 1.56.1-2 (updates) | `network-manager` (main)                    | `wait-for-vpn`                                |
| `dig`                 | `bind-utils` 9.18.50-2 (updates)    | `bind9-dnsutils` 1:9.20.24 (main)           | `_fzf_comprun` in `.shell_functions.sh`       |
| `pgrep`               | `procps-ng` 4.0.6-1 (release)       | `procps` 2:4.0.4-9ubuntu1 (main)            | `tmux-sessionizer`                            |
| `tput`                | `ncurses` 6.6-1 (release)           | `ncurses-bin` 6.6+20251231-1 (main)         | `delta-auto`                                  |
| `ssh`                 | `openssh-clients` 10.2p1-7          | `openssh-client` 1:10.2p1-2ubuntu3.6 (main) | `theme-push-connect`                          |
| `python3`             | `python3` 3.14.7-1 (updates)        | `python3` 3.14.3-0ubuntu2 (main)            | `.config/notes/config.sh`, `autotiling`       |
| `python3` `i3ipc`     | `python3-i3ipc` 2.2.1-20 (release)  | `python3-i3ipc` 2.2.1-3build1 (universe)    | `.local/scripts/autotiling`                   |
| `zsh`                 | `zsh` 5.9-21 (updates)              | `zsh` 5.9-8ubuntu3 (main)                   | login shell, `bootstrap.sh`                   |
| `git`                 | `git` 2.55.0-1 (updates)            | `git` 1:2.53.0-1ubuntu1 (main)              | `.zshrc`, `bootstrap.sh`                      |
| `stow`                | `stow` 2.4.1-4 (release)            | `stow` 2.4.1-2build1 (universe)             | `bootstrap.sh`                                |
| `flatpak`             | `flatpak` 1.18.2-1 (updates)        | `flatpak` 1.16.6-1 (universe)               | sway config                                   |

### nvim's external tools that mise does not provide

| Binary invoked                         | Fedora 44 package                  | Ubuntu 26.04 package                                                |
| -------------------------------------- | ---------------------------------- | ------------------------------------------------------------------- |
| `clangd`, `clang-format`, `clang-tidy` | `clang-tools-extra` 22.1.8-4       | `clangd`, `clang-format`, `clang-tidy`, each 1:21.1.6-71 (universe) |
| `texlab`                               | **not in Fedora**                  | `texlab` 5.25.1-2 (universe)                                        |
| `latexindent`                          | `texlive-latexindent` svn76064-105 | `texlive-extra-utils` 2025.20260124-1 (universe)                    |
| `latexmk`                              | `latexmk` 4.88-1 (updates-testing) | `latexmk` 1:4.87~ds-1 (universe)                                    |
| `gcc` (treesitter parsers)             | `gcc` 16.0.1-0.10                  | `gcc` 4:15.2.0-5ubuntu1 (main)                                      |

### Flatpak applications the repo launches by application id

`.config/sway/config` launches two applications through `flatpak run`, so the
application id is the interface and there is no distro package question:

- `org.mozilla.thunderbird`, version 155.0 on Flathub, installed here from the
  `flathub` remote.
- `md.obsidian.Obsidian`, version 1.13.7 on Flathub, installed here from the
  `flathub` remote.

Both verified with `flatpak list --columns=application,origin,version`, which
lists them with origin `flathub`, and `flatpak remotes`, which shows exactly one
remote, `flathub system`.

## Per-program notes

Only programs whose table cell cannot carry the fact.

### ghostty

Absent from Fedora's own repositories: `apt`-side it is packaged, Fedora-side
`https://mdapi.fedoraproject.org/f44/pkg/ghostty` returns nothing and
`https://packages.fedoraproject.org/search?query=ghostty` answers "No results
found!". Ghostty's own install page names the two routes, and the Ubuntu one
confirms what this machine shows:
[Ghostty's binary install documentation](https://ghostty.org/docs/install/binary)
states "Ghostty is available in the official package repository starting from
Ubuntu 26.04." with `apt install ghostty`, and for Fedora "Ghostty is available
in Fedora COPR." with `dnf copr enable scottames/ghostty` followed by
`dnf install ghostty`; Terra is listed as a second Fedora source. That COPR's
latest successful build is
[ghostty 1.3.1-4](https://copr.fedorainfracloud.org/api_3/package/list?ownername=scottames&projectname=ghostty&with_latest_build=true),
against Ubuntu's 1.3.0, so Ubuntu's is one upstream patch release behind.
`CONTEXT.md` already records the Fedora machine reporting `ghostty 1.3.1`.

The same page also offers `snap install ghostty --classic`. The map has ruled
snap out, so this is recorded and not counted as a route.

Not on Flathub: `flatpak search ghostty` returns "No matches found", and the
appstream endpoints for `com.mitchellh.ghostty`, `com.mitchellh.Ghostty` and
`dev.ghostty.Ghostty` all answer HTTP 404.

### librewolf

In neither distro's archive. On Ubuntu this machine has it from LibreWolf's own
repository: `apt-cache policy librewolf` gives 155.0-1 from
`https://repo.librewolf.net librewolf/main`, and
`/etc/apt/sources.list.d/extrepo_librewolf.sources` is the file that added it.
That matches
[LibreWolf's Debian-based install page](https://librewolf.net/installation/debian/),
whose instructions are `sudo apt install extrepo -y`, then
`sudo extrepo enable librewolf && sudo extrepo update librewolf`, then
`sudo apt install librewolf -y`.

For Fedora,
[LibreWolf's RHEL-distros install page](https://librewolf.net/installation/rhel/)
says "We have an rpm repository available with which you can install LibreWolf."
and gives
`sudo dnf config-manager addrepo --from-repofile=https://repo.librewolf.net/librewolf.repo`
for dnf5 (Fedora 41+), then `sudo dnf install librewolf`.

Flathub carries it as `io.gitlab.librewolf-community`, version 155.0-1, and
[LibreWolf's own "Other Linux" page](https://librewolf.net/installation/linux/)
points at it with `flatpak install flathub io.gitlab.librewolf-community`. That
page also warns that the Flatpak "prevents the browser from using its usual
sandbox for process isolation".

### satty

Absent from both distros and from Flathub. Verified four ways:
`apt-cache policy satty` prints nothing at all and `apt-cache search satty`
returns only `golang-github-mattn-go-isatty-dev` and `node-tty-browserify`;
`https://packages.fedoraproject.org/search?query=satty` answers with a "Did you
mean" suggestion rather than a package; `flatpak search satty` returns "No
matches found"; and `https://flathub.org/api/v2/appstream/io.github.gabm.Satty`
answers HTTP 404.

On this machine it lives at `/usr/local/bin/satty` and belongs to no package:
`dpkg -S /usr/local/bin/satty` answers "no path found matching pattern".

The upstream README's install section lists only Gentoo (`emerge -av satty`, via
the guru overlay) and Alpine (`apk add satty`) as distribution packages, plus
`cargo install satty`, plus
["You can download a prebuilt binary for x86-64 on the Satty Releases page."](https://github.com/gabm/Satty).
It has a Flatpak route, but not a Flathub one: "Satty is available as a Flatpak
bundle. Pre-built bundles are automatically created for each release and can be
downloaded from the GitHub Releases page", installed with
`flatpak install satty-<version>.flatpak`. A bundle is a file, not a remote, so
it updates by hand.

There is a third-party COPR, `mineiro/satty`, found through
`https://copr.fedorainfracloud.org/api_3/project/search?query=satty`. It is a
personal COPR with no relation to the project, recorded here only so the option
is on the table.

### protonvpn

The binary `.config/sway/config` execs (`protonvpn connect --p2p`) and
`.local/scripts/wait-for-vpn` probes (`command -v protonvpn`) belongs to
`proton-vpn-cli`, which is in neither archive.

On Ubuntu, `dpkg -S /usr/bin/protonvpn` says `proton-vpn-cli`, and
`apt-cache policy proton-vpn-cli` reports version 1.0.1 with its only source
being `/var/lib/dpkg/status`: nothing on this system currently offers it, and
`/etc/apt/sources.list.d/protonvpn-stable.sources` (URI
`https://repo.protonvpn.com/debian`) carries `Enabled: no`. Ubuntu's archive
does carry the GUI: `apt-cache policy proton-vpn-gtk-app` gives 4.15.2-1 from
`resolute/universe`. The GUI is not the CLI, and `protonvpn` is what the config
calls.

Fedora carries neither: `proton-vpn-gtk-app` and `protonvpn-cli` are both absent
from mdapi, although the shared library package `python3-proton-vpn-api-core`
0.36.6-7 is in `release`.

Proton's own repository has both, for both distros. Its
[Fedora install page](https://protonvpn.com/support/official-linux-vpn-fedora/)
says "Download the package that contains the repository configuration and keys
required to install the Proton VPN GUI app and CLI." and gives
`wget "https://repo.protonvpn.com/fedora-$(cat /etc/fedora-release | cut -d' ' -f 3)-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.4-1.noarch.rpm"`
then `sudo dnf install ./protonvpn-stable-release-1.0.4-1.noarch.rpm`. The
[Debian and Ubuntu page](https://protonvpn.com/support/official-linux-vpn-ubuntu/)
gives
`wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb`
then `sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb && sudo apt update`.
Both pages then install `proton-vpn-gnome-desktop`, the GUI metapackage, not the
CLI.

The CLI is in that repository under its own name on both sides. The Debian pool
at `https://repo.protonvpn.com/debian/dists/stable/main/binary-all/` lists
`proton-vpn-cli_1.0.3_all.deb` as its newest, and
`https://repo.protonvpn.com/fedora-44-stable/` has a `proton-vpn-cli/` directory
alongside `proton-vpn-gnome-desktop/`, which is also the primary evidence that
Proton builds for Fedora 44.

Flathub has `com.protonvpn.www` at 4.18.1, but its own appstream description
opens: "**NOTE: This app is built from Proton VPN's official open-source code,
but it is not an official Proton app. It is not affiliated with or supported by
Proton AG.**" It is also the GUI, so it does not supply `protonvpn` either.

### imv

The package name is `imv` on both distros and the versions match (5.0.1), but
the binaries do not.

Fedora's `imv` ships `/usr/bin/imv` alongside `imv-dir`, `imv-msg`,
`imv-wayland` and `imv-x11`, per
`https://mdapi.fedoraproject.org/f44/files/imv`. Ubuntu's does not:
`dpkg -L imv` lists `/usr/bin/imv-dir`, `/usr/bin/imv-msg`,
`/usr/bin/imv-wayland` and `/usr/bin/imv-x11`, with no plain `imv`, and
`command -v imv` on this machine finds nothing while `command -v imv-wayland`
gives `/usr/bin/imv-wayland`.

The ticket's premise that imv is missing on the Ubuntu machine is therefore
wrong: `apt-cache policy imv` reports 5.0.1-3 installed from `resolute/universe`
and `dpkg -S /usr/bin/imv-wayland` answers `imv`. What is missing is the name.

`.config/imv/config` is a config file, not an invocation, so no tracked file in
this repo calls either name; the divergence bites whatever opens images and
whatever later checks the machine is complete.

### kitten

`.local/scripts/fzf-preview` calls `kitten icat` for the top rung of the Render
Ladder. Ubuntu ships that binary in `kitty`:
`https://packages.ubuntu.com/resolute/amd64/kitty/filelist` lists both
`/usr/bin/kitten` and `/usr/bin/kitty`. Fedora splits them:
`https://mdapi.fedoraproject.org/f44/files/kitty` shows `kitty` shipping only
`/usr/bin/kitty`, while `kitty-kitten` 0.47.1-1, summary "The kitten
executable", ships `/usr/bin/kitten`. Fedora's `kitty` does
`Requires: kitty-kitten(x86-64)`, so installing `kitty` still yields `kitten`;
the point is that on Fedora `kitty-kitten` alone would do, and that a package
set naming only `kitty` means two different things on the two distros.

Neither binary is present on this machine (`command -v kitten` finds nothing),
which is consistent: the Render Ladder's kitty rung is only taken under ghostty
or kitty as Client Terminal, and `chafa` is likewise not installed here, so the
ladder currently has no image rung at all on the Ubuntu machine.

### zathura

Present in both archives, but the PDF backend behaves differently.

On Ubuntu the backend is a hard dependency: `apt-cache show zathura` lists
`Depends: zathura-pdf-poppler, ...`, so `apt install zathura` gives a zathura
that opens PDFs.

On Fedora it is not. `https://mdapi.fedoraproject.org/f44/pkg/zathura` shows an
empty `recommends` list and `zathura-pdf-poppler` only under `suggests`, and dnf
does not install Suggests. `zathura-pdf-poppler` 2026.07.18-1 and
`zathura-pdf-mupdf` 2026.07.18-1 both exist in `updates`. So on Fedora a package
set that names only `zathura` produces a viewer that cannot open the PDF vimtex
hands it.

### ffmpeg

`.local/scripts/convert_flac` calls `ffmpeg` and refuses to run without it.
Ubuntu has `ffmpeg` 7:8.0.1-3ubuntu2 in universe. Fedora has no package named
`ffmpeg`: `https://mdapi.fedoraproject.org/f44/pkg/ffmpeg` returns nothing,
while `https://packages.fedoraproject.org/search?query=ffmpeg` shows the
`ffmpeg` source package building the binary package `ffmpeg-free`. `ffmpeg-free`
8.1.2-4 ships `/usr/bin/ffmpeg`, `ffplay` and `ffprobe`, and its description
ends "This build of ffmpeg is limited in the number of codecs supported."

For this repo's one use, mp3 encoding, the limited build is enough:
`libavcodec-free` requires `libmp3lame.so.0`, so the lame encoder is linked in.
RPM Fusion carries the unrestricted build if it is ever wanted:
`ffmpeg-8.0.1-6.fc44.x86_64.rpm` is in
[RPM Fusion free's Fedora 44 package directory](https://download1.rpmfusion.org/free/fedora/releases/44/Everything/x86_64/os/Packages/f/).

### autotiling

The repo does not depend on a packaged autotiling at all: `.local/scripts/`
carries its own copy, which `.config/sway/config` runs with
`exec_always ~/.local/scripts/autotiling`. What it needs is the Python module it
imports, `from i3ipc import Connection, Event`, declared in its own header as
"Dependencies: python-i3ipc>=2.0.1 (i3ipc-python)". Both distros package it:
`python3-i3ipc` 2.2.1-20 in Fedora `release`, `python3-i3ipc` 2.2.1-3build1 in
Ubuntu universe, installed on this machine.

For completeness, a packaged autotiling exists on Ubuntu (`autotiling`
1.9.3-1build1 in universe, not installed) and not in Fedora
(`https://packages.fedoraproject.org/search?query=autotiling` answers "No
results found!"; only third-party COPRs such as `yselkowitz/nwg-shell` turn up).

### sway-systemd

Fedora has `sway-systemd` 0.4.1-4 in `release`, and its file list contains
exactly the path `.config/sway/config` tests for:
`https://mdapi.fedoraproject.org/f44/files/sway-systemd` shows
`/usr/libexec/sway-systemd` holding `assign-cgroups.py`, `locale1-xkb-config`,
`session.sh` and `wait-sni-ready`.

Ubuntu has no such package: `apt-cache policy sway-systemd` prints nothing and
`apt-cache search --names-only sway` lists `sway`, `sway-backgrounds`,
`sway-notification-center`, `swaybg`, `swayidle`, `swayimg`, `swaykbdd`,
`swaylock`, `swayosd`, `swaysome`, `papersway`, and nothing else. On this
machine `/usr/libexec/sway-systemd/` does not exist, so the config's
`|| dbus-update-activation-environment ...` fallback is the branch that runs
here. Both halves of that line are packaged on both sides:
`dbus-update-activation-environment` is `dbus-tools` on Fedora and `dbus-bin` on
Ubuntu.

### keepassxc

Both archives have it, but this machine does not use either.
`dpkg -S /usr/bin/keepassxc` answers `keepassxc-full`, and
`apt-cache policy keepassxc-full` shows 2.7.12+dfsg1-1xtradeb2.2604.1 installed
from `https://ppa.launchpadcontent.net/xtradeb/apps/ubuntu resolute/main`, a
PPA. Ubuntu's own `keepassxc` in universe is 2.7.10+dfsg1-2ubuntu1. Fedora's
`keepassxc` is 2.7.12-1. So the archive version on Ubuntu is one upstream minor
release behind Fedora's, and the PPA exists on this machine to close that gap.

Flathub has `org.keepassxc.KeePassXC` at 2.7.12.

### fcitx5 and its input-method packages

The framework and the Hangul engine carry the same names on both distros; the
configuration tool and the IM modules do not.

Fedora: `fcitx5` 5.1.21-1, `fcitx5-hangul` 5.1.10-1, `fcitx5-configtool`
5.1.14-1, `fcitx5-gtk` 5.1.7-1, `fcitx5-qt` 5.1.14-3, all in `updates`.

Ubuntu: `fcitx5` 5.1.19-1 and `fcitx5-hangul` 5.1.9-1, both installed here from
universe. `fcitx5-configtool` does not exist:
`apt-cache policy fcitx5-configtool` reports `Candidate: (none)`, and the Ubuntu
name is `fcitx5-config-qt` 5.1.13-1, which is what `dpkg -l` shows installed.
The IM modules are split per toolkit rather than per language binding:
`fcitx5-frontend-gtk3`, `fcitx5-frontend-gtk4`, `fcitx5-frontend-qt5`,
`fcitx5-frontend-qt6`, with `fcitx5-frontend-all` as the metapackage. All five
are installed on this machine.

### swaync

The binaries `swaync` and `swaync-client`, which `.config/sway/config`,
`.config/waybar/sway_config.jsonc` and `.local/scripts/theme-switch` all call,
come from a package named neither of those things. Fedora:
`SwayNotificationCenter` 0.12.5-1, shipping `/usr/bin/swaync` and
`/usr/bin/swaync-client`. Ubuntu: `sway-notification-center` 0.12.4-1, per
`dpkg -S /usr/bin/swaync`. `apt-cache policy swaync` prints nothing at all.

### slurp

Named in the ticket's confirm-list, but no tracked file in this repo invokes it.
`git grep -lI -- slurp` over the repo (excluding `.scratch/` and `docs/`)
returns nothing: the screenshot bindings use `grim -o <output>` for a whole
output and hand the crop to satty (`grim -o ... - | satty -f -`). It is packaged
on both sides anyway (`slurp` 1.5.0-6 in Fedora `release`, `slurp` 1.6.0-1 in
Ubuntu universe, installed here), which is the one case in this survey where
Ubuntu is ahead of Fedora.

### battery-threshold-toggle

`.config/sway/config` binds `Control+Alt+p` to
`exec sudo battery-threshold-toggle`. No package on either distro provides that
name, no tracked file in this repo defines it, and it is not on this machine's
`PATH`. It is not a packaging question but a missing artifact, already ticketed
as [07](../issues/07-battery-threshold-keybind.md).

### thunderbird on Ubuntu

Ubuntu's archive package is not the program. `apt-cache show thunderbird` gives
version `2:1snap1-0ubuntu5` with `Pre-Depends: debconf, snapd` and the
description "Transitional package - thunderbird -> thunderbird snap ... This is
a transitional dummy package. It can safely be removed. thunderbird is now
replaced by the thunderbird snap." Under the map's "Flatpak, never snap" rule
the archive route does not exist on Ubuntu at all, which is exactly why
`.config/sway/config` launches `flatpak run org.mozilla.thunderbird`. Fedora
still ships a real package, `thunderbird` 153.0.2-2 in `updates`.

Flathub carries two ids: `org.mozilla.thunderbird` at 155.0, the one this
machine has installed, and `org.mozilla.Thunderbird` at 140.10.2esr.

### obsidian

No package on either distro: `apt-cache search --names-only obsidian` returns
only `obsidian-icon-theme`, and
`https://packages.fedoraproject.org/search?query=obsidian` answers "No results
found!". Flathub's `md.obsidian.Obsidian` at 1.13.7 is the only route, which is
what `.config/sway/config` uses. Its app_id is why `sway-start-on-workspace`
takes a `|`-separated list: the same Flatpak reports `md.obsidian.Obsidian` on
one machine and `obsidian` on another.

### texlab

`.config/nvim/lua/core/lsp.lua` enables `texlab`, and it is not among the
mise-managed LSP servers. Ubuntu has `texlab` 5.25.1-2 in universe, not
installed on this machine (`command -v texlab` finds nothing). Fedora does not
package it: `https://mdapi.fedoraproject.org/f44/pkg/texlab` returns nothing and
`https://packages.fedoraproject.org/search?query=texlab` answers with "Did you
mean tecla?" rather than a package. Third-party COPRs exist (`shadow53/texlab`,
`efoerster/texlab`); upstream ships prebuilt binaries and it is a Rust crate, so
a mise or cargo route also exists. This is the one program in the survey where
Ubuntu has an archive package and Fedora has none.

### clang tooling

nvim wants three binaries: `clangd` (LSP), `clang-format` (conform) and
`clang-tidy` (nvim-lint). Ubuntu splits them into three packages of exactly
those names, all 1:21.1.6-71 in universe and all installed here. Fedora puts all
three in one: `https://mdapi.fedoraproject.org/f44/files/clang-tools-extra`
lists `clang-format`, `clang-tidy` and `clangd` in `/usr/bin`, while the `clang`
package ships only `clang`, `clang++`, `clang-cl`, `clang-cpp` and
`clang-scan-deps`. Naming `clang` on Fedora gives none of the three.

### latexindent

`.config/nvim/lua/core/plugins/conform.lua` runs `latexindent` for `tex`, with
`~/.latexindent.yaml`. Fedora packages it alone as `texlive-latexindent`; Ubuntu
buries it in `texlive-extra-utils`, per `dpkg -S /usr/bin/latexindent`.

## Package name versus binary name

Every case in this survey where naming the package does not name the binary, or
where the two distros disagree about the name. A completeness check that probes
one of the two per program needs this list, because each row is a way for a
check to pass on a machine that is broken, or fail on one that is fine.

| Binary the repo calls                   | Fedora package            | Ubuntu package                                        |
| --------------------------------------- | ------------------------- | ----------------------------------------------------- |
| `imv` (Fedora) / `imv-wayland` (Ubuntu) | `imv`                     | `imv`, and it has no `/usr/bin/imv`                   |
| `swaync`, `swaync-client`               | `SwayNotificationCenter`  | `sway-notification-center`                            |
| `thunar`                                | `Thunar`                  | `thunar`                                              |
| `kitten`                                | `kitty-kitten`            | `kitty`                                               |
| `protonvpn`                             | `proton-vpn-cli`          | `proton-vpn-cli`                                      |
| `wl-copy`, `wl-paste`                   | `wl-clipboard`            | `wl-clipboard`                                        |
| `blueman-manager`                       | `blueman`                 | `blueman`                                             |
| `wpctl`                                 | `wireplumber`             | `wireplumber`                                         |
| `xdg-open`                              | `xdg-utils`               | `xdg-utils`                                           |
| `notify-send`                           | `libnotify`               | `libnotify-bin`                                       |
| `gsettings`, `gdbus`                    | `glib2`                   | `libglib2.0-bin`                                      |
| `nmcli`                                 | `NetworkManager`          | `network-manager`                                     |
| `dig`                                   | `bind-utils`              | `bind9-dnsutils`                                      |
| `pgrep`                                 | `procps-ng`               | `procps`                                              |
| `tput`                                  | `ncurses`                 | `ncurses-bin`                                         |
| `ssh`                                   | `openssh-clients`         | `openssh-client`                                      |
| `dbus-update-activation-environment`    | `dbus-tools`              | `dbus-bin`                                            |
| `systemd-inhibit`                       | `systemd`                 | `systemd`                                             |
| `metaflac`                              | `flac`                    | `flac`                                                |
| `fc-cache`                              | `fontconfig`              | `fontconfig`                                          |
| `ffmpeg`                                | `ffmpeg-free`             | `ffmpeg`                                              |
| `latexindent`                           | `texlive-latexindent`     | `texlive-extra-utils`                                 |
| `clangd`, `clang-format`, `clang-tidy`  | `clang-tools-extra`       | `clangd`, `clang-format`, `clang-tidy`                |
| `keepassxc`                             | `keepassxc`               | `keepassxc`, or `keepassxc-full` from the xtradeb PPA |
| (fcitx5 config tool)                    | `fcitx5-configtool`       | `fcitx5-config-qt`                                    |
| (fcitx5 IM modules)                     | `fcitx5-gtk`, `fcitx5-qt` | `fcitx5-frontend-gtk3`, `-gtk4`, `-qt5`, `-qt6`       |
| (session unit)                          | `sway-systemd`            | no package                                            |

## What forces a decision

Facts only; each of these has no package-name answer, so
[04](../issues/04-package-set-form.md) or
[06](../issues/06-config-assumptions.md) has to say something.

### Absent on one side

- **satty** is absent from both archives, from Flathub and from upstream's own
  distribution packaging. The only routes are a prebuilt x86-64 binary, a
  `.flatpak` bundle file, `cargo install`, or a third-party COPR. It is the one
  program in this repo with no repository route on either distro.
- **texlab** is in Ubuntu universe and in no Fedora repository. It is the only
  program where Ubuntu has the archive package and the reference machine does
  not.
- **ghostty** is in Ubuntu 26.04's universe and in no Fedora repository. The
  Fedora route is a COPR, so on Fedora the terminal is a third-party source.
- **librewolf** and **protonvpn** are in neither archive; both have an upstream
  repository for both distros, which the map's "third-party sources are
  documented, never scripted" note already governs.
- **sway-systemd** is Fedora-only. The config already tolerates its absence
  through the `dbus-update-activation-environment` fallback, so this is a
  documented divergence rather than a hole.
- **obsidian** and, on Ubuntu, **thunderbird** have no usable archive package.
  Ubuntu's `thunderbird` is a snap transition stub, which the map's "Flatpak,
  never snap" rule rules out by construction, and the config already goes
  through `flatpak run` for both.

### Installed by hand, owned by nothing

- **satty** on the Ubuntu machine is `/usr/local/bin/satty`, and
  `dpkg -S /usr/local/bin/satty` answers "no path found matching pattern": no
  package owns it, nothing updates it, and nothing records where it came from.
- **battery-threshold-toggle** is bound to a key and exists nowhere: no package,
  no file in this repo, not on `PATH`.

### Config ships, program does not

Programs whose config is tracked here while the Ubuntu machine has no binary for
it, checked with `command -v`:

- **`.config/imv/config`** ships, and the binary on Ubuntu is `imv-wayland`, not
  `imv`. The config is delivered; the name it would be launched under is not the
  name Fedora uses.
- **`chafa`** and **`kitten`** are both missing on the Ubuntu machine, so
  `fzf-preview`'s Render Ladder has no image rung there at all: `render_chafa`
  returns non-zero at its `command -v chafa` guard on every rung including the
  symbol-art floor, so an image preview falls through to `bat`.
- **`metaflac`** is missing, so `organize_flac` aborts at its
  `check_installation metaflac` guard.
- **`texlab`** is missing, so nvim's `vim.lsp.enable` list names a server that
  never starts.
- **`keepassxc`** is present but only via a PPA, not the archive.

### Two more that the survey turned up

- **Fedora's zathura installs without a PDF backend.** `zathura-pdf-poppler` is
  a Suggests there and a hard Depends on Ubuntu, so the same package name gives
  a working viewer on one distro and a viewer that opens nothing on the other.
- **`jq` is mise-managed and called from the login session.** The sway config,
  both `.config/sway/scripts/*.sh`, and `sway-start-on-workspace` all need it
  before an interactive shell has ever run `mise activate`. Excluded from this
  survey per the ticket, but it is a `PATH` assumption rather than a packaging
  one, which puts it in [06](../issues/06-config-assumptions.md).
