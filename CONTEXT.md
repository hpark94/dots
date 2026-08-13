# Dotfiles

Vocabulary for this repo: the machine Roles it deploys onto, how it switches its
terminal/editor/WM tooling between light and dark color themes from a single
script, how the file pickers preview what they are about to open, and how the
music scripts turn audio tags into paths.

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

**Client Terminal**:\
The terminal that actually draws what a program writes: inside tmux the one an
attached client runs in, elsewhere the one that owns the tty. There can be
several at once, because tmux draws a pane on every client attached to its
session and those clients need not be the same terminal, so the question has a
list for an answer: `tmux list-clients -t "$TMUX_PANE" -F '#{client_termtype}'`,
one self-report per client, targeted so that clients of other sessions on the
same server stay out of it. `tmux display -p` answers for whichever client tmux
last considered current, which is a coin toss the moment a second terminal
attaches (see ADR-0007). Identified by what it reports about itself, never by
the terminfo name it claims: `#{client_termtype}` is the terminal's own
XTVERSION reply (`ghostty 1.3.1`, `foot(1.27.0)`), and outside tmux
`$TERM_PROGRAM` (`ghostty`), with `$TERM` left as the fallback for a terminal
that exports neither (`xterm-ghostty`). Outside tmux the environment can also
answer nothing at all, and for foot it does: foot's changelog records
"`$TERM_PROGRAM` and `$TERM_PROGRAM_VERSION` environment variables unset in the
slave process", so foot deliberately deletes the variable instead of setting it,
and `foot.ini` renames `$TERM` to `xterm-256color`, so both sources are silent
about the terminal actually drawing. A terminal that says nothing stays unnamed,
because asking it is not available here: the reply to such a question goes to
whoever owns the terminal's input, which in a preview is fzf and never the
preview, so it arrives as typing in fzf's query line rather than as an answer.
So foot is given something to say rather than asked: `.config/foot/foot.ini`
sets `TERM_PROGRAM=foot` in an `[environment]` section, the same variable
ghostty and kitty already set, which is why no code here knows foot is special
(see ADR-0007). A name is not a terminal: `$TERM` in a pane names tmux's own
terminfo entry, and `#{client_termname}` is only what the terminal was
configured to claim, which `.config/foot/foot.ini` deliberately sets to
`xterm-256color` so SSH to hosts without foot terminfo keeps working (see
ADR-0007). It is the Session Fact that has a way out of its own staleness:
`TERM_PROGRAM` and `GHOSTTY_BIN_DIR` live on in the tmux server environment and
keep naming whichever terminal started the server, so after a reattach from foot
they still claim ghostty, while `#{client_termtype}` is a property of the client
and is therefore re-read on every attach. Consulted for what the terminal can
draw, the Kitty graphics protocol or sixel, never for who or where the user is.\
_Avoid_: `$TERM` (inside tmux that is a terminfo name, not a terminal),
`#{client_termname}` (a claim a config can rewrite), terminal emulator, outer
terminal, _the_ Client Terminal (one pane can have several)

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

### File picking

**Previewer**:\
The one executable behind every fzf preview window, `fzf-preview <path> [line]`,
so a directory, a text file and an image look the same whether the window was
drawn by `ffd`, `frg`, `_fzf_comprun` or fzf-tab. It takes a path and not a
mode: what the target is, and therefore how it should be drawn, is the
Previewer's question to answer, which is what keeps each caller down to a single
`--preview` string and stops four of them drifting apart. The optional line
number is the line `frg` matched, handed to `bat --highlight-line` so it stands
out; the scrolling that brings it into view is fzf's own
`--preview-window '+{2}-/2'`, not the Previewer's. It is not a second mode.
Because it runs on every keystroke it may only read and draw, and every cost it
carries is paid once per cursor move.\
_Avoid_: preview command (that is fzf's `--preview` option, whose only job here
is to name the Previewer), preview script

**Opener**:\
The command a picker hands its selection to once you accept it: the tool and
flags `ffd` wraps around `{+}`, the `nvim {1} +{2}` and `nvim +cw -q {+f}` pair
in `frg`. It is a string fzf expands and a shell then splits, never one this
shell expands, which is why an Opener flag can carry neither a space nor a
quote. Deliberately the Previewer's opposite number: the Previewer runs unbidden
and changes nothing, while the Opener runs once, on an explicit key, and is
allowed to.\
_Avoid_: action, handler, editor (nvim is only the default; `ffd` opens with any
tool on PATH)

**Render Ladder**:\
The ordered rungs the Previewer tries for one image: `kitten icat` under ghostty
or kitty, `chafa -f sixels` under foot where the sixels can reach it, and
`chafa -f symbols` under anything else. The sixel rung carries a second guard
because a tmux built without `--enable-sixel` erases the image a moment after
drawing it: inside tmux the rung is taken only when the `#{sixel_support}`
Capability Probe says tmux can carry it, which is `0` on this machine and makes
foot-in-tmux symbol art until tmux gains that support (see ADR-0007). Beneath
all of them is the text path, the ladder's floor rather than a rung of it: it
draws no image at all and exists only so a preview window is never blank. Each
rung is guarded by the Client Terminal that can display it, read from that
terminal's self-report and never asked of the terminal from here. Where several
Client Terminals draw the pane at once the rung is the one they all agree on,
and any disagreement, like a session with no client attached at all, collapses
to symbol art: it is the only rung that is plain text and therefore the only one
correct on every attached terminal at once. The collapse self-heals, since
detaching the weaker terminal puts the next preview back on the better rung with
no state to clear. A rung whose binary is missing or whose render fails drops to
the next, which makes the bottom rung the one that cannot fail: symbol art is
only text. Ordered by fidelity, so adding a renderer means placing it against
the terminals that can draw it, never appending it (see ADR-0007). No rung asks
the terminal anything, not even the one with no name to go on. Inside tmux the
question is already answered, for free and per client, by the handshake tmux
performs at attach when it does own the terminal; outside tmux a Client Terminal
the environment names nowhere gets symbol art rather than a question, because a
preview does not own the terminal's input and the reply would land in fzf's
query line as typing. A terminal that erases its own name, as foot does, is
therefore given one back in its own config rather than interrogated (see
ADR-0007).\
_Avoid_: fallback chain (the order is fidelity, not failure), backend list,
protocol detection (the rung follows the terminal's self-report, and nothing
here asks the terminal which protocols it speaks)

### Music library

**Album Artist**:\
The artist a release as a whole is credited to, read from the `ALBUMARTIST` tag
and falling back to `ARTIST` where that tag is absent. Sole decider of the
artist directory, so every track of a release files together however its
individual tracks are credited: a guest on one track cannot fork the album into
a sibling directory. Deliberately a different tag from the Track Artist rather
than a parse of it, because a genuine joint release credits both names in
`ALBUMARTIST` and taking the first would be a guess (see ADR-0006).\
_Avoid_: artist (ambiguous with Track Artist), main artist, primary artist

**Track Artist**:\
The artist credited on one individual recording, read from the `ARTIST` tag,
guests included. Decides the artist suffix of the filename and never a
directory. It exists as its own term because once the directory keys on the
Album Artist, the filename is the only place a collaboration still shows on
disk.\
_Avoid_: artist, performer, featured artist (that names only the guest half of
the credit)

**Slug**:\
The single form every tag value takes before it becomes a path segment:
lowercased, with each character that is neither letter, digit, nor parenthesis
turned into `-`, runs of `-` collapsed to one, and `-` trimmed from both ends.
Letter and digit are meant in the Unicode sense, so Hangul, Kana and CJK
survive; parentheses are the one punctuation exception, because the bracketed
qualifier carries meaning in this library's titles. `-` is the only separator a
Slug can contain, which is what makes doubled and stranded separators
unrepresentable rather than merely repaired. A value that slugs to the empty
string counts as unusable metadata and sends its file to Skipped.\
_Avoid_: sanitized name, safe name, normalized (normalization means Unicode
NFC/NFD folding, which a Slug does not do)

**Skipped**:\
The quarantine directory holding files whose tags cannot yield a complete path,
because a tag is missing, because a track number is not a decimal, or because a
value slugs to nothing. A file goes there rather than being filed under a
guessed or empty name, and it is neither deleted nor retagged; a name already
taken there leaves the file where it is. The counterpart to the collision guard
in the filed tree: both fail loudly and move on instead of overwriting.\
_Avoid_: rejected, failed, trash, quarantine as the directory name
