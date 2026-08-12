# An image preview picks its rung from the client terminal's self-report

`fzf-preview` handed every non-directory to `bat`, so selecting a PNG in `ffd`
printed `[bat warning]: Binary content ...` and nothing else. The fix is a
**Render Ladder** in front of the `bat` branch: `file --mime-type -b` decides
whether the target is an image, and an image is drawn by the best renderer the
terminal actually supports, with anything else keeping the previous behaviour
untouched.

The rungs, in order, are `kitten icat` under ghostty or kitty, `chafa -f sixels`
under foot where the sixels can reach it, and `chafa -f symbols` under anything
else. Outside tmux the bottom rung is reached by way of one more step, a `chafa`
that probes the terminal and picks its own format, because outside tmux the
terminal can be anonymous; that is the second decision recorded here. A rung
whose binary is missing, or whose render fails, drops to the symbol art every
terminal understands; if that fails too the target falls through to the text
path, so a preview window is never left blank.

The Client Terminal is identified by what it says about itself, from
`tmux list-clients -t "$TMUX_PANE" -F '#{client_termtype}'` inside tmux, one
line per client attached to the pane's session, and from `$TERM_PROGRAM`,
falling back to `$TERM`, outside it. This decision first read the terminfo name
instead, `#{client_termname}` and `$TERM`, and that was wrong in practice: this
repo's own `.config/foot/foot.ini` sets `term=xterm-256color` so that SSH to
hosts without foot terminfo keeps working, so a foot window is named
`xterm-256color`, no `*foot*` pattern ever matched it, and every image preview
in foot fell to symbol art while ghostty got Kitty graphics. A terminal is free
to be configured to claim any name. What it cannot be configured away from is
its own answer to XTVERSION, which tmux keeps per client as
`#{client_termtype}`: `foot(1.27.0)` and `ghostty 1.3.1`. Outside tmux the
terminal was assumed to state the same thing in `TERM_PROGRAM` (`ghostty`); foot
turned out to state nothing there, which the next section takes up. Both values
are matched by the patterns the `case` had already, which are globs.

What each terminal is worth was measured on this machine: ghostty 1.3.1 speaks
the Kitty graphics protocol including Unicode placeholders and does not speak
sixel; foot 1.27 speaks sixel and not the Kitty protocol; `kitten` 0.47.1 and
`chafa` 1.18.2 are installed, while `timg`, `viu` and `ueberzugpp` are not.
`.tmux.conf` already sets `allow-passthrough on`, so the graphics escapes reach
the terminal through tmux.

## Outside tmux the environment answers nothing, so chafa asks the terminal

The paragraph above is wrong about foot outside tmux, and measuring it is what
found that out. `$TERM_PROGRAM` does not name foot, because foot does not set
it: its changelog records, under Removed, "`$TERM_PROGRAM` and
`$TERM_PROGRAM_VERSION` environment variables unset in the slave process". foot
deliberately deletes the variable from the environment it hands the shell rather
than filling it in, so it is not merely absent, it is absent on purpose and will
stay that way. Confirmed live: in a foot window outside tmux, `TERM_PROGRAM` is
unset. `$TERM` cannot cover for it either, for the reason this ADR already
records at length, `.config/foot/foot.ini` sets `term=xterm-256color`, so
`$TERM` reads `xterm-256color` and names nothing. Outside tmux, therefore,
nothing in the environment identifies the Client Terminal at all, and every
image preview in foot fell to symbol art, which is the exact failure this ADR
was written to fix, surviving in the one place it was not measured.

There is no name left to read, so the decision is to ask the terminal. Outside
tmux, and only where the name has already failed to give a rung, the ladder runs
`chafa --probe=0.2 --probe-mode=ctty -s "${geometry}" "${target}"` and lets
chafa choose the format from what the terminal answers. No `-f`: choosing is the
whole point of that call. The probe question goes over the controlling terminal
because a preview's stdout is fzf's pipe, and an escape sequence written there
would be garbage in the preview window with no reply ever coming back. The
timeout is explicit and short because this runs on every keystroke.

Inside tmux nothing changes. `#{client_termtype}` per attached client, the rule
that disagreeing clients collapse to symbol art, and the `#{sixel_support}` gate
all stand exactly as they were, and no probe is issued there whatever the
self-report says. The name is still consulted first outside tmux too, so ghostty
(`xterm-ghostty`) and kitty still take the top rung at no cost, and only the
case with no cheaper answer pays for the round trip.

## Considered Options

**Unicode placeholders over raw graphics escapes.** `chafa --passthrough=tmux`
would put the same pixels on the screen with one fewer dependency, and `chafa`
is already the fallback rung. It transmits a bare graphics command, though, and
tmux then has no idea the image occupies any cells: the image is painted over
the pane and stays painted, so moving the selection from an image to a text file
leaves the picture sitting on top of the text, and scrolling or a pane redraw
smears it. Unicode placeholders exist precisely to solve this.
`kitten icat --unicode-placeholder` writes the image into the text grid as
U+10EEEE cells carrying the image id in combining marks, so the cells are the
pane's own content: the next preview redraw overwrites them and the image goes
with them. `--passthrough tmux` implies the flag, but nothing implies it outside
tmux, so the ladder passes it unconditionally; both terminals on the top rung
understand placeholders. Verified live here under tmux with a ghostty client,
over five image-to-text selection changes with zero placeholder cells left
behind, across a window switch and back, and across a pane split that resized
and redrew the preview. Verified outside tmux by capturing the emitted bytes on
a pty with `TERM=xterm-ghostty`: with the flag they are placeholder cells, and
without it a bare graphics command preceded by an absolute cursor move to screen
row 1.

**The self-report over the name the terminal claims.** `#{client_termname}` and
`$TERM` are one lookup shorter and were this decision's first answer. A name is
the terminal's claim about which terminfo entry describes it, though, and a
claim is configurable: `foot.ini` sets `term=xterm-256color` on purpose, so foot
names itself something that says nothing about foot, and the sixel rung became
unreachable in the one terminal it exists for. The XTVERSION reply is the
terminal answering for itself, and nothing in this repo can override it without
lying about which program is running. It also costs nothing extra: tmux performs
that handshake once at attach and holds the answer, so the ladder reads it back
rather than asking for it.

**A self-report over probing the terminal from here.** Asking the terminal what
it supports (`kitten icat --detect-support`, or a hand-written primary device
attributes query) is the answer that cannot be wrong, and it is what a one-shot
tool should do. A preview command runs on every keystroke, so each probe would
add a terminal round trip and, when the reply never comes, a timeout, to every
cursor move. A cache would make that once-per-terminal instead of
once-per-keystroke, at the price of state on disk that goes stale exactly when
the terminal changes underneath it. tmux's one handshake per attach is that
cache, kept by the process that already knows when the client changes. What it
costs is a rung chosen from a list of terminals rather than from what the
terminal can actually do.

That rejection was right for the general case and is kept everywhere a
self-report exists to read, which is everywhere inside tmux. It was wrong as a
blanket rule, because it assumed a self-report always exists, and outside tmux
in foot there is none: the probe there is not a round trip instead of a free
answer, it is a round trip instead of no answer. The cost is bounded rather than
argued away. `--probe` takes a number of seconds, and the ladder passes `0.2`
against chafa's default of `5.0`; measured against a pty that never answers, the
call returned in 0.213s at `0.2` and 5.018s at the default, so the cap is
honoured to the millisecond and a silent terminal costs a fifth of a second per
keystroke, not five seconds. Measured against a pty answering as a sixel
terminal, the same call returned in 0.012s and emitted sixel where it had
emitted symbol art, so the probe is fast when a terminal is listening and it
does change the rung. A timeout is not a failure either: chafa still renders, in
symbol art, which is exactly what this path drew before. No cache is added, so
nothing goes stale, and the terminal is asked afresh on each keystroke it cannot
be named on.

**The tmux client over the environment.** `TERM_PROGRAM` and `GHOSTTY_BIN_DIR`
are the obvious way to recognise the terminal and would need no tmux call at
all. Inside tmux both are wrong: tmux overwrites `TERM_PROGRAM` with `tmux` in a
pane, and the server keeps whatever the first client exported, so after
detaching and reattaching from foot the server copy still names ghostty and the
ladder would send Kitty protocol escapes to a terminal that cannot read them.
`#{client_termtype}` is a property of the attached client, so it is re-read per
client and stays correct across a reattach. This is the Session Fact rule
applied to a terminal: probe the connection, never the environment a longer
lived process is holding. Outside tmux there is no longer lived process holding
a copy, which is what makes `TERM_PROGRAM` the right source exactly there and
nowhere else. It is a source only where the terminal sets it at all, and foot
does not, which is what the section above resolves.

**Every attached client over the one tmux calls current.**
`tmux display -p '#{client_termtype}'` is the shorter question and was this
decision's first answer: one value in, one rung out. A pane is not drawn on one
terminal, though. tmux draws it on every client attached to its session, all at
the same time, and those clients need not run the same terminal. Measured here
with two clients on one session, `/dev/pts/0` a foot window and `/dev/pts/8` a
ghostty window, `display -p` answered `foot(1.27.0)` for every pane that asked,
from either window, because "current client" is tmux's own notion of recency and
not a property of the pane doing the asking. The ghostty window therefore got
symbol art for as long as a foot window stayed attached, and had the recency
gone the other way, foot would have got Kitty graphics escapes printed as
literal garbage. `tmux list-clients -t "$TMUX_PANE" -F '#{client_termtype}'` is
the honest question: it names every client of the pane's session, one
self-report per line. The target matters as much as the subcommand. Untargeted,
`list-clients` lists the clients of every session on the server, and a terminal
attached to some other session, drawing none of this pane, would drag the rung
down with it. A pane id is a valid target here: tmux 3.7b resolves `%5` to the
session that owns it and lists exactly that session's clients, verified live
against the running server.

**Symbol art when the clients disagree, over picking a favourite among them.**
Once the answer is a list, two terminals can deserve different rungs, and one
preview command writes one stream of bytes into one pane: there is no per-client
answer to give. Preferring the better terminal paints Kitty escapes into a foot
window as garbage it will never erase; preferring the worse punishes a good
terminal for the bad one's presence, and neither choice is stable, since which
one wins would depend on the order tmux happens to list them in. Symbol art is
the only rung that is plain text, so it is the only rung that is correct on all
of them at once. That makes the disagreement collapse the same rule the ladder
already applies to a missing binary: where a rung cannot be right everywhere the
pane is drawn, drop to the one that cannot fail. It costs nothing permanent
either, because it is recomputed per keystroke from the live client list: detach
the weaker terminal and the next preview is back on the better rung, with no
cache to clear and nothing to restart.

The whole rule, measured against a stubbed tmux:

| Clients attached to the pane's session | Rung           |
| -------------------------------------- | -------------- |
| ghostty alone                          | Kitty graphics |
| foot alone, tmux without sixel support | symbol art     |
| foot alone, tmux with sixel support    | sixels         |
| ghostty and foot                       | symbol art     |
| two ghostty clients                    | Kitty graphics |
| none                                   | symbol art     |

**A self-report over `#{sixel_support}` for identifying the terminal.** tmux
exposes `#{sixel_support}`, so it is tempting to let that one flag choose the
rung. It is one boolean about one protocol, though: it says nothing about the
Kitty graphics protocol the top rung needs, so it could gate only the middle
rung, and it exists only inside tmux, so the ladder would still need a second
mechanism outside. One value that identifies the terminal answers for every
rung, in both places. `#{sixel_support}` earns its place elsewhere in the
ladder, as the Capability Probe below.

**A Capability Probe over a tmux version check for the sixel rung.**
`#{sixel_support}` is not about the terminal at all: it is tmux saying whether
_tmux_ can parse and re-render sixel, and on this machine it answers `0` while
`#{client_termfeatures}` in the same breath lists `sixel` for the foot client
that tmux is attached to. `strings` on Fedora's tmux-3.7b-2.fc44 finds no
DECSIXEL parser at all, so the package is built without `--enable-sixel`.
Handing tmux the escapes raw with `chafa --passthrough=tmux` was tried by hand
under foot: the image appears for a moment and is immediately erased, the same
failure yazi shows there, reported as a tmux 3.7b regression that worked in 3.6
and is expected to be fixed in 3.8. Outside tmux the identical command renders
correctly, so the sixel rung is gated only inside tmux, and gated on the probe
rather than on a parsed version number: a version comparison would have to guess
which future release fixes this, while the probe turns the rung back on by
itself the day a sixel-enabled tmux runs, with no code change here. This is what
`CONTEXT.md` means by a Capability Probe, and it is preferred for exactly this
reason.

**A ladder over `chafa -f symbols` everywhere.** One symbol-art rung would work
in every terminal, need no protocol knowledge, and never leave residue, since it
is only text. It is also the whole reason to reach for images at all: symbol art
resolves a photograph into coloured half-blocks, which answers "is this the
right file" far less often than the picture does. Symbol art therefore stays as
the rung that always works rather than the only rung.

## Consequences

- `fzf-preview` validates `eza` and `bat` inside the branch that uses them
  instead of up front. An image preview needs neither, and failing before the
  ladder because a tree lister is missing would be a loud error where the
  correct answer was a picture.
- The detection needs `file(1)`. Where it is absent, nothing classifies the
  target and every file takes the text path, which is exactly what this script
  did before the ladder existed. `bat` already reports binary content in one
  clean line, so that fallback stays readable rather than dumping bytes.
- The transfer mode is pinned to `memory`. Detecting it is another terminal
  round trip, and streaming the pixels through escape codes is the slow path.
  Shared memory does not survive a hop, so an image previewed in a tmux session
  on a Headless machine, drawn by a Desktop terminal over SSH, will not appear
  on the top rung; the ladder's lower rungs are unaffected because they write
  escape codes only.
- A terminal that can draw better than symbol art but is not named in the `case`
  gets symbol art anyway: wezterm and konsole speak the Kitty protocol, xterm
  and mlterm speak sixel, and all four fall to the bottom rung silently. That is
  the accepted cost of identifying the terminal instead of its protocols, not
  something the design prevents. Each is one more pattern in the `case` once it
  is worth adding, and the wrong answer is always a lower-fidelity picture
  rather than a broken pane.
- foot inside this tmux gets symbol art today, and only outside tmux does it get
  sixels. That is the whole benefit of the fix cancelled in the place the owner
  spends most of the day, and it is still the right answer: a picture that
  flashes and vanishes says less about the file than blocky art that stays on
  the screen, and it leaves the preview window looking broken. Nothing here has
  to change when tmux gains sixel support; the rung comes back on its own.
- A terminal that answers no XTVERSION leaves `#{client_termtype}` empty, which
  matches no pattern and therefore lands on symbol art. The claimed name is
  deliberately not consulted to fill that gap: it is the source this decision
  stopped trusting, both terminals on the upper rungs do answer, and the only
  thing such a fallback could buy is a wrong rung for a terminal nobody here
  runs. Such a client is one client among however many, so it does not only land
  itself on symbol art: it holds every other client there with it.
- Attaching a second terminal to a session can visibly downgrade previews in the
  first one, with nothing in the preview window explaining why. That is the
  honest outcome rather than a regression: the pane is being drawn on both
  screens, and the better rung was only ever correct while one terminal was
  watching. It reverses on detach, at the next keystroke.
- A session with no attached client previews as symbol art. Nothing is drawing
  pixels, so there is no terminal to be right about, and the rung that cannot
  fail is the only defensible answer for whatever reads the pane later.
- The client list is read on every keystroke, which is one more tmux round trip
  per preview than `display -p` was. It is a query to a local server over a unix
  socket, not a terminal round trip with a timeout behind it, which is the cost
  this decision was avoiding.
- `--place ...@0x0` means the cursor only under Unicode placeholders. Plain
  `kitten icat` reads that origin as the top-left of the screen, so the same
  flag that keeps the image out of the terminal's raw graphics layer is also the
  one that puts it in the preview window at all. That is why
  `--unicode-placeholder` is passed unconditionally instead of being left to
  `--passthrough tmux` to imply.
- `kitten icat` is left at its default `--scale-up=no`, so an image smaller than
  the preview window is drawn at its own size rather than blown up to fill the
  pane.
- The geometry comes from `FZF_PREVIEW_COLUMNS`/`FZF_PREVIEW_LINES`, which only
  fzf sets. Run by hand outside fzf the script falls back to 80x24, which draws
  a sane preview instead of failing on an empty rectangle.
- Adding a terminal to a rung is a pattern in one `case`. Adding a rung is a
  function plus an arm, which is the shape to keep: the ladder is ordered by
  fidelity, and the bottom rung must remain the one that cannot fail.
- Outside tmux, an image preview in a terminal no name identifies costs up to
  0.2s per keystroke, measured at 0.213s against a pty that never answers. That
  is the price of the only rung better than symbol art such a terminal can be
  given, and it is paid only there: a named terminal never reaches the probe, so
  ghostty and kitty previews are unchanged.
- The probe picks the format, so it can pick the Kitty graphics protocol, and
  `chafa` writes that without Unicode placeholders, which is the residue problem
  the top rung uses `kitten icat` to avoid. Every terminal on this machine that
  speaks the protocol is named in the `case` and never reaches the probe, so
  this is reachable only from a wezterm or konsole outside tmux. The
  lower-fidelity answer for an unnamed terminal was symbol art with no image at
  all, so a picture that may need a redraw is not a regression, but it is the
  one way this path can be worse than what it replaced.
- `chafa` probes the terminal by default, even when `-f` has already decided the
  format: measured on 1.18.2, `chafa -f symbols` with no probe option at all
  sends `OSC 10`, `OSC 11`, `CSI 18t`, `CSI 14t`, `CSI 16t` and `CSI 0c` over
  the controlling terminal and waits 5.016s for a reply that never comes. That
  is a five-second stall per keystroke in front of anything that answers
  nothing, an ssh session or a tty console, and it costs a rung that already
  knows its format precisely nothing to avoid. Both `-f` rungs therefore pass
  `--probe=off`, whose output is byte-identical to leaving it out. Only the rung
  that has no name to go on asks a question, which is the whole point of that
  rung.
