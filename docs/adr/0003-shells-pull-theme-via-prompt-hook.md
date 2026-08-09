# Shells pull the theme via a command hook, making fzf and bat live

ADR-0001 classified fzf and bat as Next-launch apps: they read their theme from
the environment (`FZF_DEFAULT_OPTS`, `BAT_THEME`), which only a newly started
shell inherits, so an already-open shell kept its old colors until replaced. We
promote them to Live-switchable via the **Pull** route, the same shape as
waybar. The interactive shell registers a hook that unconditionally re-sources
the generated `shell-env.sh` fragment _before each command_: zsh via a `preexec`
hook plus a `line-init` ZLE hook so tools spawned by editor widgets (fzf-tab,
Ctrl-R, Ctrl-T) re-theme as well; bash via a `DEBUG` trap. Because fzf and bat
re-read their env var at each launch and are always spawned from the prompt, the
next invocation is themed. `theme-switch` gains no code: it already writes the
fragment.

We re-source before each command rather than on the prompt because a
`precmd`/`PROMPT_COMMAND` hook fires _after_ the just-accepted command, so the
first `bat` or `fzf` run right after a switch was still themed with the old mode
(an off-by-one). Firing before each command removes that lag. One residual
sliver remains: a completion or history widget invoked on the exact command line
already in progress at the moment of the switch re-themes only from the next
prompt line, since `line-init` fired before the switch; closing that would need
a per-keystroke hook, which is out of proportion to the gain.

## Considered Options

**Pull (chosen) over Push (a `SIGUSR1` trap in each rc, fanned out by
`pkill`).** Push carries a footgun: `SIGUSR1`'s default disposition is to
_terminate_ the process, so any shell matched by `pkill` that lacks the trap (a
non-interactive shell running a script, a subshell, anything whose command line
merely contains "zsh"/"bash") is killed outright. Pull structurally avoids this
because the hook exists only in the interactive rc files; non-interactive shells
never carry it, so there is nothing to signal and nothing to kill. Pull also
needs no new coupling from the switch script to the process table and works
outside tmux.

**No change-detection gate.** The guarded work is two `export`s reading a
two-line file. A gate cheap enough to help (an in-process file read) costs about
what it saves; a gate that forks `stat` every command costs more than the work
it guards. Unconditional re-sourcing is simpler and always correct.

## Consequences

- Sourcing the fragment before every command widens the window in which a shell
  could read a half-written fragment during a switch, so `generate_shell_env`
  now writes atomically (temp file plus `mv`) rather than truncate-in-place.
- On a Headless machine, an already-open SSH shell self-re-themes at its next
  command when the Desktop pushes a mode via `--render`, since the shared rc
  carries the same hook.
