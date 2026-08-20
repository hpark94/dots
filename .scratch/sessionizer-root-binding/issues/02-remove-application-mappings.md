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

**Status:** ready-for-agent

- [ ] The nvim mapping for the key is gone
- [ ] The yazi keymap entry for the key is gone
- [ ] The zsh binding, its widget registration, and the shell function it
      wrapped are all gone
- [ ] No reference to the removed shell function survives anywhere in the repo
- [ ] Any config block left empty by the removal is cleaned up rather than left
      as an empty stub
- [ ] `C-f` still opens the sessionizer from a pane, unchanged from ticket 01
- [ ] The existing test suite still passes
