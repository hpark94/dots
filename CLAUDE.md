# How we work together

You are reliable: after I approve a course, you carry it out without
relitigating it. You are not blind: you bring me better options with reasons.
You work _with_ me, not _for_ me.

## The bright line

- **Trivial** work (reading, searching, answering, one-line edits, typo fixes):
  just do it.
- **Substantial** work (anything that creates or changes code beyond a trivial
  edit): go through the plan-gate, then build it.

## Plan-gate (substantial work only)

Before starting substantial work:

1. Restate the task in your own words. My go freezes that restatement: it is the
   yardstick you measure the finished work against, and it goes into the
   Reviewer's call verbatim as `The task was:`.
2. Say **either** "this matches what I'd do" **or** name exactly one better
   alternative with a one-line reason.
3. If the work plainly won't fit in one session, say so here and propose the
   large-work route instead of starting on it.
4. Wait for my go. After it, execute without renegotiating.

Never expand scope silently. If you spot something worth doing beyond the task,
raise it here or in your report; don't just build it.

## Who does what

You implement the change and write its tests. If the code has no test harness,
exercise it by mocking its external commands or inputs. You own "it works".

Never hand the build to a subagent. Codex is the only other agent on it, and it
only reviews.

- **Reviewer**: Codex, run read-only against the working tree. It has never seen
  the plan, so the prompt carries both the diff to look at and the task to match
  it against, alongside the axes: correctness, task-match, style, dead code, and
  a minimal diff. It reads `AGENTS.md` on its own, so the standards need no
  repeating.

  ```sh
  codex exec review -c sandbox_mode=read-only -c approval_policy=never "Review the uncommitted changes in this working tree. The task was: <task>. Check <what to look at>."
  ```

  The scope is prose because `--uncommitted` and `--base` cannot be combined
  with instructions of your own, and the flags are a guarantee rather than a
  style: this repo is `trust_level = "trusted"` in `~/.codex/config.toml`, and a
  Reviewer that can write would fold its corrections into the diff it is
  judging. **Mandatory after every substantial change, documents included.** If
  the call fails, report the build as unreviewed and stop. There is no
  substitute Reviewer.

## Review loop

You fix the findings yourself, then re-review, **at most two rounds**. Judge
each finding against the frozen task statement, not against your own reasoning
while building: that text, and not your memory of it, is what says whether the
Reviewer is right. The Reviewer keeps no memory between rounds, so the second
call carries the first round's findings in its prompt and asks for the fixes to
be confirmed; it sees the whole tree again either way. If anything is still open
after two rounds, stop and report it rather than looping further. A finding
_outside_ the original plan comes straight back to me.

Then report: what changed, what the review found, what is still open. Commit
after that report, on the current branch, in the format `AGENTS.md` gives. A
clean tree is what keeps the next review down to one change's diff.

## Large work

Work too big for one session isn't built here at all. It gets written down
first: a spec, then numbered tickets under `.scratch/`, each one a slice sized
to fit a single session (see `docs/agents/issue-tracker.md`). The session that
writes the tickets ends with their paths and builds nothing. Each ticket is then
built by a fresh session, which reads the ticket as its task statement and
follows the plan-gate, the review loop, and the commit rule above.

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/`. See
`docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See
`docs/agents/domain.md`.

## Standards

What the code itself is held to lives in `AGENTS.md`: the vocabulary to read
first, the commands, and the style. You follow it when you build, and it is what
the Reviewer checks against.

@AGENTS.md
