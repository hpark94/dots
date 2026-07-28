# 08 — delta-auto: width-adaptive side-by-side pager

**Status:** done

Built and reviewed on `main`. `.local/scripts/delta-auto` added (side-by-side at
>= 100 cols, else unified, args passed through, `exec delta`); `core.pager =
delta-auto` in `.gitconfig.shared`; lazygit left unified via its own pager.
Reviewer APPROVE; the one low-severity gap it noted (non-numeric width untested)
was closed with a 7th test. bats 7/7 for delta-auto, full suite green, shellcheck
clean.

## Problem

delta has no native "side-by-side only when wide enough" option. In a full-width
terminal side-by-side is nice; in a narrow one it wraps badly, so unified is
better. We want the split to switch on automatically at a width threshold.

## What to build

1. **`.local/scripts/delta-auto`**: a small pager wrapper that enables
   `--side-by-side` only when the terminal is at least **100** columns wide, and
   delegates to plain `delta` otherwise. It must pass through any extra arguments
   (`"$@"`) so callers like lazygit can still add flags, and `exec` delta so it
   adds no process overhead.
   - Width source: `tput cols` (as a git pager, stdout is the terminal, so this
     reports the real width). Fall back to `$COLUMNS`; a missing or non-numeric
     value falls through to unified (the safe default).
   - Guard the arithmetic so `set -euo pipefail` does not abort on a false
     comparison (use it inside an `if`, not as a bare `(( ))` statement).
   - Match the style of the existing scripts in `.local/scripts/` (bash shebang,
     `set -euo pipefail`, a short *why* header comment). Make it executable.

2. **`.gitconfig.shared`**: change `core.pager = delta` to `core.pager =
   delta-auto` (resolves via PATH; `~/.local/scripts` is on PATH). Leave the
   lazygit pager alone: lazygit uses its own `git.paging.pager` (`delta
   --paging=never`), not `core.pager`, so it stays unified by design.

3. **`.local/scripts/tests/delta-auto.bats`**: test the threshold behavior by
   stubbing `tput` and `delta` on PATH and running the script end to end:
   - width >= 100 (e.g. 120) -> delta invoked WITH `--side-by-side`.
   - width < 100 (e.g. 80) -> delta invoked WITHOUT `--side-by-side`.
   - width exactly 100 -> side-by-side (boundary is inclusive).
   - `tput` failing but `COLUMNS=120` set -> side-by-side (fallback path).
   - non-numeric / unavailable width -> unified (safe default).
   - extra args are passed through to delta (e.g. run `delta-auto --paging=never`
     and assert `--paging=never` reaches the delta stub).
   Follow the existing bats conventions in `.local/scripts/tests/` (e.g.
   `fy.bats`, `theme-switch.bats`): a `setup()` that puts a stub dir first on
   PATH; the `delta` stub echoes its args so assertions can substring-match.

## Acceptance

- [ ] `delta-auto` adds `--side-by-side` at >= 100 cols, omits it below, is
      inclusive at exactly 100, and falls through to unified on unknown width.
- [ ] Extra args pass through to delta.
- [ ] `core.pager = delta-auto` in `.gitconfig.shared`; lazygit pager unchanged.
- [ ] `bats .local/scripts/tests/delta-auto.bats` passes; `shellcheck
      .local/scripts/delta-auto` is clean.

## Notes / out of scope

- The width trick is reliable for the terminal `git` pager (stdout is a tty). It
  is deliberately NOT used inside lazygit, where the pager's stdout is a pipe and
  the relevant width is only the narrow diff panel. lazygit stays explicitly
  unified via its own pager string.
- A delta upgrade does not change wrapper behavior unless delta removes/renames
  `--side-by-side` or breaks its output (a real breaking change).
