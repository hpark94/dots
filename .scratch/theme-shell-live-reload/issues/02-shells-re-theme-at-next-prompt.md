# 02: Already-open shells re-theme at the next prompt

**What to build:** An already-open shell picks up a Theme Mode change on its
own, at its next prompt, with nothing to restart. After a switch, the next `fzf`
picker and the next `bat` invocation in any shell I already had open are themed
to the new mode. This is the Pull route from ADR-0003: the interactive shell
subscribes to the change itself; the switch script gains no code.

Replace the inline startup-source line in each interactive init with a single
`_theme_reload` function that re-sources only the shell-env fragment. Call it
once at startup (preserving today's startup theming) and register it to run
before each command: zsh via `add-zsh-hook preexec` plus an
`add-zle-hook-widget line-init` hook (so tools spawned by editor widgets like
fzf-tab re-theme too); bash via an interactive-only `DEBUG` trap after the
direnv/mise/zoxide `eval` lines, leaving `PROMPT_COMMAND` untouched. Firing
before each command rather than on the prompt avoids an off-by-one where the
first `fzf`/`bat` after a switch still saw the old mode (see ADR-0003). The
re-source is unconditional (no change-detection gate). The init files have no
OpenCode twin (the twin convention covers `CLAUDE.md`/`AGENTS.md` only), so the
hook is authored once per shell directly in each init file.

**Blocked by:** 01, the fragment must be written atomically before it is sourced
on every prompt.

**Status:** implemented

- [ ] After a switch, the next `fzf` in an already-open shell shows the new
      Theme Mode's colors, in both zsh and bash.
- [ ] After a switch, the next `bat` invocation in an already-open shell uses
      the new Theme Mode, in both zsh and bash.
- [ ] The update happens at the next prompt with no manual trigger.
- [ ] It works for shells inside a tmux pane and for a bare terminal outside
      tmux.
- [ ] direnv, mise, and zoxide still fire on every prompt after the change; the
      pure prompt still works in zsh.
- [ ] Nothing is signalled or killed by a switch; non-interactive shells and
      subshells are unaffected (the hook lives only in the interactive inits).
- [ ] A shell opened before the first switch is still themed correctly at
      startup, and a brand-new pane/window starts in the current Theme Mode.
- [ ] The startup-source line is replaced by one shared `_theme_reload`
      definition; only the shell-env fragment is re-sourced, never the full
      init.
- [ ] Verified by manual smoke (switch in a live shell, confirm fzf/bat re-theme
      and direnv still fires, in zsh and bash). The Headless SSH self-re-theme
      path, if smoke-tested, is exercised on the ubuntu-server host per the
      SSH-testing scope.
- [ ] Formatter/linter clean on the touched regions.
