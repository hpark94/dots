# 03 Root Binding enters the vocabulary and the decision record

**Spec:** [The sessionizer key becomes a Root Binding](../spec.md)

**What to build:** a future reader can find out what a Root Binding is and why
this repo has one, without reconstructing the reasoning from the config.

The glossary gains **Root Binding**: a key tmux claims in its root table, taken
before the pane's program sees it. Unconditionally global inside tmux, absent
outside it, and unrecoverable for the program in the pane, which is what makes
an application mapping for such a key pointless. It is contrasted with a prefix
binding, which is the opposite arrangement and the likely confusion, and with
the conditional pass-through the vim/tmux navigator plugin performs on its own
root table keys, which shows that a root table key need not be unconditional.

An ADR records the decision and, more importantly, the alternatives that were
weighed and rejected, so they are not re-proposed: `run-shell`, eliminated by
measurement rather than taste because its command has no tty and fzf cannot run
there; `new-window`, rejected over window renumbering; and an SSH-conditional or
Role-keyed binding, rejected because the existing F12 toggle already covers
nested tmux and SSH-ness is named in the glossary as a wrong proxy.

The ADR also carries the one risk that was not closed. The popup command
requires a tmux new enough to have it. The Desktop machine was measured and is
new enough; the Headless hosts could not be reached at the time of writing, and
on one with an older tmux the binding would fail when the config is sourced.
That is recorded rather than guarded against, in keeping with this repo's
preference for failing loudly over a silent fallback.

The glossary is a glossary: the term goes in without implementation detail, and
the decision, the flags, and the measurements live in the ADR.

**Blocked by:** 01, 02. The ADR describes what actually shipped, including the
removals, so it is written once both are real.

**Status:** ready-for-agent

- [ ] The glossary defines **Root Binding**, with the terms to avoid
- [ ] The definition contrasts it with a prefix binding and with a conditional
      root table key
- [ ] An ADR records the decision, following the numbering and format the
      existing ADRs use
- [ ] The ADR names the rejected alternatives with the reason each was rejected
- [ ] The ADR records the unverified tmux version requirement on Headless
      machines as an open risk
- [ ] No implementation detail leaks into the glossary entry
