# 04: `battery-charge-limit`, the charge limit without sudo

**What to build:** `Control+Alt+p` lifts or restores the battery charge limit
with no password and says which state it is in now. At every login the limit
comes back on its own, so a forgotten full-charge state lasts until the next
login at most. The repo no longer has a `sudo` in it.

**Blocked by:** None, can start immediately.

**Status:** done

- [x] `.config/sway/scripts/battery-charge-limit` takes a required verb,
      `toggle` or `restore`, and refuses anything else.
- [x] The device is found with UPower's `EnumerateDevices`, as the one whose
      `ChargeThresholdSupported` is true. No device name is hard-coded, and no
      such device is a refusal.
- [x] `toggle` reads `ChargeThresholdEnabled`, calls `EnableChargeThreshold`
      with its inverse, and notifies with the new state; a refusal also
      notifies.
- [x] `restore` calls `EnableChargeThreshold true` and never notifies.
- [x] Both verbs write a refusal to stderr and exit non-zero. `busctl` has a
      precondition check. All strings are English.
- [x] `.config/sway/config` has the two lines from the spec, and
      `exec sudo battery-threshold-toggle` is gone.
- [x] A bats suite in `.config/sway/scripts/tests/` stubs `busctl` on `PATH` and
      covers both verbs in both states, no supported device, a missing `busctl`,
      and a bad verb.
- [x] `AGENTS.md` lists the script under "Sway session scripts" and in the
      `bats` line of Commands.

**Further Notes:** Spec section "The charge limit without sudo". The mechanism
and its measurements are in
[The battery threshold keybind and its missing script](../../distro-provisioning/issues/07-battery-threshold-keybind.md)
sections 2, 4 and 5, with the `busctl` call shapes in section 4 and 9. The hwdb
file, the removal of the old artifacts and the live check are ticket 07 and
ticket 08, not this one.
