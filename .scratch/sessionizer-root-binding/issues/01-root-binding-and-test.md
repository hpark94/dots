# 01 `C-f` becomes a Root Binding

**Spec:** [The sessionizer key becomes a Root Binding](../spec.md)

**What to build:** `C-f` opens `tmux-sessionizer` from any pane, in any program.
Today the key only means something inside nvim, yazi, and an empty zsh command
line; after this ticket it means the same thing in `less`, in `man`, in a REPL,
in `htop`, and everywhere else, because tmux claims the key before the pane's
program sees it.

The picker is drawn as a popup over the current pane rather than in a new
window, it is sized relative to the terminal, and it stays open when the
sessionizer fails so its error is readable. A normal abort still closes it with
no extra keystroke.

From the prototype, because the flags carry the decision more precisely than
prose can:

```
bind -n C-f display-popup -EE -w 70% -h 70% tmux-sessionizer
```

The doubled `-E` is load-bearing: `tmux-sessionizer` reports its four abort
paths on stderr and exits non-zero, and a single `-E` would close the popup on
those exits with the message never displayed. `run-shell` is not an option and
was not a preference: its command gets no tty on stdin or stdout, and fzf dies
there. `new-window` was rejected because `renumber-windows` is on, so a
transient window renumbers the window list twice per use.

The binding belongs with the existing root key table binding, not among the
prefix bindings, and it must stay out of the passive `off` table so the F12
toggle keeps handing keys to an inner tmux over SSH.

A new bats file covers it, at the highest deterministic seam: an isolated tmux
server on its own socket, given a temporary `HOME` and this repo's real tmux
config, then asked what it holds. Grepping the config text is not the seam,
because it would pass on a line tmux refused to parse. The repo's real config
was prototyped in that environment and loads cleanly with the plugin manager and
the theme fragment both absent, so no fixture beyond a temporary directory is
needed.

**Blocked by:** None, can start immediately.

**Status:** ready-for-agent

- [ ] `C-f` opens the sessionizer popup from a pane running a program that has
      no keymap of its own
- [ ] The popup closes on a normal abort without an extra keystroke
- [ ] A failing sessionizer leaves its stderr message visible in the popup
- [ ] fzf inside the popup still receives `C-f` itself
- [ ] A test asserts the key is bound in the `root` table to a popup running
      `tmux-sessionizer`
- [ ] A test asserts the key is absent from the `off` table
- [ ] The new test file is listed among the repo's documented test commands
- [ ] The theme system is untouched: the popup follows Theme Mode through the
      terminal's own default colors
- [ ] `tmux-sessionizer` itself is unchanged
