# 03 What the Fedora reference machine actually has

**Type:** `task` (AFK, this session runs on the ZenBook itself)

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Fedora is the reference machine, and it cannot be reached from here: every entry
in `~/.ssh/config` is a headless remote or a VM, none of them the ZenBook. So
the reference list has to be fetched by hand.

**Nothing is decided here.** The answer records facts that
[04](04-package-set-form.md), [05](05-install-route-and-manual-steps.md),
[06](06-config-assumptions.md) and [07](07-battery-threshold-keybind.md) all
depend on.

### What must come back from the ZenBook

1. **Explicitly installed packages**, not the full dependency closure:
   `dnf repoquery --userinstalled --qf '%{name}'`.
2. **Enabled third-party repositories**: `dnf repolist --enabled`, plus which
   COPRs are enabled.
3. **Flatpaks**: `flatpak list --app --columns=application,origin`.
4. **Programs outside any package**: what sits in `/usr/local/bin` and
   `~/.local/bin` that neither this repo nor mise put there.
5. **`battery-threshold-toggle`**: it is bound in `.config/sway/config` and
   exists nowhere in this repo. Its source, its content, and the sudoers entry
   that lets it run without a password.
6. **Anything else held together by hand**: sudoers drop-ins, systemd units the
   repo does not ship, udev rules, anything the operator remembers configuring
   once and never wrote down.

### The comparison that matters

The interesting output is not the Fedora list itself but the **difference**
against this Ubuntu machine, and specifically the things Fedora has that Ubuntu
lacks silently: `imv` is already one such case, found while charting.

## Answer

**Resolved on the ZenBook itself.** The ticket's premise, that the reference
machine cannot be reached, was true when it was written from the EliteBook and
is false from here: this session ran on `ASUSTeK ZenBook UX363EA`, Fedora Linux
44 (Sway), kernel 7.2.5. Every command below was run locally, as the user,
except the sudoers question, which `sudo -n -l` answered without a password
prompt because of the very rule it reports. Nothing was installed, removed or
changed.

### 1. The two lists, and why only one of them is usable

`dnf repoquery --userinstalled --qf '%{name}'` returns **443 names**, and the
list does not separate what somebody installed from what the Sway spin's live
ISO put there. The machine was installed from that ISO, so the image build is
recorded as user-installed too, and the list contains `bash`, `filesystem`,
`setup` and `shim-x64` beside the programs this repo invokes.

The origins of those 443, joined against
`dnf repoquery --installed --qf '%{name}|%{from_repo}'`: **201** `updates`,
**138** `fd6afd52f6a94c888514cdc4ebeea0b2` (the anaconda install medium), **46**
`fedora`, **37** `<unknown>`, and 21 across seven third-party repository ids,
belonging to five sources, plus `@commandline`. The 175 anaconda and `<unknown>`
rows are not the measure of how much came from the ISO, because `from_repo`
records the **last** transaction that touched a package, not the one that first
installed it: an ISO package upgraded since reports `updates`. That is precisely
why the field cannot answer the question.

`dnf history list` can. Transactions **1 and 2** (2026-04-22,
`dnf5 --config /kiwi_dnf5.config` and `/builddir/result/image`) are the image
build. Everything from **3** onward (2026-05-30 11:21 to 2026-09-19) is this
machine's own history, 120 transactions, and the `install` lines in it name what
was installed here and when.

### 2. Third-party sources, and the two ways they were enabled

`dnf repolist --enabled` reports 11 repositories. Three are Fedora's own
(`fedora`, `updates`, `fedora-cisco-openh264`; `updates-testing` is **not**
enabled). The other eight belong to five foreign sources, RPM Fusion accounting
for four ids on its own:

| Repository                | Enabled how                                                                                                              | `.repo` file owned by              |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- |
| `terra`                   | `dnf install --nogpgcheck --repofrompath terra,https://repos.fyralabs.com/terra$releasever terra-release` (tx 6)         | `terra-release-44-9`               |
| `rpmfusion-free/-nonfree` | `dnf install https://mirrors.rpmfusion.org/{free,nonfree}/fedora/rpmfusion-{free,nonfree}-release-44.noarch.rpm` (tx 12) | `rpmfusion-*-release-44-3`         |
| `protonvpn-fedora-stable` | `dnf install ./protonvpn-stable-release-1.0.4-1.noarch.rpm` (tx 24, repeated at 35)                                      | `protonvpn-stable-release-1.0.4-1` |
| `librewolf`               | a bare `/etc/yum.repos.d/librewolf.repo`, **owned by no package**                                                        | nothing                            |
| `docker-ce-stable`        | a bare `/etc/yum.repos.d/docker-ce.repo`, **owned by no package**                                                        | nothing                            |

So there are exactly **two enablement mechanisms**, and the split matters for
[05](05-install-route-and-manual-steps.md): three sources arrive as a release
RPM that carries its own repo definition and GPG key, and two are a file dropped
into `/etc/yum.repos.d/` by hand. **No COPR is enabled**, and there are no
`_copr*.repo` files.

`enabled=1` is set in `librewolf.repo` with `gpgcheck=1`, `repo_gpgcheck=1` and
`gpgkey=https://repo.librewolf.net/pubkey.gpg`, which is LibreWolf's own
repofile verbatim.

### 3. The survey's blind spot: Terra

[The survey](../research/02-package-availability.md) checked Fedora's own
repositories, COPR by name, RPM Fusion and Flathub. It never checked
[Terra](https://terra.fyralabs.com/), and Terra is where two of its three
hardest cases actually come from on this machine:

- **`satty` 0.22.0-1.fc44, from `terra`.** The survey concluded "absent
  everywhere", and on the Ubuntu machine that conclusion is still right, which
  is why `satty` sits in `/usr/local/bin` there. On Fedora it is a packaged
  program from a repository with a GPG key.
- **`ghostty` 1.3.1-3.fc44, from `terra`**, installed at tx 7, not from the
  `scottames/ghostty` COPR the survey named. Terra was enabled at tx 6, one
  transaction earlier, for exactly this.
- `spotify-launcher` 0.6.6-2.fc44 also comes from Terra.

This is a correction to the survey's facts, not to its method: two of its
`absent everywhere` and `COPR` cells are answered by a fourth Fedora source it
did not query, and `spotify-launcher` is not in the survey at all. It does
**not** change the Ubuntu side, where Terra has no counterpart.

Terra was checked for the survey's other Fedora gaps and closes none of them:
`dnf repoquery --repo=terra texlab` and the same for `clang-tools-extra`,
`librewolf` and `proton-vpn-cli` all return nothing. So neither Fedora's archive
nor Terra carries `texlab`; the survey's own `shadow53/texlab` and
`efoerster/texlab` COPRs remain the packaged routes it named, and this machine
uses none of them.

### 4. The roster, probed on this machine

Every binary in the survey's tables was resolved with `command -v` and then
`rpm -qf` on the resolved path. **Nothing in the roster is missing**, and five
binaries, in three rows below, come from no package at all:

| Binary                                 | Path                                       | Provided by                    |
| -------------------------------------- | ------------------------------------------ | ------------------------------ |
| `battery-threshold-toggle`             | `/usr/local/bin/battery-threshold-toggle`  | **no package** (see section 6) |
| `clangd`, `clang-format`, `clang-tidy` | `~/.local/llvm/LLVM-22.1.3-Linux-X64/bin/` | **a hand-extracted tarball**   |
| `texlab`                               | `~/.cargo/bin/texlab`                      | **`cargo install`**            |

`clang-tools-extra` is **not installed** here, although the survey lists it as
the Fedora route and it exists in Fedora. `llvm` was installed at tx 18 and
removed again at tx 19 on the same minute. The three binaries on `PATH` today
come from an LLVM 22.1.3 release tarball unpacked under `~/.local/llvm/`. On the
reference machine, the reference answer for clangd is therefore **not a
package**, and [06](06-config-assumptions.md) has to decide whether that is the
route to reproduce or the thing to replace.

Everything else resolves to the Fedora, Terra, RPM Fusion, LibreWolf or
ProtonVPN **package the survey named**. The versions have moved on since it was
run, in both directions and without pattern: `SwayNotificationCenter` is 0.12.6
against its 0.12.5, `foot` 1.27.0 against 1.26.1, `wireplumber` 0.5.17 against
0.5.14, while `file` is 5.46-10 where the survey read 5.48-2 from
`updates-testing`, which is not enabled here. Package identity is what carried
over; version numbers in the survey are a snapshot and should not be read as
facts about this machine. The divergences that matter:

- **`imv` and `imv-wayland` both exist here**, both `/usr/bin`, both from
  `imv-5.0.1-1.fc44`. The Ubuntu package ships only `imv-wayland`. So
  `command -v imv` succeeds on Fedora and fails on Ubuntu with the same package
  installed: the asymmetry [06](06-config-assumptions.md) and
  [08](08-completeness-check.md) were charted around is confirmed, and it runs
  in one direction only.
- **`zathura` has its backend, and only because it was installed by hand.** The
  history shows `zathura` (tx 50), then `zathura-pdf-poppler` (tx 51), then a
  swap to `zathura-pdf-mupdf` (tx 89, 90) six weeks later. The survey's warning
  that Fedora's `zathura` installs without a PDF backend is confirmed by the
  machine's own history.
- **`ffmpeg` is RPM Fusion's, not Fedora's `ffmpeg-free`**, swapped at tx 13
  with `dnf swap ffmpeg-free ffmpeg --allowerasing`, followed by
  `dnf update @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin`
  at tx 14. That is Fedora's documented multimedia route and it is two commands,
  not a package name.
- **`protonvpn` is `proton-vpn-cli-1.0.3-1.fc44`**, reached only on the fourth
  attempt: `proton-vpn-cli` at tx 20 before the repository existed,
  `python3-proton-vpn-cli` at tx 22, both removed, then
  `proton-vpn-gnome-desktop` at tx 30, removed at tx 32, and finally the release
  RPM at tx 35 and `proton-vpn-cli` at tx 36. The GUI metapackage both of
  Proton's install pages recommend was installed and then deliberately removed.
- **`slurp` 1.5.0-6.fc44 is installed** although, as the survey found in
  passing, nothing in the repo invokes it.
- `direnv` is installed twice over: `dnf install direnv` at tx 103 and
  `.config/mise/config.toml`. mise's copy wins, being earlier on `PATH`.

Session plumbing, which the repo configures but never provides:
`sway-systemd-0.4.1-4`, `sway-config-fedora-0.4.3-3` and
`sddm-wayland-sway-0.4.3-3`, with `sddm` as the display manager
(`/etc/systemd/system/display-manager.service` →
`/usr/lib/systemd/system/sddm.service`, enabled). Which package owns what was
checked rather than assumed: `rpm -qf /usr/share/wayland-sessions/sway.desktop`
answers **`sway-config-fedora`**, and `sddm-wayland-sway` owns
`/usr/lib/sddm/sddm.conf.d/wayland-sway.conf`,
`/usr/libexec/sddm-compositor-sway` and the greeter's theme, so it is the
compositor SDDM runs for **itself**, not the entry for the user's session.

This is a divergence and not a hole. Ubuntu's own `sway` package ships
`/usr/share/wayland-sessions/sway.desktop`
([its file list](https://packages.ubuntu.com/resolute/amd64/sway/filelist)),
which Fedora's `sway` does not; there the spin's `sway-config-fedora` supplies
it. So the session entry exists on both machines, from a different package each
time, and what is left open for [05](05-install-route-and-manual-steps.md) is
only whether the route installs a greeter at all. The survey reached the same
verdict for `sway-systemd`: its absence on Ubuntu is covered by the config's
`dbus-update-activation-environment` fallback.

Input method: `fcitx5` 5.1.22 with `fcitx5-hangul`, `fcitx5-configtool`,
`fcitx5-gtk{,2,3,4}` and `fcitx5-qt{,5,6}`. The hangul engine is the reason the
input method is not optional, and it is a separate package from `fcitx5` (tx 47
and 48).

Fonts: `~/.local/share/fonts` holds `Geist`, `Libertinus`, `Maple_Mono_NF`,
`Noto_CJK_Sans` and `Noto_CJK_Serif`, all five from `font-install`. No font
package was installed by hand.

### 5. Flatpaks

Seven applications, all from `flathub`, which is the only configured remote
beside the unused `fedora` OCI remote:

```
com.obsproject.Studio          org.libreoffice.LibreOffice
md.obsidian.Obsidian           org.localsend.localsend_app
org.kde.okular                 org.mozilla.thunderbird
org.zotero.Zotero
```

Two of them, `md.obsidian.Obsidian` and `org.mozilla.thunderbird`, are launched
by `.config/sway/config`; the other five are invoked nowhere in this repo.
Whether that line is also the boundary of a managed set is
[04](04-package-set-form.md)'s to draw.

Two of the seven replaced an RPM of the same application: `libreoffice`,
installed at tx 66 and removed at tx 100, and `okular`, installed at tx 92 and
removed at tx 98, each time pulling in or dropping about 90 packages. `kwrite`
went the same way in tx 95 and 98 but has no Flatpak here, so it was dropped
rather than replaced. The machine has already made the move the map's Flatpak
rule describes, and made it twice.

### 6. `battery-threshold-toggle`, complete

It is four pieces, none of them in this repo, and the keybind reaches only the
first.

**The script**, `/usr/local/bin/battery-threshold-toggle`, `root:root`, mode
755, 961 bytes, dated 2026-06-06:

```bash
#!/usr/bin/env bash
set -e

THRESHOLD_FILE="/sys/class/power_supply/BAT0/charge_control_end_threshold"
STATE_FILE="/etc/battery-threshold-mode"

if [[ ! -f "${THRESHOLD_FILE}" ]]; then
    echo "Threshold file note found: ${THRESHOLD_FILE}"
    exit 1
fi

current=$(cat "${THRESHOLD_FILE}")

if [[ "${current}" -ge 100 ]]; then
    new_threshold=60
    mode="Conservative (60%)"
else
    new_threshold=100
    mode="Full (100%)"
fi

echo "$new_threshold" > "$THRESHOLD_FILE"
echo "$new_threshold" > "$STATE_FILE"
echo "Battery threshold set to: ${mode}"

REAL_USER=${SUDO_USER:-$USER}

if command -v notify-send &> /dev/null; then
    # sudo -u sorgt dafür, dass die Benachrichtigung auf dem Desktop des Nutzers auftaucht
    sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$REAL_USER")/bus" \
    notify-send "Batterie-Modus" "Schwelle geändert auf: ${mode}" -t 3000
else
    echo "Hinweis: notify-send ist nicht installiert."
fi
```

It does not meet this repo's shell standards: no `set -euo pipefail`, unbraced
`$new_threshold` and `$THRESHOLD_FILE` on the write lines, German strings, and a
typo, `Threshold file note found`. It also calls `sudo` a second time from
inside a script that is already running as root, to reach the user's session
bus.

**The sudoers rule**, from `sudo -n -l` (`/etc/sudoers.d/` is `root:root` 750
and cannot be listed as the user):

```
User hpark may run the following commands on hpark:
    (ALL) ALL
    (ALL) NOPASSWD: /usr/local/bin/battery-threshold-toggle
```

The `NOPASSWD` entry is what makes the keybind work at all. `sudo -n -l`
returning at all, without a prompt, is itself the proof that the rule is live.
Which file under `/etc/sudoers.d/` holds it cannot be read without root.

**The systemd unit**, `/etc/systemd/system/battery-threshold.service`, `enabled`
against a preset of `disabled`, which is the third piece and was not in the
ticket's list:

```ini
[Unit]
Description=Set Battery charge threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'val=$(cat /etc/battery-threshold-mode 2>/dev/null || echo 60); echo "$val" > /sys/class/power_supply/BAT0/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
```

**The state file**, `/etc/battery-threshold-mode`, `root:root` 644, currently
`60`. The unit reads it at boot to restore the threshold, because the sysfs
value does not survive a reboot. The script writes it so the unit can. So
[07](07-battery-threshold-keybind.md) is deciding about **four** artifacts, and
three of them are root-owned files outside `${HOME}` that stow can never deploy.

The sysfs path is `charge_control_end_threshold` under `BAT0`, which exists on
this ZenBook. `asusctl`, which would be the vendor route, was installed at tx 76
and removed at tx 77 the same minute.

### 7. Everything else held together by hand

- **`/etc/systemd/system/` holds exactly one unit file of its own**,
  `battery-threshold.service`. Everything else at that level is a symlink or a
  dependency directory, `.wants` or `.requires`. Three further system services
  are `enabled` against a `disabled` preset and therefore switched on by hand:
  `docker.service`, `libvirtd.service`, `me.proton.vpn.split_tunneling.service`.
- **`/etc/udev/rules.d/` is empty.** No rules.
- **One user unit is enabled against a `disabled` preset**: `syncthing.service`.
  The map already treats Syncthing as a manual step; this is the exact form it
  takes on the reference machine.
- **Group memberships**: `hpark` is in `wheel`, `docker`, `wireshark` and
  `libvirt`. Each is a per-machine, root-owned change no `bootstrap.sh` makes,
  and docker and libvirt are what `.envs.sh`'s two `_export_if_socket` probes
  are probing for.
- **`~/.env` carries `PATH` additions, not only secrets.** `.envs.sh` sources it
  with the comment "machine-local secrets only (credentials, tokens);
  untracked", and on this machine its first two lines prepend
  `~/.local/llvm/LLVM-22.1.3-Linux-X64/bin` and `~/.opencode/bin` to `PATH`.
  `clangd` on the reference machine therefore depends on an untracked file whose
  stated purpose excludes what it is doing. This is a finding for
  [06](06-config-assumptions.md).
- **`~/.local/bin` holds a hand-installed winapps**: `winapps-src/` with
  `winapps` and `winapps-setup` symlinks, plus 18 generated launcher scripts
  (`WINWORD`, `excel-o365`, `powershell`, `windows`, and so on). Its
  dependencies were installed at tx 108,
  `dnf install -y curl dialog freerdp git iproute libnotify nmap-ncat`, and it
  is why `@virtualization` (tx 49) and the docker packages (tx 110, 111,
  replacing podman) are on the machine. `mise` and a `python3.12` symlink into
  uv's store also live there.
- **`~/.local/bin/wheel` is orphaned.** 162 bytes, dated 2026-07-11, owned by no
  package, and it is not a winapps launcher. It is a console script that does
  `from wheel._commands import main`, and `python3 -c 'import wheel'` on this
  machine raises `ModuleNotFoundError`, so it is a leftover of a Python
  environment that no longer exists.
- **`/usr/local/bin` holds nothing but `battery-threshold-toggle`.** No `satty`
  here, unlike the Ubuntu machine.
- **No snap.** `snapd` is not installed and `/var/lib/snapd/` does not exist.
  Fedora's stock `sudoers` `secure_path` nevertheless lists
  `/var/lib/snapd/snap/bin`; that is the distribution default and not evidence
  of anything installed.

### 8. Where the reference machine is wider than the repo

The install history contains far more than the repo's roster, and
[04](04-package-set-form.md) needs the boundary. Installed by hand and invoked
by nothing in this repo: `pass`, `cmus`, `gimp`, `chromium`, `spotify-launcher`,
`wireshark`, `hashcat`, `nmap`, `checksec`, `ddcutil`, `waypipe`, `wl-mirror`,
`fastfetch`, `socat`, `tuned-utils`, `hunspell` with the German and English
dictionaries, `texlive-scheme-full` (5081 packages, of which the repo needs only
`latexmk` and `latexindent`), the `development-tools` and `development-libs`
groups, `@virtualization`, the docker packages, and a set of `-devel` packages
(`cairo`, `gdk-pixbuf2`, `gtk4`, `libadwaita`, `libepoxy`, `gtk4-layer-shell`)
that are build dependencies of something no longer identifiable.

A package set derived from "what is installed" would carry all of this. A
package set derived from "what the repo invokes" carries none of it, and then
`texlive-scheme-full` becomes the question of whether the repo asks for a 5081
package scheme or for two binaries.

### 9. The comparison the ticket asked for

Against the Ubuntu machine, as the survey recorded it, the gaps that are silent
in each direction:

| Case              | Fedora reference                                  | Ubuntu                                | Direction                                          |
| ----------------- | ------------------------------------------------- | ------------------------------------- | -------------------------------------------------- |
| `satty`           | Terra package, `/usr/bin/satty`                   | no package anywhere, `/usr/local/bin` | Fedora has a route Ubuntu does not                 |
| `ghostty`         | Terra package                                     | `universe` package                    | different source, same program                     |
| `imv`             | both `imv` and `imv-wayland` on `PATH`            | only `imv-wayland`                    | `command -v imv` lies on Ubuntu only               |
| `zathura` backend | needs an explicit `zathura-pdf-mupdf`             | pulled in as a dependency             | Fedora fails silently, as a PDF that does not open |
| `texlab`          | no archive or Terra package, `cargo install` here | `universe` package                    | Ubuntu has an archive route Fedora does not        |
| `clangd`          | `clang-tools-extra` exists, unused; tarball here  | `clangd` package                      | the packaged route is available and not taken      |
| `ffmpeg`          | RPM Fusion, after a `dnf swap`                    | `universe` package                    | two commands versus one name                       |
| session entry     | `sway.desktop` from `sway-config-fedora`          | `sway.desktop` from `sway` itself     | different package, same file; not a hole           |
| `thunderbird`     | Flatpak                                           | snap transition stub in the archive   | already decided by the Flatpak rule                |

### Commands run

```sh
dnf repoquery --userinstalled --qf '%{name}\n'
dnf repoquery --installed --qf '%{name}|%{from_repo}|%{version}-%{release}\n'
dnf repolist --enabled
dnf history list
dnf history info <id>          # for the truncated command lines
rpm -qf "$(readlink -f "$(command -v <binary>)")"   # for each roster binary
rpm -qa 'fcitx5*' 'zathura*' 'xdg-desktop-portal*'
flatpak list --app --columns=application,origin
flatpak remotes --columns=name,url
sudo -n -l
systemctl list-unit-files --state=enabled --type=service
systemctl --user list-unit-files --state=enabled
systemctl cat battery-threshold.service
find /etc/systemd/system -maxdepth 1 -type f
ls -la /etc/udev/rules.d/ /usr/local/bin/ ~/.local/bin/ ~/.local/share/fonts/
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
id
```

### What is still not known

`/etc/sudoers.d/` cannot be listed without root, so the **filename** holding the
`NOPASSWD` rule is unknown; its content is known from `sudo -n -l`. Nothing else
in the ticket's list went unanswered.
