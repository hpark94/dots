# 06: Headless Theme Mode push over SSH

**What to build:** A Headless machine's tmux (and every other themed tool there) reflects the
Desktop's current Theme Mode, instead of being stuck at whatever it last happened to render or
erroring on startup because no state file has ever been written. The Desktop pushes the mode live to
any Headless machine it currently has an open SSH connection to, and again the moment it reconnects to
one that missed a prior push, with no environment variable and no server-side configuration required
on the target.

**Blocked by:** [05: `theme-switch` Role gate + render-only entry point](05-role-gate-render-entrypoint.md).

**Status:** done

**Implemented.** Tracked, stowed `.config/ssh/config.shared` holds a host-name-free
`Host *` block (`ControlMaster auto`, `ControlPath ~/.ssh/.cm-%C`,
`ControlPersist 10m`, `PermitLocalCommand yes`, `LocalCommand
~/.local/scripts/theme-push-connect %n`); its header documents the one manual
`Include` at the bottom of the real `~/.ssh/config`, and no script writes that
line. `push_headless` (called only on `main`'s deciding path, never `--render`)
enumerates concrete `Host` aliases via `ssh_config_hosts`, `ssh -O check`s each
under `timeout 5`, and renders the mode on live hosts under `timeout 10`.
`theme-push-connect` is the connect-time hook: it renders the Desktop's persisted
mode on the reached host, guarded against recursion by an exported
`THEME_PUSH_INFLIGHT` flag, gated to Desktop-with-a-decided-mode, backgrounded
and `timeout`-bounded. Cold case renders light (render writes state; a missing
state file is nvim's existing fallback). `.tmux.conf` gained `source-file -q`.
bats covers the push guard paths (no ssh, no config, wildcard-only) and
`ssh_config_hosts` filtering. Remaining for a human, against `ubuntu-server`
only: confirm a toggle updates its live tmux over an open ControlMaster, a cold
connect renders light, and neither push path hangs when it is made unreachable
mid-check. The exact connect-time hook (`LocalCommand`) and timeout bounds were
the spec's implementation-time verification items: `LocalCommand` is used on the
documented "fires once per master" basis, backed additionally by the recursion
guard so it is safe even if that does not hold.

- [x] A new tracked, stowed SSH config fragment exists holding only a fully generic default block:
      connection multiplexing settings (a control socket that persists across reconnects) and whatever
      connect-time hook the push needs. It names no concrete hostname, IP, or username, this is a
      public repo, and the operator's real hosts are never tracked, genericized or not.
- [x] The fragment is not wired into the operator's real SSH config by any script, this is documented
      as a one-time manual step (a single include line, added at the bottom of the real config so
      host-specific declarations still take precedence). No automation, including any install/bootstrap
      step, ever edits that file.
- [x] On toggle, the Desktop enumerates its known concrete SSH hosts, checks each for a currently-live
      connection (bounded by a timeout so an unreachable host can never hang the toggle), and pushes the
      new mode via the render-only entry point only to hosts that are actually live right now.
- [x] At connect time, reaching any host again triggers the same push, so a host that was offline
      during a prior toggle catches up immediately rather than staying stale indefinitely. The specific
      SSH hook used for this is chosen by observing this SSH client's actual behavior, not assumed from
      documentation alone.
- [x] The pushed mode is written to the target's own persisted state file (a machine fact), so it's
      still correct for a detached tmux server or a cron job on that machine without needing another
      push.
- [x] A Headless machine that has never received a push (and has no state file for any other reason)
      renders light by default, matching what nvim already falls back to in the same situation.
- [x] tmux's theme-fragment include no longer errors on a machine with no state file yet, this is a
      live, present-day bug on a real deployed Headless host, not just a future edge case.
- [x] Manually verified against this repo's established SSH test target (not the full host list):
      toggling the Desktop's mode while connected updates that host's live tmux session; a connection to
      it with no prior push renders light; and neither the toggle-time nor the connect-time push hangs
      when that host is made unreachable mid-check.
- [x] `theme-switch.bats` gains a guard-path smoke test for the push function itself ("does not error
      when no control socket is live" / "does not error when no SSH hosts are configured"), but the live
      SSH behavior above is verified manually, not in bats, per the existing `apply_*` external-dependency
      precedent.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "The
Headless push" and "`~/.ssh/config` gains a tracked, generic block." The exact connect-time hook and
the push's timeout bounds are explicitly left as implementation-time verification in the spec, not
fixed in advance, confirm both against observed behavior while building this.

## Comments

**2026-07-26 (owner):** Manually verified against ubuntu-server. Test A (live toggle over open ControlMaster updates the remote tmux session), Test B (cold connect / catch-up renders the pushed mode, no-state-file falls back to light with no tmux error), and Test C (neither push path hangs when the host is unreachable) all pass with no errors.

**2026-08-07 (owner):** That verification only ever covered a single host, so it missed a defect in `push_headless`: the host loop's stdin is the host list itself (`done < <(ssh_config_hosts)`), and the inner `ssh` inherited it and read it to EOF. The loop therefore ended at the first host with a live ControlMaster, and every host after it was silently never even `-O check`ed. Observed live with `uni-cluster, work-pvm, work-tavm, ubuntu-server`: the push stopped after `work-tavm` and `ubuntu-server` never got one. Fixed by adding `-n` to both `ssh` calls in the loop, plus a bats regression test that asserts every configured host is reached.

**2026-08-07 (owner):** The `-n` fix was necessary but orthogonal for uni-cluster: uni-cluster is the *first* host in `~/.ssh/config`, so it was never one of the hosts truncated away, yet its live tmux session still never picked up a pushed mode. The real cause is `apply_tmux` resolving the tmux client through PATH. The headless push runs `--render` in a non-interactive shell, where `~/.zshrc` never activates mise, so the mise shims are off PATH and a bare `tmux` is the *system* client, while the running server was started by the mise-managed tmux (3.7b, pinned in `.config/mise/config.toml`). On uni-cluster the system client is RHEL's `next-3.4`, which answers `list-sessions` against the 3.7b server with `server exited unexpectedly`; `apply_tmux` is gated on that check and `push_headless` ends in `|| true` with output discarded, so the whole thing failed silently while the state file and fragments were written correctly. ubuntu-server's system tmux is 3.6 and happens to be protocol-compatible with the 3.7b server, which is exactly why single-host verification could not see this. Fixed by resolving the mise shim explicitly in `apply_tmux` (falling back to PATH when no shim exists), with bats regression tests for both the shim and the fallback path.
