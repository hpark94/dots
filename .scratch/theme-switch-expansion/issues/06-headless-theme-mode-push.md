# 06 — Headless Theme Mode push over SSH

**What to build:** A Headless machine's tmux (and every other themed tool there) reflects the
Desktop's current Theme Mode, instead of being stuck at whatever it last happened to render or
erroring on startup because no state file has ever been written. The Desktop pushes the mode live to
any Headless machine it currently has an open SSH connection to, and again the moment it reconnects to
one that missed a prior push — with no environment variable and no server-side configuration required
on the target.

**Blocked by:** [05 — `theme-switch` Role gate + render-only entry point](05-role-gate-render-entrypoint.md).

**Status:** ready-for-agent

- [ ] A new tracked, stowed SSH config fragment exists holding only a fully generic default block:
      connection multiplexing settings (a control socket that persists across reconnects) and whatever
      connect-time hook the push needs. It names no concrete hostname, IP, or username — this is a
      public repo, and the operator's real hosts are never tracked, genericized or not.
- [ ] The fragment is not wired into the operator's real SSH config by any script — this is documented
      as a one-time manual step (a single include line, added at the bottom of the real config so
      host-specific declarations still take precedence). No automation, including any install/bootstrap
      step, ever edits that file.
- [ ] On toggle, the Desktop enumerates its known concrete SSH hosts, checks each for a currently-live
      connection (bounded by a timeout so an unreachable host can never hang the toggle), and pushes the
      new mode via the render-only entry point only to hosts that are actually live right now.
- [ ] At connect time, reaching any host again triggers the same push, so a host that was offline
      during a prior toggle catches up immediately rather than staying stale indefinitely. The specific
      SSH hook used for this is chosen by observing this SSH client's actual behavior, not assumed from
      documentation alone.
- [ ] The pushed mode is written to the target's own persisted state file (a machine fact), so it's
      still correct for a detached tmux server or a cron job on that machine without needing another
      push.
- [ ] A Headless machine that has never received a push (and has no state file for any other reason)
      renders light by default, matching what nvim already falls back to in the same situation.
- [ ] tmux's theme-fragment include no longer errors on a machine with no state file yet — this is a
      live, present-day bug on a real deployed Headless host, not just a future edge case.
- [ ] Manually verified against this repo's established SSH test target (not the full host list):
      toggling the Desktop's mode while connected updates that host's live tmux session; a connection to
      it with no prior push renders light; and neither the toggle-time nor the connect-time push hangs
      when that host is made unreachable mid-check.
- [ ] `theme-switch.bats` gains a guard-path smoke test for the push function itself ("does not error
      when no control socket is live" / "does not error when no SSH hosts are configured"), but the live
      SSH behavior above is verified manually, not in bats, per the existing `apply_*` external-dependency
      precedent.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "The
Headless push" and "`~/.ssh/config` gains a tracked, generic block." The exact connect-time hook and
the push's timeout bounds are explicitly left as implementation-time verification in the spec, not
fixed in advance — confirm both against observed behavior while building this.
