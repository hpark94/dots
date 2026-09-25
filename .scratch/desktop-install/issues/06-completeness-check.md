# 06: `completeness-check.sh`

**What to build:** Run from the clone on a Desktop machine, one command reports
whether the machine has everything the roster, the Flatpak list and the manual
steps promise. The missing entries are named, the rest is counted so the sum
adds up, and the exit status says complete or not. It changes nothing.

**Blocked by:** [01](01-distro-vocabulary-and-adr.md), [02](02-package-set.md)

**Status:** ready-for-agent

- [ ] `completeness-check.sh` at the repo root, with no arguments and no flags,
      and the three `.stow-local-ignore` lines from the spec.
- [ ] Functions behind the `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard, and a
      suite at `.local/scripts/tests/completeness-check.bats` that calls them
      with the external commands stubbed.
- [ ] Roster section: `command -v` on the first column. If the first column is
      `-`, the package column is queried with `rpm -q`, or with `dpkg-query`
      requiring `installed`, with every exit code handled as the spec says. `-`
      in both columns is not checkable. The package manager is picked by probing
      `rpm` and `dpkg`.
- [ ] Flatpak section: `flatpak info <id>` per line. It is not checkable without
      `flatpak`.
- [ ] Manual-steps section: the five entries from the spec. The hwdb file is
      checked only where UPower enumerates a device with
      `ChargeThresholdSupported`; otherwise the entry is
      `not supported on this machine`.
- [ ] The stdout report has the shape of 08 section 6: per section, the missing
      named, present and not checkable counted, one closing line pointing at
      `docs/install.md`. Exit 1 if anything is missing, 0 otherwise.
- [ ] Exit 2 with a message on stderr for each of the five refusals: no Role
      Marker, Headless, two package managers or none, no `busctl`, a
      `dpkg-query` exit 2.
- [ ] It does not read `packages/optional.md`, and `bootstrap.sh` does not call
      it.
- [ ] `CONTEXT.md` has the **Completeness Check** entry after Capability Probe,
      verbatim from the spec. `AGENTS.md` has a row for it in Commands and names
      it in the `bats` line.

**Further Notes:** Spec section "The completeness check". Every decision and its
reasoning is in
[A completeness check for a machine](../../distro-provisioning/issues/08-completeness-check.md)
sections 1 to 11; the Role Marker reader is described in `CONTEXT.md` and
[How a script reads the Role Marker](../../portable-dotfiles/issues/13-role-marker-reader.md).
Blocked by 01 so the new entry lands after the rewritten Capability Probe, and
by 02 because the check reads `packages/`.
