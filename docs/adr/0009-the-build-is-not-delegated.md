# The build is not delegated

Substantial work here went to a fresh Builder subagent, and the reason given in
`CLAUDE.md` was never context size. It was neutrality: keeping the build out of
the Supervisor's context is what let it judge the review findings against the
plan rather than against its own reasoning. That reason no longer holds. Since
ADR-0008 the Reviewer runs on Codex, outside Claude entirely, so the
independence that matters has moved. What decides whether a finding is right is
not who reads it but what it is measured against, and a text can be that
yardstick as well as a foreign context can. The session that plans now also
builds.

So the plan-gate's first step gets a second job. The restatement of the task is
frozen when I approve it, before any code exists, and it is the same sentence
that goes into `codex exec review` as `The task was:`. Builder and Reviewer used
to receive the plan in two separate prompts written by the same Supervisor; now
one approved sentence serves both the build and the check, which is fewer places
for the task to drift. In large work the ticket file plays that part.

The cost of delegation was real and had nothing to do with judgment. A Builder
subagent cannot ask me anything, so every ambiguity it hits is resolved by
guessing, and I cannot watch it work or stop it halfway. Paying that to protect
a neutrality the external Reviewer already provides is a bad trade.

The context saving the Builder incidentally gave is preserved by moving the
boundary from the subagent to the session. Work too big for one session is
written down as a spec and numbered tickets under `.scratch/`, and each ticket
is built by a fresh session that starts from the ticket. This is the same
boundary, drawn where a human can see it: the artifact survives the session, a
subagent's prompt did not.

Two lanes, then, and the light one is the default. The heavy one is described by
its artifacts rather than by the skills that usually produce them, because
`/to-spec` and `/to-tickets` live in `~/.agents/skills/`, which is under no
version control and absent from a freshly bootstrapped machine.
`docs/agents/issue-tracker.md` is in the repo and can be followed by hand.

The optional Tester subagent goes with the Builder. It was a Claude checking
Claude's work, which is the arrangement ADR-0008 removed from the Reviewer for
being no check at all.

Considered and rejected: keeping the Builder purely to spend less context. The
session boundary saves the same context without cutting the channel back to me,
and it saves it at a point where the work is written down.

Considered and rejected: routing every substantial change through spec and
tickets. The last ten commits landed through the plan-gate with no spec at all,
so making the pipeline mandatory would tax every two-file bugfix for a structure
that only pays off across sessions.

ADR-0008 stands unchanged, including its line that Codex is never the Supervisor
and never the Builder. Both roles are gone from `CLAUDE.md`, which leaves that
sentence pointing at nothing, and it stays anyway: an ADR records what was
decided when it was decided, and editing it later to match the present would
cost the series the one property that makes it worth keeping.
