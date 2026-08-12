# An image preview picks its rung from the client terminal's name

`fzf-preview` handed every non-directory to `bat`, so selecting a PNG in `ffd`
printed `[bat warning]: Binary content ...` and nothing else. The fix is a
**Render Ladder** in front of the `bat` branch: `file --mime-type -b` decides
whether the target is an image, and an image is drawn by the best renderer the
terminal actually supports, with anything else keeping the previous behaviour
untouched.

The rungs, in order, are `kitten icat` under ghostty or kitty, `chafa -f sixels`
under foot, and `chafa -f symbols` under anything else. A rung whose binary is
missing, or whose render fails, drops to the symbol art every terminal
understands; if that fails too the target falls through to the text path, so a
preview window is never left blank.

The terminal is identified by name, from `tmux display -p '#{client_termname}'`
inside tmux and from `$TERM` outside it. What each name is worth was measured on
this machine: ghostty 1.3.1 speaks the Kitty graphics protocol including Unicode
placeholders and does not speak sixel; foot 1.27 speaks sixel and not the Kitty
protocol; `kitten` 0.47.1 and `chafa` 1.18.2 are installed, while `timg`, `viu`
and `ueberzugpp` are not. `.tmux.conf` already sets `allow-passthrough on`, so
the graphics escapes reach the terminal through tmux.

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

**A name lookup over probing the terminal.** Asking the terminal what it
supports (`kitten icat --detect-support`, or a hand-written primary device
attributes query) is the answer that cannot be wrong, and it is what a one-shot
tool should do. A preview command runs on every keystroke, so each probe would
add a terminal round trip and, when the reply never comes, a timeout, to every
cursor move. A cache would make that once-per-terminal instead of
once-per-keystroke, at the price of state on disk that goes stale exactly when
the terminal changes underneath it. The name is free and available before
anything is drawn, and what it costs is a rung chosen from a list of names
rather than from what the terminal can actually do.

**`#{client_termname}` over the environment.** `GHOSTTY_BIN_DIR` and
`TERM_PROGRAM` are the obvious way to recognise the terminal, and both are
present in the tmux server environment here. Both are also wrong there: the
server keeps whatever the first client exported, so after detaching and
reattaching from foot they still name ghostty, and the ladder would send Kitty
protocol escapes to a terminal that cannot read them. `#{client_termname}` is a
property of the attached client, so it is re-read per client and stays correct
across a reattach; `#{client_termtype}` (`ghostty 1.3.1`) is equally correct and
carries a version, but nothing here needs one. This is the Session Fact rule
applied to a terminal: probe the connection, never the environment a longer
lived process is holding.

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
  the accepted cost of reading a name, not something the design prevents. Each
  is one more pattern in the `case` once it is worth adding, and the wrong
  answer is always a lower-fidelity picture rather than a broken pane.
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
