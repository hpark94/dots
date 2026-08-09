---
status: superseded by ADR-0005
---

# Two agent instruction templates, split by model strength

One generic starting-point instruction file has to serve both Claude Code
(strong) and OpenCode running smaller models like Mistral, Qwen, GPT-OSS, and
Devstral (weak, high variance between sessions). A single file cannot serve both
well: written to the weak models' needs (terse, imperative, heavily scripted) it
wastes Claude, and written for Claude (principles, judgment) it lets the weak
models drift.

We ship two templates that share one operating model in two registers, under
`templates/`. `CLAUDE.md` (Claude Code reads it) states the model as principles
and defaults. `AGENTS.md` (OpenCode reads it) states the same model as a
numbered checklist with fill-in-the-blank subagent prompts. Both carry the same
Supervisor role, the same trivial/substantial bright line, the same plan-gate,
the same Builder and Reviewer roles, the same bounded two-round review loop, and
the same style rules. The tools partition themselves, so no guard instruction is
needed: Claude Code never reads `AGENTS.md`, and OpenCode uses `AGENTS.md` in
preference to `CLAUDE.md` when both are present.

Because the two files duplicate one operating model, any change to a shared
element (the Supervisor role, the bright line, the plan-gate, the Builder and
Reviewer roles, the review loop, or the style and commit rules) must land in
both files in the same change, each in its own register. When only one is
updated the twins drift and silently disagree, which is the exact failure this
split is meant to avoid.

Both templates use a real, separate subagent for the Reviewer even on weak
models. This is deliberate: a weak model reviewing its own output in the same
context rubber-stamps it, so fresh-context isolation matters more for weak
models, not less. That isolation is the whole reason a separate Reviewer exists.

Considered and rejected: a single file written to the weakest common
denominator. It would have made every Claude session pay for the scripting the
weak models need, and Claude is the primary driver here, with the others used
only as backup and for testing.
