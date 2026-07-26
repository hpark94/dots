Status: done

# Roles, bootstrap, and deployment: from `git clone` to a fully built machine

## Problem Statement

This repo has no documented install procedure at all today, on either target: a fresh Fedora/sway
Desktop or a headless Linux SSH remote. `stow .` is the only step written down anywhere, and it isn't
even written down correctly — a fresh Fedora `$HOME` ships `/etc/skel` files that make the first `stow`
abort entirely, with no pre-step documented. Past that point, nothing coordinates the rest: `zinit` and
lazy.nvim self-install on first use, `mise` (which provides most of the toolchain the rest of the
config assumes exists) isn't installed by anything, and `tpm` is never cloned by anything at all, so
every `@plugin` line in `.tmux.conf` has been silently inert on any machine that didn't happen to have
it already. Separately, `~/.gitconfig` is a symlink-deployed tracked file that `gh auth login` dirties
on write, `.envs.sh` still branches three Capability-Probe-shaped variables on SSH-ness (a proxy this
map has already found wrong twice elsewhere), and there is no Role Marker anywhere for any of the
other specs built on top of this map to read.

This spec is the write-up of [Choose the deployment
mechanism](../portable-dotfiles/issues/05-choose-deployment-mechanism.md), [The bootstrap sequence
after the dotfiles land](../portable-dotfiles/issues/11-bootstrap-sequence.md), and [What `.env`
holds, and whether `.envs.sh` needs the Role Marker](../portable-dotfiles/issues/15-env-secrets-scope.md)
on the [Portable dotfiles map](../portable-dotfiles/map.md), informed by the survey in [Deployment
mechanism survey](../portable-dotfiles/issues/02-deployment-mechanism-survey.md). It does **not**
re-decide the Role/Headless/Desktop split itself, the Role Marker's file format, or the canonical
Role-reading contract — those are already settled by [Name the
split](../portable-dotfiles/issues/01-name-the-split.md) and [How a script reads the Role
Marker](../portable-dotfiles/issues/13-role-marker-reader.md), and already implemented as consumers in
the notetaking-rewrite and theme-switch-expansion specs. This spec is about **writing** the Marker for
the first time and everything else that has to happen once, in order, for either Role to go from a bare
clone to a working machine.

## Solution

A single tracked, idempotent `bootstrap.sh <desktop|headless>` owns the entire sequence from just
after `git clone` to a fully built machine, with no Role branch in its own behavior — the Role is an
input it records, not something it decides differently for. It pre-creates the container directories
`stow` must not be allowed to fold, neutralizes the `/etc/skel` conflict that aborts a fresh machine's
first `stow`, runs `stow .`, writes the Role Marker and a `~/.gitconfig` stub (both create-if-absent,
never clobbering an already-provisioned machine), installs `mise` and activates it in-process, runs
`mise install`, clones and installs `tpm` (the one outright gap today), forces `lazy.nvim` and `zinit`
to complete their self-installs rather than leaving them lazy, and generates the Theme Mode state and
every app's Generated Config fragment via `theme-switch`'s own render entry point — so a Desktop never
launches `sway` for the first time missing the fragments waybar's tracked stylesheets hard-require.
Every step guards itself, so re-running is always safe, which is also what makes bootstrap **retrofit**
a machine that already has the dotfiles deployed by hand with no Marker and no state, not just bring up
a fresh one.

`~/.gitconfig`'s Write-Back Config problem is fixed the same way `.config/mise/config.toml`'s
write-through is deliberately kept: a tracked `.gitconfig.shared` holds the shared settings, and a
real, untracked `~/.gitconfig` contains only an `[include]` pointing at it, so `gh auth login`'s
credential-helper write lands outside the repo instead of dirtying it. `.envs.sh`'s three
SSH-ness-gated variables that are actually Capability Probes in disguise become real Capability
Probes, closing the last open piece of [Name the split](../portable-dotfiles/issues/01-name-the-split.md)'s
diagnosis. The README shrinks to three lines: install `git`/`stow`, clone, run `bootstrap.sh <role>`.

## User Stories

1. As the dotfiles owner, I want to go from a bare `git clone` to a fully working machine by running
   one script with one argument, so that setting up a new machine isn't a checklist I have to remember
   or re-derive.
2. As the dotfiles owner, I want that same script to work identically for a Desktop and for a Headless
   machine, only differing in which Role gets recorded, so that I don't need two different bootstrap
   procedures to maintain.
3. As the dotfiles owner, I want the first `stow` on a fresh Fedora machine to succeed instead of
   aborting on `/etc/skel` files, so that I don't have to remember an undocumented `.bak`-and-retry
   dance every time.
4. As the dotfiles owner, I want `~/.config` and `~/.local` to remain real directories rather than
   being folded into single symlinks by `stow`, so that `mise`, `zinit`, nvim's plugins, and the Role
   Marker all land in their real XDG locations instead of silently drifting into my repo's working
   tree.
5. As the dotfiles owner, I want the Role Marker written automatically from the argument I pass, so
   that I don't have to remember its exact path or format by hand.
6. As the dotfiles owner, I want re-running the bootstrap script on a machine that's already fully set
   up to be a safe no-op, so that I can run it again without fear after, say, a partial run failed
   partway through.
7. As the dotfiles owner, I want re-running the bootstrap script to never overwrite an already-written
   Role Marker or reset my current Theme Mode, so that a retrofit or a recovery run can't silently
   change decisions I've already made on that machine.
8. As the dotfiles owner, I want running the bootstrap script on a machine that already has the
   dotfiles deployed by hand, with no Marker and no state (like my real `uni-cluster` today), to bring
   it fully up to date without disturbing anything already working there.
9. As the dotfiles owner, I want `mise` installed automatically if it's missing, and activated within
   the same bootstrap run, so that every later step (installing the pinned toolchain, then building
   nvim's plugins against the pinned neovim) sees the right tools without a second script run.
10. As the dotfiles owner, I want to be warned that installing the full toolchain can take a while, so
    that a slow first boot doesn't look like the script has hung.
11. As the dotfiles owner, I want `tpm` cloned and its plugins installed automatically, so that my
    tmux plugin declarations actually take effect on a fresh machine instead of being silently inert.
12. As the dotfiles owner, I want nvim's plugin manager to finish installing every plugin during
    bootstrap, not on my first interactive nvim session, so that the machine is genuinely done when the
    script exits.
13. As the dotfiles owner, I want zinit's self-install to complete during bootstrap for the same
    reason, so that my first interactive shell isn't the moment it happens.
14. As the dotfiles owner, I want a default Theme Mode written if none exists yet, without ever
    resetting a Theme Mode that's already active, so that a fresh machine renders something sensible
    and a retrofit run never flips my current theme.
15. As the dotfiles owner, I want every app's Generated Config fragment to exist before I ever launch
    `sway` on a freshly bootstrapped Desktop, so that waybar and zathura's tracked configs — which
    hard-fail to parse when their `@import`/`include` target is missing — don't break on first launch.
16. As the dotfiles owner, I want `~/.gitconfig`'s shared settings to propagate to every machine
    automatically when I change them, so that they aren't frozen at whatever they were the day a
    machine was first set up.
17. As the dotfiles owner, I want `gh auth login`'s credential-helper write to land outside my tracked
    dotfiles, so that authenticating `gh` on any machine never dirties my repo.
18. As a public user of this repo, I want a missing `~/.gitconfig` on a fresh clone to still result in
    a fully working git config after bootstrap, so that there's no separate "copy the example file
    first" step to forget.
19. As the dotfiles owner, I want `.envs.sh`'s environment exports to reflect whether the relevant
    service is actually reachable on this machine right now, rather than whether the shell happens to
    be an SSH session, so that SSHing into my own Desktop doesn't strip variables that should still be
    set there.
20. As the dotfiles owner, I want `.envs.sh` to need no Role Marker at all, so that a shared, tracked
    file that ships identically to both Roles never depends on install having already run.
21. As the dotfiles owner, I want `~/.env`'s scope (machine-local secrets only) documented at its
    source, so that a future me — or a public user — knows what does and doesn't belong there without
    having to ask.
22. As the dotfiles owner, I want the README to say only what's needed to get from zero to a working
    machine, so that it stays accurate instead of drifting from whatever the bootstrap script actually
    does.
23. As a public user of this repo, I want to fork it and run the same one-line bootstrap command on my
    own machine, so that this repo is actually usable by someone who isn't its original owner.
24. As the dotfiles owner, I want bootstrap's own logic (its guards, its sequencing, its argument
    handling) to be covered by tests I can run without actually installing software or touching a real
    `$HOME`, so that I can safely change it later with confidence.
25. As the dotfiles owner, I want bootstrap to follow the same strict-mode and error-reporting
    conventions as every other script in `.local/scripts/`, so that a failure anywhere in the sequence
    stops loudly instead of continuing silently into a half-built machine.

## Implementation Decisions

### `bootstrap.sh <desktop|headless>`: a tracked script, no Role branch in behavior

Lives alongside the other scripts, follows the same conventions already established for them: opens
with strict mode, has a `usage()` function, reports errors with a consistent prefix and a non-zero
exit, and does not silently fall back on bad input. Its one argument is validated against exactly
`desktop`/`headless`; anything else is a hard usage error. The Role is **recorded**, not branched on —
every step of the sequence below runs identically regardless of which Role was passed, with the sole
exception of what gets written into the Marker itself.

### The ordered sequence

Every step guards itself first, so the whole script is idempotent and safe to re-run, which is the
same property that makes it safe to run against a machine that already has the dotfiles deployed by
hand (a real retrofit case: a machine can have the repo cloned and stowed with no Marker and no Theme
Mode state at all).

1. **Pre-create real container directories**: the shared XDG namespaces (`~/.config`, `~/.local`, and
   defensively `~/.local/bin`) must exist as real directories before `stow` runs. This is load-bearing:
   if either is missing, `stow` folds the entire namespace into one directory symlink into the repo
   (since the repo only tracks a subset of each), and every later tool that writes into that namespace
   — `mise`'s own binary, `zinit`'s data directory, nvim's plugin directory, and the Role Marker itself
   — silently lands inside the repo's working tree instead of its real XDG location.
2. **Neutralize `/etc/skel` conflicts**: for each of the handful of shell startup files a fresh Fedora
   `$HOME` ships, if it exists as a real file (not already a symlink into the repo), back it up out of
   the way. Idempotent: a file that's already a symlink into the repo is left alone.
3. **Stow**: run stow's normal single-package invocation. A no-op on re-run.
4. **Role Marker**: if it already exists, leave it untouched; otherwise write it from the required
   argument. A missing Marker with no argument is a hard error, per the canonical Role-reading
   contract's "no default Role" rule — the argument is therefore only ever consulted on a machine that
   doesn't have a Marker yet, so re-running on an already-marked machine never needs it passed again.
5. **`~/.gitconfig` stub**: write the include-only stub (see below) only if the file is absent; never
   overwrite an existing one.
6. **`mise`**: if its binary isn't present, install it via its official installer, then activate it
   within bootstrap's own process (not just export a PATH line for later shells) so every subsequent
   step in this same run sees the pinned toolchain rather than whatever the distro provides or nothing
   at all. `mise` itself is deliberately left unpinned — it's the bootstrapper of the pinned toolchain,
   not a member of it.
7. **`mise install`**: installs everything the tracked `mise` config declares. This is accepted as slow
   on a Headless machine (it includes several Desktop-weight builds) — bootstrap prints a warning to
   that effect before running it, so a long first boot doesn't read as hung.
8. **`tpm`**: clone it if missing, then run its plugin-install step. This is the one outright gap in
   the repo today — nothing else clones it, so every tmux plugin declaration is currently inert on any
   machine that doesn't already happen to have it.
9. **nvim plugins, forced**: run nvim's plugin manager to completion non-interactively, now that the
   mise-provided, pinned neovim is on PATH, so the machine has its plugins installed on exit rather
   than on first interactive use.
10. **`zinit`, forced**: trigger its self-install the same way, rather than leaving it for the first
    interactive shell.
10b. **`bat cache --build`**: rebuild bat's theme cache so the tracked custom themes (`hp_dark` /
    `hp_light` under `.config/bat/themes/`) are registered. The stowed bat config selects them via
    `--theme-dark`/`--theme-light`, but bat only reads custom themes from its cache, so without this a
    freshly deployed machine warns `Unknown theme 'hp_dark', using default` and silently falls back to
    a built-in theme. Same "make a tracked asset actually take effect" category as the tpm/nvim/zinit
    steps, and idempotent to re-run. Numbered 10b to keep step 11 (Theme Mode) stable for the ticket
    cross-references.
11. **Theme Mode**: write the default state file only if one doesn't already exist (never resets a
    Theme Mode already in effect on a retrofit run; renders light on a genuinely cold machine, matching
    nvim's own fallback). Then, **unconditionally, every run**, invoke `theme-switch`'s render-only
    entry point (from the theme-switch-expansion spec) to (re)generate every app's Generated Config
    fragment. These two things are not the same guard: the mode value is create-if-absent, but the
    fragments are derived and safe to regenerate every time, and they must exist before a Desktop's
    first `sway` launch, since waybar's and zathura's tracked configs hard-fail to parse when their
    include target is missing.

### `~/.gitconfig` becomes a stub over a tracked shared file

- `.gitconfig.shared`, tracked and stowed, holds the settings every machine shares (user identity,
  core settings, default branch, pull behavior).
- `~/.gitconfig` becomes a real, untracked file containing only an include pointing at
  `.gitconfig.shared`. Bootstrap writes this stub if absent (step 5 above); it is never clobbered on
  re-run, so anything a tool appends there later (`gh auth login`'s credential helper is the one live
  case) persists across bootstrap re-runs.
- `.gitconfig.example` is removed — it was byte-identical to the tracked config it was meant to
  demonstrate, so it varied nothing and is redundant once the tracked file is always enough to boot on
  its own.
- The stow-ignore list gains an entry excluding a literal `~/.gitconfig` from ever being folded back
  into a symlink over the real stub, since stow would otherwise be free to do exactly that.

### `.envs.sh`: the last SSH-ness branch becomes real Capability Probes

The four variables currently gated on `$SSH_CONNECTION`/`$SSH_TTY` being unset each stop proxying
through SSH-ness; three become independent Capability Probes testing for the thing they actually need,
and the fourth loses its gate entirely:

- The two variables naming a local daemon's socket are gated on that socket actually existing, not on
  whether the shell is local.
- The one variable with no real precondition needs no gate at all.
- The variable selecting the Wayland Qt platform is gated on a compositor display actually being
  attached to this session, the same Session Fact this repo already uses for the equivalent clipboard
  question — not on SSH-ness, which gets both waypipe and "SSHing into your own Desktop" wrong today.

`.envs.sh` itself continues to need no Role Marker at all: it's a shared, tracked file that ships
byte-identical to both Roles, and every branch inside it after this change is a Capability Probe, not
a Role Fact.

### `.env`'s scope, documented at its source

`~/.env` is machine-local secrets — credentials, tokens, anything in that class — untracked, and
already sourced conditionally. This spec adds nothing beyond a one-line comment stating that scope
directly above where `.envs.sh` sources it, so the file documents its own contract rather than leaving
it implicit.

### README shrinks to three lines

Install `git` and `stow` (both stock packages on every target distro), clone the repo, run
`bootstrap.sh <desktop|headless>`. Everything the current README says beyond an install procedure
(the descriptive "Key Highlights" prose) is untouched by this spec — only the install story changes,
from nothing documented to three lines that are actually true.

## Testing Decisions

- `bootstrap.sh` gets a bats file under the same coverage bar already established for `.local/scripts/`:
  its **sequencing and guard logic** — whether it skips a `stow` conflict correctly against a faked
  `$HOME`, whether it writes the Role Marker only when absent and errors correctly when absent with no
  argument, whether it writes the `~/.gitconfig` stub only when absent, whether it skips `mise`
  install when the binary is already present, whether it skips cloning `tpm` when already present,
  whether it writes the Theme Mode default only when absent — gets tests, using the same
  sourcing-plus-fake-`$XDG_*`-dirs pattern `theme-switch.bats` and `note.bats` already establish.
- The actual `mise install`, the installer's `curl | sh`, `nvim --headless` plugin sync, and `tpm`'s
  install step get **no** bats coverage — there is no throwaway machine in this loop to run them
  against safely, matching the same limitation already named for these exact steps.
- `.envs.sh`'s new Capability Probes get bats coverage: source the file with a faked socket path
  present/absent and `$WAYLAND_DISPLAY` set/unset, and assert each variable is exported or not
  accordingly.
- The full end-to-end bootstrap (a genuinely fresh machine, or a real retrofit of an already-deployed
  one) is verified manually, not in bats, against this repo's established SSH test target where a
  remote machine is needed.

## Out of Scope

- **Re-deciding the Role/Headless/Desktop split, the Role Marker's file format, or the canonical
  Role-reading contract.** All settled elsewhere and already implemented as consumers by the
  notetaking-rewrite and theme-switch-expansion specs; this spec only writes the Marker for the first
  time.
- **A shared script library.** Confirmed in the source ticket: no library is placed by install, and
  none is introduced here. Each script that needs to read the Marker hand-rolls the canonical
  contract, as already decided.
- **Any Role-dependent bootstrap behavior beyond writing the Marker's value.** The one candidate
  exception (enabling a systemd unit on exactly one Role) no longer exists — that unit is deleted
  entirely by the clipboard-rewire spec, not conditionally started by this one.
- **Wiring the `theme-switch`-expansion or clipboard-rewire specs' own deliverables.** This spec only
  *calls* `theme-switch`'s render-only entry point in its bootstrap sequence; it does not build that
  entry point, the Role gate behind it, or anything else those specs own.
- **Automating `~/.ssh/config`'s `Include` line or any live SSH host configuration.** Out of scope for
  this spec specifically because it's already decided, and deliberately manual, in the
  theme-switch-expansion spec.
- **A general secrets-management or credentials-vaulting story beyond documenting `.env`'s scope.**
  No further sweep for other Write-Back Configs was requested beyond the one already found (`gh`'s
  `.gitconfig` write).
- **Packaging or distributing `bootstrap.sh` outside this repo** (a curl-pipeable installer script,
  a release process, etc.) — it's a tracked script run from a clone, nothing more.

## Further Notes

- Read [The bootstrap sequence after the dotfiles
  land](../portable-dotfiles/issues/11-bootstrap-sequence.md) in full before implementing — it
  documents the exact dependency knot (mise before nvim's first launch, lazy/zinit's self-install
  timing) that makes the ordering non-obvious, and the follow-up note about fragment generation needing
  to be unconditional while the mode file stays create-if-absent.
- Step 11's call into `theme-switch`'s render-only entry point is a real dependency on the
  theme-switch-expansion spec's Role-gate ticket. Sequence this spec's implementation after that ticket
  lands, or add a minimal equivalent call if it hasn't yet and reconcile later.
- `CONTEXT.md`'s **Role**, **Role Marker**, **Role Fact**, **Session Fact**, **Capability Probe**, and
  **Write-Back Config** entries already document the vocabulary this spec implements against; no
  further vocabulary changes are expected here, only code.
- The repo's working tree currently has `.gitconfig.example` already deleted and some CONTEXT.md/ADR
  amendments already staged, uncommitted, from earlier work on this map — `.gitconfig.shared` itself,
  `bootstrap.sh`, and the README's install section do not exist yet and are this spec's actual
  deliverables.
- Per this repo's own testing convention, when a manual end-to-end verification needs a live remote
  target, use this repo's established default host, not the full list.
