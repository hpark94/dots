# The sessionizer key is a prefix binding

`tmux-sessionizer` was reachable from three keymaps written in three languages:
an nvim normal-mode mapping launching it through `tmux neww`, a yazi keymap
entry running it blocking in place, and a zsh line editor widget pushing it onto
the command line and accepting. Together they still left most of the terminal
uncovered. In `less`, in `man`, in a Python REPL, in `htop`, `C-f` did nothing,
so reaching another project meant first quitting whatever was running, which is
the interruption the sessionizer exists to remove. The nvim one was broken
outside tmux on top of that, where its `tmux neww` has no server to talk to and
nothing reports the failure.

All three rest on the same wrong assumption, that the key belongs to the
application. Every one of those programs runs inside a tmux pane, and tmux sees
the keystroke before they do. So the key is defined once, at the multiplexer,
and the three application mappings are deleted:

```
bind-key C-f display-popup -EE -w 70% -h 70% tmux-sessionizer
```

One definition instead of four, in the layer that already sees every keystroke.

## Considered Options

**A prefix binding (chosen) over a Root Binding.** The first answer was
`bind -n C-f`, a Root Binding, which reaches even further: it fires with no
prefix at all, so it covers the pager and the REPL as well as nvim and yazi. It
was rejected because this particular Root Binding could not give the key back. A
root table command is free to hand it on, which is how the navigator keys leave
`C-h` and its neighbours to nvim and fzf, but a popup has nothing conditional to
say: it would take `C-f` in every pane, so `C-f` would stop meaning
`forward-char` in any shell that is not zsh, stop paging forward in `less` and
`man`, and stop pasting an image in nvim, where `<C-f>` in insert mode is bound
to this repo's own `note.paste_img()`. That is a permanent tax on every program
in the terminal, paid to save one keystroke.

And it does not even save a keystroke, which is what settled it. `C-b C-f` is
two bytes, `0x02` then `0x06`, and neither of them records whether Ctrl was
released in between, so the hand never leaves Ctrl and tmux cannot tell the
difference. Measured against an isolated server with a real pty client: writing
`\x02\x06` in one call, with no pause, fires the prefix binding.

`C-f` is free in the prefix table, so nothing is overwritten. Measured with the
plugins loaded, 81 keys are bound there and `C-f` is not among them, which also
means `C-b f` keeps tmux' own `find-window`. The obvious `prefix f` would have
cost that.

Nested tmux then needs no rule of its own. On a Desktop machine with an SSH
session into a Headless one, `C-b C-b C-f` reaches the inner server through the
`send-prefix` binding tmux already ships, and the outer server is untouched:
measured with two servers on two sockets, the inner window fired and the outer
did not. A Root Binding would have needed the F12 toggle for this, and the
question of an SSH-conditional or Role-keyed binding does not arise at all.
SSH-ness is named in `CONTEXT.md` as a wrong proxy anyway, and this is not a
Role Fact.

**A popup over `run-shell`.** `run-shell` runs the command on the server with no
terminal at all, and that is a measurement rather than a preference: probed
against an isolated server, the command sees no tty on stdin and none on stdout,
and interactive fzf dies there with `inappropriate ioctl for device`.
`fzf --filter` still works, which is exactly the trap: the non-interactive half
of fzf runs fine, so nothing fails until a human tries to pick something.

**A popup over `new-window`.** This is how the nvim mapping worked, and it is
the reason the window list moved twice on every use: `renumber-windows` is on,
so a transient window renumbers the list when it opens and again when it closes.
A popup draws over the current pane and leaves the window list alone, which also
keeps the pane you are switching away from visible behind the picker.

**`-EE` over `-E`.** The doubled flag is load-bearing. `tmux-sessionizer` has
four abort paths that report on stderr and exit non-zero, as this repo's shell
standard requires, and with a single `-E` the popup closes on any exit, so those
messages are never read: a missing dependency would look like a popup that
blinks and vanishes. `-EE` keeps the popup open on a non-zero exit and still
closes it on zero, and a normal fzf abort exits zero, so the common path costs
no extra keystroke.

**A percentage over fixed cells.** The same config is deployed to both Roles,
and a fixed width large enough to be useful on a monitor can exceed a small SSH
terminal. 70% by 70% on a 100 by 40 terminal yields 68 by 26 usable cells, and
fzf scrolls inside a popup too small for the candidate list.

## Consequences

- The sessionizer is defined in one file. The nvim normal-mode mapping, the yazi
  keymap entry, and the zsh `bindkey` with its widget and the shell wrapper
  behind it are all deleted. Nothing was unreachable, so this is a deliberate
  choice of one definition over four rather than a removal of dead code.
- `.config/yazi/keymap.toml` held nothing else and is deleted with its entry
  rather than left as an empty `prepend_keymap`.
- Outside tmux the key does not exist. The shell function that puts every
  interactive shell into tmux returns early in the VS Code and JetBrains
  terminals, so in those two the sessionizer is reachable only as a typed
  command. No fallback is added for them.
- `C-f` keeps its meaning everywhere else, which is the whole point of choosing
  the prefix table. nvim's insert-mode `<C-f>` for pasting an image, paging in
  `less` and `man`, and `forward-char` in a non-zsh shell all survive.
- The theme system is untouched. `popup-style` and `popup-border-style` stay at
  tmux' `default`, which resolves to the terminal's own foreground and
  background, and Theme Mode is already pushed to the terminal, so the popup
  follows the theme with no new generated fragment.
- `tmux-sessionizer` itself is unchanged. Its comment about inheriting the tmux
  server's frozen environment now names the popup instead of the deleted nvim
  route; the reason it gives holds either way, because a popup also runs through
  the server.
- A test loads the real config into an isolated tmux server on its own socket
  and asks `list-keys` what the server holds, rather than grepping the file,
  which would pass on a line tmux refused to parse. It asserts the key is bound
  in the `prefix` table to a popup running `tmux-sessionizer`, and that it is
  absent from the `off` table so the F12 toggle keeps behaving as it does for
  the prefix itself. `list-keys -T <table>` reports through the message log
  rather than stdout on a server with no attached client, so the test reads the
  unfiltered listing and matches the table in the line.
- One risk is open. `display-popup` requires tmux 3.2 or newer. The Desktop
  machine runs 3.7b, measured; the Headless host was unreachable at the time of
  writing and could not be probed. On a Headless machine with an older tmux this
  line will fail when the config is sourced. That is recorded rather than
  guarded against, in keeping with this repo's preference for failing loudly
  over a silent fallback, and it should be checked the next time a Headless host
  is reachable.
