# 02: The package set

**What to build:** The programs a Desktop needs, with their package names on
Fedora and Ubuntu, live in the repo as data that one `dnf install` or
`apt install` line reads. The one optional program and the two Flatpaks live
next to it. None of it is deployed into `${HOME}`.

**Blocked by:** None, can start immediately.

**Status:** ready-for-agent

- [ ] `packages/roster.md` is one flat Markdown table
      `binary | fedora | ubuntu`, sorted by the first column, with the four
      header statements the spec names.
- [ ] Its rows are what the tracked files invoke, taken from
      [the survey](../../distro-provisioning/research/02-package-availability.md),
      plus the four toolchain rows, with the spec's corrections applied: `jq`,
      `upower` and `imv-wayland | imv | imv` are in; `texlab`, `protonvpn`, the
      clang tools, `slurp` and `battery-threshold-toggle` are out.
- [ ] `-` rows and `-` cells as the spec lists them: `sway-systemd`, the two
      portals, the fcitx5 IM modules, `python3-i3ipc`, the zathura PDF backend
      and `glibc-devel` have `-` in the first column; `ffmpeg` on Fedora and
      `satty` on Ubuntu have `-` in their package column.
- [ ] Every name the survey leaves unclear (for example the fcitx5 config tool's
      binary on each side) is checked against the distro's own package metadata,
      not guessed.
- [ ] `packages/optional.md` holds the one row
      `protonvpn | proton-vpn-cli | proton-vpn-cli` in the same three columns,
      and a header saying that nothing promises what it lists.
- [ ] `packages/flatpak.txt` holds `org.mozilla.thunderbird` and
      `md.obsidian.Obsidian`, one per line.
- [ ] `.stow-local-ignore` has `^/packages`.
- [ ] After `prettier -w`, the spec's Fedora and Ubuntu install lines, and the
      same `awk` pointed at `packages/optional.md`, print exactly the expected
      package names: no header, no separator, no `-`, duplicates collapsed.

**Further Notes:** Spec section "The package set". The form and the reasoning
are in
[Where the package sets live and in what form](../../distro-provisioning/issues/04-package-set-form.md).
The corrections come from
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
sections 3 and 4,
[The battery threshold keybind and its missing script](../../distro-provisioning/issues/07-battery-threshold-keybind.md)
section 8 and
[A completeness check for a machine](../../distro-provisioning/issues/08-completeness-check.md)
section 10. The `imv` row and the missing clang rows were decided in the
handoff, in
[Turn the decisions into a spec and build tickets](../../distro-provisioning/issues/09-spec-and-build-tickets.md).
The install lines are not changed to carry exceptions: 04 proved them against a
fixture.
