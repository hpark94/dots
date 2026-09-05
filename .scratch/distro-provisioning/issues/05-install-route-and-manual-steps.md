# 05 The install route and where the manual steps are written

**Type:** `grilling`

**Status:** open

**Blocked by:**
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md),
[04 Where the package sets live and in what form](04-package-set-form.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`README.md` today claims a fresh machine is four steps: install `git` and
`stow`, clone, export a token, run `bootstrap.sh`. That is false on a bare
distro install, where none of sway, waybar, foot, ghostty or the Flatpaks
exists, and the session will not even start.

What is the **real route**, in order, and where is it written?

### To settle

1. **The ordered route**, from a bare install to a working machine. Rough shape,
   to be corrected rather than accepted: enable the third-party sources the
   survey found, install the native package set, install the Flatpaks, clone,
   `bootstrap.sh`, then the steps only a human can do.
2. **The manual step roster.** Everything that stays a human action. Known so
   far: protonvpn login and network configuration (the opening idea called this
   out explicitly), Syncthing installation and pairing, **creating `~/Sync` and
   `~/projects` by hand** (both are Syncthing folders that nothing in this repo
   creates, and `.config/sway/config` points `$wallpaper` and `$screenshots`
   into the first while `tmux-sessionizer` searches the second), the GitHub
   token `bootstrap.sh` already demands, the KeePassXC database, fcitx5's own
   per-language configuration, the `Include ~/.config/ssh/config.shared` line
   that [12](../../portable-dotfiles/issues/12-ssh-config-ownership.md) decided
   is always manual, plus whatever [03](03-fedora-reference-inventory.md) turns
   up.
3. **Where `font-install` sits in the route.** Fonts are settled: the script
   plus the stowed `.config/fontconfig/`. What is open is only whether the route
   calls it before or after `bootstrap.sh`, and whether `bootstrap.sh` should
   call it at all. Note it needs `curl`, `unzip` and `fc-cache`, which makes it
   a step that depends on the package set having run.
4. **Where it lives.** `README.md`, a `docs/install/` set, one file per distro,
   or one file with per-distro sections? Note that `.stow-local-ignore` already
   keeps `docs/` out of `${HOME}`, and that `README.md` is the file a stranger
   reads first while this document is written for exactly one reader.
5. **What `README.md` will say.** Its current install section is wrong on a bare
   distro install. The rewrite is deliberately not this map's work, but this
   ticket must still decide what the new documents leave to `README.md`, so that
   the eventual rewrite is a transcription rather than another decision.
6. **How a manual step is written so it survives.** A step that is done once per
   machine and never again is a step whose instructions rot unnoticed. Is there
   a form that makes rot visible, for instance a checklist the operator ticks
   per machine, or is that over-engineering for two machines?
