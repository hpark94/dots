# 16 Nested tmux and `tmux-sessionizer` under the Roles

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

Two loose ends the map noticed while charting but never sharpened. Both are about whether
`.local/scripts/tmux-sessionizer` and the F12 nested-tmux toggle need any Role-awareness, now that
[Name the split](01-name-the-split.md) has settled Desktop/Headless and the Role Marker.

### 1. The F12 key-table toggle

`.tmux.conf:41-58` flips the outer tmux into a passive state so keystrokes reach an inner tmux server
(e.g. Desktop tmux, SSH into a Headless box, tmux there too):

```
bind -T root F12  set prefix None; set key-table off; set status-style "...bg=#97909D"; ...
bind -T off  F12  set -u prefix; set -u key-table; set -u status-style; ...
```

Does this need Role-awareness at all, or is it inherently about outer-vs-inner tmux server rather
than Desktop-vs-Headless, and therefore already correct as a Role-agnostic keybind? If it stays
Role-agnostic, say so explicitly and close this half without a code change, the way
[13](13-role-marker-reader.md) closed the "is nvim a reader" question by verifying rather than
assuming.

### 2. `tmux-sessionizer`'s hardcoded paths

`.local/scripts/tmux-sessionizer:3-15`:

```bash
fixed_paths=(~/ ~/dots ~/projects ~/bookmarks ~/repos)
search_paths=(~/projects ~/bookmarks ~/repos)
```

These read as Desktop-shaped assumptions. `find "${search_paths[@]}" ... 2>/dev/null` degrades
silently on a missing directory, so the script may already be harmless on a Headless box, just with
`fixed_paths` entries that resolve to nothing interesting beyond `~/` and `~/dots`. Or the operator
may want a different, Role-scoped project list.

**Establish first, don't assume:** which of `~/projects`, `~/bookmarks`, `~/repos` actually exist on
the real Headless hosts. [Theme Mode propagation](08-theme-mode-propagation.md) already has the host
list and the pattern for probing them live rather than guessing:

| Host | OS |
| --- | --- |
| uni-cluster | RHEL 10 |
| work-pvm | Ubuntu 6.8 |
| work-tavm | Ubuntu 6.8 |
| ubuntu-server | Ubuntu 7.0 |
| vm-app | (shares `ubuntu-server`'s `Hostname`) |

If the directories are absent everywhere, the honest answer may be "nothing to do, `find` already
degrades correctly," which is a legitimate resolution and not a cop-out, the same shape
[What signal picks the clipboard backend](09-clipboard-backend-signal.md) reached when it found tmux
"never had a clipboard branch at all."

### What resolution must cover

Whether either half needs a Role branch (via the [13](13-role-marker-reader.md) Role Marker contract,
if so), or whether both are already correct as Role-agnostic code and this ticket closes by saying so
with evidence, not assumption.

### Not this ticket

`.tmux.remote.conf` and the SSH-ness `if-shell` it lived behind are gone;
[09](09-clipboard-backend-signal.md) already deleted both, and the remote status bar accent question
that motivated the file is already resolved there (Role-keyed inside `generate_tmux`).

## Answer

Both halves are **already Role-agnostic**, closed with no code change.

**1. The F12 toggle.** `.tmux.conf:41-58` binds live unconditionally, outside the now-deleted
`.tmux.remote.conf` and its SSH-gated `if-shell`. Nothing in the bind reads `SSH_CLIENT`, the Role
Marker, or any Desktop/Headless state; it only flips prefix/key-table/status-style on whichever tmux
client handles the keypress. That's a statement about outer-vs-inner server nesting, which can occur
in any combination (Desktop→Desktop, Desktop→SSH→Headless, Headless→SSH→Headless), not about which
Role the machine is. Verified by reading, no code change needed.

**2. `tmux-sessionizer`'s hardcoded paths.** Probed live rather than guessing, per the memory default
of testing dots-repo behavior against `ubuntu-server` only: `~/projects` (8 entries), `~/repos` (2
entries) and `~/dots` (23 entries) all exist and are populated; `~/bookmarks` exists but is empty.
This overturns the ticket's speculation that the paths would "resolve to nothing interesting beyond
`~/` and `~/dots`" on a Headless box, at least on this one, they're genuinely useful.

Operator call: no Role branch anyway. `find "${search_paths[@]}" ... 2>/dev/null` already degrades
silently wherever a path is genuinely absent (uni-cluster, or a fresh Headless box before the operator
has created `~/projects`/`~/bookmarks`/`~/repos`), and where present it's correctly useful without any
script change. The operator creates the directories by hand on a Headless host if and when they want
`tmux-sessionizer` to search them there, the same "no code, operator does it" shape
[10](10-vault-flattening-migration.md) used for the vault migration. Not probed further on work-pvm,
work-tavm or uni-cluster: the `find`-degrades-safely argument doesn't depend on the outcome on any
particular host, so more probes wouldn't change the resolution.
