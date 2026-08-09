# Spec: Already-open shells re-theme live (fzf and bat)

Status: implemented

## Problem Statement

When I switch the Theme Mode, every already-open shell keeps the old fzf and bat
colors until I start a fresh shell. The colors are carried by environment
variables (`FZF_DEFAULT_OPTS`, `BAT_THEME`) that a shell reads once at startup,
so a terminal I opened before the switch shows mismatched fzf pickers and bat
output against a freshly re-themed foot, tmux, and sway. In practice I keep
long-lived shells open (often inside a persistent tmux session), so "just open a
new shell" means re-establishing my working context, which I do not want to do
just to recolor two tools.

## Solution

Already-open shells pick up the new Theme Mode on their own, at the next prompt,
with no action from me and nothing to restart. After a switch, the next `fzf`
picker and the next `bat` invocation in any shell I already had open are themed
to the new mode, exactly as a newly started shell would be. This promotes fzf
and bat from Next-launch to Live-switchable via the Pull route, the same shape
waybar already uses: the shell subscribes to the change itself, and the switch
script contributes no new code to make it happen.

## User Stories

1. As a developer, I want my already-open shell to show fzf in the new Theme
   Mode's colors after I switch, so that my picker matches my newly re-themed
   terminal without opening a new shell.
2. As a developer, I want `bat` output in an already-open shell to use the new
   Theme Mode after I switch, so that paged and previewed files match the rest
   of my session.
3. As a developer, I want the update to happen at the next prompt, so that it
   costs me nothing and I never have to remember to trigger it.
4. As a developer working inside a long-lived tmux session, I want every pane's
   shell to re-theme on its own, so that I do not have to detach, restart, or
   re-establish my working context to recolor fzf and bat.
5. As a developer, I want the re-theme to reach shells that are not inside tmux,
   so that a bare terminal window updates the same way a tmux pane does.
6. As a developer, I want the re-theme to work identically in zsh and bash, so
   that my interactive-shell experience does not depend on which shell I am in.
7. As a developer, I want nothing to be killed or interrupted when I switch, so
   that a running editor, agent, ssh session, or any process in a pane is never
   disturbed by the theme switch.
8. As a developer, I want non-interactive shells (scripts, subshells) to be
   entirely unaffected by the re-theme mechanism, so that no background shell
   can be accidentally signalled or terminated.
9. As a developer, I want the switch script itself to gain no new code for this,
   so that the theming machinery stays as simple as it is today and the shell
   owns its own subscription.
10. As a developer, I want the switch to keep `git status` clean, so that
    re-theming an open shell never produces a tracked diff.
11. As a developer on a Headless machine, I want an already-open SSH shell to
    re-theme at its next prompt when the Desktop pushes a mode, so that my
    remote sessions follow the one global Theme Mode without my restarting them.
12. As a developer, I want a switch that happens while a prompt is being drawn
    to never expose a half-written fragment, so that I never see a broken
    `FZF_DEFAULT_OPTS` or an unset `BAT_THEME` for a prompt.
13. As a developer, I want direnv, mise, and zoxide to keep firing on every
    prompt after this change, so that adding the theme hook does not break the
    other per-prompt integrations I rely on.
14. As a developer, I want the pure prompt to keep working unchanged in zsh, so
    that the theme hook coexists with my existing prompt hooks.
15. As a developer, I want a shell I open before the first switch to still be
    themed correctly at startup, so that the live mechanism does not regress the
    existing next-launch behavior.
16. As a developer opening a brand-new pane or window mid-session, I want it to
    start in the current Theme Mode, so that new and old shells agree.
17. As a maintainer, I want this decision and its trade-offs recorded, so that a
    future reader understands why the shell polls its own fragment instead of
    being signalled.

## Implementation Decisions

- **Route: Pull, not Push.** The interactive shell subscribes to the change and
  re-reads the Generated Config fragment on its own; the switch script is not
  taught to signal shells. This mirrors waybar's Pull integration and matches
  ADR-0003. Push (a `SIGUSR1` trap fanned out by `pkill`) is rejected because
  `SIGUSR1`'s default disposition is to terminate any matched process lacking
  the trap, endangering non-interactive shells and subshells; Pull avoids this
  by construction because the hook exists only in the interactive init files.

- **Trigger: a per-command hook.** zsh registers a `preexec` hook via
  `add-zsh-hook` and a `line-init` widget via `add-zle-hook-widget`; bash sets a
  `DEBUG` trap. Both run a shared `_theme_reload` function that re-sources the
  shell-env fragment _before each command_ rather than on the prompt. Firing on
  the prompt (`precmd`/`PROMPT_COMMAND`) runs after the just-accepted command,
  so the first `bat` or `fzf` right after a switch still saw the old mode (an
  off-by-one); firing before each command removes that lag. The zsh `line-init`
  hook additionally re-themes tools spawned by editor widgets (fzf-tab, Ctrl-R,
  Ctrl-T), since it fires once per prompt line and the fragment `export`s
  propagate to those children. The bash `DEBUG` trap is placed after the
  direnv/mise/zoxide `eval` lines and replaces the earlier `PROMPT_COMMAND`
  append; because it leaves `PROMPT_COMMAND` untouched, those integrations' own
  per-prompt hooks keep firing.

- **Scope: the shell-env fragment only.** The hook re-sources only the generated
  fragment carrying `FZF_DEFAULT_OPTS` and `BAT_THEME`, never the full shell
  init. A full re-source would re-run plugin managers, completion init,
  keybindings, ulimit, and tmux auto-attach, which is out of proportion to
  recoloring two tools.

- **No change-detection gate.** The hook re-sources unconditionally before every
  command. The guarded work is two `export`s reading a two-line file; a gate
  cheap enough to help costs about what it saves, and a `stat`-based gate forks
  a process every command and costs more than the work it guards.

- **Single source of truth for the shell side.** The existing inline
  startup-source line in each interactive init is replaced by defining
  `_theme_reload` once, calling it at startup, and registering it as the
  per-command hook, so startup theming and live re-theming share one definition.

- **Atomic fragment write.** Because the fragment is now sourced before every
  command, the switch script's shell-env generator (`generate_shell_env`) writes
  the fragment atomically: to a temporary file in the same directory, then `mv`
  into place, so a re-source firing mid-switch either reads the complete old
  fragment or the complete new one, never a truncated file. This is the only
  change to the switch script.

- **Cross-role behavior falls out for free.** Because the interactive init files
  are shared across Roles, an already-open SSH shell on a Headless machine
  re-themes at its next command when the Desktop renders a mode via `--render`.
  No Headless-specific code is added.

## Testing Decisions

- **What a good test checks here:** the externally observable content of the
  Generated Config fragment, not how it is produced. Tests assert what a shell
  would read, in the same style as the existing suite, and do not assert
  internal helpers or the exact write sequence.

- **Seam:** the single, existing seam in
  `.local/scripts/tests/theme-switch.bats`, which sources `theme-switch` and
  calls generator functions directly against a temporary output directory, then
  inspects the written file. No new seam is introduced. This is the highest
  available seam for the one change to the switch script.

- **Module under test:** the shell-env generator (`generate_shell_env`). The
  atomic-write change is covered by asserting that after generation the fragment
  is complete and correct (the existing `FZF_DEFAULT_OPTS` / `BAT_THEME`
  assertions continue to hold for both modes) and that no stray temporary file
  is left behind in the output directory.

- **Prior art:** the existing `generate_shell_env` tests for the light and dark
  palettes, and the pattern of the other `generate_*` tests, which call a
  generator against `$BATS_TEST_TMPDIR/out` and match the resulting file.

- **The per-command hook is verified by manual smoke, not automated.** Its body
  is a trivial `[ -f ] && source`; the risk lives in the interactive wiring
  (`add-zsh-hook`, `PROMPT_COMMAND` append), which cannot be exercised without
  standing up a full interactive shell with the plugin stack, and which would
  force extracting the function out of the init files purely to test it. Manual
  smoke: switch the Theme Mode in a live shell, confirm the next `fzf` and `bat`
  are themed and that direnv still fires each prompt, in both zsh and bash. The
  Headless self-re-theme path, if smoke-tested, is exercised on the
  ubuntu-server host per the repo's SSH-testing scope.

## Out of Scope

- Any live re-theme for the remaining Next-launch apps, nvim and GTK. Their
  reload stories are unchanged by this spec. (ghostty was later promoted from
  Next-launch to live-switch via a `SIGUSR2` config reload; see ADR-0004.)
- Re-sourcing the full shell init, aliases, functions, or prompt on a switch.
  Only the shell-env fragment is re-read.
- Auto-following the desktop or OS light/dark preference. Switching stays an
  explicit user action; the shell only learns about a switch the user already
  made, consistent with ADR-0001.
- Any change-detection or debouncing of the per-command re-source.
- Teaching the switch script to enumerate, signal, or otherwise reach out to
  running shells.

## Further Notes

- fzf and bat need no restarting: each re-reads its environment variable at
  launch and is always spawned from the prompt, so refreshing the parent shell's
  environment is sufficient to theme the next invocation. This is why the whole
  feature reduces to "get the running shell to re-source its fragment."
- The interactive init files have no OpenCode twin: the repo's twin-file
  convention mirrors the supervisor-instruction files (`CLAUDE.md` and
  `AGENTS.md`) only, so there is no second copy of the zsh/bash init to keep in
  sync. The same hook is authored once per shell, directly in each init file.
- The decision and its rejected alternative are recorded in
  `docs/adr/0003-shells-pull-theme-via-prompt-hook.md`; the glossary in
  `CONTEXT.md` now lists the shell as a Pull Live-switchable app and no longer
  lists fzf/bat under Next-launch. ADR-0001 carries a pointer to ADR-0003.
