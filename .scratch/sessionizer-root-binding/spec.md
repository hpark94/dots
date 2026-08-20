# Spec: The sessionizer key becomes a Root Binding

Status: ready-for-agent

## Problem Statement

`C-f` opens `tmux-sessionizer`, and it is defined three separate times: as a zsh
line editor widget, as an nvim normal-mode mapping, and as a yazi keymap entry.
Each is written in a different language, each launches the script a different
way, and together they still leave most of the terminal uncovered.

The gaps are the daily cost. In `less`, in `man`, in a Python REPL, in `htop`,
in `git log`, in anything that is not one of those three programs, `C-f` does
nothing. Reaching a different project means first leaving whatever is running,
which is exactly the interruption the sessionizer exists to remove.

The three definitions also drift. The nvim mapping launches the script through a
new tmux window, the yazi entry runs it blocking in place, and the zsh widget
pushes it onto the command line and accepts. The nvim one is already broken
outside tmux, where its `tmux neww` has no server to talk to, and nothing
reports that.

Underneath all three sits the same wrong assumption: that the key belongs to the
application. Every one of these programs runs inside a tmux pane, and tmux sees
every keystroke before they do.

## Solution

Define the key once, at the layer that already sees every keystroke: a Root
Binding in the tmux config, opening `tmux-sessionizer` in a popup over the
current pane.

From then on `C-f` means the same thing in every pane, in every program, whether
you are in nvim, in yazi, in a shell, in `less`, or in a REPL that has never
heard of this repo. The three application mappings are deleted, because a Root
Binding makes them unreachable: tmux takes the key first and the program in the
pane never sees it.

The cost is accepted deliberately. `C-f` stops meaning page-forward in `less`
and `man`, and stops meaning `forward-char` in any shell that is not zsh. Inside
tmux nothing else is lost: the zsh widget was already guarded to do nothing when
the command line was non-empty.

## User Stories

1. As a dotfiles owner, I want one definition of the sessionizer key, so that I
   do not maintain the same intent in three languages.
2. As a dotfiles owner, I want `C-f` to work while `less` is paging a file, so
   that I do not quit the pager to switch projects.
3. As a dotfiles owner, I want `C-f` to work inside a Python REPL, so that a
   program with no keymap of its own does not become a dead zone.
4. As a dotfiles owner, I want `C-f` to work inside `htop`, `man`, and
   `git log`, so that the key is a property of my terminal rather than of
   whichever tool I happened to open.
5. As a dotfiles owner, I want the key to behave identically in nvim and in
   yazi, so that muscle memory does not have to know which program has focus.
6. As a dotfiles owner, I want the picker drawn over the current pane rather
   than in a new window, so that my window list is not renumbered twice on every
   use.
7. As a dotfiles owner, I want the pane I came from to stay visible behind the
   picker, so that I keep the context I am switching away from.
8. As a dotfiles owner, I want the picker to scroll when the candidate list
   outgrows the popup, so that a growing set of projects stays reachable.
9. As a dotfiles owner, I want the picker sized relative to the terminal, so
   that the same config works on a large monitor and in a small SSH window.
10. As a dotfiles owner, I want a failing sessionizer to leave its message on
    screen, so that a missing dependency is visible rather than a popup that
    blinks and vanishes.
11. As a dotfiles owner, I want a normal abort to close the picker without an
    extra keystroke, so that the error-visibility behavior costs nothing on the
    common path.
12. As a dotfiles owner, I want `C-f` inside the picker itself to reach fzf, so
    that the binding does not shadow the picker's own editing keys.
13. As a dotfiles owner working on a Headless machine over SSH, I want F12 to be
    the one rule that hands keys to the inner tmux, so that I learn no second
    mechanism for the sessionizer key.
14. As a dotfiles owner, I want the key absent from the `off` key table, so that
    the F12 toggle keeps working the way it does for the prefix.
15. As a dotfiles owner, I want the deleted application mappings gone rather
    than kept as a fallback, so that no unreachable code stays in the tree.
16. As a dotfiles owner, I want the popup to follow the current Theme Mode, so
    that the picker does not glare in light mode.
17. As a dotfiles owner, I want the binding covered by a test, so that a later
    edit to the tmux config cannot silently remove it.
18. As a dotfiles owner, I want the absence of the key from the `off` table
    asserted, so that a future addition there cannot silently break nested tmux.
19. As a future reader of this repo, I want the vocabulary to name what a Root
    Binding is, so that I understand why an application mapping for this key
    would be pointless.
20. As a future reader of this repo, I want the reasoning recorded as a
    decision, so that the rejected alternatives are not re-proposed.
21. As a dotfiles owner deploying to a Headless machine, I want the same config
    to work there, so that the key means the same thing on every machine this
    repo targets.

## Implementation Decisions

**The key is claimed at the multiplexer, not by the applications.** The tmux
config gains one Root Binding for `C-f`, placed with the other root key table
binding rather than among the prefix bindings. This is the new glossary term:
tmux takes the key before the pane's program sees it, so the program can never
get it back, which is precisely why the application mappings are deleted rather
than left as a fallback.

**The launcher is a popup, not a window and not a detached command.**
`run-shell` was eliminated by measurement, not preference: its command runs with
neither stdin nor stdout on a tty, and fzf dies there with
`inappropriate ioctl for device`. `new-window`, which is how the nvim mapping
works today, was rejected because the repo sets `renumber-windows on`, so a
transient window renumbers the window list on open and again on close.

**The popup closes on success and stays open on failure.** From a prototype, the
decision in the form that prose cannot state as precisely:

```
bind -n C-f display-popup -EE -w 70% -h 70% tmux-sessionizer
```

The doubled `-E` is the load-bearing part. `tmux-sessionizer` has four abort
paths that report on stderr and exit non-zero, as this repo's shell standard
requires; with a single `-E` the popup closes on exit either way and those
messages are never seen. A normal fzf abort exits zero, so the common path still
closes without an extra keystroke. Geometry is a percentage rather than fixed
cells, because the same config is deployed to both Roles and a fixed width can
exceed a small SSH terminal.

**Nested tmux is left to the existing F12 toggle.** On a Desktop machine with an
SSH session into a Headless one, the outer server takes `C-f` and opens the
local picker. F12 already flips the outer server into its passive key table for
exactly this reason, and it covers the sessionizer key with no additional rule.
No branch on SSH-ness or on the Role Marker is added; SSH-ness is explicitly
listed in the glossary as a wrong proxy, and this is not a Role Fact.

**Three application mappings and one shell function are deleted:** the nvim
normal-mode mapping, the yazi keymap entry, and the zsh widget together with the
function it wraps. The consequence is accepted: the shell function `tmux_start`
returns early in the VS Code and JetBrains terminals, so in those two the key
reverts to `forward-char` and the sessionizer is reachable only as a typed
command.

**The theme system is not touched.** `popup-style` and `popup-border-style` are
both at tmux's `default`, which resolves to the terminal's own foreground and
background. Because Theme Mode is already pushed to the terminal, the popup
follows the theme with no new generated fragment.

**`tmux-sessionizer` itself does not change.** Its `switch-client` path was
exercised from inside a popup and worked, including the case where the popup is
switching the client away from the session that opened it.

**Two documents are produced alongside the code**: the glossary gains **Root
Binding**, contrasted with a prefix binding and with the conditional
pass-through that the vim/tmux navigator plugin performs on its own root table
keys; and an ADR records the decision with its rejected alternatives,
`run-shell`, `new-window`, and an SSH-conditional binding.

## Testing Decisions

**A good test here asserts what tmux ended up bound to, not what the config file
says.** Grepping the config text would pass on a line that tmux refused to
parse, so the config is loaded by a real tmux server and the server is asked
what it holds. The prior art is the existing theme-switch suite, which is the
one place in this repo that already tests a config file rather than a script.

**Exactly one new seam**, a new bats file, at the highest point that stays
deterministic: an isolated tmux server on its own socket, given a fake `HOME`
and the repo's real tmux config, then queried with `list-keys`. This was
prototyped and the config loads cleanly in that environment even with the plugin
manager and the theme fragment both absent, so no fixture beyond the temporary
directory is needed.

**Two assertions:**

1. `C-f` is bound in the `root` key table to a popup that runs
   `tmux-sessionizer`.
2. `C-f` is absent from the `off` key table.

The second is the one carrying real weight. It pins the nested-tmux decision:
should someone later add the key to the passive table, SSH into a Headless
machine would silently open the local picker, and nothing else in the repo would
notice.

**The deletions get no test.** Asserting that a line is absent from three
configuration files is brittle, and it is redundant: once tmux holds the key in
its root table, no mapping in a pane's program can fire, which assertion 1
already establishes.

**Full-path key delivery is deliberately not tested.** Driving a real keystroke
through an outer tmux into an inner one was prototyped and does work, but it
needs a second server, timing waits, and screen capture. That cost buys a
property the `list-keys` seam already covers.

Because a test now loads the tmux config, the repo's list of what the bats suite
covers gains a line for it.

## Out of Scope

- Any change to `tmux-sessionizer` itself, including its hardcoded search paths,
  which a previous ticket resolved as correct and Role-agnostic.
- Theming the popup border or background through `theme-switch`.
- A fallback for the VS Code and JetBrains terminals, where the key is knowingly
  given up.
- Any Role branch or SSH-conditional behavior for the binding.
- Rebinding the keys that `C-f` displaces in `less`, `man`, or non-zsh shells.
- Changing the F12 toggle, whose behavior this spec depends on but does not
  modify.

## Further Notes

**One risk is unverified.** `display-popup` requires tmux 3.2 or newer. The
Desktop machine runs 3.7b, measured. The Headless hosts could not be probed:
`ubuntu-server` was unreachable at the time of writing. On a Headless machine
with an older tmux, the binding line would fail when the config is sourced. This
is recorded rather than guarded against, in keeping with the repo's preference
for failing loudly over silent fallbacks, but it should be checked the next time
a Headless host is reachable.

**Measurements that settled the decisions**, all made against isolated tmux
servers on their own sockets, never against the live setup:

- A root table binding fires without the prefix, and the pane's program never
  receives the key: a raw-mode `cat` in the pane recorded only the following
  keystrokes, no `0x06`.
- Inside the popup the root table does not apply, and the popup's own program
  received `0x06`, so fzf keeps `C-f`.
- Under `run-shell` the command has no tty on either stdin or stdout, and fzf
  fails there.
- fzf scrolls inside a small popup: with 50 candidates in 8 visible rows, 30
  cursor moves landed on entry 31 and the viewport followed.
- `-E` closed the popup on a non-zero exit with the error message never
  displayed; `-EE` kept it open with the message visible, and still closed on a
  zero exit.
- A 70% by 70% popup on a 100 by 40 terminal yields 68 by 26 usable cells.
- The repo's real tmux config loads in an isolated server with no plugin manager
  present, and `list-keys` reports the new binding in `root` and nothing in
  `off`.
