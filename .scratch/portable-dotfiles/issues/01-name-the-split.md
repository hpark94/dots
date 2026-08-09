# 01 Name the split: roles and where divergence is expressed

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

What are the roles this repo deploys into, and where is divergence between them
expressed?

Two questions, one ticket, because in practice they are the same question and
neither can be answered without the other.

**Roles.** Is it a binary host/remote, or layers (something like base / dev /
desktop)? A layered model lets a headless box take base + dev while the laptop
takes all three, but it costs a vocabulary and a composition rule. A binary
split is cheaper and may be enough for exactly two target kinds.

**Where divergence lives.** Two candidate seams:

- **Deploy time.** Different files land on different machines. The role is
  chosen once, at install.
- **Runtime.** The same files land everywhere and branch when they run. This is
  what the repo already does: `.tmux.conf` has
  `if-shell 'test -n "$SSH_CLIENT"' 'source-file ~/.tmux.remote.conf'` and
  `.envs.sh` wraps its Wayland/docker/libvirt exports in
  `if [[ -z "$SSH_CONNECTION" && -z "$SSH_TTY" ]]`.

**A hard constraint, established by
[the deployment mechanism survey](02-deployment-mechanism-survey.md) after this
ticket was written: no mechanism can resolve SSH-ness at deploy time.** chezmoi
and yadm evaluate their conditions when `apply`/`alt` runs, which describes the
session doing the deploying, not future sessions. So the two existing runtime
branches are answering a question only runtime can answer. They are not portable
to any deploy-time conditional mechanism, whichever one is eventually chosen.

That forces the shape of this ticket's answer. The choice is not "deploy time or
runtime" across the board; it is **which questions belong to each seam**. A
useful reframing to grill on: deploy time can answer "what kind of machine is
this?" (a role, fixed at install), while only runtime can answer "how is this
session being used right now?" (SSH-ness, whether Wayland is up). If the roles
are named well, some of what is currently an `$SSH_CONNECTION` branch may be a
role question in disguise, and some genuinely is not.

Worth grilling on: the existing runtime pattern already works, so the burden is
on deploy time to justify itself. Where it plausibly does: `sway`, `waybar`,
`fuzzel`, `swaync`, `zathura`, `imv`, `mpv`, `satty` are pure dead weight on a
headless remote, and no runtime branch makes an unused config file cheaper to
sync. Where runtime plausibly wins: anything a single machine needs to behave
differently about depending on how it is being used right now, rather than what
it is.

Also in scope for this ticket, because they are the same decision applied to
specific files:

- Does the vault-based notetaking (`note`, `scratch`, `.config/notes/`, the nvim
  notetaking module) exist on remotes at all? `SYNC_FOLDER_PATH="${HOME}/Sync"`
  presumes a synced folder that a server probably does not have.
- Which side does `theme-switch` sit on, given it already generates shared
  fragments (tmux, shell-env, bat) and host-only ones (foot, sway, ghostty, GTK)
  from one script.

## Resolution should produce

Vocabulary in `CONTEXT.md` for the roles and the seam, since every later ticket
needs these names. Use `/domain-modeling` for that half.

## Answer

### Roles

Two, binary, no layers: **Desktop** and **Headless**, defined in `CONTEXT.md`. A
layered `base`/`dev`/`desktop` model was considered and rejected: it permitted
only two combinations (`base+dev` and `base+dev+desktop`), which is a total
order rather than a lattice, so the third name bought nothing but a composition
rule for every later ticket to maintain. Every machine in scope is one you write
code on, so `dev` is constant and the only live question is whether the machine
runs a compositor.

`Desktop`/`Headless` was chosen over `host`/`remote` because `host` already
means three other things here (`DOCKER_HOST`, ssh `HostName`, libvirt
host/guest) and `remote` names a machine by the reader's vantage point rather
than by any property of the machine. `remote` remains fine as informal prose.

**`Headless` is a claim about the machine, not about whether GUI appears.**
Under waypipe or `ssh -X` a Headless machine displays GUI apps on the Desktop's
screen. That is a Session Fact.

### Where divergence is expressed

**One flat repo. Everything ships to both Roles. Nothing is gated by which files
land.** Divergence is expressed entirely as branches inside shared files, keyed
off the **Role Marker** (`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role`, one
word, written once at install, sole source of truth). A file rather than an env
var, so systemd units, cron and nvim read the same value an interactive shell
does.

Broad role-scoped directory trees were picked early in the session and then
walked back as the concrete cases were worked through. What killed them:

- **Size is not a reason.** The entire desktop surface (`foot`, `fuzzel`,
  `ghostty`, `imv`, `mpv`, `satty`, `sway`, `swaync`, `waybar`, `zathura`,
  `fontconfig`) is ~88K across 19 files. The `nvim` config alone is 204K across
  42 files and ships everywhere regardless.
- **Most of it is not even inert on a Headless box.** Under waypipe, `foot`,
  `imv`, `mpv`, `zathura` and `satty` genuinely run there. Only the
  compositor-and-shell set (`sway`, `waybar`, `swaync`, `fuzzel`) cannot.
- **The last file-selection case was withdrawn.** `.config/mise/config.toml` was
  the flagship argument for role-gating by deployment, since `mise install` on a
  Headless box really does build `cmake`, `ninja`, `resvg`, `java` and `maven`.
  It ships unchanged to both Roles anyway: the file churns constantly under hand
  editing, and keeping two of it in sync costs more than the installs.

### The seam rule

**Deploy time answers what the machine _is_. Runtime answers where this session
_came from_ and what is attached to it _now_.**

The strongest argument for the Role Marker is that runtime SSH-ness is not
stable. `.tmux.conf:38`'s `if-shell 'test -n "$SSH_CLIENT"'` evaluates once,
when the tmux **server** starts; detach and reconnect from a different client
and it is stale. The same goes for `sudo -i`, cron, and systemd user units. A
Role cannot go stale.

Where a shared executable can answer a machine question itself, a **Capability
Probe** is preferred over a Role branch. `theme-switch` is the model: every
`apply_*` guards on `command -v` / `$SWAYSOCK` / `tmux list-sessions`, so the
script already runs correctly on both Roles unmodified.

### What this assigns to specific files

**`.envs.sh:4` splits three ways, and its single `-z $SSH_CONNECTION` gate is
wrong in both directions.**

- `DOCKER_HOST`, `LIBVIRT_DEFAULT_URI`, `OMPI_CXX` are **Role Facts**. The
  daemons live on the Desktop, so ssh'ing into your own Desktop should not strip
  them. Today it does. **Amended by [13](13-role-marker-reader.md): these three
  become Capability Probes, not Role branches.** The diagnosis here stands, the
  remedy reached for the Role one step too early. A socket probe answers the
  same question and is strictly more correct (it stays right when the Marker is
  missing or wrong), and it keeps the Marker off the login path, which
  `.envs.sh` is.
- `QT_QPA_PLATFORM=wayland` is a **Session Fact**, probed on `$WAYLAND_DISPLAY`.
  Today it is skipped whenever `$SSH_CONNECTION` is set, which is exactly the
  waypipe case that needs it.

**`theme-switch` ships whole to both Roles, with role-gated authority.** There
is one Theme Mode and the Desktop owns it; a Headless machine follows one-way
and cannot change it. The script already has the seam: `resolve_mode` (`:21`)
and `write_state` (`:43`) **decide**, `generate_*` and `apply_*` (`:51-201`)
**render**. On Headless the deciding half refuses and only the rendering half
runs. One script rather than two, so palette sourcing and state-path logic are
not duplicated. This is the one place a Role check lives inside a script, and it
is what forces the Role to be readable at runtime.

**Notetaking is Desktop-only, but its config ships everywhere.**

- `note` and `scratch` are Desktop-only via a Role check. They are not inert
  elsewhere: both call `check_dirs` on every invocation, which `mkdir -p`s a
  `~/Sync/vault/{assets,daily,scratch,templates,zettelkasten}` tree on any
  machine that runs them, and on a Headless box that vault syncs nowhere.
- `.config/notes/` and the nvim `custom/notetaking/` module ship to both Roles.
  Carving 3 files out of a 42-file nvim tree is disproportionate, and the module
  self-disables via `is_note()`.
- **Constraint handed to [06](06-shared-note-config-shape.md): an absent config
  must fail _closed_.** Today it fails open. `util.lua:49` reads config via
  `bash -c "source <path> && echo $VAR"`; if the file is missing, `source`
  fails, `&&` short-circuits, and `get_base_path()` returns `""`. Then
  `is_in_vault()` does `vim.startswith(currentpath, "")`, which is **true for
  every path**, so every markdown buffer is treated as a note. This is why the
  config ships even where the scripts do not.

**The clipboard tunnel is a Session Fact, and SSH-ness is a wrong proxy for
it.** The pair is `clipboard-tunnel.service` running
`socat TCP-LISTEN:11989 EXEC:wl-paste` on the Desktop, four
`RemoteForward 11989 localhost:11989` entries in `~/.ssh/config`, and the
consumers at `.tmux.remote.conf:2` and `nvim init.lua:59`. But `ubuntu-server`
and `vm-app` are the same machine (`192.168.122.87`) and only one has a
`RemoteForward`, so "am I in SSH" and "is a tunnel reachable" are different
questions. Split out as [09](09-clipboard-backend-signal.md).

### Follow-on

- [08](08-theme-mode-propagation.md): how Theme Mode reaches a Headless machine.
  Graduated from fog; the _whether_ is decided here, the _how_ is open.
- [09](09-clipboard-backend-signal.md): what signal a session uses to choose its
  clipboard backend.
