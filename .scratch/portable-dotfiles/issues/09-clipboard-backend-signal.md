# 09 What signal picks the clipboard backend

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

`.tmux.conf:38` and `nvim init.lua:50` both switch clipboard strategy on **SSH-ness**
(`$SSH_CLIENT` / `$SSH_TTY`). [01](01-name-the-split.md) established that SSH-ness is a *proxy* for
the question they actually mean, and a wrong one. **What should they test instead?**

### Why SSH-ness is wrong here

The real question is "is the clipboard tunnel reachable from this session", and that is not the same
as "am I in an SSH session":

- `~/.ssh/config` gives `ubuntu-server` and `vm-app` the **same** `Hostname` (`192.168.122.87`), but
  only `ubuntu-server` carries `RemoteForward 11989 localhost:11989`. Connect as `vm-app` and
  `$SSH_CLIENT` is set while no tunnel exists, so `nvim` will hand paste to
  `vim.fn.systemlist("nc localhost 11989")` against nothing.
- `.tmux.conf:38`'s `if-shell` evaluates once, when the tmux **server** starts. Detach and reconnect
  through a different client, or with a different forwarding setup, and the decision is stale. This
  is the staleness that motivated the Role Marker in the first place, except here a Role Marker does
  not help, because the answer genuinely varies per connection.

### The candidates

- **Probe the port.** Test that something answers on `localhost:11989` and fall back to OSC 52 alone
  otherwise. Correct by construction, but costs a connection attempt, and the frequency matters
  because `nvim` sets `vim.g.clipboard` once at startup while tmux would re-evaluate more often.
- **Declare it per host.** Something set explicitly for the hosts that do forward, rather than
  inferred. Truthful, but adds a second place to keep in sync with `~/.ssh/config`.
- **Make the fallback harmless.** Stop branching at all: always try the tunnel and degrade quietly
  when it is absent, so a wrong guess costs nothing. Changes the question from "which backend" to
  "how does the tunnel path fail".

### What resolution must cover

The signal, where it is read from in each of the two consumers, what happens on `vm-app` specifically,
and whether `.tmux.remote.conf` survives as a separate file at all once the condition changes.

## Answer

### 0. The premise was wrong, and finding out why is most of the answer

This ticket asked which signal should pick the clipboard backend. The honest answer is that **the
backend it was choosing between should not exist**.

The original problem, in the owner's words, was being unable to paste from the host into nvim on a
remote, and the tunnel was built because nested tmux made it look impossible. The actual cause is one
tmux option:

```
$ tmux show -g get-clipboard
get-clipboard buffer
```

`buffer` is the default. It means that when a program asks tmux for the clipboard, **tmux answers
with its own newest paste buffer and never asks the terminal**. Every clipboard read from inside tmux
was being served the wrong thing, on the Desktop as much as on a remote. SSH and nesting were not the
cause; they were where it got noticed. tmux 3.7b (installed) supports `request` and `both`, which
make tmux ask its client and relay the reply.

So the tunnel is a TCP workaround for a one-line option, and the branch this ticket was asked to fix
exists only to decide when to use that workaround.

### 1. The tunnel is deleted

Removed outright: `.config/systemd/user/clipboard-tunnel.service`, the four
`RemoteForward 11989 localhost:11989` lines in `~/.ssh/config`, and the `nc` dependency in nvim.

Replaced by **OSC 52 in both directions**. Every link is already installed:

| Link | Before | After |
| --- | --- | --- |
| foot `[security] osc52` | **already `enabled`**, which includes paste | unchanged |
| tmux `get-clipboard` | `buffer` (never asks the terminal) | `both`, set in `.tmux.conf` unconditionally |
| tmux `set-clipboard` | `on` at `.tmux.conf:7`, so copy already worked | unchanged |
| nvim paste | `vim.fn.systemlist("nc localhost 11989")` | `vim.ui.clipboard.osc52.paste` |
| ghostty `clipboard-read` | `ask`, so it prompts | `allow`, to match foot |

`get-clipboard` goes in `.tmux.conf` **unconditionally, not in a remote-only file**, because every
tmux layer is a relay: the inner tmux asks its client, which is the outer tmux, which asks foot. A
layer left on `buffer` breaks the chain.

**This is more private than the tunnel, not less.** `socat TCP-LISTEN:11989,fork,reuseaddr` serves
the Desktop clipboard to anything on the remote that can reach that port, including other users on a
shared box like uni-cluster. An OSC 52 read is answerable only to programs on the owner's own
terminal. Moving ghostty to `clipboard-read = allow` is a deliberate relaxation, and it lands
strictly tighter than what it replaces.

### 2. The signal: `$WAYLAND_DISPLAY`

`$SSH_CLIENT`/`$SSH_TTY` at `core/init.lua:50` are replaced by `$WAYLAND_DISPLAY`, a **Session
Fact**, the same shape [01](01-name-the-split.md) chose for `QT_QPA_PLATFORM`.

- **Set**: a compositor clipboard is reachable from this session, so use native `wl-copy`/`wl-paste`.
- **Unset**: use OSC 52 for both copy and paste.

It is the question the branch actually means. It is right under **waypipe**, where the display is
forwarded and `wl-copy` genuinely works while SSH-ness would wrongly say remote. It is right when
**SSHing into your own Desktop**, where SSH-ness wrongly selects a remote strategy for a machine with
a live compositor. And it is per-session, so it cannot go stale the way `.tmux.conf:38`'s `if-shell`
does by evaluating once at server start.

The `vm-app` case that motivated this ticket **dissolves**: with no tunnel, `vm-app` and
`ubuntu-server` behave identically despite sharing a `Hostname`, because nothing depends on which
one carries a forward. The whole class of "SSH-ness is set but the tunnel is not there" stops
existing.

Rejected: probing `localhost:11989` (answers a narrower question than the branch asks, and is moot
once the port is gone), and the Role Marker (a deploy-time fact answering a per-session question,
which gets SSH-into-Desktop wrong).

### 3. Dead configuration found

`.tmux.remote.conf`'s `set -g @copy_backend_remote_tunnel_port 11989` is **read by nothing**.
Grepping every installed plugin under `~/.tmux/plugins/` returns no match. tmux-yank supports
`@override_copy_command`, `@yank_selection`, `@yank_action` and `@yank_line`, and has no tunnel
option in its source or README.

Copy on remotes has therefore always been working via `.tmux.conf:7`'s `set -s set-clipboard on`,
tmux's native OSC 52, entirely independent of the branch. **tmux never had a clipboard branch at
all.** Its `if-shell` was cosmetic.

### 4. `.tmux.remote.conf` does not survive, and the remote status bar is Role-keyed instead

The file and the `if-shell` at `.tmux.conf:38` are both deleted.

The remaining wish, a visually distinguishable status bar on remote tmux, is satisfied better without
them. `generate_tmux` reads the **Role Marker** and emits a different accent when the Role is
Headless, from existing palette slots so the palette still does not grow (per
[07](07-theme-switch-app-roster.md)).

Why not keep the file:

- **Hardcoded colors there would be a live bug.** `.tmux.remote.conf` is sourced at `:38`, *after*
  the generated theme fragment at `:26`, so it overrides it and would pin the remote status bar to
  one mode permanently. That is exactly the defect [07](07-theme-switch-app-roster.md) removed from
  waybar and swaync.
- **Role-keyed generation needs no condition at all**, so nothing can go stale on detach and
  reattach through a different client, which was this ticket's second stated complaint.
- It follows dark/light automatically, and [08](08-theme-mode-propagation.md) already makes a
  Headless machine regenerate on every push.

Accepted consequence: SSHing into your own Desktop and running tmux there is **not** recolored, since
that machine's Role is Desktop. SSH-ness would have recolored it. This is the correct trade, because
the same Role logic is what keeps the bar following the theme.

### 5. Knock-on

- [12](12-ssh-config-ownership.md): the four `RemoteForward` lines are gone, so `~/.ssh/config` holds
  less. Its ownership question stands on [08](08-theme-mode-propagation.md)'s `ControlMaster`
  requirement alone.
- The map's fog on nested tmux anticipated that this ticket "may dissolve the file entirely". It did.
  What remains fog there is the F12 key-table toggle and `tmux-sessionizer`'s hardcoded paths.

### Carried forward as implementation checks, not decisions

- **The OSC 52 read chain through two tmux layers is inference.** Each link is documented and
  installed, but nvim → inner tmux → outer tmux → foot → Wayland clipboard has not been executed end
  to end. Confirm before deleting the service, since that is the step that removes the fallback.
- **`osc52.paste` behaviour when no reply arrives.** A blocking read would freeze the editor exactly
  as an unbounded `nc` could. Whatever timeout it has needs checking rather than assuming.
- `clipboard-tunnel.service` hardcodes `Environment=WAYLAND_DISPLAY=wayland-1`, which happens to be
  correct today but assumes sway's start order. Noted only because it explains why the tunnel may
  have seemed flaky; the file is being deleted anyway.
- **Missed on first pass: `.config/sway/config:15` also starts the unit**,
  `exec systemctl --user start clipboard-tunnel.service`. This line is tracked and must go along with
  the service file, or every fresh `sway` start tries to start a unit that no longer exists. The
  operator is handling the live-machine side (disabling/removing the running service) by hand; the
  tracked `sway/config` line still needs deleting whenever this ticket's decision is implemented.
