# 08 How Theme Mode reaches a Headless machine

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

There is one Theme Mode, the Desktop owns it, and a Headless machine follows one-way and cannot
change it. That was decided by [01](01-name-the-split.md). **How does the mode actually get there,
and what makes a Headless machine re-render when it changes?**

### What is already settled

- One Theme Mode across all machines. The Desktop is the sole authority.
- `theme-switch` ships whole to both Roles. On Headless, `resolve_mode` (`:21`) and `write_state`
  (`:43`) refuse; `generate_*` and `apply_*` (`:51-201`) run against whatever mode arrives.
- The rendering half is already Role-agnostic: every `apply_*` is a Capability Probe, so it does the
  right thing on a machine with no compositor without being told.

### The open questions

1. **The channel.** Candidates, none surveyed yet: `SendEnv`/`SetEnv` in `~/.ssh/config` (the four
   hosts there already carry per-host config, so this is the lowest-friction place to put something);
   writing the state file over the existing tunnel; a `LocalCommand`/`ProxyCommand` hook; or the
   Headless side simply reading a value the Desktop pushed at connect time.
2. **Granularity: per-connection or per-machine?** A mode delivered at SSH connect time is a
   **Session Fact** and dies with the session. A mode written into the Headless machine's state file
   is a **Role**-independent machine fact that outlives it, and is what a detached tmux server or a
   later `cron` job would see. These give different answers when you connect twice with the mode
   changed in between.
3. **What happens on a mode change mid-session.** The Desktop toggling does not currently reach
   anything already running elsewhere. Does a Headless machine re-render live, at next connect, or
   never? Note `apply_tmux` (`:179`) against a *remote* tmux server is the case that would visibly
   matter, since that server is long-lived.
4. **The cold case.** A Headless machine that has never been told a mode, or is reached from
   something that is not the Desktop. What does it render?

### Why this is not blocked

The mechanism is about a running channel, not about how files get deployed, so it does not wait on
[05](05-choose-deployment-mechanism.md).

### Watch for scope

The **roster** of apps `theme-switch` covers is [07](07-theme-switch-app-roster.md), not this ticket.
This one is only about getting a mode value across the wire and deciding what re-renders when.

## Answer

### 0. Two facts that reframed the question before any of it was decided

**The channel only has to carry one word.** After [05](05-choose-deployment-mechanism.md) a Headless
machine holds the whole repo: `theme-switch` itself, both palette files, every tracked config. It can
generate every fragment locally. It lacks exactly one thing, the string `dark` or `light`. Nothing
needs to cross the wire except that.

**The remote surface is three consumers, not seven.** When you SSH, the terminal runs on the Desktop
and is already correct, so `apply_foot`, `apply_sway`, `apply_gtk` and the ghostty fragment are
Desktop-side by construction. What is actually wrong on a Headless machine is tmux (the fragment plus
the running server), the shell-env fragment (`FZF_DEFAULT_OPTS`, `BAT_THEME`), and nvim reading the
state file. Of those, **only tmux behaves differently than it does locally**: on the Desktop it is
Live-switchable, on Headless it would not be. Closing that asymmetry is the whole of open question 3.

### 1. The channel: the Desktop pushes the state file over SSH

**No environment variable.** `theme-switch` writes `~/.local/state/theme/mode` on the remote and then
invokes the remote's rendering half.

The obvious candidate was `SendEnv`/`SetEnv` of an `LC_*` variable, `LC_*` being the conventional
smuggling channel because Debian and Ubuntu ship `AcceptEnv LANG LC_*` while `sshd`'s compiled
default is to accept nothing. **Probed against all four hosts rather than assumed**, with
`ssh -o SetEnv=LC_THEME_MODE=probe <host> 'echo ${LC_THEME_MODE:-DROPPED}'`:

| Host | OS | Result |
| --- | --- | --- |
| uni-cluster | RHEL 10 | **DROPPED** |
| work-pvm | Ubuntu 6.8 | passed |
| work-tavm | Ubuntu 6.8 | passed |
| ubuntu-server | Ubuntu 7.0 | passed |

It splits cleanly on distro family, and the one host that drops it is the one host that can never be
fixed. Further read-only probing of uni-cluster: `~/dots` **exists** and `~/.tmux.conf` symlinks into
`/home/lab/2026/s8077556/dots`, so the dotfiles are already deployed and in daily use there; `sudo -n`
fails, so `sshd_config` is unreachable; and there is no theme state file at all.

That makes uni-cluster a real Headless machine that structurally cannot receive an SSH environment
variable. It is also, read literally, the map's own out-of-scope category ("remotes without root or
package install"), so ruling it out was available and was rejected: the dotfiles are already there.

A push needs nothing but a login, which by definition works, so it covers every host uniformly with
**zero remote configuration**, no `sshd` dependency, and no per-host exception to forget when a fifth
host appears. It is also the most literal expression of [01](01-name-the-split.md): the Desktop is
sole authority and writes, Headless only reads.

Rejected alongside the env var: an OSC 11 terminal-background query from the remote shell (elegant,
zero config, and the mechanism Claude Code's `theme: auto` already uses successfully here, but it
needs an interactive TTY, is fiddly to read with a timeout, and inside tmux the reply may come from
tmux rather than the real terminal), and a pull over the existing `RemoteForward 11989` tunnel (most
capable, but requires a listener on the Desktop, and that port is the clipboard tunnel, which
[09](09-clipboard-backend-signal.md) may reshape anyway).

### 2. Granularity: a machine fact, not a Session Fact

The mode lands in the remote's state file and outlives the connection, so a detached tmux server, a
later `cron` job, or a second session all see it without being told again. A Session Fact delivered
per connection would die with the session and leave exactly those cases blind.

The accepted consequence, not re-litigated here because [01](01-name-the-split.md) already decided
it: a Headless machine reached from something that is not the Desktop still renders the Desktop's
mode. There is one Theme Mode and the Desktop owns it.

### 3. The shape of the push: write, then render

Two steps, because writing the state file alone changes nothing on screen: fragments do not
regenerate and the running tmux server keeps its old options.

[01](01-name-the-split.md) already cut the seam this needs. `resolve_mode` (`:21`) and `write_state`
(`:43`) **decide** and refuse on Headless; `generate_*` and `apply_*` (`:51-201`) **render** and run
anywhere. So the remote step is not new logic, only a verb meaning "render from the state file",
invoked on a Role where the deciding half is closed.

### 4. Push set: live ControlMaster sockets on toggle, plus a connect-time push

On toggle, `theme-switch` pushes only to hosts with a live master, tested per host with
`ssh -O check`. That is exactly the set where staleness is visible, it is instant, it can never hang
on an unreachable host, and it never wakes a sleeping VM. Pushing to every host in `~/.ssh/config`
was rejected on those grounds; a separate opt-in host list was rejected as a second place to
maintain host names that will drift from `~/.ssh/config`.

A connect-time push covers the rest, because a host that was offline during a toggle would otherwise
stay stale by however many toggles it missed.

**This requires `ControlMaster`/`ControlPersist`/`ControlPath` in `~/.ssh/config`, which is not
configured today.** `ssh -O check` is meaningless without a `ControlPath`. See section 7.

**On the connect-time ordering race.** A connect-time push can land just after the remote's rc has
already read the state file. This is harmless here, and deliberately so: the visible surface is tmux,
and the push runs the render half itself, so `apply_tmux` hits the running server directly regardless
of shell timing. The rc's only job is the existing `[ -f ] && source` of `shell-env.sh`.

### 5. Mid-session: live, and the asymmetry closes

Because the push runs the render half, `apply_tmux` fires against the **remote** tmux server. tmux is
therefore Live-switchable on Headless exactly as it is on Desktop, which was the one behaviour that
would otherwise have differed by Role. Everything else on a Headless machine (nvim, `FZF_DEFAULT_OPTS`,
`BAT_THEME` in already-open shells) is Next-launch there for precisely the same reasons it is
Next-launch on the Desktop, so no new asymmetry is introduced.

### 6. The cold case: light, silently, and closed at bootstrap

A machine with no state file renders **light**, which is what nvim already does
(`colorscheme.lua`'s `theme_mode()` returns `light` for a missing file, an unreadable file, or any
value that is not exactly `dark`/`light`). The shells already guard with `[ -f ]`.

`.tmux.conf:26` does **not** guard: `source-file ~/.local/state/theme/tmux-colors.conf` has no `-q`.
**This is a live bug, not a hypothetical.** uni-cluster has the dotfiles deployed and no state file,
so tmux emits a missing-file error there on every start today. Adding `-q` is the fix and makes tmux
consistent with the other two consumers.

[11](11-bootstrap-sequence.md) should write a default state file as part of install, which reduces
the cold window to the gap between clone and first render.

### 7. What this surfaced: `~/.ssh/config` is untracked and now load-bearing

`~/.ssh/config` is not in the repo at all (`git ls-files` matches nothing under `ssh`). This decision
makes it carry required configuration: `ControlMaster`/`ControlPersist`/`ControlPath`, and the
connect-time push. Whether it becomes tracked, stowed, generated, or stays hand-maintained is a real
question that touches hostnames, usernames and internal IPs, and it is not this ticket's to answer.
Raised as [12](12-ssh-config-ownership.md).

### Carried forward as implementation checks, not decisions

- **Whether `LocalCommand` is the right connect-time hook.** It fires once per master and is the
  obvious fit, but `ssh` does not wait for it, so the exact hook should be chosen against observed
  behaviour rather than the manual page. The ordering race is already established as harmless
  (section 4), so this is about reliability of firing, not sequencing.
- **The push must not hang the toggle.** `ssh -O check` against a stale socket, and any push to a
  host that dropped off between the check and the write, both need bounded timeouts.
