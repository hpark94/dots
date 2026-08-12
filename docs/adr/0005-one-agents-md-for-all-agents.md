---
status: superseded by ADR-0008
---

# One AGENTS.md for all agents

Claude Code, OpenCode on Mistral Medium 3.5, and Codex now share one instruction
file. ADR-0002 split it into two registers by model strength; keeping the twins
in sync cost more than the drift it prevented, and the `templates/` directory it
describes is gone since 2b5ed6b. `AGENTS.md` carries the principle register,
because the weaker models are tested against it rather than pre-scripted for.

Claude Code 2.1.220 does not discover `AGENTS.md`: its project-doc lookup is
hardcoded to `CLAUDE.md` and `CLAUDE.local.md`, and no setting changes that. So
`CLAUDE.md` survives as a two-line `@`-import stub rather than a second source
of truth.

Consequence: if the weak models drift, the fix is to sharpen the passage that
failed, not to reintroduce a second file.
