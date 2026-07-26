# 02 — `.envs.sh` Capability Probes

**What to build:** The three environment variables currently gated on whether the shell is an SSH
session instead react to whether the thing they actually depend on is present right now — a local
daemon's socket, or an attached compositor display. SSHing into one's own Desktop, or connecting under
waypipe, no longer strips variables that should still be set there.

**Blocked by:** None — can start immediately.

**Status:** done

Verified done on `main` (landed in `05e0d03`). `.envs.sh` now gates `DOCKER_HOST`/`LIBVIRT_DEFAULT_URI` on their sockets via `_export_if_socket`, exports `OMPI_CXX` ungated, gates `QT_QPA_PLATFORM=wayland` on `$WAYLAND_DISPLAY`, reads no Role Marker, and documents `~/.env`'s scope above the source line. Covered by `.local/scripts/tests/envs.bats` (green in the full suite).

- [x] The two variables naming a local daemon's socket path are exported only when that socket
      actually exists, not based on SSH-ness.
- [x] The variable with no real precondition is exported unconditionally, with no gate.
- [x] The variable selecting the Wayland Qt platform is exported only when a compositor display is
      attached to the current session (the same signal this repo already uses for the equivalent
      clipboard question), not based on SSH-ness.
- [x] `.envs.sh` reads no Role Marker anywhere — every branch in it after this change is a Capability
      Probe, not a Role Fact.
- [x] A one-line comment is added directly above where `.envs.sh` conditionally sources `~/.env`,
      stating its scope: machine-local secrets only (credentials, tokens).
- [x] A bats file covers `.envs.sh`: sourcing it with each socket path faked present and absent, and
      with the compositor-display variable set and unset, asserting each variable is exported or not
      accordingly.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions →
"`.envs.sh`: the last SSH-ness branch becomes real Capability Probes" and "`.env`'s scope, documented
at its source."
