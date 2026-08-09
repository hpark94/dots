# 05: README install section

**What to build:** A public user (or the dotfiles owner setting up a new
machine) can read the README and know exactly how to get from nothing to a fully
working machine, in three lines that actually match what `bootstrap.sh` does.

**Blocked by:**
[04: `bootstrap.sh` Theme Mode + fragment generation](04-bootstrap-theme-fragment-generation.md).

**Status:** done

Verified done on `main`. README's `## Installation` section states the
three-step procedure (install `git`/`stow`, clone, run
`bootstrap.sh <desktop|headless>`) and notes bootstrap handles everything else
idempotently. No other install steps implied; the descriptive "Key Highlights"
prose is untouched.

- [x] The README states the complete install procedure in three steps: install
      `git` and `stow`, clone the repo, run `bootstrap.sh <desktop|headless>`.
- [x] No other install steps are implied or required beyond those three,
      everything else happens inside `bootstrap.sh`.
- [x] The rest of the README's existing descriptive content is left untouched.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Solution
and Implementation Decisions → "README shrinks to three lines."
