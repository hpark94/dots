# Dotfiles

Vocabulary for this repo: the machine Roles it deploys onto, and how it switches
its terminal/editor/WM tooling between light and dark color themes from a single
script.

## Language

### Deployment

**Role**:\
The classification of a machine, one of Desktop or Headless, chosen once at
install and recorded in the Role Marker. Binary by design, with no layers and no
composition rule: every machine this repo targets is one you write code on, so
the only question left is whether it runs a compositor.\
_Avoid_: profile, machine class, host type

**Desktop**:\
The Role of a machine that runs the compositor, where the screen is physically
attached. Sole authority for Theme Mode.\
_Avoid_: host (collides with `DOCKER_HOST`, ssh `HostName`, and libvirt
host/guest), workstation, local

**Headless**:\
The Role of a machine that runs no compositor of its own, reached over SSH. Says
nothing about whether GUI apps appear: under waypipe or `ssh -X` a Headless
machine displays GUI apps on the Desktop's screen, because a forwarded display
is a Session Fact and not a property of the machine.\
_Avoid_: remote as the Role name (it stays fine as informal prose for "a machine
you ssh to", but it names a machine by your vantage point rather than by
anything true of the machine itself), server, box

**Role Marker**:\
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role`, holding the single word
`desktop` or `headless`. Written once at install, and the sole source of truth
for the Role. Deliberately a file rather than an exported variable, so systemd
user units, cron jobs and nvim read the same value as an interactive shell does.
Consumers may cache it in-process; nothing exports a competing copy.\
_Avoid_: `DOTFILES_ROLE`, role env var

**Role Fact**:\
Something true of the machine however you reached it, so it branches on the Role
Marker: whether Theme Mode may be changed here, whether the note vault exists.
The entire repo ships to both Roles, so a Role Fact is expressed as a branch
inside a shared file, never by withholding the file. Kept deliberately narrow:
only code a human explicitly invokes reads the Marker, never anything on the
login path, so that a machine without a Marker fails at a command rather than on
every shell.\
_Avoid_: host-only, deploy-time config

**Session Fact**:\
Something true only of the current connection, which no install-time value can
answer and which is therefore probed at runtime: whether a display is attached
(`$WAYLAND_DISPLAY`), which is the single probe behind both `QT_QPA_PLATFORM`
and the choice between a native `wl-copy`/`wl-paste` clipboard and OSC 52.
Distinct from a Role Fact because it can differ between two sessions on the same
machine, and because it goes stale in anything outliving the shell that set it,
notably a tmux server.\
_Avoid_: runtime config, SSH check (SSH-ness is only a proxy for these, and a
wrong one)

**Write-Back Config**:\
A config file that its own tooling rewrites, rather than one only a human edits.
Because deployment is stow symlinks, a write-back lands in the repo working
tree. That is wanted when the write is yours to keep (`mise use` editing
`.config/mise/config.toml`) and a liability when it is machine-local noise
(`gh auth login` appending a credential helper to `~/.gitconfig`). The test is
not whether a tool writes there, but whether that write should be tracked; where
it should not, the file is kept out of the stow package and given an untracked
real file to write into.\
_Avoid_: generated config (that is a Generated Config, which no human or tool
edits), mutable config

**Capability Probe**:\
A runtime test for whether something is present right now (`command -v swaymsg`,
`$SWAYSOCK`, `tmux list-sessions`, `[ -S "$XDG_RUNTIME_DIR/docker.sock" ]`),
letting one shared executable adapt itself instead of branching on Role. The
`apply_*` functions in `theme-switch` are the model: the script runs correctly
on both Roles unmodified. Preferred over a Role branch wherever it can answer
the same question, because it stays correct when the Role Marker is missing or
wrong, and because it keeps the Marker out of code that runs unbidden: the
docker and libvirt sockets are probed rather than Role-branched for exactly this
reason.\
_Avoid_: feature detection

### Theming

**Theme Mode**:\
The global light/dark state (`dark` or `light`), persisted in one state file
that is the source of truth for "what mode is currently active." Other tools may
query it. There is one Theme Mode across all machines, and the Desktop owns it:
a Headless machine receives it one-way and may render it but never change it.\
_Avoid_: color scheme, appearance

**Canonical Palette**:\
The hand-maintained, git-tracked source of the 16 ANSI colors plus
bg/fg/selection for a given Theme Mode: one shell-sourceable file per mode.\
_Avoid_: theme file (ambiguous with Selected Theme)

**Generated Config**:\
A derived, gitignored file the switch script writes from the Canonical Palette
(or a fixed theme-name choice), which a tracked app config `include`s or
`source`s. Regenerated on every switch; never hand-edited. Normally one file per
app holding the _current_ Theme Mode's values, because the switch script decides
the mode. Where the app decides instead (a **pull** Live-switchable app, see
below), the script writes **one file per mode** and all of them stay on disk at
once, because the app picks between them without asking.\
_Avoid_: cache, build output

**Selected Theme**:\
A hand-authored, pre-built theme artifact that exists for both modes ahead of
time (nvim colorscheme, bat syntax theme); switching means picking a name, not
regenerating colors. Uses richer semantic roles (comment, string, keyword, type,
function, ...) than the Canonical Palette's flat 16 slots.\
_Avoid_: generated theme

**Live-switchable app**:\
An app whose already-running instances pick up a Theme Mode change immediately,
by either of two routes. **Push**, where the switch script signals the app: foot
(`SIGUSR1`/`SIGUSR2`), ghostty (`SIGUSR2`), tmux (`set-option` against the
running server), sway (`swaymsg`), swaync (`swaync-client -rs`), zathura
(`SourceConfig()` on each `org.pwmt.zathura.PID-<pid>` D-Bus name). **Pull**,
where the app subscribes to the change itself and the switch script contributes
no code at all: waybar, which watches the XDG desktop portal's
`org.freedesktop.appearance` and re-reads its stylesheet on every change; and
the interactive **shell**, whose `preexec` (zsh) / `DEBUG`-trap (bash) hook
re-sources the Generated Config fragment `shell-env.sh` before each command,
plus a zsh `line-init` hook so completion/history widgets (fzf-tab, Ctrl-R)
re-theme too (see ADR-0003). fzf and bat are carried along by the shell: each
re-reads its env var (`FZF_DEFAULT_OPTS`, `BAT_THEME`) at launch and is always
spawned from the prompt, so the shell's refreshed environment themes the next
invocation without any signal reaching fzf or bat themselves. The route is a
property of the app, not a preference; what makes an app Live-switchable is that
running instances update, not how they were told.\
_Avoid_: hot reload

**Next-launch app**:\
An app that only picks up a Theme Mode change in new instances/sessions, because
it has no live-reload hook without fragile extra infra: nvim (colorscheme picked
at startup), GTK, and the git pager delta. delta has no persistent instance at
all: git spawns it fresh on every invocation, so it reads its generated
`~/.local/state/theme/delta.gitconfig` fragment (included by the tracked
`.gitconfig.shared`) current each time. GTK apps split into two consumer
categories, both handled by `apply_gtk` setting both gsettings keys together:
classic GTK3/GTK4 apps without portal integration (evince, xarchiver,
pavucontrol) read `gsettings set org.gnome.desktop.interface gtk-theme`, via
`GtkSettings` at each app's own startup; portal-aware apps (Librewolf/Firefox,
confirmed via `org.freedesktop.appearance`/`org.freedesktop.portal.Settings`
strings compiled into `libxul.so`, and any future libadwaita app) instead read
`gsettings set org.gnome.desktop.interface color-scheme`. Confirmed via manual
testing that an already-running GTK3/GTK4 app does not re-theme live on this
system (neither links libadwaita, and no gnome-settings-daemon runs under sway
to bridge `color-scheme` into anything they watch), so both categories are
Next-launch, though a _new window_ opened in an already-running portal-aware
app's process did pick up the change, since that app's own portal subscription
is live even though the switch script's write to it isn't tied to any per-app
signal.\
_Avoid_: static, cold
