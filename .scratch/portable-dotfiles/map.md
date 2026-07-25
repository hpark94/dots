# Map: Portable dotfiles

**Label:** `wayfinder:map`

## Destination

A decided route for a dotfiles repo that bootstraps a full dev environment on both the Fedora/sway
host and headless Linux SSH remotes from one clone. Reached when the split, the deploy mechanism,
the script conventions, the shared note config, and `theme-switch`'s remaining app roster are all
settled and written up as implementable specs.

## Notes

- **Domain:** personal dotfiles, single context. Read `CONTEXT.md` and
  `docs/adr/0001-theme-switching-per-app-strategy.md` before any ticket touching theming.
- **Planning only.** No execution is carried into this map. Tickets resolve decisions; implementation
  goes through the normal `.scratch/<feature>/spec.md` + `issues/` flow already used for
  `theme-switch`.
- **Nothing in this effort touches `~/Sync/vault`.** The vault is live data in a Syncthing folder;
  [10](issues/10-vault-flattening-migration.md) decided the operator migrates it by hand. When the
  notetaking work is eventually built, it is exercised against a throwaway vault, never that one.
- **Skills:** `/grilling` and `/domain-modeling` by default. `/prototype` for the `note` restructure.
  `/research` for the two survey tickets.
- **Targets:** Fedora/sway host and headless Linux SSH remotes. Nothing else (see Out of scope).
- **Style:** no em dashes, per `CLAUDE.md`.

### Why this is one map and not four

The four threads are not independent. The split cuts through each of the others:

- `note`'s `SYNC_FOLDER_PATH="${HOME}/Sync"` is host specific, so whether `note` ships to remotes at
  all is a split decision, not a script decision.
- `theme-switch` already straddles the line: its tmux, shell-env and bat fragments are shared, while
  its foot, sway, ghostty and GTK paths are host only.
- `.config/mise/config.toml` is one flat list mixing shared dev tooling with host-weight entries
  (`cmake`, `ninja`, `resvg`, `java`, `maven`).
- Divergence today is handled at **runtime**, not deploy time: `.tmux.conf` branches on
  `if-shell 'test -n "$SSH_CLIENT"'` and `.envs.sh` on `$SSH_CONNECTION`.

## Decisions so far

<!-- one line per closed ticket: gist plus link. Zoom the link for detail. -->

- [Deployment mechanism survey](issues/02-deployment-mechanism-survey.md): no candidate is
  disqualified, so the choice is real. Stow provably cannot template or conditionalize (a symlink has
  no content), and symlink deployment versus per-machine content is a direct structural trade-off:
  symlinks make drift impossible, copies make templating possible. Sharpest practical obstacle found
  is Stow aborting entirely against a fresh Fedora `$HOME`'s `/etc/skel` files.
- [Theme reload and include capability survey](issues/03-theme-capability-survey.md): waybar is
  **already** Live-switchable and already reacting to `apply_gtk` on every toggle; it wants
  `style-dark.css`/`style-light.css`, which do not exist, and that is the entire integration. Four of
  six apps need no new palette roles. All pressure is waybar and swaync, and it is surfaces and
  borders, not severity colors. Also corrected a wrong premise: `SIGUSR1` toggles waybar's
  visibility, it does not reload it.
- [Name the split](issues/01-name-the-split.md): two Roles, **Desktop** and **Headless**, binary with
  no layers, named and defined in `CONTEXT.md` along with Role Marker, Role Fact, Session Fact and
  Capability Probe. **The repo stays flat and everything ships to both Roles**; nothing is gated by
  which files land. Divergence is a branch inside a shared file, keyed off a Role Marker file at
  `~/.config/dotfiles/role`. Seam rule: deploy time answers what the machine *is*, runtime answers
  where the session *came from*. Assigns `.envs.sh:4` (wrong in both directions today), makes the
  Desktop sole authority for Theme Mode with `theme-switch` role-gated internally, and makes
  `note`/`scratch` Desktop-only while their config still ships everywhere.
- [Restructure `note`](issues/04-note-restructure-prototype.md): **stays bash, python is deleted**.
  The whole reason for python was Korean filename sanitizing, and locale-aware `[[:alnum:]]` does it
  without the hardcoded codepoint ranges, keeping Japanese and Cyrillic that the python silently
  dropped. Roster cut from 14 flags to 7 (`-z`, `-d [N]`, `-sn`, `-sl`, `-x`, `-f`, `-u`); `scratch`
  the script is deleted and folded in; `yesterday`/`tomorrow` become the `-d` argument. **Vault goes
  flat**, only `assets/` and `templates/` keep directories, which forces `-u` to exclude dailies by
  filename pattern rather than by path. **`--nvim-mode` is deleted**: stdout is always the path and
  nothing else, every message goes to stderr. Type table must be parallel arrays, not delimited
  records, because bash silently pads a short record and hides malformed rows. Carries one verified
  hard requirement: the script must `export LC_ALL=C.UTF-8` itself, because under an inherited
  `LC_ALL=C` a Korean title slugs to the **empty string** and every such note collapses into a single
  hidden `.md` file.
- [Choose the deployment mechanism](issues/05-choose-deployment-mechanism.md): **stow stays**, single
  package, `cd ~/dots && stow .`. [01](issues/01-name-the-split.md) killed the case for switching by
  removing any need for templating or conditionals, and stow's symlink write-through is actively
  wanted for hand-edited files like the mise config. The operator's existing workflow is now the
  documented procedure: the first `stow` **always** aborts against a fresh Fedora `$HOME`'s
  `/etc/skel` files, you `.bak` them and re-run. Install also writes the Role Marker and a
  `~/.gitconfig`. Four unusable symlinks on a Headless box are accepted rather than subtracted,
  keeping deployment byte-identical everywhere. Establishes a principle: **a config its own tooling
  rewrites must not be a symlink into the repo** (`gh auth` dirties `~/.gitconfig`), so
  `.gitconfig.shared` is tracked and `~/.gitconfig` is an untracked stub that `[include]`s it.

- [Shape of the shared note config](issues/06-shared-note-config-shape.md): **JSON**, one key
  (`vault`), tracked and stowed at `.config/notes/config.json`. Decided on verified dependency facts:
  nvim decodes JSON natively and `jq` is already pinned, while nothing on this machine can read TOML
  at all (no `yq`/`taplo`/`dasel`, no Lua module, and treesitter installs `json` but not `toml`), so
  TOML would cost a new CLI plus a new nvim plugin to read one path. Everything else in `config.sh`
  turns out to be derived, dead with the flat vault, or an internal intermediate, so
  **`.config/notes/config.sh` is deleted outright** and the "where do the functions move" question
  resolves to nowhere. nvim reads it **once at setup**, killing the per-lookup bash subprocess.
  Fail-closed verified in this repo's actual nvim: missing, malformed and empty configs all yield
  `nil`, where today a failed read yields `""` and `vim.startswith(path, "")` is **true for every
  path**.

- [theme-switch app roster and palette roles](issues/07-theme-switch-app-roster.md): roster is
  **waybar, swaync, fuzzel, zathura**; swaylock (sets zero colors today, so nothing to repair) and
  swaybg (a photograph, not a palette) are out. **The Canonical Palette does not grow**, upholding
  rather than overturning the spec's "no new palette roles" line, which is the opposite of what the
  ticket expected: tracing every off-palette value to its rule dissolves all four supposedly-missing
  roles, once `alpha()` is verified to parse across the `@import` boundary in both GTK 3 and GTK 4.
  waybar is a **pull** app, the first of its kind here: it subscribes to the portal that `apply_gtk`
  already writes, so `theme-switch` contributes no code at all, and the only structural cost is that
  the generator must emit **both** modes because waybar rather than the script picks. swaync and
  zathura are push (`swaync-client -rs`, D-Bus `SourceConfig`), fuzzel needs no reload. zathura's
  `recolor` becomes mode-driven, on in dark and off in light, with `i` overriding until the next
  switch re-asserts it. Verified that relative includes resolve through stow's symlinks rather than
  the canonicalized repo path, which the whole waybar and zathura wiring depends on. Found in
  passing: zathura is hardcoded **dark** while waybar and swaync are hardcoded light, so three of the
  four have been stuck at one end of the toggle all along. `CONTEXT.md` and ADR-0001 amended.

- [How Theme Mode reaches a Headless machine](issues/08-theme-mode-propagation.md): **the Desktop
  pushes the state file over SSH**, no environment variable anywhere. Decided on a probe rather than
  an assumption: `LC_*` forwarding works on the three Ubuntu hosts and is **dropped by uni-cluster**
  (RHEL 10), where `sudo -n` fails so `sshd_config` can never be fixed, and where the dotfiles turn
  out to be deployed and in daily use already. A push needs only a login, so it covers every host
  with zero remote configuration. Two reframings did most of the work: the channel carries **one
  word**, since a Headless machine already holds the repo and can generate everything locally, and
  the remote surface is only tmux, shell-env and nvim, of which **only tmux** would have behaved
  differently by Role. The push writes the state file then runs the rendering half, so `apply_tmux`
  hits the remote server and that asymmetry closes: tmux stays Live-switchable everywhere. Mode is a
  **machine fact**, not a Session Fact, so detached tmux and cron see it. Toggle pushes only to hosts
  with a live `ControlMaster` socket; a connect-time push catches hosts that were offline. Cold case
  renders **light** silently, matching what nvim already does. Found in passing: `.tmux.conf:26`
  lacks `-q`, so uni-cluster emits a missing-file error on every tmux start **today**.

- [What signal picks the clipboard backend](issues/09-clipboard-backend-signal.md): the premise was
  wrong, and **the tunnel is deleted**. `tmux show -g get-clipboard` is `buffer`, the default, which
  means tmux answers clipboard reads from its own paste buffer and **never asks the terminal**, on
  the Desktop as much as on a remote. That, not SSH or nesting, is why host-to-remote paste never
  worked, and the whole `socat`/`RemoteForward`/`nc` apparatus is a TCP workaround for a one-line
  option. Replaced by **OSC 52 both directions**, every link already installed: foot is already
  `osc52=enabled`, tmux gets `get-clipboard both` **unconditionally** since every layer is a relay,
  nvim's paste becomes `osc52.paste`, ghostty moves to `clipboard-read = allow`. This lands stricter
  than the tunnel, which served the clipboard over a TCP port to any user on the remote. The signal
  question itself resolves to **`$WAYLAND_DISPLAY`**, a Session Fact, right under waypipe and right
  when SSHing into your own Desktop, where SSH-ness is wrong in both directions; the `vm-app` case
  that motivated the ticket dissolves once no tunnel can be missing. Found dead: tmux never had a
  clipboard branch at all, `@copy_backend_remote_tunnel_port` is read by **nothing** in any installed
  plugin, and copy always worked via `set -s set-clipboard on`. `.tmux.remote.conf` and its `if-shell`
  are deleted; a distinguishable remote status bar becomes **Role-keyed** inside `generate_tmux`, so
  it follows dark/light instead of overriding it and needs no condition that can go stale.

- [Migrating the existing vault to the flat layout](issues/10-vault-flattening-migration.md): the
  survey inverted the ticket. **Zero basename collisions** across the 658 notes, and no zettel matches
  the daily or scratch exclusion patterns, so the risk it was written around is empty; the item it
  listed as needing a survey is the entire job, **436 `../assets/` references in 205 files** that
  resolve outside the vault once notes sit in the root. Collision policy is **verify and refuse**, no
  discriminator added to the naming scheme. Asset links become **`![[assets/…]]`**, wikilink style,
  because Obsidian cannot resolve an absolute path; the `../` prefix turns out to be written in one
  place (`util.lua:86`) and read in one place (`core.lua:133`), and the reader becomes tolerant of
  both forms because Syncthing can deliver an old-form note after the migration. **Nothing maintains
  a `templates/` inside the vault**, which also kills `check_dirs`. **The migration ships as no code:
  the operator does it by hand**, because the vault is a live Syncthing folder shared with another
  device and a 658-file rename is a sync event that only they can sequence. `.obsidian/` needs
  nothing: its `daily-notes` and `templates` plugins have no folder configured, so both already
  default to the vault root. With this closed, the notetaking rewrite is fully specified across
  [04](issues/04-note-restructure-prototype.md), [06](issues/06-shared-note-config-shape.md) and this
  ticket, and is ready to hand off.

- [How a script reads the Role Marker](issues/13-role-marker-reader.md): **there is no default
  Role.** Missing, empty, unreadable and unrecognized are one hard error naming the file and the fix;
  whitespace is stripped first, because [05](issues/05-choose-deployment-mechanism.md)'s install
  writes the Marker with `echo` while `theme-switch` writes its own state with `printf '%s'`. What
  made an absolute refusal survivable was **amending [01](issues/01-name-the-split.md)**: `.envs.sh`
  is sourced on every shell, so its three Role Facts would have put the Marker on the login path and
  errored on every login on a Marker-less machine (uni-cluster today, a shared box). `DOCKER_HOST`
  and `LIBVIRT_DEFAULT_URI` become **Capability Probes** on their sockets and `OMPI_CXX` needs no
  gate, which is strictly more correct than the Role for the ssh-into-your-own-Desktop case 01 cared
  about. The Marker is therefore read **only by code a human explicitly invokes**, which is two
  scripts, `note` and `theme-switch`, each hand-rolling the read against a contract pinned in the
  ticket. No shared library: that question is fog waiting on
  [11](issues/11-bootstrap-sequence.md). nvim is **not** a reader and does not become one, verified
  against `colorscheme.lua:1-13`, which reads Theme Mode rather than the Role. Also ruled out:
  probing for a compositor as a fallback, which is the same staleness trap the Marker exists to
  avoid. `CONTEXT.md` amended.

- [The bootstrap sequence after the dotfiles land](issues/11-bootstrap-sequence.md): **a tracked,
  idempotent `bootstrap.sh <desktop|headless>`** owns everything from just after `git clone` to a
  fully built machine, with **no behavioral Role branch** (Role is an input it records). The ordered
  sequence: pre-create real `~/.config` and `~/.local` (load-bearing, or stow **folds** the namespace
  into a symlink and mise/zinit/nvim-plugins/Marker all drift into the repo working tree), `.bak` the
  skel conflicts, `stow .`, write Marker (kept if present, else from the required arg, hard-error if
  neither) and `.gitconfig` stub, `curl https://mise.run | sh` then activate in-process, `mise
  install`, clone tpm + `install_plugins`, force `nvim --headless '+Lazy! sync' +qa` and zinit, write
  default theme state **only if absent**. mise is the bootstrapper of the toolchain so it is
  deliberately unpinned; plugin installs are forced eagerly so the machine is done on exit and each
  step is verifiable. **Idempotent = retrofit-safe**: the same script brought up uni-cluster (deployed
  with no Marker/state per [08](issues/08-theme-mode-propagation.md)) without touching live state.
  **No shared library is placed by install**, closing the question [13](issues/13-role-marker-reader.md)
  parked and graduating the script-conventions fog to [14](issues/14-script-conventions.md). README
  shrinks to three lines. tpm was the one outright gap (nothing cloned it, so `.tmux.conf:58` was
  inert on every fresh box).

- [Who owns `~/.ssh/config`](issues/12-ssh-config-ownership.md): the five `Host` entries never get
  tracked, forever, full stop, a straight public-repo call, even genericized. Only a fully generic
  `Host *` block (`ControlMaster`/`ControlPersist`/`ControlPath`, no concrete host/IP/user) gets
  tracked, at `.config/ssh/config.shared`, stowed normally like anything else. Wired in via one
  manually-added `Include ~/.config/ssh/config.shared` line at the **bottom** of the real
  `~/.ssh/config`: `man ssh_config` confirms first-obtained-value-wins, the opposite of
  `.gitconfig`'s include behavior, so general defaults must sit after host-specific declarations,
  not before. The `Include` line is **Desktop-only and always manual**, never scripted: the
  `ControlMaster` requirement [08](issues/08-theme-mode-propagation.md) needs lives entirely on the
  Desktop side of the push, and machines like `uni-cluster` already carry institution-managed SSH
  config nothing here should risk touching.

- [What `.env` holds, and whether `.envs.sh` needs the Role Marker](issues/15-env-secrets-scope.md):
  **`.env` is machine-local secrets** (credentials, tokens), untracked, sourced conditionally by
  `.envs.sh:11-13`. **`.envs.sh` needs no Role Marker**, confirming rather than changing
  [13](issues/13-role-marker-reader.md)'s Capability Probe design. Closes the map's last fog patch on
  machine-local overrides and secrets.

- [Conventions for the `.local/scripts/` set](issues/14-script-conventions.md): **strict mode is
  universal**, no script opts out, best-effort calls use `|| true` per call rather than dropping
  `set -euo pipefail` for a whole script. Usage and errors follow one shared idiom (a `usage()`
  function, `Error:`-prefixed stderr, no silent fallback) as a convention, not shared code. The bats
  bar is per-function, not per-script: pure and branching logic (argument parsing, path resolution,
  idempotency guards) gets tests via the sourcing-plus-fake-`$XDG_*`-dirs pattern `theme-switch.bats`
  already uses; bare external-command calls do not. `bootstrap.sh` gets a `.bats` file under that rule,
  covering its sequencing and guards, not its `mise install`/`curl | sh`/`nvim --headless` steps. The
  Role Marker read (contract pinned by
  [13](issues/13-role-marker-reader.md)) is **one canonical function copy-pasted verbatim** into `note`
  and `theme-switch`, not two independently-written implementations, closing the exact class of drift
  13 found between `echo` and `printf '%s'`. This fully specifies the Script conventions fog patch;
  nothing further graduates from it.

- [Nested tmux and `tmux-sessionizer` under the Roles](issues/16-nested-tmux-and-sessionizer.md): both
  halves are **already Role-agnostic**, no code change. The F12 toggle binds unconditionally outside
  the deleted `.tmux.remote.conf`, and never reads `SSH_CLIENT`/the Role Marker, it's about
  outer-vs-inner server nesting, not Desktop-vs-Headless. Probed `ubuntu-server` live rather than
  guessing: `~/projects` and `~/repos` are populated there, overturning the ticket's premise that the
  paths might resolve to nothing on a Headless box. `find`'s silent degradation already covers hosts
  where a path is genuinely absent, so no Role branch is added; the operator creates the directories
  by hand where they want them searched, same shape as [10](issues/10-vault-flattening-migration.md).

## Not yet specified

In scope, but not yet sharp enough to ticket. Graduates as the frontier advances.

Empty. No tickets remain open; the map's destination is reached.

## Out of scope

Beyond the destination. Never graduates; returns only if the destination is redrawn, and then as a
fresh effort.

- **macOS, containers/ephemeral devboxes, and remotes without root or package install.** Ruled out
  while naming the destination: targets are the Fedora/sway host and headless Linux SSH remotes only.
- **Qt/KDE app theming.** Attempted and abandoned before this map existed; see
  `.scratch/theme-switch/spec.md` and ADR-0001.
- **Implementing any decision this map makes.** Planning only, per Notes. The notetaking rewrite
  decided by [04](issues/04-note-restructure-prototype.md),
  [06](issues/06-shared-note-config-shape.md) and [10](issues/10-vault-flattening-migration.md) is
  now written up as [`.scratch/notetaking-rewrite/spec.md`](../notetaking-rewrite/spec.md)
  (`ready-for-agent`), but building it is not this map's work. The theme-switch expansion and Headless
  propagation decided by [03](issues/03-theme-capability-survey.md),
  [07](issues/07-theme-switch-app-roster.md) and [08](issues/08-theme-mode-propagation.md) — plus
  [12](issues/12-ssh-config-ownership.md), folded in because its only consumer is this work — is now
  written up as [`.scratch/theme-switch-expansion/spec.md`](../theme-switch-expansion/spec.md)
  (`ready-for-agent`), same caveat.
- **Migrating the vault data itself.** [10](issues/10-vault-flattening-migration.md) decided the
  operator does this by hand; no code in this repo touches `~/Sync/vault`.
- **The clipboard tunnel's deletion**, decided by
  [09](issues/09-clipboard-backend-signal.md), is now written up as
  [`.scratch/clipboard-rewire/spec.md`](../clipboard-rewire/spec.md) (`ready-for-agent`); stopping the
  live `clipboard-tunnel.service` and editing the real `~/.ssh/config` stay operator-run, per that
  spec.
- **The deployment mechanism, bootstrap sequence, and env/secrets scope**, decided by
  [02](issues/02-deployment-mechanism-survey.md), [05](issues/05-choose-deployment-mechanism.md),
  [11](issues/11-bootstrap-sequence.md) and [15](issues/15-env-secrets-scope.md), is now written up as
  [`.scratch/roles-bootstrap-deployment/spec.md`](../roles-bootstrap-deployment/spec.md)
  (`ready-for-agent`). This is the last of the four specs this map's destination called for; with it
  written, every decision on this map is either implemented, in a ticketed spec, or explicitly out of
  scope.
