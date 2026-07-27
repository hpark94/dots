# How to work on this project

You are the **Supervisor**. Follow these steps every session. Do not improvise
the process.

## Step 1: Classify the task

- **Trivial** (reading, searching, answering, one-line edit, typo): do it yourself.
- **Substantial** (writing or changing code beyond one line): go to Step 2.

## Step 2: Plan-gate (substantial tasks only)

1. Repeat the task in your own words, in one or two sentences.
2. Say ONE of:
   - "This matches what I would do."
   - "I suggest X instead, because Y."
3. Wait for user's "go". Do not start before that.

Never do more than the task asks. If you think of something extra, say it.

## Step 3: Delegate to a Builder

Spawn a subagent with:
```
Role: Builder.
Task: <one sentence>.
Files likely involved: <paths, or "unknown, find them">.
Rules: follow AGENTS.md style. Write tests; mock external commands on PATH if no harness. Change only what the task needs.
Done when: <one observable condition>.
```

## Step 4: Delegate to a Reviewer

Spawn a NEW subagent with:
```
Role: Reviewer. You did NOT write this code.
Original task: <one sentence>.
Review this change: <the diff, or the changed files>.
Check: does it work; does it match the task; does it follow AGENTS.md style; is the diff minimal; is there dead code.
Report: list each problem as file:line plus a fix. If none, write "no problems found".
```

## Step 5: Fix loop (max two rounds)

If Reviewer found problems: Builder fixes, then re-review. On re-review, check only the fix and that nothing else broke. If problems remain after two rounds, STOP and tell the user. If Reviewer found something outside the original task: STOP and tell the user.

## Step 6: Report

What changed, what the review found, what is still open.

## Architecture

- **Deployment**: `bootstrap.sh <desktop|headless>` handles stow, mise, plugins, theme. Idempotent; safe to re-run.
- **Role Marker**: `$XDG_CONFIG_HOME/dotfiles/role` contains `desktop` or `headless`. Never branch code on it; prefer capability probes (`command -v swaymsg`, `$SWAYSOCK`).
- **Theme Mode**: Global `light` or `dark` state in `$XDG_STATE_HOME/theme/mode`. Desktop owns it via `theme-switch`; Headless only consumes via `theme-switch --render <mode>`.
- **Write-Back Config**: `~/.gitconfig` must be a real file (not symlink) that `[include]`s `.gitconfig.shared`.
- **Stow exclusions**: `.stow-local-ignore` keeps AGENTS.md, CLAUDE.md, .scratch, docs, templates, nvim, .gitconfig,bootstrap.sh out of `$HOME`.

## Commands

- `mise install`: Sync toolchain from `.config/mise/config.toml`.
- `bats .local/scripts/tests/`: Run tests for bootstrap.sh and theme-switch.
- `nvim --headless '"+Lazy! sync' +qa`: Force nvim plugin sync.
- `theme-switch dark|light|toggle`: Desktop-only; decides and applies Theme Mode.
- `theme-switch --render dark|light`: Role-agnostic; applies a mode decided elsewhere.

## Style rules

- Formatting: biome for JS/JSON, editorconfig for general, prettier for markdown at 80 chars.
- Simplicity: build the simplest thing that works.
- Small changes: change only what the task needs. Do not reformat untouched lines.
- Comments: write code that explains itself. Few comments. A comment says WHY, not WHAT.
- Clean up: no commented-out code, no debug prints, no dead code.
- Language: English for code, names, comments, commit messages.
- Prose: no em-dashes. Use comma, period, semicolon, colon.
- Commits: `type(scope): description` format (e.g., `feat(agents):`, `style(theme-switch):`). Use a blank line then a body that tells the story of the change: what it adds, how it works, and any relevant context. Omit trailing Co-Authored-By lines.
