# 07 — delta syntax-theme follows the Theme Mode

**Status:** done

Built and reviewed on `main`. `generate_delta` added and wired into `render()`;
`.gitconfig.shared` includes the fragment; two `generate_delta` unit tests plus
the extended `--render` assertion pass (bats 61/61, shellcheck clean). Verified
end to end on this machine: delta resolves `hp_light` via the include, the
`Unknown theme 'light'` warning is gone, and regenerating the fragment for
`dark` flips delta to `hp_dark`.

### Follow-up (same session)

The initial local activation edited the untracked `dots/.gitconfig` in place. That
has since been superseded by finishing the gitconfig split on this machine, which
the theme include was always meant to ride on:

- This machine's stale `~/.gitconfig` symlink (`-> dots/.gitconfig`, the full
  pre-split config) is replaced by the real untracked stub `[include] path =
  ~/.gitconfig.shared`, matching `bootstrap.sh`'s `write_gitconfig_stub`. The old
  full config was migrated into the tracked `.gitconfig.shared` (`core.pager`,
  `interactive.diffFilter`, `delta.navigate`, `merge.conflictStyle`; the delta
  theme `[include]` was already there) and the orphaned `dots/.gitconfig` deleted.
  A backup sits at `~/.gitconfig.presplit.bak`. delta now resolves through the
  chain stub -> `~/.gitconfig.shared` -> `~/.local/state/theme/delta.gitconfig`.
- `delta.line-numbers = true` enabled in `.gitconfig.shared` (side-by-side was
  tried and reverted; kept unified with line numbers).
- lazygit wired to delta via a `git.paging` block (`pager: delta --paging=never`)
  in `.config/lazygit/config.yml`; it inherits delta's git-config settings (theme,
  navigate, side-by-side) and so live-switches with the Theme Mode too.

## Problem

`git diff` (paged through delta, installed via mise) prints:

```
[bat warning]: Unknown theme 'light', using default.
```

and renders diffs with delta's default theme instead of `hp_light`/`hp_dark`.

Root cause: the shell-env fragment exports `BAT_THEME=light` (or `dark`). Those
are **bat-only aliases** that bat 0.26 resolves via `~/.config/bat/config`'s
`--theme-light="hp_light"` / `--theme-dark="hp_dark"`. delta also reads
`BAT_THEME` but implements neither the `light`/`dark` alias nor bat's
`--theme-*` config, so it looks for a theme literally named `light`, fails, and
falls back to its default. delta *does* have the `hp_light`/`hp_dark` themes
available (`delta --list-syntax-themes` lists them); it just needs the resolved
name.

delta is a **next-launch** app in the ADR-0001 sense: it is spawned fresh per
`git` invocation and reads git config each time, so a regenerated fragment
themes the next diff with no signal or apply step.

## What to build

1. **`generate_delta`** in `.local/scripts/theme-switch`: write
   `$out_dir/delta.gitconfig` containing a `[delta]` section that sets
   `syntax-theme = hp_<mode>`. Wire it into `render()` alongside the other
   `generate_*` calls. Follow the shape and comment style of the existing
   generators (e.g. `generate_ghostty`), including a short *why* comment noting
   that delta does not understand bat's `BAT_THEME` aliases.

2. **`.gitconfig.shared`**: add an `[include]` of
   `~/.local/state/theme/delta.gitconfig`. git expands the leading `~`, silently
   ignores the file when absent (so machines without delta or before the first
   switch are unaffected), and `syntax-theme` is inert where delta is not the
   pager. delta's `syntax-theme` from the included fragment wins over the
   `BAT_THEME` env fallback, which silences the warning.

3. **Tests** in `.local/scripts/tests/theme-switch.bats`:
   - `generate_delta` writes `syntax-theme = hp_light` for light and
     `hp_dark` for dark (two tests, mirroring the `generate_ghostty` pair).
   - Extend the `--render` pipeline test to assert
     `$XDG_STATE_HOME/theme/delta.gitconfig` exists.

## Acceptance

- [ ] `generate_delta <mode> <dir>` writes `delta.gitconfig` with the
      mode-appropriate `hp_light`/`hp_dark` syntax-theme.
- [ ] `render()` produces `delta.gitconfig` in the theme state dir.
- [ ] `.gitconfig.shared` includes the fragment path.
- [ ] bats suite passes (`bats .local/scripts/tests/theme-switch.bats`).

## Out of scope / notes

- This machine's `~/.gitconfig` predates the gitconfig split
  (`.scratch/roles-bootstrap-deployment/issues/01`): it is the full pre-split
  config and does **not** `[include]` the tracked `.gitconfig.shared`, and it
  currently hardcodes `[delta] syntax-theme = hp_light`. So the tracked change
  above does not take effect here until that untracked file is activated: drop
  the static `syntax-theme` line and add the same `[include]`. Done as a manual
  local step after the repo change, not part of this ticket's diff.
- Migrating delta's other settings (`core.pager`, `navigate`) from the untracked
  `~/.gitconfig` into `.gitconfig.shared` is a separate concern, left alone.
