# 13 How a script reads the Role Marker

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

Graduated from the map's **Script conventions** fog patch, which named it but
could not yet phrase it sharply. Two halves, one ticket, because the second is
meaningless without the first:

**Where does the read live**, and **what does a reader do when the Marker is
missing or holds a word it does not recognize?**

[01](01-name-the-split.md) made
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role` the sole source of truth for
the Role, deliberately a file rather than an exported variable so that systemd
units, cron and nvim read the same value an interactive shell does. It never
said what reading it looks like, and every ticket since has added a consumer
without answering that.

### The consumers, as they stand today

| Consumer                                                                  | Decided by                              | What it does with the Role                                                                   |
| ------------------------------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------- |
| `note`                                                                    | [01](01-name-the-split.md)              | Desktop-only; refuses on Headless rather than `mkdir`ing a vault that syncs nowhere          |
| `theme-switch`, deciding half (`resolve_mode` `:21`, `write_state` `:43`) | [01](01-name-the-split.md)              | refuses on Headless; the Desktop is sole authority for Theme Mode                            |
| `theme-switch`, `generate_tmux` (`:134`)                                  | [09](09-clipboard-backend-signal.md)    | Role-keyed status bar accent, so remote tmux is visually distinct without a stale `if-shell` |
| install                                                                   | [05](05-choose-deployment-mechanism.md) | **writes** it: `echo headless > ~/.config/dotfiles/role`                                     |

So one script reads it twice, another reads it once, and a fourth thing writes
it. `scratch` was a fifth consumer in [01](01-name-the-split.md) and is gone,
deleted by [04](04-note-restructure-prototype.md).

### Why the missing-Marker case is not hypothetical

[08](08-theme-mode-propagation.md) probed uni-cluster and found `~/dots`
**already deployed and in daily use**, with `~/.tmux.conf` symlinked into it.
The Marker is new, so that machine has the dotfiles and no Marker, and it is the
machine where a wrong answer costs the most: it is a shared multi-user box where
`sudo -n` fails.

The default is not obviously safe in either direction, which is what makes this
a decision rather than an implementation detail:

- Defaulting to **`desktop`** hands a Headless machine authority over Theme
  Mode, which is exactly what [01](01-name-the-split.md) built the Role to
  prevent, and makes `note` create a vault tree on a box that syncs nowhere.
- Defaulting to **`headless`** makes a Desktop that lost or never wrote its
  Marker refuse to switch its own theme, with no obvious symptom pointing at the
  Marker.
- Failing **loudly** is the third option and is not free: it puts a hard
  dependency on install having run, on machines where deployment today is "clone
  and `stow`".

An unrecognized word (a typo, a trailing newline, `Desktop` with a capital) is
the same question wearing different clothes, and is worth settling in the same
breath.

### Where the code could live, and what that costs

There is no shared library today. `.local/scripts/` is 12 flat executables (11
bash, 1 vendored python) plus `tests/`, and the directory is on `PATH` via
`.envs.sh:1`, so anything placed there becomes a command name whether or not it
is meant to be one.

`theme-switch` is the only script with any internal structure worth copying:
`set -euo pipefail`, and small pure functions like `theme_state_dir` (`:4`) and
`theme_state_file` (`:8`) that compute XDG paths instead of hardcoding them. It
is also the only script with tests (`.local/scripts/tests/theme-switch.bats`).

Three shapes are available, and they are not equally cheap:

1. **Hand-rolled per script.** Two consumers today, three reads. Duplication is
   real but small.
2. **A sourced bash library**, which needs a home that is not on `PATH`, and a
   rule for how a script finds it that survives being invoked through a stow
   symlink.
3. **A tiny executable** that prints the Role, callable from bash, from a
   systemd unit, and from Lua alike, at the cost of a subprocess per call. Note
   [06](06-shared-note-config-shape.md) has already ruled against exactly this
   shape once, for the note config, on the grounds that a subprocess to read a
   string constant is the complaint it was opened about.

### The language question hiding underneath

[01](01-name-the-split.md) justified the Marker being a file by naming **nvim**
among the readers. No nvim code reads it today, and after
[06](06-shared-note-config-shape.md) the notetaking module gates itself on the
vault config rather than the Role. If nvim genuinely never needs the Role, a
bash-only answer is sufficient and option 3 loses its main advantage. If it
does, a bash library cannot serve it and the answer has to be a file format
contract rather than shared code.

### What resolution must cover

Where the read lives, what a missing Marker means, what an unrecognized value
means, whether the answer is uniform across consumers or per-consumer, and
whether nvim is a reader at all.

### Not this ticket

The rest of the **Script conventions** fog patch: strict mode, usage and error
handling, and bats coverage across the other scripts. Those wait on
[11](11-bootstrap-sequence.md), which decides what install owns. This ticket
takes only the Marker, because three pieces of already-decided work depend on it
and it can be answered without settling the rest.

## Answer

### 1. There is no default Role: missing and unrecognized are the same hard error

A reader either returns `desktop`/`headless` or fails. Absent file, unreadable
file, empty file, trailing garbage, wrong word, wrong case: all one outcome, an
error naming the file and the fix, and a non-zero exit.

Defaulting to `desktop` was rejected because of how it rots rather than how it
fails: once a missing Marker works, nobody writes the file, and then a Headless
machine that also lacks it quietly claims authority over Theme Mode, which is
the exact thing [01](01-name-the-split.md) built the Role to prevent. Defaulting
to `headless` fails the other way, with a Desktop refusing to switch its own
theme and no symptom pointing at the Marker.

**Probing for a compositor when the Marker is absent was ruled out explicitly**,
despite looking like [01](01-name-the-split.md)'s Capability Probe principle
applied consistently. It fails for the same reason the Marker exists: a cron job
or a detached tmux server on a Desktop has no compositor attached to it and
would probe as Headless. That is the staleness trap in a new costume.

### 2. What made "uniform" survivable: `.envs.sh` comes off the Marker entirely

This is the reframing that did the work in this ticket, and it was surfaced by
one question from the operator: _what happens when I connect to a new SSH
remote?_

Tracing it exposed that the answer chosen in section 1 could not stand as
written. [01](01-name-the-split.md) assigned `.envs.sh:4`'s `DOCKER_HOST`,
`LIBVIRT_DEFAULT_URI` and `OMPI_CXX` to be **Role Facts**, and `.envs.sh` is
sourced unconditionally by `.zshrc:16` and `.bashrc:21`. That puts the Marker on
the **login path**. Under a literal uniform refusal, a machine with the dotfiles
and no Marker prints an error on every shell, every tmux pane and every
`ssh host cmd`. uni-cluster is exactly that machine today, and it is a shared
multi-user box, so the error would arrive on every login and train the operator
to ignore it.

Two ways out were weighed. Qualifying the refusal by who asked (refuse for
invoked commands, withhold silently for ambient code) works, but it is a
composition rule that every future consumer must be sorted into, which is the
cost [01](01-name-the-split.md) refused when it killed the layered Role model.

**Chosen instead: the three variables become Capability Probes, and the Marker
leaves the login path.** `DOCKER_HOST` gates on the rootless socket existing
(`[ -S "$XDG_RUNTIME_DIR/docker.sock" ]`), `LIBVIRT_DEFAULT_URI` on the libvirt
socket, and `OMPI_CXX=g++` is harmless anywhere and needs no gate at all.

This is **strictly more correct than the Role** for the case
[01](01-name-the-split.md) cared about. ssh into your own Desktop and the socket
is present, so the probe exports the variable, and it stays right even when the
Marker is wrong, missing, or written on the wrong machine. It also shrinks the
Marker's blast radius to the point where the absolute refusal in section 1 has
no exceptions to remember.

**The answer to the original question, now that this holds:** connecting to an
SSH remote never produces a Marker error. Not on a bare remote, where nothing
reads it because the scripts are not there; and not on a remote carrying the
dotfiles, because nothing on the login path reads it any more. The error
surfaces only when a human runs `note` or `theme-switch` on a machine that was
never given a Role.

### 3. The read is hand-rolled in each consumer, and there are only two

After section 2 the complete consumer list is `note` and `theme-switch`.
`theme-switch` reads it in two places (the deciding half, and `generate_tmux`
per [09](09-clipboard-backend-signal.md)), but that is one function serving
both. Nothing ambient, nothing in Lua, nothing on the login path.

No shared library. Two implementations do not pay for one, and **"whether there
is a shared library" is still fog** in the map's Script conventions patch,
waiting on [11](11-bootstrap-sequence.md) to say what install owns. Deciding it
here would answer a foggy question from inside a ticket that scoped it out. The
accepted cost is that if [11](11-bootstrap-sequence.md) does produce a library,
the function is written twice and then moved once.

What keeps two copies from drifting is that the contract is pinned here, not
left to each site:

- **Path**: `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role`.
- **Content**: exactly one word, `desktop` or `headless`, matched
  case-sensitively against that whitelist.
- **Whitespace is stripped before matching.** Not cosmetic:
  [05](05-choose-deployment-mechanism.md)'s documented install writes the Marker
  with `echo headless >`, which leaves a trailing newline, while `theme-switch`
  writes its own state file with `printf '%s'`, which does not. Both conventions
  exist in this repo already, so the reader tolerates both rather than betting
  on one.
- **Anything else**: error to stderr naming the file and the one-line fix,
  non-zero exit, no fallback.

### 4. nvim is not a reader, and does not become one

Verified rather than assumed. `colorscheme.lua:1-13` reads
`$XDG_STATE_HOME/theme/mode`, which is **Theme Mode, not the Role**,
whitelisting the value against `dark`/`light` and falling back. It is the only
one-word-file reader in the nvim config. After
[06](06-shared-note-config-shape.md) the notetaking module gates on the vault
config rather than the Role, so the Lua side has no Role consumer and none
pending.

[01](01-name-the-split.md) named nvim among the readers when justifying a file
over an exported variable. That justification survives without nvim: systemd
user units and cron are enough on their own, and both are real.

If Lua ever does need the Role, the contract in section 3 is the whole
interface, and `colorscheme.lua`'s existing reader is the shape to copy: four
lines, no shared code, no subprocess. That is also why a `dotfiles-role`
executable was rejected. Its one real advantage is serving Lua, which is not a
consumer, and [06](06-shared-note-config-shape.md) already ruled once against
spawning a subprocess to read a string constant.

### 5. What this amends

- **[01](01-name-the-split.md)**: `DOCKER_HOST`, `LIBVIRT_DEFAULT_URI` and
  `OMPI_CXX` move from Role Fact to Capability Probe. 01's diagnosis stands
  untouched (the single `-z $SSH_CONNECTION` gate is wrong in both directions);
  it reached for the Role one step too early on the remedy.
- **`CONTEXT.md`**: the **Role Fact** entry uses the docker socket and libvirt
  daemon as its worked example, and must not, since they are now probes. The
  **Capability Probe** entry gains them. (Corrected on review: this line
  originally said "Session Fact entry," contradicting the sentence above it and
  the actual `CONTEXT.md` edit, which put them under Capability Probe.)

### 6. Knock-on

- **[12](12-ssh-config-ownership.md)**: tracing the "new SSH remote" case
  exposed that [08](08-theme-mode-propagation.md) never said what the
  connect-time push does when the target has no dotfiles and therefore no
  `theme-switch` to run. Whether the push hook is a `Host *` default or per-host
  opt-in is precisely 12's shared-defaults-versus-host-entries question, so it
  is recorded there rather than as a new ticket.
- **[11](11-bootstrap-sequence.md)**: section 1 makes writing the Marker a hard
  prerequisite on machines deployed before install existed. 11 already carries
  that question.
