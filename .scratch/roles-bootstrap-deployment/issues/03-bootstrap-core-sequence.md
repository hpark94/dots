# 03 — `bootstrap.sh` core sequence

**What to build:** Running one script with one argument takes a machine from a bare `git clone` to a
fully built toolchain: `stow` succeeds even on a fresh Fedora `$HOME`, the Role Marker and a
`~/.gitconfig` stub exist, `mise` and everything it manages is installed, and every tmux plugin
(including `tpm` itself, never cloned by anything today) and nvim plugin is actually installed rather
than waiting on first interactive use. The whole script is safe to re-run on a machine that's already
fully set up, and safe to run against a machine that already has the dotfiles deployed by hand with no
Marker and no state at all.

**Blocked by:** [01 — `.gitconfig` split](01-gitconfig-split.md) — the gitconfig stub this script
writes is only meaningful once the tracked shared file it includes actually exists.

**Status:** done

Verified done on `main`. The core sequence landed in `05e0d03`; the `bat cache --build` step (10b) was the one remaining gap from this ticket's owner comment below and is now wired in. All guard/sequencing logic is covered by `.local/scripts/tests/bootstrap.bats` (17 tests, green under `bats 1.13.0`). The two "manually verified" boxes need a genuinely fresh machine / live retrofit and are left for a real bring-up (per this repo's convention, ubuntu-server for the remote case); they are not exercisable in this sandbox and match the same limitation the testing decisions already named.

- [x] The script takes exactly one required argument, `desktop` or `headless`; anything else (missing,
      misspelled, extra) is a hard usage error naming the valid values.
- [x] Opens with strict mode, a `usage()` function, and reports errors with a consistent prefix and a
      non-zero exit, matching the conventions already established for other scripts in this repo.
- [x] The shared XDG container directories are created as real directories before `stow` runs, if they
      don't already exist as real directories.
- [x] Any fresh-machine shell startup file that would collide with `stow` is backed up out of the way
      first, but only if it's a real file and not already a symlink into the repo — idempotent on
      re-run.
- [x] Runs `stow` for the whole package; a no-op on a machine that's already stowed.
- [x] The Role Marker is left untouched if it already exists; otherwise it's written from the required
      argument.
- [x] The `~/.gitconfig` stub is written only if absent; an existing one (including one a tool has
      since appended to) is never overwritten.
- [x] `mise` is installed only if its binary isn't already present, and is activated within the
      script's own process so every following step sees the pinned toolchain.
- [x] `mise install` runs, preceded by a warning that the first run can take a while.
- [x] `tpm` is cloned only if missing, followed by its plugin-install step, every run.
- [x] nvim's plugin manager is run to completion non-interactively, and zinit's self-install is
      triggered the same way, every run (both are safe to re-run upstream).
- [x] `bat cache --build` runs every run, so bat registers the tracked custom themes (`hp_dark` /
      `hp_light` under `.config/bat/themes/`) instead of warning `Unknown theme 'hp_dark', using
      default` and falling back to a built-in theme. Without this, `--theme-dark`/`--theme-light` in the
      stowed bat config point at themes bat has never cached, so a freshly deployed machine (Desktop or
      Headless) never renders the intended bat colors until a manual cache build. Safe and idempotent to
      re-run, same as the tpm/nvim/zinit steps.
- [ ] Manually verified: running the script twice in a row on the same machine produces no errors and
      no unwanted changes on the second run. (Pending a live bring-up; not exercisable in-sandbox.)
- [ ] Manually verified against a machine simulating the "already deployed, no Marker, no state" case:
      the script brings it fully up to date without disturbing anything already working. (Pending a live
      retrofit run.)
- [x] A bats file covers the script's guard and sequencing logic (directory pre-creation, skel-file
      backup, Role Marker write-or-skip and its error case, gitconfig stub write-or-skip, `mise`/`tpm`
      presence checks) against a faked `$HOME`/`$XDG_*` tree, following the same pattern established for
      other scripts in this repo. The actual `mise install`, its installer's `curl | sh`, the nvim
      plugin sync, `tpm`'s install step, and `bat cache --build` get no bats coverage: there's no
      throwaway machine in this loop to run them against safely.

**Further Notes:** See `.scratch/roles-bootstrap-deployment/spec.md`, Implementation Decisions → "The
ordered sequence" (steps 1-10b; step 11, Theme Mode and fragment generation, is a separate ticket).

## Comments

**2026-07-26 (owner):** Discovered on a freshly cloned Headless host (ubuntu-server): `bat` emitted `[bat warning]: Unknown theme 'hp_dark', using default.` because bootstrap never runs `bat cache --build`, so the tracked `hp_dark`/`hp_light` themes are not registered on a fresh machine. Worked around manually with `bat cache --build`. Captured here as a bootstrap requirement so it is not lost.
