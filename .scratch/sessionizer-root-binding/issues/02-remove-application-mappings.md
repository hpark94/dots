# 02 The three application mappings are removed

**Spec:** [The sessionizer key becomes a Root Binding](../spec.md)

**What to build:** nothing changes for the operator, and that is the assurance
this ticket delivers. `C-f` keeps opening the sessionizer exactly as it did
after ticket 01, while the three places that used to define it stop defining it:
the nvim normal-mode mapping, the yazi keymap entry, and the zsh line editor
widget together with the shell function it wraps.

They go because a Root Binding makes them unreachable. tmux takes the key first,
so a mapping in a pane's program can never fire again, and this repo does not
keep code that cannot run. The nvim one was additionally broken outside tmux
already, where its new-window launch has no server to talk to and nothing
reports the failure.

One consequence is accepted rather than mitigated: the shell startup function
that puts every interactive shell into tmux deliberately returns early in the VS
Code and JetBrains terminals. In those two, `C-f` reverts to `forward-char` and
the sessionizer becomes reachable only as a typed command. No fallback is added
for them.

Inside tmux nothing is lost, because the zsh widget was already guarded to do
nothing when the command line was non-empty.

**Blocked by:** 01. Removing them before the Root Binding exists would leave the
key dead in every program.

**Status:** done

- [x] The nvim mapping for the key is gone
- [x] The yazi keymap entry for the key is gone
- [x] The zsh binding, its widget registration, and the shell function it
      wrapped are all gone
- [x] No reference to the removed shell function survives anywhere in the repo
- [x] Any config block left empty by the removal is cleaned up rather than left
      as an empty stub
- [x] `C-f` still opens the sessionizer from a pane, unchanged from ticket 01
- [x] The existing test suite still passes

## Comments

The removals happened as written, but the reason above does not hold: under a
prefix binding the three mappings stayed reachable, so this was the owner's
deliberate choice of one definition over four rather than the deletion of
unreachable code. See the spec's comment and ADR-0010.

Two notes on what was and was not touched. nvim's insert-mode `<C-f>`, bound to
`note.paste_img()`, is a different feature and stays; the prefix binding is what
lets it keep working. And the comment in `tmux-sessionizer` naming `tmux neww`
as the launch route was stale after the deletion, so it now names the popup; the
reason it gives is unchanged, because a popup also runs through the tmux server.
