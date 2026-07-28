# 01: `.gitconfig` split (Write-Back Config fix)

**What to build:** `gh auth login`'s credential-helper write, and any future tool write to
`~/.gitconfig`, lands outside the tracked repo instead of dirtying it. Shared git settings still
propagate to every machine when changed, instead of being frozen at whatever an example file said on
the day a machine was first cloned.

**Blocked by:** None, can start immediately.

**Status:** done

Verified done on `main` (landed in `05e0d03`). `.gitconfig.shared` is tracked and stows normally; the `~/.gitconfig` stub is written by `bootstrap.sh`'s `write_gitconfig_stub` (create-if-absent, covered by bats). `.gitconfig.example` is gone from the working tree, and README/active docs reference it nowhere (only historical `.scratch/portable-dotfiles` planning notes still mention it, which is expected). `.stow-local-ignore` has the `^/\.gitconfig$` guard. The manual "no `~/.gitconfig` at all resolves to shared settings" box needs a live machine and is left for a real bring-up.

- [x] A new tracked, stowed file holds the settings every machine shares today (user identity, core
      settings, default branch, pull behavior).
- [x] The real `~/.gitconfig` becomes an untracked file containing only an include pointing at that
      tracked file. (Written by `bootstrap.sh`; `.gitconfig` is untracked in the repo.)
- [x] `.gitconfig.example` is fully removed (already deleted in the working tree; confirm nothing else
      references it, e.g. README or docs).
- [x] The stow-ignore list gains an entry so a literal `~/.gitconfig` can never be folded back into a
      symlink over the real stub.
- [ ] Manually verified: on a machine with no `~/.gitconfig` at all, sourcing/reading git config after
      the tracked file is stowed and the stub is created by hand once resolves correctly to the shared
      settings. (Pending a live bring-up.)

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions →
"`~/.gitconfig` becomes a stub over a tracked shared file." The stub itself gets **written** by
`bootstrap.sh` (a later ticket in this set), this ticket only needs the tracked shared file and the
stow-ignore guard to exist.
