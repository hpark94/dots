Status: done

# Clipboard rewire: delete the tunnel, OSC 52 both directions

## Problem Statement

Pasting from the Desktop's clipboard into nvim on a remote machine was
unreliable, and the fix built for it, a `socat` TCP tunnel forwarded over SSH,
gated by branching on SSH-ness (`$SSH_CLIENT`/ `$SSH_TTY`) in both `.tmux.conf`
and nvim, was itself broken in a way
[Name the split](../portable-dotfiles/issues/01-name-the-split.md) predicted:
SSH-ness is only a proxy for "is the tunnel actually reachable," and a wrong
one. `~/.ssh/config` gives two hosts (`ubuntu-server` and `vm-app`) the
identical `Hostname`, but only one carries the `RemoteForward` that makes the
tunnel exist, connect as the other and nvim hands paste to a `nc` call against
nothing. `.tmux.conf`'s branch is worse: it evaluates once when the tmux
**server** starts, so detaching and reattaching through a different client
leaves it stale.

The real defect was never SSH or nesting. `tmux show -g get-clipboard` is
`buffer`, the tmux default, which means tmux answers every clipboard read from
its own paste buffer and never asks the terminal at all, on the Desktop as much
as over SSH. The tunnel is a TCP workaround for a one-line tmux option that was
never set.

This spec is the write-up of
[What signal picks the clipboard backend](../portable-dotfiles/issues/09-clipboard-backend-signal.md)
on the [Portable dotfiles map](../portable-dotfiles/map.md).

## Solution

Delete the tunnel entirely: the tracked `clipboard-tunnel.service` unit, the
sway config line that starts it, and the `nc localhost 11989` calls in nvim.
Replace it with OSC 52 in both directions, using links that are already
installed and simply not wired together: foot already has OSC 52 paste enabled,
tmux gets `get-clipboard both` set unconditionally (every tmux layer, inner and
outer, is a relay, so one layer left on `buffer` breaks the chain), nvim's paste
becomes the same built-in OSC 52 module its copy already uses, and ghostty's
clipboard-read prompt becomes an automatic allow to match foot. This lands
**more private** than the tunnel it replaces: a `socat` listener served the
Desktop's clipboard to any process that could reach that port, including another
user on a shared box, where an OSC 52 read answers only the owner's own
terminal.

The branch itself is replaced, not just its consequences:
`$SSH_CLIENT`/`$SSH_TTY` in nvim become `$WAYLAND_DISPLAY`, the Session Fact
this repo already uses for the same "is a compositor clipboard reachable from
this session" question elsewhere. tmux's branch is deleted outright, because
tracing it found tmux never actually had a clipboard branch to begin with, copy
always worked over its own native OSC 52 support, independent of the now-dead
tunnel option it appeared to gate. `.tmux.remote.conf` is deleted along with the
branch that sourced it; the one thing it was keeping alive, a visually
distinguishable remote status bar, is rebuilt as a Role-keyed accent inside
`theme-switch`'s tmux generator instead, so it can never go stale on
detach/reattach the way the deleted `if-shell` could.

## User Stories

1. As the dotfiles owner, I want to copy text on any machine and paste it into
   nvim running over SSH, so that a copy-paste workflow works the same
   everywhere without me thinking about which machine I'm on.
2. As the dotfiles owner, I want pasting to work correctly when I SSH into a
   machine that shares an IP with another host entry that happens to have
   different forwarding configured, so that which `~/.ssh/config` alias I used
   never silently changes whether paste works.
3. As the dotfiles owner, I want clipboard behavior to stay correct across
   detaching and reattaching a tmux session through a different client, so that
   a long-running session never gets stuck on a stale decision made when the
   server first started.
4. As the dotfiles owner, I want nested tmux (tmux inside tmux, e.g. Desktop
   tmux SSH'd into a remote tmux) to relay clipboard reads correctly through
   every layer, so that copy-paste isn't only correct for a single, unnested
   session.
5. As the dotfiles owner, I want the OSC 52 paste path to have no separate
   service to keep running, so that clipboard paste doesn't depend on a
   background unit I have to remember exists.
6. As the dotfiles owner, I want the clipboard mechanism to be at least as
   private as what it replaces, so that removing the tunnel isn't a security
   regression on a shared multi-user machine like `uni-cluster`.
7. As the dotfiles owner, I want ghostty to allow clipboard reads without
   prompting me every time, so that OSC 52 paste doesn't interrupt my workflow
   with a confirmation dialog on every paste.
8. As the dotfiles owner, I want nvim's clipboard strategy to be chosen by
   whether a compositor clipboard is actually reachable from the current
   session, not by whether the session happens to be over SSH, so that waypipe
   and SSHing into my own Desktop both get the right behavior.
9. As the dotfiles owner, I want the case of two `~/.ssh/config` hosts sharing
   an IP with different tunnel configurations to stop being a special case
   entirely, so that there's no longer a class of bug where "SSH-ness says one
   thing but the actual reachable resource says another."
10. As the dotfiles owner, I want the dead `.tmux.remote.conf` file and its
    unused tunnel-port option deleted, so that the repo doesn't carry
    configuration that nothing reads.
11. As the dotfiles owner, I want a way to visually tell at a glance whether a
    tmux status bar belongs to a Headless machine, so that I don't lose the one
    useful thing the deleted remote-config file was trying to provide.
12. As the dotfiles owner, I want that visual distinction to always match the
    machine's actual Role and never go stale, so that detaching and reattaching
    through a different client can't leave a wrong accent on screen the way the
    deleted `if-shell` could.
13. As the dotfiles owner, I want the tracked systemd unit and the sway config
    line that starts it removed from the repo, so that a fresh machine deployed
    after this change never tries to start a tunnel service that no longer has a
    reason to exist.
14. As the dotfiles owner, I want a clear, precise checklist for cleaning up the
    tunnel on my already-running Desktop and in my real `~/.ssh/config`, so that
    I can retire the old mechanism myself without guessing what's safe to
    remove.
15. As a public user of this repo, I want the OSC 52 clipboard setup to work
    without any tunnel, service, or per-host SSH forwarding configuration, so
    that clipboard paste over SSH works for me out of the box after stowing this
    repo.

## Implementation Decisions

### The tunnel is deleted

- `.config/systemd/user/clipboard-tunnel.service` (the tracked unit running
  `socat TCP-LISTEN:11989,fork,reuseaddr EXEC:"wl-paste"`) is deleted from the
  repo.
- The sway config line that starts it
  (`exec systemctl --user start clipboard-tunnel.service`) is deleted.
- nvim's paste functions stop shelling out to `nc localhost 11989` entirely.

### OSC 52 both directions

| Link                      | Before                                      | After                                                                                              |
| ------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| foot `[security]` `osc52` | already `enabled` (includes paste)          | unchanged                                                                                          |
| tmux `get-clipboard`      | `buffer` (default; never asks the terminal) | `both`, set unconditionally in the tracked tmux config                                             |
| tmux `set-clipboard`      | `on`                                        | unchanged                                                                                          |
| nvim paste                | shells out to `nc localhost 11989`          | the same built-in OSC 52 module nvim's copy already uses, called for paste instead of a subprocess |
| ghostty `clipboard-read`  | unset (defaults to prompting)               | `allow`, to match foot's already-enabled behavior                                                  |

`get-clipboard both` goes in the **unconditional** part of the tracked tmux
config, not behind any branch or in a remote-only file, because every tmux layer
in a nested session is a relay: the inner tmux asks its client (the outer tmux),
which asks its client (foot). A single layer left on `buffer` breaks the whole
chain regardless of which layer it is.

**Verify before treating this as done**, per the source ticket's own hedge: the
full read chain (nvim → inner tmux → outer tmux → foot → the Wayland clipboard)
is inferred from each link's documented behavior, not yet executed end to end as
one path. Confirm it works nested, not just in a single tmux layer, before
removing the tunnel is considered complete. Also confirm `osc52.paste`'s
behavior when no reply arrives (e.g. the terminal doesn't support OSC 52)
doesn't block waiting for one, an unbounded wait here would be exactly the
failure mode an unbounded `nc` call already was.

### The branch: `$WAYLAND_DISPLAY`, not SSH-ness

nvim's clipboard strategy selection moves from testing `$SSH_CLIENT`/`$SSH_TTY`
to testing `$WAYLAND_DISPLAY`, the same Session Fact this repo already uses for
the same underlying question elsewhere (a compositor clipboard being reachable
from the current session). Set: use the native Wayland clipboard. Unset: use OSC
52 for both copy and paste. This is correct under waypipe (display forwarded,
SSH-ness would wrongly say "remote") and when SSHing into one's own Desktop (a
live compositor is present, SSH-ness would wrongly say "remote" here too), and
it can't go stale mid-session the way a once-evaluated tmux `if-shell` can,
since it's read fresh.

### tmux never had a clipboard branch to begin with

Tracing `.tmux.remote.conf`'s `@copy_backend_remote_tunnel_port` option found it
read by nothing in any installed plugin. Copy has always worked via the tracked
config's existing `set-clipboard on`, tmux's native OSC 52 support, entirely
independently of the tunnel or the branch that appeared to gate it.
`.tmux.remote.conf` and the `if-shell` that sourced it are deleted outright, not
merged into the unconditional config, since there is nothing left in the file
worth keeping once `get-clipboard both` is unconditional.

### The remote status bar accent becomes Role-keyed, not file-gated

The one real thing `.tmux.remote.conf` provided, a visually distinguishable
remote tmux status bar, is rebuilt inside `theme-switch`'s tmux fragment
generator instead of a separate sourced file. The generator reads the machine's
own Role Marker (via the same canonical reader
[theme-switch expansion](../theme-switch-expansion/spec.md) adds to
`theme-switch`) and swaps the existing accent color role, today hardcoded to one
palette slot across `window-status-style`, `window-status-current-style`,
`display-panes-active-colour`, `status-left`, and `status-right`, to a
different, already-existing palette slot when the Role is Headless, leaving the
Desktop's accent unchanged. **No new palette roles are introduced**, consistent
with the palette staying at its current 20 values.

**The accent read must fall back to the Desktop accent, not hard-error, when the
Marker is missing/unreadable.** `generate_tmux` is a `generate_*` function, and
the [theme-switch expansion spec](../theme-switch-expansion/spec.md) keeps its
render half (all `generate_*`/`apply_*`) usable with no Role Marker present, its
`--render <mode>` entry point is tested against a Marker-less machine, and the
Headless push exists precisely for cold/retrofit machines. So the Role read
added here must treat "Headless" as the only branch that switches the accent,
and treat every other outcome (Desktop, and equally a missing, empty, or
unreadable Marker) as the normal Desktop accent, it must **not** propagate the
canonical `read_role`'s hard "no default Role" failure out of the render
pipeline. This is the one place `generate_tmux` diverges from `read_role`'s
no-fallback contract, and it is deliberate: a Marker-less render still has to
produce a fragment. See the Role-gate reconciliation note in the theme-switch
expansion spec.

This needs no condition that can go stale: it's decided fresh every time the
fragment is generated, including by the Headless push's render-only invocation,
so a detached-and-reattached remote tmux session can never show a wrong accent
the way the deleted `if-shell` (evaluated once, at server start) could. Accepted
consequence: SSHing into one's own Desktop and running tmux there does **not**
get the distinguishing accent, since that machine's Role is Desktop, this is the
correct trade, since Role is also what keeps the bar following Theme Mode
correctly in that same case.

**This decision depended on the Role-reading capability
[theme-switch expansion](../theme-switch-expansion/spec.md) adds to
`theme-switch`** (its Role gate + render-only entry point ticket), which has
since landed. The tmux-accent work is now implemented on `main` (ticket 02):
`generate_tmux` reads the machine's own Role via that canonical `read_role` and
swaps the accent slot from `color4` to `color1` only when the Role is Headless,
falling back to the Desktop accent for every other outcome including a missing
Marker.

### Live cleanup is a manual, documented checklist, not shipped as code

Two pieces of this change live entirely outside the repo and are not touched by
any script:

1. The already-running `clipboard-tunnel.service` on the Desktop needs a
   one-time `systemctl --user disable --now clipboard-tunnel.service` (and its
   unit file removed from `~/.config/systemd/user/` once `stow` no longer
   symlinks it there).
2. The four `RemoteForward 11989 localhost:11989` lines in the real, untracked
   `~/.ssh/config` need deleting by hand.

Neither is scripted or automated by this spec's implementation, matching the
treatment already established for the vault migration and the SSH `Include` line
elsewhere on this map: these are real-machine, real-file changes outside what a
repo checkout can safely reach into.

## Testing Decisions

- The only piece of this spec with real branching logic is the tmux generator's
  new Role-keyed accent. It gets bats coverage extending the existing
  `theme-switch.bats`, using the same sourcing-plus-fake-`$XDG_*`-dirs pattern
  already established there (and the fake-Role-Marker-file pattern the
  theme-switch-expansion spec's Role-gate ticket introduces): assert the accent
  resolves to the normal palette slot when the Role Marker says `desktop`, and
  to the distinct slot when it says `headless`, for both light and dark
  palettes.
- Everything else in this spec is a static config value or a deletion, with no
  branching logic to unit test: the `get-clipboard both` tmux option, ghostty's
  `clipboard-read = allow`, nvim's `$WAYLAND_DISPLAY` check (a single
  conditional with no computation), and the removal of the service file and sway
  exec line. These are verified manually rather than in bats:
  - `tmux show -g get-clipboard` reports `both` after the config is loaded.
  - Copy/paste round-trips correctly in a single tmux layer, and in a nested
    tmux-inside-tmux session (Desktop tmux SSH'd into a remote tmux), per the
    "verify before treating this as done" note above.
  - nvim paste works correctly both with `$WAYLAND_DISPLAY` set (native path)
    and unset (OSC 52 path), exercised over an actual SSH connection to this
    repo's established test target (not the full host list).
  - ghostty no longer prompts on a clipboard read.
- No test framework exists for nvim Lua in this repo; the `$WAYLAND_DISPLAY`
  branch is simple enough that manual verification of both branches is
  sufficient.

## Out of Scope

- **Actually stopping the live `clipboard-tunnel.service` or editing the real
  `~/.ssh/config`.** Both are manual, operator-run steps per Implementation
  Decisions, this spec's implementation only changes tracked repo files.
- **`.envs.sh`'s unrelated `$SSH_CONNECTION`/`$SSH_TTY` branch** (`DOCKER_HOST`,
  `LIBVIRT_DEFAULT_URI`, `OMPI_CXX`, `QT_QPA_PLATFORM`). A different,
  already-decided fix for that branch (turning three of those into Capability
  Probes) belongs to the roles/bootstrap/deployment area, not this spec, and
  this spec does not touch that file.
- **The F12 nested-tmux key-table toggle and `tmux-sessionizer`'s hardcoded
  paths.** Both were confirmed already Role-agnostic and needing no change, on a
  different ticket on the same map; this spec doesn't revisit them.
- **Any change to `~/.ssh/config`'s
  `ControlMaster`/`ControlPersist`/`ControlPath` or the generic tracked SSH
  block.** That's the theme-switch-expansion spec's concern (the Headless Theme
  Mode push); this spec only removes lines from the real file, it doesn't add
  any.
- **Growing the Canonical Palette for the new tmux accent role.** The accent
  swap reuses an existing palette slot; no new role is added.
- **A general nested-tmux or multi-hop-SSH clipboard audit** beyond confirming
  the specific read chain named in Implementation Decisions.

## Further Notes

- Read
  [What signal picks the clipboard backend](../portable-dotfiles/issues/09-clipboard-backend-signal.md)
  in full before implementing, most of its value is in the reasoning for _why_
  the branch was wrong, not just the resulting diff, and it documents the exact
  commands used to discover `get-clipboard buffer` and to confirm
  `@copy_backend_remote_tunnel_port` is read by nothing.
- `docs/adr/0001-theme-switching-per-app-strategy.md` and `CONTEXT.md`'s
  **Session Fact** entry (`$WAYLAND_DISPLAY`, already used for
  `QT_QPA_PLATFORM`) are the precedent the nvim clipboard branch should match
  exactly, not a new pattern.
- This spec's tmux-accent work and the
  [theme-switch expansion](../theme-switch-expansion/spec.md) spec both modify
  `theme-switch`'s tmux generator function. Implement this spec's accent change
  after that spec's Role-gate ticket lands, to avoid two independent additions
  of the same Role-reading code to the same function.
- Per this repo's own testing convention, when a manual verification step needs
  a live SSH target, use this repo's established default (`ubuntu-server`), not
  the full host list.
