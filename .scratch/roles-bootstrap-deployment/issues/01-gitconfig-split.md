# 01 — `.gitconfig` split (Write-Back Config fix)

**What to build:** `gh auth login`'s credential-helper write, and any future tool write to
`~/.gitconfig`, lands outside the tracked repo instead of dirtying it. Shared git settings still
propagate to every machine when changed, instead of being frozen at whatever an example file said on
the day a machine was first cloned.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] A new tracked, stowed file holds the settings every machine shares today (user identity, core
      settings, default branch, pull behavior).
- [ ] The real `~/.gitconfig` becomes an untracked file containing only an include pointing at that
      tracked file.
- [ ] `.gitconfig.example` is fully removed (already deleted in the working tree; confirm nothing else
      references it, e.g. README or docs).
- [ ] The stow-ignore list gains an entry so a literal `~/.gitconfig` can never be folded back into a
      symlink over the real stub.
- [ ] Manually verified: on a machine with no `~/.gitconfig` at all, sourcing/reading git config after
      the tracked file is stowed and the stub is created by hand once resolves correctly to the shared
      settings.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions →
"`~/.gitconfig` becomes a stub over a tracked shared file." The stub itself gets **written** by
`bootstrap.sh` (a later ticket in this set) — this ticket only needs the tracked shared file and the
stow-ignore guard to exist.
