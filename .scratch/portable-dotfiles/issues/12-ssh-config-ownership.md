# 12 Who owns `~/.ssh/config`

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None, can start immediately

**Map:** [Portable dotfiles](../map.md)

## Question

`~/.ssh/config` is not in the repo, is not stowed, and is not documented anywhere.
[08](08-theme-mode-propagation.md) just made it **load-bearing**. Does it become tracked, and if so
in what shape?

### Why this is now a question

[08](08-theme-mode-propagation.md) decided the Desktop pushes Theme Mode to Headless machines over
SSH, pushing on toggle to hosts with a live `ControlMaster` socket and again at connect time. That
requires `ControlMaster`, `ControlPersist` and `ControlPath` to be configured, plus whatever hook
carries the connect-time push. None of it exists today, and if that configuration lives only in an
untracked file, then the theming silently does not work on a freshly bootstrapped Desktop and nothing
says why.

The file holds five `Host` entries. It used to hold more:
[09](09-clipboard-backend-signal.md) deleted the four `RemoteForward 11989 localhost:11989` lines
along with the clipboard tunnel itself, so this ticket now stands on
[08](08-theme-mode-propagation.md)'s `ControlMaster` requirement alone. What is left to decide is the
host entries and the shared defaults, not the tunnel.

### What makes it awkward

It is not cleanly one thing or the other.

- **Shared, and wanted everywhere**: `ControlMaster`/`ControlPersist`/`ControlPath` defaults, and any
  `Host *` hygiene. A Headless machine that SSHes onward wants these too.
- **Machine-specific and arguably sensitive**: `HostName 192.168.4.46`, `User s8077556`,
  `login.rbicl.cs.uni-frankfurt.de`. Internal IPs and an employer's or university's hostnames are not
  secrets in the credential sense, but this repo is not obviously the right place for them either,
  and that judgement is the owner's.
- **Role-dependent**: `uni-cluster`, `work-pvm`, `work-tavm` are reachable from the Desktop. Whether
  those same entries make sense on a Headless machine is unexamined.
- **The connect-time push has no defined behaviour against a host that is not a dotfiles machine.**
  Surfaced by [13](13-role-marker-reader.md). [08](08-theme-mode-propagation.md) decided the Desktop
  pushes at connect time, reasoning that a push "needs nothing but a login", but that assumed the
  target holds the repo and can run its own render half. A jump box, a colleague's server or any
  one-off host has no `theme-switch` to invoke. Whether the hook is a `Host *` default that fires
  everywhere or a per-host opt-in **is** this ticket's shared-defaults-versus-host-entries question,
  which is why it lands here rather than as its own ticket.

### Prior art in this map, which may or may not fit

[05](05-choose-deployment-mechanism.md) established a principle for `~/.gitconfig`: a config its own
tooling rewrites must not be a symlink into the repo, so `.gitconfig.shared` is tracked and stowed
while `~/.gitconfig` is an untracked stub that `[include]`s it.

`ssh_config` has the same `Include` capability (`Include` must appear before the `Host` blocks it
should affect, or inside one), so the identical split is available: a tracked
`.ssh/config.shared` holding the `ControlMaster` defaults and the push hook, and an untracked
`~/.ssh/config` holding the host entries. **But the analogy is not exact**: `~/.gitconfig` was split
because `gh` writes to it, and nothing writes to `~/.ssh/config`. The reason to split here would be
privacy of the host entries, which is a different reason and may want a different shape.

### The decision

1. Does the repo track any of `~/.ssh/config`, and if so which parts?
2. If it splits, does it follow the `.gitconfig.shared` pattern exactly, or does something about
   `ssh_config`'s `Include` ordering rules argue for a different shape?
3. Do the host entries stay untracked, get tracked as-is, or get tracked with the identifying values
   pulled out?
4. Does a Headless machine get an ssh config at all?

### Not this ticket

What goes *in* the host entries. [09](09-clipboard-backend-signal.md) already removed the
`RemoteForward` lines by deleting the tunnel, and [08](08-theme-mode-propagation.md) already decided
that `ControlMaster` must be present. This ticket decides only who **owns** the file.

## Answer

**The `Host` entries never get tracked, in any form, forever.** `uni-cluster`, `work-pvm`,
`work-tavm`, `ubuntu-server` and `vm-app` stay exactly where they are today: untracked, unstowed,
unmodified by this repo. This is a straight public-repo call: even non-credential machine
identifiers (internal IPs, a username, a university login hostname) don't belong in a public
dotfiles repo, and pulling the identifying values out and tracking a genericized version was
rejected too, not just tracking as-is. This settles sub-question 3 and half of sub-question 1.

**What *does* get tracked is a single fully generic `Host *` block** holding `ControlMaster`,
`ControlPersist` and `ControlPath`, written with the `%h`/`%p`/`%r` tokens so it names no concrete
host, IP or user. Nothing else. This settles the other half of sub-question 1: the file doesn't
split into "shared vs. host-specific" the way `~/.gitconfig` did (the `.gitconfig` split exists
because `gh auth` rewrites that file; nothing rewrites `~/.ssh/config`, so the only real reason to
track a fragment of it at all is that this one fragment is genuinely content-free of anything
personal).

**Shape (sub-question 2): the analogy to `.gitconfig.shared` holds for *mechanism*, not for
*position*.** The generic block is tracked at `.config/ssh/config.shared` and deployed by the same
`stow .` used everywhere else in the repo, no special-casing, since (unlike `~/.gitconfig`) nothing
ever rewrites this file at runtime, so it never needed excluding from the stow package in the first
place. But `ssh_config` is confirmed (`man ssh_config`) to use **first-obtained-value-wins**, the
opposite of `.gitconfig`'s "later include is fine" behavior: "more host-specific declarations should
be given near the beginning of the file, and general defaults at the end." So the wiring is one
manually-added line at the **bottom** of the real `~/.ssh/config`:

```
Include ~/.config/ssh/config.shared
```

Putting it first would make the generic defaults win for every parameter and silently block any
later host-specific override. `~/.ssh/config` itself stays outside the stow package entirely (no
`.ssh/` directory exists in the repo), so stow never creates it, never touches it, and can never
conflict with whatever's already there.

**Headless (sub-question 4): the `Include` line is Desktop-only, and always manual, never
scripted or part of `bootstrap.sh`.** The `ControlMaster` requirement ticket
[08](08-theme-mode-propagation.md) actually depends on lives entirely on the Desktop side: the
Desktop is the SSH client that checks for a live control socket before pushing Theme Mode, so
that's the only side the push mechanism needs. Wiring the generic block into a Headless machine's
own `~/.ssh/config` is optional, per-machine, at the operator's discretion, and deliberately never
automated: some Headless boxes (`uni-cluster`) already carry an institution-managed `~/.ssh/config`
with its own infrastructure-critical settings that nothing in this repo should risk touching by
script.

**Left open, not this ticket:** the concrete mechanism that actually *fires* the connect-time push
(a `LocalCommand`, a shell wrapper around `ssh`, or something else) is an implementation detail of
the push script, not a question of who owns the config file. It stays unresolved here, consistent
with this ticket's own scope line above.
