# 11 The bootstrap sequence after the dotfiles land

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

[05](05-choose-deployment-mechanism.md) documented the install up to the point
where `stow .` succeeds, the Role Marker is written and `~/.gitconfig` exists.
**What runs after that, in what order, and what owns it?**

### The gap, stated concretely

Nothing in the repo coordinates any of this, and one piece is missing outright:

- **`zinit` self-installs** from `.zshrc:4-9` on first shell start.
- **lazy.nvim self-installs** from `lazy.lua:1-22` on first nvim start.
- **`tpm` is never cloned by anything.** `.tmux.conf:58` runs
  `~/.tmux/plugins/tpm/tpm`, but no file in this repo ever clones it. On a fresh
  machine that line silently does nothing and every `@plugin` declaration above
  it is inert.
- **`mise` is not installed by any of the above**, and it is the thing that
  provides `bat`, `fd`, `fzf`, `ripgrep`, `zoxide`, `neovim`, the language
  servers and the formatters that `.aliases.sh`, `.zshrc` and the nvim config
  all assume exist.
- **No theme state file exists until the first `theme-switch` run.**
  [08](08-theme-mode-propagation.md) handed this ticket a concrete job: write a
  default state file as part of install, which closes the cold window down to
  the gap between clone and first render. Related and separate: `.tmux.conf:26`
  sources the generated fragment without `-q`, which
  [08](08-theme-mode-propagation.md) already decided is a bug to fix rather than
  something bootstrap should work around.

### The ordering problem

There is a real dependency knot to untangle, not just a list:

- `mise` must precede nvim's first launch, or lazy.nvim installs plugins against
  whatever `nvim` the distro has, or none at all.
- `mise install` on a Headless machine builds `cmake`, `ninja`, `resvg`, `java`
  and `maven`. That was accepted deliberately in [01](01-name-the-split.md) (the
  file is hand-edited constantly and splitting it costs more than the installs),
  but it means first boot is **slow**, and the sequence should say so rather
  than look hung.
- `zinit` and lazy.nvim self-install on _first use_, so they are triggered by
  starting a shell or an editor, not by a script. Whether bootstrap should force
  them (`nvim --headless '+Lazy! sync' +qa`) or leave them lazy is a real
  choice.

### The open questions

1. **What owns the sequence.** A tracked `bootstrap.sh` in the repo, a
   documented checklist in `README.md`, or nothing beyond the manual steps
   [05](05-choose-deployment-mechanism.md) already wrote down. Note
   [02](02-deployment-mechanism-survey.md) found that chezmoi and yadm both ship
   bootstrap hooks (`run_once_`, `.config/yadm/bootstrap`) _precisely because_
   tool-managed deploy does not cover installing mise or cloning tpm, so this
   work exists regardless of mechanism.
2. **Where `mise` itself comes from.** It is not in official Fedora, so it
   bottoms out at a curl pipe or a manual binary drop. That is the one step no
   tool in this repo can avoid.
3. **Idempotency.** Whether re-running is safe, and whether that matters or the
   script is genuinely run once per machine.
4. **Role-awareness.** Whether bootstrap differs by Role at all beyond writing
   the Marker itself. [01](01-name-the-split.md) says almost nothing should, and
   the one candidate exception this ticket originally carried has since been
   removed: `clipboard-tunnel.service` was the only unit needing
   `systemctl --user enable` on exactly one Role, and
   [09](09-clipboard-backend-signal.md) deleted it. So there may now be **no**
   Role-dependent step at all, which is worth confirming rather than assuming,
   since a bootstrap with no Role branch is a materially simpler thing to own.
5. **Machines that already have the dotfiles but never ran an install.**
   [08](08-theme-mode-propagation.md) found uni-cluster deployed and in daily
   use with no state file, and by the same token no Role Marker, since the
   Marker is new. Whether bootstrap is only for fresh machines or is also the
   thing you run on an already-deployed one changes whether it can assume a
   clean `$HOME`.

### What resolution must cover

The ordered sequence, what owns it, where mise comes from, whether tpm gets
cloned by the bootstrap or by something else, and what install writes beyond the
dotfiles themselves (Role Marker, `~/.gitconfig` stub, default theme state).

## Answer

**A tracked, idempotent `bootstrap.sh <desktop|headless>` owns the whole
sequence, from just after `git clone` to a machine that is fully built when the
script exits.** No Role branch in its behavior: the Role is an input it records,
every step runs identically on both Roles.

### What owns it: a tracked script, not prose

Chosen over a README checklist because the sequence has a real dependency knot
that prose invites getting wrong (mise must be installed _and active in
bootstrap's own process_ before nvim's first launch, or lazy.nvim builds against
the distro nvim or none), because a script can _verify_ each step
(`nvim --headless` returns non-zero on a failed `Lazy sync`; a lazy self-install
failure only surfaces as a broken editor later), and because "script with bats
coverage" is already this repo's idiom via `theme-switch`.
[02](02-deployment-mechanism-survey.md)'s finding stands: chezmoi and yadm ship
bootstrap hooks _precisely because_ deploy tooling never installs mise or clones
tpm, so this work exists regardless of mechanism.

### The ordered sequence

Left edge is immediately after `git clone <repo> ~/dots` (the clone cannot live
inside the repo it clones). README shrinks to three lines: install `git`/`stow`,
clone, `~/dots/bootstrap.sh <role>`.

1. **Pre-create real container dirs**: `mkdir -p ~/.config ~/.local`
   (defensively `~/.local/bin` too). This is load-bearing, not hygiene. If
   `~/.local` does not exist, `stow .` **folds** the whole namespace into a
   single symlink `~/.local -> ~/dots/.local` (the repo tracks only
   `.local/scripts`, so nothing stops the fold), and then `~/.local/bin/mise`
   (step 6's curl install), `~/.local/share/zinit` (step 10) and nvim's lazy
   plugins under `~/.local/share/nvim` (step 9) all write **into the repo
   working tree**. Same trap on `~/.config`: a fold sends the Role Marker
   (`~/.config/dotfiles/role`) and every later-installed app's config into the
   repo. Pre-creating the two shared namespaces as real dirs forces stow to fold
   only at the app level (`~/.config/nvim -> repo`, `~/.local/scripts -> repo`,
   exactly what [05](05-choose-deployment-mechanism.md) wanted), while
   `~/.local/bin`, `~/.local/share` and `~/.config/dotfiles` become real dirs
   their own tools create.
2. **Neutralize skel conflicts**: for each of
   `.bashrc .bash_profile .bash_logout .zshrc .zprofile`, if it exists and is
   not already a symlink into the repo, `.bak` it. This is
   [05](05-choose-deployment-mechanism.md)'s documented `.bak`-and-re-run dance,
   now code. Idempotent: an already-stowed symlink is left alone.
3. **Stow**: `cd ~/dots && stow .`. A no-op on re-run.
4. **Role Marker**: if `~/.config/dotfiles/role` exists, keep it; else write it
   from the required argument. Missing Marker with no argument is a hard error
   (per [13](13-role-marker-reader.md)'s "no default Role"). The argument is
   therefore _consulted only when the Marker is absent_, so a re-run on an
   already-marked machine succeeds without re-passing it.
5. **`.gitconfig` stub**: write the `[include]` stub
   ([05](05-choose-deployment-mechanism.md)) only if absent, never clobber.
6. **mise**: if `~/.local/bin/mise` is absent, `curl https://mise.run | sh` (the
   official installer, which lands the binary at the exact path `.zshrc:17`
   already hardcodes). Then **activate in bootstrap's own process** so later
   steps see the pinned toolchain. mise is the bootstrapper of the pinned
   toolchain, not a member of it, so it is deliberately _not_ version-pinned:
   once on PATH, `mise install` pins every real tool.
7. **`mise install`**: installs everything in `.config/mise/config.toml`,
   including the heavy Desktop-weight builds (`cmake`, `ninja`, `resvg`, `java`,
   `maven`) on Headless, accepted in [01](01-name-the-split.md). Bootstrap
   should warn that first boot is slow so it does not look hung.
8. **tpm** (the one outright gap: nothing in the repo clones it today, so
   `.tmux.conf:58` silently does nothing on a fresh box): clone to
   `~/.tmux/plugins/tpm` if missing, then run
   `~/.tmux/plugins/tpm/bin/install_plugins`.
9. **nvim plugins, forced**: `nvim --headless '+Lazy! sync' +qa`, now that the
   mise-provided pinned neovim is on PATH.
10. **zinit, forced**: trigger its self-install (`.zshrc:4-9`) via a throwaway
    `zsh -ic true` or by sourcing the zinit block, so the machine is complete on
    exit rather than half-built until the first interactive shell.
11. **Default theme state**: write **only if absent** (the job
    [08](08-theme-mode-propagation.md) handed here), create-if-absent so a
    retrofit run never resets a live Theme Mode. Renders **light** on a cold
    machine, matching what nvim already does.

### Decisions inside the sequence

- **Idempotent, not run-once.** Every step guards first (`command -v`, `[ -d ]`,
  `[ -e ]`); most heavy steps (`mise install`, `Lazy! sync`, `install_plugins`)
  are already idempotent upstream. Idempotency is what makes re-running the
  recovery path for a partial run (mise installs, network drops before
  `Lazy sync`), and it is _the same property_ as retrofit-safety below.
- **Also retrofits, does not just bootstrap fresh machines.**
  [08](08-theme-mode-propagation.md) found uni-cluster deployed and in daily use
  with no Marker and no theme state. Running bootstrap there writes exactly what
  is missing (Marker, theme state, the tpm nobody cloned, the mise nobody
  installed) and touches nothing live, because of the create-if-absent rules on
  Marker and theme state. Retrofit costs ~zero extra design given idempotency.
  The seam: bootstrap covers the post-clone sequence and is safe to run on an
  already-stowed machine; it does not re-clone.
- **No shared library is placed by install.** Each script hand-rolls its Role
  Marker read against [13](13-role-marker-reader.md)'s contract; bootstrap is a
  standalone script, not a library host. This resolves the question
  [13](13-role-marker-reader.md) parked as "fog waiting on 11" and unblocks the
  script-conventions fog patch, which graduates to
  [14](14-script-conventions.md).

### Facts later work depends on

- The mise binary is at `~/.local/bin/mise`; `.zshrc:17`/`.bashrc:22` activate
  it gated on `_has mise`.
- lazy.nvim self-installs from `.config/nvim/lua/core/lazy.lua:1-22`; the nvim
  config lives under `.config/nvim` (the repo-root `nvim/` dir holds only stray
  logs, excluded from stow).
- The four declared tmux plugins are `tpm`, `tmux-sensible`,
  `vim-tmux-navigator`, `tmux-yank` (`.tmux.conf:33-36`).
- Container dirs that must be pre-created real: `~/.config` and `~/.local`. This
  is a hard requirement, not a preference: skipping it silently drifts mise,
  zinit, nvim plugins and the Role Marker into the repo working tree.

## Note: step 11 must generate fragments, not just write the mode file

Step 11 conflates two things that need separating. Writing the one-word `mode`
file is the create-if-absent step described above (never reset a live Theme Mode
on a retrofit run). But the per-mode **Generated Config** fragments every
consumer reads are gitignored, so on a fresh clone they do not exist yet, and
generating them must run **unconditionally on every bootstrap**, not "only if
absent" (they are derived and idempotent, so regenerating is always safe).

This matters because the consumers do not fail the same way when a fragment is
missing. [08](08-theme-mode-propagation.md) §6 makes tmux (`-q`), the shells
(`[ -f ]`) and nvim (fallback to light) all degrade softly. But
[07](07-theme-switch-app-roster.md) §3 wires waybar as tracked
`style-{dark,light}.css` that `@import` a generated fragment, and a missing
`@import` target is a **hard parse error**; zathura's `include` is the same
shape. So a Desktop bootstrapped without the fragments having been generated
breaks waybar on the first `sway` launch, silently until then.

Resolution: bootstrap invokes `theme-switch`'s render/generate half once, after
the mode file is settled, so all fragments (waybar's **both** modes per
[07](07-theme-switch-app-roster.md), plus the current-mode fragments for
tmux/fuzzel/swaync/zathura/foot/sway/gtk/shell-env) exist before any app reads
them. The mode value stays create-if-absent; the fragments do not.
