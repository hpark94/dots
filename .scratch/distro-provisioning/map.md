# Map: From a clone to a working Desktop on Fedora and Ubuntu

**Label:** `wayfinder:map`

## Destination

A decided route for taking either real Desktop machine, the Fedora ZenBook and
the Ubuntu EliteBook, from a bare distro install to a working machine: which
programs a Desktop needs, how each one is installed on each distro, what stays
manual and where that is written down, and what the existing configs must stop
assuming. Reached when all of that is settled and written up as implementable
specs. Nothing is built here.

## Notes

- **Domain:** personal dotfiles, single context. Read `CONTEXT.md` first, above
  all Role, Role Fact, Session Fact and Capability Probe.
- **The preceding map is settled and is not reopened.**
  [`portable-dotfiles`](../portable-dotfiles/map.md) decided the Role split,
  stow as the deployment mechanism, and `bootstrap.sh`. This map starts where
  that one stopped: it never asked which distro the machine runs.
- **Planning only.** Tickets resolve decisions; the building happens afterwards
  through the normal `.scratch/<feature>/spec.md` + `issues/` flow. Deciding
  what a document must say is planning; writing that document is not.
- **Fedora is the reference.** The ZenBook is the machine that works; the
  EliteBook is the copy with holes. Where the two disagree about what a complete
  machine has, Fedora is right until a ticket says otherwise.
- **`bootstrap.sh` stays sudo-free.** Package installation is a step in front of
  it, never a step inside it. This keeps the bats suite runnable without root
  and keeps `bootstrap.sh` usable on a Headless machine.
- **Flatpak, never snap.** A snap is an Ubuntu-only answer that Fedora cannot
  reproduce, so it would create a per-distro special case by construction.
- **Third-party sources are documented, never scripted.** A script that adds
  foreign repositories and GPG keys is the one piece that fails quietly and
  changes the system underneath you.
- **Headless installs no packages at all.** There is usually no sudo on those
  machines, so the whole packaging question is a Desktop question.
- **`~/Sync` and `~/projects` are created by hand.** Both are Syncthing folders.
  Nothing in this repo creates them, and several things point into them, so
  their creation is a documented manual step.
- **The input method stays fcitx5.** It is the one that works under sway, so no
  ticket weighs alternatives; only its packaging and configuration are open.
- **Fonts are `font-install` plus a stowed `.config/fontconfig/`.** Settled, so
  fonts are a step in the install route rather than a decision.
- **`README.md` is not rewritten by this map.** It is renewed once the work is
  built, or on explicit command.
- **Skills:** `/grilling` and `/domain-modeling` by default, `/research` for the
  survey.
- **Style:** no em dashes. Conversation in German, everything written down in
  English.

## Decisions so far

<!-- one line per resolved ticket: gist plus link. Zoom the link for detail. -->

Empty. The map has just been charted.

## Not yet specified

In scope, but not yet sharp enough to ticket. Graduates as the frontier
advances.

Empty. The four patches charted here were all settled in the same session:
`~/Sync` and `~/projects` and the fcitx5 and font steps became input to
[05](issues/05-install-route-and-manual-steps.md), and the completeness check
graduated into [08](issues/08-completeness-check.md).

## Out of scope

Beyond the destination. Never graduates; returns only if the destination is
redrawn, and then as a fresh effort.

- **Arch.** Named in the opening idea, ruled out while naming the destination:
  no Arch machine exists to verify anything against, so every Arch decision
  would be a guess. Decisions here should not actively block a third distro, but
  none of them is made for one.
- **Package installation on Headless machines.** No sudo there, so nothing to
  decide.
- **Keeping the machines in sync over time.** Drift detection between two
  machines that were both installed correctly is a different problem from
  installing them.
- **macOS, containers and ephemeral devboxes**, inherited from
  [`portable-dotfiles`](../portable-dotfiles/map.md).
- **Implementing any decision this map makes.** Planning only, per Notes.
- **Rewriting `README.md`.** Its install section is wrong on a bare distro
  install, and [05](issues/05-install-route-and-manual-steps.md) decides what
  replaces it, but the rewrite itself waits for the build or for an explicit
  command.
