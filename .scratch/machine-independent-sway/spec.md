# Spec: Machine-independent sway config

Status: done

## Problem Statement

A second Desktop machine is coming: an HP EliteBook running Ubuntu LTS 26,
alongside the current Fedora ZenBook. The Iiyama monitor moves between the two.
Today `.config/sway/config` is the one file in this repo that cannot be deployed
unchanged to it, and three of its lines are already wrong on the machine it was
written for:

- Workspaces 6 to 10 are pinned to the external monitor alone, so with the
  monitor unplugged they have nowhere to go, and after a replug they do not come
  back. The workspace-to-output block encodes one docking state rather than the
  set of states the machine actually passes through.
- Thunderbird's launch waits up to sixty seconds for the `proton0` device to
  reach connected. On a machine where protonvpn is not installed, that is sixty
  seconds of delay at every login for a condition that can never be met. The
  wait is also wedged into the sway config as a `sh -c` one-liner, so no other
  program that needs the network can reuse it.
- The screenshot keybind writes into `~/Bilder/Screenshots`, which does not
  exist on this machine. `grim` exits non-zero, the `&&` chain swallows the
  `notify-send`, and the screenshot is lost with no message at all. The path is
  also a leftover from an install whose locale no longer applies.

## Solution

Make the sway config deployable unchanged to both Desktop machines, without
introducing any per-machine file or any new deployment concept. Everything that
looked machine-specific is resolved one of three ways: expressed as a preference
order sway resolves at runtime, moved behind a Capability Probe in a shared
executable, or left alone because it was proven harmless when it points at
hardware that is not there.

Three changes:

1. **Workspace assignments become preference lists.**
   `workspace 6 output $monitor eDP-1` means "the Iiyama when it is there, the
   built-in panel otherwise", and sway migrates the workspace back by itself
   when the monitor returns. One line covers docked, undocked, and the EliteBook
   with the same monitor.
2. **A new `wait-for-vpn` command** takes over the network gate. It is a
   Capability Probe in front of an `exec`: no protonvpn on this machine means no
   wait at all. Any program that needs the VPN up can be wrapped in it, not just
   windowed ones, and the sway config loses its `sh -c` wrapper.
3. **The screenshot destination becomes a sway variable** pointing into the
   Syncthing folder, the way `$wallpaper` already does.

## User Stories

1. As a dotfiles user, I want the same sway config to deploy unchanged to both
   my ZenBook and my EliteBook, so that a second Desktop machine costs me a
   clone and a bootstrap rather than a merge.
2. As a dotfiles user, I want no untracked machine-local config file, so that
   every difference between my machines stays visible in a diff and in a review.
3. As a dotfiles user, I want workspaces 6 to 10 on the external monitor when it
   is connected, so that my window layout matches how I work at the desk.
4. As a dotfiles user, I want those workspaces to fall back to the built-in
   panel when the monitor is unplugged, so that undocking does not strand
   windows on an output that is gone.
5. As a dotfiles user, I want those workspaces to move back to the external
   monitor when I plug it in again, so that docking restores my layout without
   my intervention.
6. As a dotfiles user, I want that to keep working after many unplug and replug
   cycles, so that the connector name changing underneath me never breaks the
   assignment again.
7. As a dotfiles user, I want the monitor identified by make, model and serial
   rather than by connector name, so that the same line works whether the
   monitor lands on DP or HDMI and whichever machine it is plugged into.
8. As a dotfiles user, I want to add a second external monitor later by
   appending one entry to a preference list, so that growing the desk setup is
   not a redesign.
9. As a dotfiles user, I want Thunderbird to start only once the VPN is up, so
   that its OAuth2 token refresh does not run into a network that protonvpn is
   still rewriting.
10. As a dotfiles user, I want that wait to be a command I can put in front of
    anything, so that a backup, a mail sync or any other network job can reuse
    it without copying a loop.
11. As a dotfiles user, I want the wait skipped entirely on a machine without
    protonvpn, so that logging into the EliteBook does not cost a minute before
    my mail client appears.
12. As a dotfiles user, I want the wait skipped when the VPN is already up, so
    that a normal login is not delayed at all.
13. As a dotfiles user, I want the command to start anyway when the VPN never
    comes up, so that an offline boot still gets me my mail client.
14. As a dotfiles user, I want that timeout announced on stderr, so that a slow
    login has a recorded reason instead of looking like a hang.
15. As a dotfiles user, I want the wrapper to pass my arguments through
    untouched, so that wrapping `sway-start-on-workspace` does not change how
    that script sees its own arguments.
16. As a dotfiles user, I want the wrapper to replace itself with the command it
    launches, so that no extra process sits in the tree and the wrapped script's
    own job control keeps working.
17. As a dotfiles user, I want the sway config to call one command per autostart
    line, so that I stop having to reason about sway splitting an exec line on a
    semicolon.
18. As a dotfiles user, I want the wrapper to refuse a command that is not on
    PATH, so that a typo fails at once instead of after a sixty second wait.
19. As a dotfiles user, I want my screenshots written into my Syncthing folder,
    so that they reach my other devices without a copy step.
20. As a dotfiles user, I want the screenshot destination in one variable at the
    top of the config, so that changing it is one edit and not a hunt through
    keybinds.
21. As a dotfiles user, I want the notification to name the directory the
    screenshot actually went to, so that the message is not lying to me.
22. As a dotfiles user, I want the stylus mapping to stay in the shared config,
    so that the convertible keeps working without the EliteBook tripping over a
    device it does not have.
23. As a dotfiles user, I want a missing wallpaper to cost me a wallpaper and
    nothing else, so that a machine where Syncthing has not run yet still locks
    its screen.
24. As a dotfiles user, I want the existing Role split left alone, so that a
    change about two Desktop machines does not disturb what Desktop and Headless
    already mean.
25. As a dotfiles user, I want the new command covered by tests that stub the
    network tools, so that the test suite needs neither a VPN nor a compositor.
26. As a dotfiles user, I want `wait-for-vpn` listed among this repo's commands,
    so that the next reader finds it where every other script is documented.

## Implementation Decisions

### No new deployment mechanism

The repo stays flat, everything keeps shipping to both Roles, and nothing is
gated by which files land. No machine-local include file is introduced, and
`CONTEXT.md` gains no new vocabulary: the Capability Probe already covers what
this needs. This deliberately keeps the decisions in
`.scratch/portable-dotfiles/issues/01-name-the-split.md` and
`05-choose-deployment-mechanism.md` intact rather than reopening them, because
after investigation no value was found that must differ per machine.

### Workspace assignment becomes a preference list

`workspace <name> output <outputs...>` takes a list. The first available output
wins, and when an output higher in the list appears the workspace migrates to
it. Workspaces 6 to 10 list the external monitor first and the built-in panel
second. Workspaces 1 to 5 are unchanged: they already name an output that is
always present.

The external monitor keeps being named by its make, model and serial identifier
rather than by a connector name. This is not cosmetic. The same monitor has
appeared as an incrementing `DP-N` and currently appears as `HDMI-A-1`, while
the identifier is stable across both. `sway-output(5)` documents the identifier
form as the remedy for exactly this.

Verified against sway 1.11 with a headless compositor in a scratch directory
during the grilling that produced this spec:

```
workspace 6 output "HEADLESS-1 bogus" HEADLESS-2   -> ws6 on HEADLESS-2
```

That is the parser question the whole approach rests on: a quoted identifier
containing spaces is **one** list entry, not several. Had sway split it on
spaces, `"Iiyama North America PL2530H 1154384704254"` would have become five
bogus entries and the feature would not exist. Fallback on unplug, and migration
back when a listed output reappears, were confirmed in the same way.

The `output <identifier> pos ...` line stays as it is. An output configuration
for a monitor that is not connected is inert.

### `wait-for-vpn`, a new command

`wait-for-vpn <command> [args...]`. It gates on the network and then replaces
itself with the command, via `exec`, so it leaves no process behind.

The probe is **whether protonvpn is installed on this machine**, not whether a
connection profile exists. The connection profile is created by the protonvpn
client and its name carries the server it picked (`ProtonVPN DE#905`), so its
presence tracks connection state and its name changes under you. The command on
PATH is a durable property of the machine and is the same Capability Probe idiom
the repo already uses for `swaymsg` and `jq`.

The contract, in order:

- No `protonvpn` on PATH: run the command immediately. This is the EliteBook
  case and costs nothing.
- Otherwise poll NetworkManager once a second, for at most sixty seconds, until
  the `proton0` device reports connected, then run the command. The device name
  is stable and stays hardcoded; a `--device` flag is what gets built when a
  second VPN actually exists.
- Already connected: the first poll succeeds and the command runs at once.
- Sixty seconds elapsed: report on stderr and run the command anyway.

**The script never refuses to run its command; it only ever delays it.** This is
a deliberate reading of the "fail loudly" rule in `AGENTS.md` rather than an
exception to it. The loud part is the stderr message; the exit status belongs to
the command that was exec'd. A launcher that aborts on a degraded network turns
"the VPN is slow" into "there is no mail client", which is the failure the sixty
second cap exists to prevent. The same applies if `nmcli` is missing while
protonvpn is present: report and run.

The one case that does refuse, before any waiting, is a command that is not on
PATH, matching how `sway-start-on-workspace` validates the command it is given.

The Thunderbird autostart line becomes a single command with `wait-for-vpn` in
front of `sway-start-on-workspace`, and the `sh -c` wrapper disappears with it.
The two scripts compose and neither knows about the other: `wait-for-vpn` is
equally usable in front of a program that maps no window at all.

### Screenshot destination

A sway variable holds the directory, mirroring the existing `$wallpaper`
variable, and both the `grim` invocation and the `notify-send` text read it. The
destination is the `screens` directory inside the Syncthing folder, which
already holds screenshots in this keybind's naming scheme and is not matched by
any pattern in the folder's ignore list.

The directory is **not** created by the keybind. This was raised and decided
against: on a configured machine Syncthing provides the directory, and the
window in which it is missing is a new machine before Syncthing has run. The
cost of that decision is recorded here rather than mitigated.

### Documentation

`AGENTS.md` lists every command in this repo and every script the bats suite
covers. Both lists gain `wait-for-vpn`. `CONTEXT.md` and the ADRs are not
touched: no term changes meaning and no architectural decision is contradicted.

### Left alone deliberately

Three lines that look machine-specific were each proven harmless when the
hardware is absent, and changing them would be diff noise:

- The stylus `input` block. sway 1.11 starts with no error and no warning when
  the named device does not exist.
- `$wallpaper`. With the file missing, `swaybg` logs the failure and keeps
  running, and `swaylock -f` still locks the session and exits 0. A missing
  wallpaper costs a wallpaper, not a lock screen.
- The `battery-threshold-toggle` keybind. The script is not in this repo; on a
  machine without it the keybind does nothing when pressed.

## Testing Decisions

A good test here asserts what the command does for its caller, not how it does
it: did the wrapped command run, when did it run relative to the network
becoming ready, what arguments did it see, and what went to stderr. Nothing
asserts the shape of the polling loop or the exact `nmcli` invocation.

**One seam, and it already exists.** `wait-for-vpn` is tested through its own
CLI under bats, with `nmcli`, `protonvpn` and the wrapped command replaced by
stubs on a prepended PATH. This is the pattern
`.local/scripts/tests/sway-start-on-workspace.bats` established: stub scripts
write what they saw into log files under `BATS_TEST_TMPDIR`, and the assertions
read those logs. No VPN, no NetworkManager, no compositor, no network.

Cases to cover:

- `protonvpn` absent from PATH: the command runs, and `nmcli` is never called.
- `proton0` already connected: the command runs, with no delay attributable to
  waiting.
- `proton0` connected only after some polls: the command runs, and it runs after
  the state changed, not before.
- Never connected: the command still runs, and stderr carries the timeout
  message.
- `nmcli` missing while `protonvpn` is present: the command runs, and stderr
  says why the wait was skipped.
- Arguments, including ones containing spaces, reach the wrapped command
  unchanged.
- No command given: usage on stderr, non-zero exit.
- Command not on PATH: an error on stderr, non-zero exit, and no waiting first.

Tests must not spin the CPU or leave orphaned processes; the polling interval is
driven by a stubbed clock or a stubbed `sleep` rather than by real seconds, so
the suite stays fast and deterministic.

**The sway config gets no test.** `sway -C` would validate syntax and not
behavior, the behavior at issue was already proven against a real sway 1.11, and
the repo has never tested this file. Adding a seam for a syntax check was
considered and rejected during the grilling.

## Out of Scope

- **The distro package list.** Roughly thirty packages the repo depends on
  (`sway`, `foot`, `ghostty`, `waybar`, `keepassxc` and the rest) appear in no
  file, and `bootstrap.sh` installs no OS packages at all. On a fresh Ubuntu
  EliteBook the clone stows cleanly and then nothing starts. This is the largest
  remaining obstacle to a second machine and it is deliberately deferred to its
  own session, as work too big to carry here.
- **`battery-threshold-toggle`.** It lives untracked outside the repo, is
  referenced by the sway config, and is versioned nowhere. Noted, not decided.
- **A machine-local sway include.** Considered and rejected; see Implementation
  Decisions.
- **A second external monitor.** The preference list makes it an append when it
  happens; nothing is built for it now.
- **`bootstrap.sh`'s Fedora references.** Its skel file list was checked against
  Ubuntu's `/etc/skel` and collides with nothing the repo provides, so there is
  nothing to change.
- **Anything in the Role split.** Desktop and Headless keep their current
  meanings and the Role Marker is not read by any of this.

## Further Notes

The facts underneath these decisions were established by running things, not by
recall, and are recorded here so the implementing session does not re-derive
them:

- sway 1.11. Preference lists fall through on unplug and migrate back when a
  listed output reappears; a quoted identifier with spaces is a single list
  entry; a replugged output can come back under a different connector name,
  which is the original bug this repo hit.
- The Iiyama is currently connected as `HDMI-A-1` and has previously been a
  `DP-N`, with an unchanged make, model and serial throughout.
- `~/Bilder` does not exist; `XDG_PICTURES_DIR` is set to `$HOME/`, so
  `xdg-user-dir PICTURES` resolves to the home directory and is unusable as a
  screenshot destination; the machine's locale is `en_US.UTF-8`.
- `grim` into a missing directory exits 1, and the keybind's `&&` chain
  suppresses the notification, which is the silent failure `AGENTS.md` forbids.

One caution for whoever implements this. During the grilling, a proof script
guessed `WAYLAND_DISPLAY` by taking the first `wayland-*` socket under
`XDG_RUNTIME_DIR` and hit the live session, which locked the operator's screen
and forced a trip to a TTY. A scratch compositor must get its own
`XDG_RUNTIME_DIR`, and the isolation must be asserted before any client is
started, because the socket is named `wayland-1` in both places.
