# 07: `docs/install.md`, and README points at it

**What to build:** A person with a bare Fedora or Ubuntu install and this repo's
URL can follow one document to a working Desktop, and it ends by telling them
how to check the result. `README.md` still describes the short route, now for a
machine whose packages are already in place, and sends a bare install to the new
document.

**Blocked by:** [02](02-package-set.md), [06](06-completeness-check.md)

**Status:** done

- [x] `docs/install.md` follows the three phases in the spec's section "The
      install document", with shared steps once and per-distro command blocks
      only where a step differs.
- [x] Phase 1 step 2 names the sources per distro. ProtonVPN is marked optional
      and followed by its own optional install line reading
      `packages/optional.md`.
- [x] No source is enabled by a printed command: each gets the vendor's link,
      the package that comes out of it, and the deviation 05 section 7 records.
- [x] The install lines, the ffmpeg swap, the satty tarball command and the
      flathub commands are verbatim from the spec and 05. The satty URL is
      `Satty-org/Satty`.
- [x] Phase 3 says why logging in comes before the texlab build.
- [x] The per-machine steps include the hwdb charge-limit file with its two
      follow-up commands, for a machine whose UPower reports
      `ChargeThresholdSupported`, and a short HP paragraph carrying the commands
      from the mechanism survey's "Commands to settle it on the EliteBook".
- [x] No checklist. The last line names `completeness-check.sh`.
- [x] Every path and command the document names exists in the tree as named:
      `packages/*`, `font-install`, `bootstrap.sh`, `completeness-check.sh`.
- [x] `README.md`: intro and Key Highlights unchanged. Installation keeps its
      steps, says they apply to a machine whose packages are in place, and has
      one sentence pointing a bare distro install at `docs/install.md`.

**Further Notes:** Spec section "The install document". The route and its
reasoning are in
[The install route and where the manual steps are written](../../distro-provisioning/issues/05-install-route-and-manual-steps.md).
The corrections are in
[What the configs must stop assuming](../../distro-provisioning/issues/06-config-assumptions.md)
section 3 (ProtonVPN optional) and
[The battery threshold keybind and its missing script](../../distro-provisioning/issues/07-battery-threshold-keybind.md)
sections 3 and 6 (hwdb step, HP paragraph). The HP commands are in
[the mechanism survey](../../distro-provisioning/research/07-charge-threshold-mechanisms.md).
The README change is the two sentences of 05 section 9 and nothing more.

## Comments

- 2026-09-30, during [08](08-zenbook-migration.md): the hwdb step gained a third
  command, `sudo systemctl restart upower`. On the ZenBook, udev reported
  `CHARGE_LIMIT=_,60` after the two follow-up commands, but UPower stayed at its
  default 75/80, also after two `EnableChargeThreshold` toggles; only the
  restart brought the end threshold to 60.
