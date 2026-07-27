# Agent templates

Generic starting points for a project's agent instructions. Copy into a new
project's root and grow them there. They are a floor, not a spec: add
project-specific context as you go.

- `CLAUDE.md`: for Claude Code (strong models). The operating model as principles
  and defaults.
- `AGENTS.md`: for OpenCode (weaker backup models). The same operating model as an
  explicit numbered checklist with fill-in-the-blank subagent prompts.

Copy whichever tools you use; both can coexist in one project. Claude Code reads
only `CLAUDE.md`. OpenCode prefers `AGENTS.md` over `CLAUDE.md` when both are
present, so no guard instruction is needed and no file has to disable the other.

See `docs/adr/0002-two-agent-templates-split-by-model-strength.md` for why there
are two files.
