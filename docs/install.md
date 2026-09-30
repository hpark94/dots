# Install

From a bare Fedora or Ubuntu install to a working Desktop. The route is the same
on both distributions; where a step differs, it carries one command block per
distro, and you run the one that applies.

## Phase 1: the system

Every command here except the clone carries its own `sudo`. Do not run this
phase from a root shell: cloning as root leaves a root-owned working tree that
`bootstrap.sh` then stows from.

1. Clone the repo and stay in it. The install lines and step 6 read `packages/`
   relative to the working directory.

   ```sh
   git clone <repo-url> ~/dots && cd ~/dots
   ```

2. Enable the foreign sources. Each one is enabled by following the vendor's own
   page, which is the part that ages with the vendor; this document names what
   comes out of each source and where this setup departs from the page.

   Fedora:
   - [Terra](https://docs.terrapkg.com/usage/installing): supplies `satty` and
     `ghostty`. The `--nogpgcheck` in its install command applies to the release
     RPM itself.
   - [RPM Fusion](https://rpmfusion.org/Configuration), free and nonfree:
     supplies the unrestricted `ffmpeg` that step 4 swaps in.
   - [LibreWolf](https://librewolf.net/installation/rhel/): supplies
     `librewolf`. The reference machine has a bare
     `/etc/yum.repos.d/librewolf.repo` that no package owns, which predates the
     page's current `dnf config-manager addrepo` route. Follow the page.

   Ubuntu:
   - [LibreWolf](https://librewolf.net/installation/debian/): supplies
     `librewolf`.

   Optional, on both distros:
   - ProtonVPN
     ([Fedora](https://protonvpn.com/support/official-linux-vpn-fedora/),
     [Ubuntu](https://protonvpn.com/support/official-linux-vpn-ubuntu/)):
     supplies `protonvpn`, which `.config/sway/config` connects with. The page
     goes on to install the GUI metapackage `proton-vpn-gnome-desktop`; the
     `protonvpn` binary comes from `proton-vpn-cli`, in the same repository.
     Skip the page's install step and use the optional install line instead:

     ```sh
     sudo dnf install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $3); if ($3 !~ /^-*$/ && $3 != "fedora") print $3}' packages/optional.md | sort -u)
     ```

     ```sh
     sudo apt install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $4); if ($4 !~ /^-*$/ && $4 != "ubuntu") print $4}' packages/optional.md | sort -u)
     ```

     The page's Fedora command reads `/etc/fedora-release`. That is a vendor
     command in a documented step, which ADR-0011 does not reach.

3. Install the native package set.

   Fedora:

   ```sh
   sudo dnf install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $3); if ($3 !~ /^-*$/ && $3 != "fedora") print $3}' packages/roster.md | sort -u)
   ```

   Ubuntu:

   ```sh
   sudo apt install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $4); if ($4 !~ /^-*$/ && $4 != "ubuntu") print $4}' packages/roster.md | sort -u)
   ```

4. Fedora only: replace the limited `ffmpeg-free` with RPM Fusion's `ffmpeg`.

   ```sh
   sudo dnf swap ffmpeg-free ffmpeg --allowerasing
   sudo dnf update @multimedia
   ```

5. Ubuntu only: satty is in no archive, so it comes from the pinned release, the
   same version Terra ships on Fedora.

   ```sh
   curl -fsSL https://github.com/Satty-org/Satty/releases/download/v0.22.0/satty-x86_64-unknown-linux-gnu.tar.gz \
     | sudo tar -xz -C /usr/local/bin ./satty
   ```

6. Add the flathub remote and install the Flatpaks system-wide.

   ```sh
   sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
   sudo flatpak install flathub $(cat packages/flatpak.txt)
   ```

## Phase 2: the home

Before the first graphical login.

1. Install the fonts: `~/dots/.local/scripts/font-install`.
2. Make zsh the login shell: `chsh -s "$(command -v zsh)"`.
3. Export a GitHub API token, as `README.md` explains:
   `export GITHUB_TOKEN=<token>`.
4. Deploy: `~/dots/bootstrap.sh desktop`.

## Phase 3: the session

1. Log out and pick Sway at the greeter.
2. Build texlab:

   ```sh
   cargo install --git https://github.com/latex-lsp/texlab --tag v5.26.0 --locked
   ```

The login comes first because it is what puts mise's `cargo` on `PATH`:
`bootstrap.sh` activates mise only in its own process, and the shell that ran it
still has no `cargo`. A new shell, and the login gives you one, activates mise
through `.zshrc`.

## Per-machine steps

In any order, after phase 3.

- protonvpn, optional: log in and configure the network.
- Syncthing: install it, enable its user unit
  (`systemctl --user enable --now syncthing.service`), create the two folders it
  syncs with `mkdir ~/Sync ~/projects`, and pair. Sway's wallpaper appears only
  after the pairing has run.
- Put the KeePassXC database in its place.
- fcitx5: its own per-language configuration.
- Create `~/.ssh/config` with the line `Include ~/.config/ssh/config.shared`.
- The charge limit, on a machine whose UPower reports
  `ChargeThresholdSupported`: create `/etc/udev/hwdb.d/61-battery-local.hwdb`
  holding

  ```
  battery:*:*:dmi:*
   CHARGE_LIMIT=_,60
  ```

  then run `sudo systemd-hwdb update` and
  `sudo udevadm trigger -v /sys/class/power_supply/BAT0`.

### HP machines

`hp-wmi` exposes no charge threshold, so the hwdb step above does not apply
through it. Whether an HP machine offers a charge limit some other way is open
until these commands have run on it. Steps 0 to 5 are read-only and need no
root; step 6 needs `tlp` installed and root to run its probe; step 7 needs root
only to read an ACPI table.

```sh
# 0. Identify the machine, so the answer can be attached to a model.
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name \
    /sys/class/dmi/id/product_family /sys/class/dmi/id/board_name \
    /sys/class/dmi/id/bios_version
uname -r

# 1. Does any charge control attribute exist at all?
ls -l /sys/class/power_supply/
for b in /sys/class/power_supply/BAT*; do
  echo "== ${b}"
  ls -l "${b}" | grep -E 'charge_control|charge_behaviour|charge_type'
done
cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>&1
cat /sys/class/power_supply/BAT*/charge_control_start_threshold 2>&1
cat /sys/class/power_supply/BAT*/charge_behaviour 2>&1
cat /sys/class/power_supply/BAT*/charge_types 2>&1

# 2. Which HP platform drivers are loaded?
lsmod | grep -E 'hp_wmi|hp_bioscfg|hp_accel|wmi'
ls /sys/bus/wmi/devices/

# 3. Does ANY module in this kernel carry the attribute? (handles .ko, .xz, .zst,
#    .gz, so it works on both Ubuntu and Fedora)
cd /lib/modules/"$(uname -r)"/kernel
find . -name '*.ko*' -print0 | xargs -0 -P4 -I{} sh -c '
  case "{}" in
    *.zst) zstdcat "{}" 2>/dev/null ;;
    *.xz)  xzcat   "{}" 2>/dev/null ;;
    *.gz)  zcat    "{}" 2>/dev/null ;;
    *)     cat     "{}" ;;
  esac | grep -qa "charge_control_.*_threshold" && echo "{}"' | sort
grep -c "charge_control" /boot/System.map-"$(uname -r)"

# 4. Does the BIOS expose a charge setting through hp-bioscfg?
ls /sys/class/firmware-attributes/
ls /sys/class/firmware-attributes/*/attributes/ | grep -iE 'batt|charg|health'
# for each hit <name>:
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/type
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/current_value
#   cat /sys/class/firmware-attributes/hp-bioscfg/attributes/<name>/possible_values

# 5. What does UPower see?
# The object is discovered, never named: an HP battery need not be BAT0.
for dev in $(busctl --system call org.freedesktop.UPower /org/freedesktop/UPower \
      org.freedesktop.UPower EnumerateDevices | tr ' ' '\n' | grep '^"/' | tr -d '"'); do
  printf '%s ' "${dev}"
  busctl --system get-property org.freedesktop.UPower "${dev}" \
    org.freedesktop.UPower.Device ChargeThresholdSupported
done
upower -d | grep -iE 'native-path|charge'

# 6. What does TLP's own probe say? (needs tlp installed)
sudo tlp-stat -b

# 7. Are the firmware methods of the pending kernel RFC even present? (root,
#    read-only) cp would give the copy the source table's root-only mode, so
#    redirect into a file this user already owns instead.
sudo cat /sys/firmware/acpi/tables/DSDT > /tmp/DSDT.dat
iasl -d /tmp/DSDT.dat            # package: acpica-tools
grep -nE 'SBCC|SBCO|GBCC|GBCO|WHCM' /tmp/DSDT.dsl
```

What each outcome means:

- Step 1 shows `charge_control_end_threshold`: something out of the ordinary is
  in play (an out-of-tree or vendor module); step 3 names it.
- Step 1 shows only `charge_behaviour` or `charge_types`: the machine has mode
  control, not a percentage cap.
- Step 1 shows nothing and step 4 shows a battery attribute: the cap exists but
  lives in the firmware-attributes interface and is set there, likely needing a
  reboot (`pending_reboot`).
- Step 1 and step 4 both empty, step 6 prints `Plugin: generic` /
  `Supported features: none available`: the machine has no Linux charge control
  at all, and step 7 says whether the RFC's path could ever reach it.

To see what this machine still lacks, run `~/dots/completeness-check.sh`.
