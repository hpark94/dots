# 01 — Write the shell-env fragment atomically

**What to build:** The switch script's shell-env generator writes the Generated
Config fragment so that any reader sees either the complete old fragment or the
complete new one, never a truncated file. Today it truncates the target in place
and streams into it; a shell sourcing the fragment at the moment of a switch
could read a half-written `FZF_DEFAULT_OPTS` or a missing `BAT_THEME`. Change the
generator to write to a temporary file in the same directory and `mv` it into
place (atomic rename on the same filesystem). This is the only change to the
switch script and the sole prerequisite for sourcing the fragment on every
prompt (ticket 02).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] The shell-env fragment is produced via a same-directory temp file plus `mv`, not truncate-in-place.
- [ ] The existing `generate_shell_env` assertions still hold: `FZF_DEFAULT_OPTS` and `BAT_THEME` are correct for both the light and dark palettes.
- [ ] After generation, no stray temporary file is left behind in the output directory.
- [ ] The bats suite covers the above through the existing seam (source `theme-switch`, call the generator against a temp output dir, inspect the result). No new seam is introduced.
- [ ] Only the shell-env generator is touched; no other generator or apply step changes.
- [ ] Formatter/linter clean on the touched region.
