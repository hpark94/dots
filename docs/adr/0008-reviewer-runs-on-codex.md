# The Reviewer runs on Codex, and the instructions split by audience

Every role here ran on Claude, so the Reviewer's independence was a fresh
context window and nothing else: same model, same training, same blind spots as
the Builder it was checking. Codex 0.147.0 ships `codex exec review`, a
non-interactive reviewer whose own system prompt casts it as "a reviewer for a
proposed code change made by another engineer" and which reports findings as
file-and-line comments. The Reviewer now runs there, and only there. Codex is
never the Supervisor and never the Builder.

`CLAUDE.md` spells the call out verbatim, flags included:
`-c sandbox_mode=read-only -c approval_policy=never`. That is a guarantee rather
than a style, which is why it earns a code block in a file that otherwise states
principles. `~/.codex/config.toml` marks this repo `trust_level = "trusted"`,
relaxing exactly the defaults that keep an agent from writing, and
`codex exec review` has no `-s` flag of its own, unlike `codex exec`. A Reviewer
able to write would fold its own corrections into the uncommitted diff it is
judging, leaving the second round to review its own work.

The instructions split along the audience at the same time. One file cannot open
with "You are the Supervisor for this project" and also brief the agent called
in afterwards to check the work. `CLAUDE.md` now carries how we work together;
`AGENTS.md` carries what the code is held to. No guard instruction is needed,
because Codex's project-document lookup knows only `AGENTS.override.md` and
`AGENTS.md`, so `CLAUDE.md` never reaches it as instructions. The review prompt
reaches for those same files by name, which is how this repo's standards get to
the Reviewer without being pasted into every call.

The scope of the review is stated in prose rather than by flag, which looks like
the long way round until you try the short one. `--uncommitted`, `--base` and
`--commit` are the three ways `codex exec review` picks a diff, and each is
mutually exclusive with instructions of your own: passing both fails with "the
argument '--uncommitted' cannot be used with '[PROMPT]'". Since the Reviewer is
the only one checking task-match and has never seen the plan, the instructions
are what it cannot do without, so the diff gets named in the same sentence as
the task.

This is not a return to ADR-0002. That split put one content into two registers,
one per model strength, and the twins drifted because every shared rule had to
land in both. This one divides disjoint content between two readers: there is no
second copy of anything, so there is nothing to keep in sync.

It supersedes ADR-0005, on both of that decision's legs. The register argument
rested on weak models being tested against the file, and OpenCode is no longer
used here. The discovery claim, that Claude Code's project-doc lookup is
hardcoded to `CLAUDE.md` and `CLAUDE.local.md`, no longer holds either: 2.1.226
hardcodes `AGENTS.md` alongside them. `CLAUDE.md` keeps its explicit
`@AGENTS.md` import regardless, since six patch releases were enough to
invalidate that claim once.

Considered and rejected: reaching Codex through `codex mcp-server`, which is
configured and works. It would be the better channel if it could carry a review.
Findings would come back as data rather than as terminal output, `codex-reply`
would let the second round continue the first one's thread, and the sandbox
would be a typed parameter instead of a `-c` override. It cannot. The server
exposes exactly two tools, `codex` and `codex-reply`, and both start an ordinary
session, while review is its own task type with its own session mode, prompt
modules and finding events. `base-instructions` could paste the words of a
review prompt into a generic session but not the machinery behind it, and it
would vendor someone else's prompt into this repo to age there. So the shell it
is, and the price is a Reviewer that starts cold each round. Revisit this the
day `codex mcp-server` exposes the review task; nothing else about the decision
would have to change.

Considered and rejected: falling back to a fresh Claude subagent when Codex is
unreachable. It puts a second possible Reviewer back into instructions that just
got down to one, and it degrades at precisely the moment the check matters. The
Supervisor stops and reports the build as unreviewed instead. The price is real
and is the point: `codex login` is interactive, so `bootstrap.sh` cannot provide
it, and a freshly bootstrapped machine has the binary from
`.config/mise/config.toml` but cannot finish substantial work until a human
signs in.
