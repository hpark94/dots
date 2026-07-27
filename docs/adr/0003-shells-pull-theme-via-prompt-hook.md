# Shells pull the theme via a prompt hook, making fzf and bat live

ADR-0001 classified fzf and bat as Next-launch apps: they read their theme from
the environment (`FZF_DEFAULT_OPTS`, `BAT_THEME`), which only a newly started
shell inherits, so an already-open shell kept its old colors until replaced. We
promote them to Live-switchable via the **Pull** route, the same shape as
waybar. The interactive shell registers a `precmd` (zsh) / `PROMPT_COMMAND`
(bash) hook that unconditionally re-sources the generated `shell-env.sh`
fragment on every prompt. Because fzf and bat re-read their env var at each
launch and are always spawned from the prompt, the next invocation is themed.
`theme-switch` gains no code: it already writes the fragment.

## Considered Options

**Pull (chosen) over Push (a `SIGUSR1` trap in each rc, fanned out by
`pkill`).** Push carries a footgun: `SIGUSR1`'s default disposition is to
*terminate* the process, so any shell matched by `pkill` that lacks the trap (a
non-interactive shell running a script, a subshell, anything whose command line
merely contains "zsh"/"bash") is killed outright. Pull structurally avoids this
because the hook exists only in the interactive rc files; non-interactive shells
never carry it, so there is nothing to signal and nothing to kill. Pull also
needs no new coupling from the switch script to the process table and works
outside tmux.

**No change-detection gate.** The guarded work is two `export`s reading a
two-line file. A gate cheap enough to help (an in-process file read) costs about
what it saves; a gate that forks `stat` every prompt costs more than the work it
guards. Unconditional re-sourcing is simpler and always correct.

## Consequences

- Sourcing the fragment on every prompt widens the window in which a prompt
  could read a half-written fragment during a switch, so `generate_shell_env`
  now writes atomically (temp file plus `mv`) rather than truncate-in-place.
- On a Headless machine, an already-open SSH shell self-re-themes at its next
  prompt when the Desktop pushes a mode via `--render`, since the shared rc
  carries the same hook.
