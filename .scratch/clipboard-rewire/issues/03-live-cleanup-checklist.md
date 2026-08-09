# 03: Live cleanup checklist (operator, by hand)

**What to build:** Nothing agent-built. This ticket tracks the operator retiring
the clipboard tunnel on their actual running Desktop and in their real,
untracked `~/.ssh/config`, neither of which any script in this repo touches.

**Blocked by:**
[01: OSC 52 clipboard rewire, tunnel deleted](01-osc52-clipboard-rewire.md),
confirm the new mechanism works before tearing down the old one.

**Status:** done

Completed by the operator: OSC 52 copy-paste confirmed working over SSH, and the
`clipboard-tunnel.service` unit plus its leftover symlink are removed from the
live Desktop.

- [x] Confirm OSC 52 copy-paste works correctly (per ticket 01's manual
      verification) before proceeding.
- [x] `systemctl --user disable --now clipboard-tunnel.service` on the Desktop.
- [x] Remove the now-unmanaged unit file left under `~/.config/systemd/user/`
      once `stow` no longer symlinks it there.
- [x] Delete the four `RemoteForward 11989 localhost:11989` lines from the real
      `~/.ssh/config`.

**Further Notes:** See `.scratch/clipboard-rewire/spec.md`, Implementation
Decisions → "Live cleanup is a manual, documented checklist, not shipped as
code."
