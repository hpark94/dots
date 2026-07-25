# 05 Choose the deployment mechanism

**Type:** `grilling`

**Status:** resolved

**Blocked by:** [01 Name the split](01-name-the-split.md),
[02 Deployment mechanism survey](02-deployment-mechanism-survey.md)

**Map:** [Portable dotfiles](../map.md)

## Question

Which mechanism deploys this repo, and why that one?

Blocked by both parents for real reasons, not ceremony:

- **[01](01-name-the-split.md)** decides whether divergence lives at deploy time or runtime. If it
  is runtime, most of the mechanism's templating and conditional features are dead weight and the
  incumbent stow is probably enough. If it is deploy time, those features are the whole point and
  stow may be disqualified.
- **[02](02-deployment-mechanism-survey.md)** supplies what each candidate can actually do, so this
  session argues trade-offs instead of guessing at capabilities.

### What resolution must cover

1. The mechanism, named.
2. What it costs on a fresh headless remote: the exact bootstrap sequence up to the point where the
   dotfiles are deployed, and what has to be installed by hand before it.
3. Whether the incumbent stow is kept, and if it is dropped, what happens to `.stow-local-ignore`.
4. How machine-local files are handled, given the repo's existing `.gitconfig.example` convention.

### Watch for

The repo has **no documented install procedure at all** today. Whatever is chosen, the decision is
only worth anything if a fresh machine's setup is written down. Note the follow-on: the full
bootstrap sequence (mise, zinit, tpm, nvim plugins, and their ordering) is still fog on the map and
should graduate into its own ticket once this one lands, since it depends on this answer.

## Answer

### 1. The mechanism: GNU stow, kept

[01](01-name-the-split.md) removed the case for switching. It decided **no file needs different
content per machine and nothing is gated by which files land**, which is precisely the templating and
conditional capability that chezmoi and yadm offer over stow. Those features are now dead weight.

What stow gives that the alternatives cost: **symlink write-through**. A deployed file *is* the repo
file, so editing `~/.config/mise/config.toml` edits the repo with no re-add step. That matters here
because the mise config is hand-edited constantly, and it is exactly what chezmoi's copy-based
deployment takes away (hence `chezmoi status` and `chezmoi re-add` existing at all).

Deployment is a **single package**: `cd ~/dots && stow .`, which works because stow defaults `--dir`
to `.` and `--target` to `..`. Tree folding means each app is one directory symlink
(`~/.config/nvim -> ../dots/.config/nvim`), so a new file in the repo appears without re-stowing.

`.stow-local-ignore` is **kept as-is**, plus one defensive addition in section 4 below.

### 2. Install procedure on a fresh machine

The repo has no documented install procedure today. This is the operator's existing workflow, written
down. Prerequisites are `git` and `stow`, both stock packages (Fedora ships `stow-2.4.1`, Debian has
it in every suite).

```sh
sudo dnf install -y git stow          # or: sudo apt install -y git stow
git clone <repo> ~/dots
cd ~/dots && stow .                   # aborts, listing conflicts
```

**The first `stow` always fails on a fresh machine and that is expected.** A fresh Fedora `$HOME`
ships `/etc/skel` files (`.bashrc`, `.bash_profile`, `.bash_logout`, `.zshrc`, `.zprofile`) and stow
refuses to overwrite a real file, aborting the whole invocation with the filesystem unmodified.

```sh
for f in .bashrc .bash_profile .bash_logout .zshrc .zprofile; do
    [ -e ~/$f ] && mv ~/$f ~/$f.bak
done
stow .                                # now clean

mkdir -p ~/.config/dotfiles           # the Role Marker, per ticket 01
echo headless > ~/.config/dotfiles/role   # or: desktop

printf '[include]\n\tpath = ~/.gitconfig.shared\n' > ~/.gitconfig   # section 4
```

At that point the dotfiles are deployed. Everything after it (mise, zinit, tpm, nvim plugins, and
their ordering) is [11](11-bootstrap-sequence.md).

### 3. The stray symlinks are accepted

A Headless machine receives four symlinks it cannot use: `.config/sway`, `.config/waybar`,
`.config/swaync`, `.config/fuzzel`, plus a `clipboard-tunnel.service` unit that is simply never
enabled. (**Since superseded on that last item:** [09](09-clipboard-backend-signal.md) deletes the
unit outright, so the stray set is four directory symlinks and nothing else. The decision below is
unaffected.) Everything else that looks like desktop clutter (`foot`, `ghostty`, `imv`, `mpv`, `zathura`,
`satty`, `fontconfig`) is genuinely live there under waypipe, per [01](01-name-the-split.md).

Folding keeps this cheap: four directory symlinks, not four trees. Two alternatives were rejected
because both reintroduce per-machine file selection that [01](01-name-the-split.md) deliberately
eliminated: `--ignore` lines in an untracked `~/.stowrc` (invisible, easy to forget, and also applies
when unstowing), and moving compositor configs out of the package into a role-scoped directory.

### 4. Machine-local files, and the principle behind them

**A config file that its own tooling rewrites must not be a symlink into the repo.** Stow's
write-through is a feature for files only you edit and a liability for files a tool edits.

The live instance is `gh`. `gh auth login` writes
`[credential "https://github.com"] helper = !gh auth git-credential` into `~/.gitconfig`, which under
stow lands in the working tree and dirties the repo. Gitignoring `.gitconfig` was a correct defence.

Note the principle cuts both ways rather than banning tool writes: `mise use` also rewrites
`.config/mise/config.toml`, and there the write-through is **wanted**, because that edit is yours to
keep. The test is not "does a tool write here" but "should that write be tracked".

The arrangement, inverted from the current copy:

- **`.gitconfig.shared`**, tracked and stowed, holds `[user]`, `[core]`, `[init]`, `[pull]`.
- **`~/.gitconfig`**, a real untracked file, contains only `[include] path = ~/.gitconfig.shared`.
  `gh` appends its credential helper here, outside the repo.

This keeps the clean-repo property and fixes what the copy costs: shared git config now **propagates**
to machines already set up, instead of being frozen at whatever `.gitconfig.example` said on the day
they were cloned. It also removes an undocumented ordering trap: today `.gitconfig` is gitignored, so
on a fresh clone it does not exist, `stow .` silently creates no `~/.gitconfig` at all, and nothing
tells you to copy the example first. A missing `[include]` path is silently ignored by git, so the
tracked file alone is always enough to boot.

Implementation notes: `.gitconfig.example` is deleted (it is byte-identical to `.gitconfig` today, so
it was varying nothing), and `.stow-local-ignore` gains `^/\.gitconfig$` so a stray working-tree
`.gitconfig` can never be re-symlinked over the real one.

### Follow-on

- [11](11-bootstrap-sequence.md): everything after the dotfiles land. Graduated from the map's fog,
  as this ticket anticipated.
