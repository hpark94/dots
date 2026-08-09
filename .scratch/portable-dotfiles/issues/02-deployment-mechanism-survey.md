# 02 Deployment mechanism survey

**Type:** `research` (AFK, resolved by a `/research` subagent)

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

What are the actual capabilities and costs of the candidate mechanisms for
deploying a role-split dotfiles repo?

**Facts only. This ticket does not choose.** The choice is
[Choose the deployment mechanism](05-choose-deployment-mechanism.md), which this
unblocks.

### Candidates

- GNU stow with multiple packages (the incumbent: `.stow-local-ignore` exists,
  though no install procedure is documented anywhere and `README.md` has no
  install section)
- chezmoi
- yadm
- bare git repo with `--git-dir`/`--work-tree` and a shell alias
- a hand-rolled bootstrap script

### For each, establish

1. **Templating.** Can one tracked file produce different content per machine?
   What is the template language, and what does it cost to read a year later?
2. **Conditionals.** Can a file be deployed or skipped based on a machine
   attribute (hostname, role, presence of Wayland, SSH-ness)? Stow is called out
   explicitly here because it can do neither templating nor conditionals;
   confirm that, and confirm whether multiple packages plus selective
   `stow <pkg>` is the full extent of its answer.
3. **Machine-local state and secrets.** How does each handle a file that must
   exist but must not be tracked? The repo already has a `.gitconfig.example`
   convention for this.
4. **Bootstrap cost on a fresh headless remote.** What must already be installed
   before the tool itself can run? Is it in Fedora and Debian/Ubuntu repos, does
   it need a compiler, can it be a single static binary curl'd in, and can
   `mise` install it (mise is already the toolchain manager here)?
5. **Update and drift.** What does pulling a change look like on a machine that
   already has the repo deployed, and what happens to files that were edited in
   place?

### Constraints to hold

Targets are the Fedora/sway host and headless Linux SSH remotes. No macOS, no
containers, no remotes without root or package install. Do not evaluate against
those.

## Findings

[research/02-deployment-mechanisms.md](../research/02-deployment-mechanisms.md),
written by a `/research` subagent fired during the charting session. 783 lines,
all five candidates against all five dimensions, with an appendix of executed
Stow behavior.

## Answer

Surveyed. No candidate is disqualified by this map's constraints, so
[Choose the deployment mechanism](05-choose-deployment-mechanism.md) has a real
choice to make. The four findings that should drive it:

1. **Stow cannot template or conditionalize, confirmed structurally rather than
   by omission.** Zero matches for `templat|conditional|hostname|interpolat|{{`
   across the complete GNU Stow 2.4.1 info manual and the complete
   implementation. A symlink has no content, so this is not a missing feature.
   Selective `stow <pkg>` is the only file-set-selection lever, plus per-machine
   `--ignore` lines in an untracked `~/.stowrc`, which can subtract files but
   cannot select packages.
2. **Symlink deployment and per-machine content are mutually exclusive by
   construction.** Stow, yadm and bare git deploy real files or symlinks, so
   drift is impossible (verified: editing a stowed file writes through to the
   repo working tree). chezmoi deploys copies, which is what buys templating and
   is exactly what creates drift, hence `chezmoi status` and `re-add` existing
   at all. The two properties trade off directly and cannot both be had for the
   same file.
3. **The sharpest practical obstacle is Stow versus `/etc/skel`.** Executed
   against a scratch tree: a pre-existing real file at the target aborts the
   entire invocation (`All operations aborted`), filesystem unmodified. A fresh
   Fedora `$HOME` ships `.bashrc`, `.bash_profile`, `.bash_logout`, `.zshrc`,
   `.zprofile`. So the first `stow` on any fresh remote fails today, and no
   pre-step is documented anywhere. Milder for yadm and bare git (initial
   checkout only), absent for chezmoi.
4. **Packaging is a near-inversion between the two managed tools.** chezmoi is
   in official Fedora (2.70.5) but Debian sid only; yadm is in all Debian suites
   but not official Fedora. Both recoverable via single-file download, so
   neither is a blocker. Of the two, only chezmoi is in mise's registry
   (`aqua:twpayne/chezmoi`), and mise itself is not in official Fedora either,
   so "mise installs it" still bottoms out at a curl pipe with one extra hop.

**Carried to other tickets** (see the Decisions-so-far entry on the map): the
SSH-ness finding went to [Name the split](01-name-the-split.md); the `/etc/skel`
collision and a tpm bootstrap gap went to the map's Bootstrap sequence fog
patch.

**Known limit, flagged by the research agent:** only Stow was executed. chezmoi
and yadm are documented rather than run, since neither is installed here. If
anything load-bearing rests on their behavior, prototype it before
[ticket 05](05-choose-deployment-mechanism.md) closes.
