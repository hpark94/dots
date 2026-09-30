# 08: Retire the ZenBook's hand-built pieces

**What to build:** The reference machine runs on what the repo now describes:
the charge limit through the hwdb file and `battery-charge-limit`, the clang
tools through mise, and every package the roster promises. The hand-built pieces
these replace are gone. `completeness-check.sh` reports it complete.

**Blocked by:** [04](04-battery-charge-limit.md),
[05](05-clang-tools-from-mise.md), [07](07-install-document.md)

**Status:** done

It touches `/etc`, root-owned files and untracked files in `${HOME}`, so it is a
human's to run. An agent can prepare each command and wait for a yes before
running it.

- [x] `mise install` has put clangd, clang-format and clang-tidy in place, and
      `gcc-c++` is installed.
- [x] The hwdb charge-limit step from `docs/install.md` is done:
      `/etc/udev/hwdb.d/61-battery-local.hwdb`, `systemd-hwdb update`,
      `udevadm trigger`.
- [x] The four legacy artifacts from
      [the reference inventory](../../distro-provisioning/issues/03-fedora-reference-inventory.md)
      section 6 are removed: `/usr/local/bin/battery-threshold-toggle`, its
      sudoers rule (which file under `/etc/sudoers.d/` holds it can only be read
      as root), `/etc/systemd/system/battery-threshold.service` (disabled
      first), and `/etc/battery-threshold-mode`.
- [x] `Control+Alt+p` toggles the limit with a notification and no password.
      After a new login, `restore` has turned it back on.
- [x] `~/.local/llvm` is removed, and both `PATH` lines have left `~/.env`: the
      one for `~/.local/llvm/LLVM-22.1.3-Linux-X64/bin` and the one for
      `~/.opencode/bin`, which restores the file to secrets only. In a new
      shell, `command -v clangd clang-format clang-tidy` resolves into mise;
      nvim attaches clangd to a `cpp` buffer, formats it, and lints it.
- [x] `./completeness-check.sh` exits 0. Anything it reported missing was
      installed along the route in `docs/install.md`.

**Further Notes:** Spec, Further Notes. The artifacts and their locations are in
[What the Fedora reference machine actually has](../../distro-provisioning/issues/03-fedora-reference-inventory.md)
section 6. Their removal is decided in
[The battery threshold keybind and its missing script](../../distro-provisioning/issues/07-battery-threshold-keybind.md)
section 3, and the tarball's in
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
section 7. Do the hwdb step before removing the old service, so the cap is never
unmanaged across a reboot.
