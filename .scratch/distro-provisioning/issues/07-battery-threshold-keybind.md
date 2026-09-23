# 07 The battery threshold keybind and its missing script

**Type:** `grilling`

**Status:** resolved

**Blocked by:**
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md),
[06 What the configs must stop assuming](06-config-assumptions.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

`.config/sway/config` binds `Control+Alt+p` to `sudo battery-threshold-toggle`.
That program is in no package, is not in this repo, and does not exist on the
Ubuntu machine. It is the only place in the repo that calls `sudo`, and it is
the one keybind that is hardware-specific: the charge-threshold sysfs interface
differs between the ASUS ZenBook and the HP EliteBook, and a laptop that does
not expose one at all cannot have the feature in any form.

### To settle

1. **Does it come into the repo?** A tracked script under `.local/scripts/`
   would follow the conventions
   [14](../../portable-dotfiles/issues/14-script-conventions.md) already fixed,
   and would get bats coverage. Against that: it needs root, and everything else
   in that directory runs as the user.
2. **The sudoers entry.** A passwordless sudo rule is a manual, per-machine,
   root-owned change that no `bootstrap.sh` should make. If the script is
   tracked, its sudoers entry is a manual step for
   [05](05-install-route-and-manual-steps.md); if the script is not tracked,
   both are.
3. **The hardware difference.** One script probing sysfs for whichever interface
   is present, or genuinely different behaviour per machine? Fold in what
   [01](01-name-the-distro-divergence.md) settles: this is not a distro
   difference at all, it is a hardware difference, and it may need its own place
   in the vocabulary or may collapse into a Capability Probe.
4. **Or the keybind goes.** Deleting it is a real option and costs one keystroke
   that today does nothing on at least one of the two machines.

## Answer

The keybind stays, and the `sudo` in front of it does not. It turns out the
machine already carries a mechanism that lets an ordinary desktop session move
the charge limit with no password and no root-owned rule of this repo's making,
so the ticket's four options collapse into a fifth it did not list. The facts
behind the comparison are in
[the mechanism survey](../research/07-charge-threshold-mechanisms.md), which
decides nothing; the deciding is here.

### 1. It is two features, and only one of them is code

The four artifacts section 6 of [03](03-fedora-reference-inventory.md) found do
not implement one thing. `/etc/battery-threshold-mode` and
`battery-threshold.service` exist so that the cap survives a reboot: a machine
setup with no keystroke in it. The script, the keybind and the sudoers rule
exist so the cap can be lifted before a flight. The two have different answers
and are decided separately below. Stow reaches `/etc` never, so the first is a
documented manual step for [05](05-install-route-and-manual-steps.md) in any
case, and only the second was ever a question about repo code.

The persistent side is not optional, which the ticket did not know: the kernel
**resets the threshold on every boot**. `asus_wmi_battery_add()` on 7.2 runs
`charge_end_threshold = 100` with a comment calling it regression avoidance, the
hook fires on every boot, `modprobe` and battery re-add, and the shipped module
on this machine carries the matching string
`Failed to reset battery charge threshold`. Something has to write the value
back after that, or the cap is fiction.

### 2. The mechanism: UPower over polkit, and why the other four fall

- **`sudo` plus a tracked script is not available at all.** The moment the
  script is tracked it is a stow symlink onto `~/dots`, which the user can edit,
  and `sudoers(5)` is explicit that sudo does not protect against that:
  "Warning, if the user has write access to the command itself (directly or via
  a sudo command), it may be possible for the user to replace the command". A
  NOPASSWD rule on a user-writable file is a root shell on a keystroke. Keeping
  the script root-owned in `/usr/local/bin` avoids this and forfeits tracking,
  tests and the whole point of the ticket.
- **udev cannot hand the file to the user.** `OWNER`, `GROUP` and `MODE` are
  documented in `man 7 udev` as "The permissions for the device node", and a
  `power_supply` has none
  (`udevadm info -p /sys/class/power_supply/BAT0 | grep -c DEVNAME` is 0). What
  is left is `RUN+="/bin/chmod"`, which no systemd or kernel document presents
  as a pattern and for which this machine holds no precedent at all, and the
  mode is lost on every re-creation because `DEVICE_ATTR_RW` recreates the file
  at 0644.
- **TLP is the wrong size and the wrong hardware.** Its own page opens with
  "Battery care is not supported for any hardware that is not specifically
  listed on this page" and HP appears nowhere on it; its `bat.d/` ships no `hp`
  plugin. `tlp setcharge` hard-codes `id -u = 0`, so the toggle lands back on
  the sudoers problem. The Fedora package carries `Conflicts: tuned`, and this
  machine has `tuned` and `tuned-ppd` installed. It is a power management daemon
  that rewrites CPU, disk and USB policy on every AC transition, adopted for one
  keybind.
- **asusctl is ASUS by construction.** It does toggle without a password,
  through a D-Bus policy on group membership, but it is in no Fedora repository
  (the copy this machine once had came from Terra) and in no Ubuntu archive at
  all, and on the EliteBook it could never be the answer. A Terra row in the
  roster for one key.
- **UPower is already running and already authorised.** Measured here:
  `pkcheck --action-id org.freedesktop.UPower.enable-charging-limit --process $$`
  exits 0, in a session `loginctl` reports as
  `Active=yes Type=wayland Remote=no`, because the shipped policy sets
  `allow_active=yes` on that action. The daemon does the sysfs write as root;
  the user needs no write access to the attribute and no rule of ours.

So the repo's only `sudo` is not replaced with a better `sudo`. It is deleted.

### 3. Feature 1: one file instead of two, and UPower does the restoring

`docs/install.md` gains a manual step creating
`/etc/udev/hwdb.d/61-battery-local.hwdb`:

```
battery:*:*:dmi:*
 CHARGE_LIMIT=_,60
```

followed by `systemd-hwdb update` and
`udevadm trigger -v /sys/class/power_supply/BAT0`. The route is documented by
UPower itself, in the header of the `60-upower-battery.hwdb` it ships, and the
`_,60` form sets the end threshold alone, which matches
`ChargeThresholdSettingsSupported = 2` as read from the running daemon. Without
the override the pair is the shipped default 75/80.

UPower persists the state in `<state_dir>/charging-threshold-status` and
re-applies it at coldplug, so this one file replaces both
`battery-threshold.service` and `/etc/battery-threshold-mode`. The ZenBook's
four existing artifacts, the script in `/usr/local/bin`, the sudoers rule, the
unit and the state file, are removed by hand; that removal is a manual step for
the spec, and it is where the repo stops having a `sudo` in it.

### 4. Feature 2: `.config/sway/scripts/battery-charge-limit`

Tracked, with a bats suite beside its three neighbours. It goes to
`.config/sway/scripts/` and not `.local/scripts/` on the ground
[06](06-config-assumptions.md) already laid for the screenshot script: it is
Desktop-only, invoked by path and never typed, and stage 1 of 06's rule binds
there, so it may assume `libnotify` from the roster instead of probing it away.

The name changes. `battery-threshold-toggle` describes neither what the script
now touches nor what it now does: the percentage lives in the hwdb, the script
turns a limit on and off, and after the decision below it has two verbs. The
noun names the file, the verb is a required argument, so both call sites read as
what they are:

```
bindsym Control+Alt+p exec ~/.config/sway/scripts/battery-charge-limit toggle
exec ~/.config/sway/scripts/battery-charge-limit restore
```

- `toggle` reads the `ChargeThresholdEnabled` property and calls the
  `EnableChargeThreshold` method with its inverse, then notifies either way. The
  two names are not the same thing: the property is the readable state, the
  method is the only way to set it, and there is no method that flips it.
- `restore` sets it true at session start, so a forgotten full-charge state is
  undone at the next login rather than persisting indefinitely.

The guarantee is deliberately that narrow. A full-charge state does outlive the
session it was set in: it survives logout and shutdown, because UPower restores
it at coldplug and nothing runs at session end to stop it. It cannot survive the
**next** session, which is the bound that matters, because the state the design
is defending against is the forgotten one, and forgetting is measured in weeks
while a login happens on every boot. An end-of-session restore was considered
and rejected: shutting down with the cap lifted is what somebody about to travel
actually wants, and a logout hook would undo the thing they just asked for.

`restore` exists because UPower is sticky where this repo wants self-reverting.
The alternative was a two-state toggle whose "full" setting survives a reboot,
and its failure mode is silent and long-lived: the cap is off for months, the
battery is the thing that pays, and nothing ever says so. The reverting design's
failure mode is that a reboot costs one keystroke, which is visible immediately.
The state file disappears with it, because there is no second state to record.

**The device is enumerated, never named.** `EnumerateDevices`, then the device
whose `ChargeThresholdSupported` is true. The property is its own filter,
measured here:

```
$ busctl --system call org.freedesktop.UPower /org/freedesktop/UPower \
    org.freedesktop.UPower EnumerateDevices
ao 5 "/org/freedesktop/UPower/devices/battery_BAT0" …

/org/freedesktop/UPower/devices/battery_BAT0                  Type=2   Supported=true
/org/freedesktop/UPower/devices/battery_hid_…_battery_7       Type=10  Supported=false
/org/freedesktop/UPower/devices/line_power_AC0                Type=1   Supported=false
/org/freedesktop/UPower/devices/line_power_ucsi_…_USBC000o001 Type=1   Supported=false
/org/freedesktop/UPower/devices/line_power_ucsi_…_USBC000o002 Type=1   Supported=false
```

Exactly one of five answers true. The other enumerated device that carries a
cell is not even a battery to UPower: `Type=10` is `tablet`, and `upower -i`
names it `ELAN9008:00 04F3:2D4B Stylus`. `GetDisplayDevice` is a dead end,
measured too: the composite device carries the whole interface and reports
`ChargeThresholdSupported=false`, so the one-call shortcut does not exist. A
hard-coded `battery_BAT0` could refuse on the EliteBook because the battery is
named differently there, which would be a lie about the hardware rather than a
statement about it.

**The client is `busctl`.** It ships inside the `systemd` package on both
distros, which is the one package neither of them can be without:
`rpm -qf "$(command -v busctl)"` answers `systemd-259.9-1.fc44` here, and
packages.ubuntu.com lists `/usr/bin/busctl` under `systemd` for noble. So it
needs no roster row. It still gets a precondition check on `PATH` like every
other script here: `AGENTS.md` mandates one, and 06's stage 1 forbids probing a
promise away, not validating it. `gdbus` comes from `glib2` instead,
`rpm -qf "$(command -v gdbus)"` answering `glib2-2.88.3-1.fc44`, and
`dnf repoquery --installed --whatrequires glib2 | wc -l` counts 385 installed
packages that pull it in. It is on this machine as somebody else's dependency
and belongs to no promise this repo makes, exactly the class of silent
freeloader 06 caught at `jq`.

**The test seam is `busctl` itself.** Because the script talks to a command
rather than writing a path, the suite stubs it on `PATH` like
`wait-for-vpn.bats` stubs `protonvpn` and `nmcli`, and no override variable has
to be invented to make the script testable.

### 5. `toggle` notifies, `restore` says nothing

06's rule is that a guard which refuses notifies, "because the hole it leaves
says nothing about why it is there". Read for its reason rather than its words,
it does not reach `restore`: at session start nobody asked for anything, so
nobody is looking at a hole, and on a machine that will never support the
feature the rule as written would mean a popup at every single login. The
keystroke is the case where a human is waiting for a result, and it notifies on
both outcomes, the success included, because the entire visible effect otherwise
is a number in a root-owned file that displays nowhere.

Both branches write to stderr and exit non-zero on refusal, per `AGENTS.md`, and
sway's `exec` children put that in the journal under the script's own name, as
06 measured at waybar and fcitx5. The German strings of the old script go;
everything written down is English.

### 6. The EliteBook gets a paragraph, not a ticket

`hp-wmi` exposes neither `charge_control_end_threshold` nor
`charge_control_start_threshold`. This is not partial or model-dependent
support: the driver has no battery hook and no `charge_control` symbol at all,
and a scan of every module shipped for kernel 7.2.5 finds the attribute in
eleven drivers, none of them HP. The RFC in flight for HP machines deliberately
proposes `CHARGE_BEHAVIOUR` instead and states "do not synthesize
charge_control_*_threshold properties in the kernel", so even success upstream
would not produce the property this design reads.

No ticket, because its only blocker is hardware nobody on this map can reach,
and a map whose last ticket is the handoff must not bind that handoff to a
business trip. Instead `docs/install.md` carries the commands that settle it on
an HP machine, which the survey spells out in full. The difference this buys
over silence is the difference between a closed and an open question: the
keystroke says "not here", the commands say why not.

### 7. No new vocabulary

The ticket asked whether a hardware difference needs its own place in the
language. It does not, and the term it needs is one 06 has already drawn.
Reading `ChargeThresholdSupported` and then declining to act is a **precondition
check**, not a Capability Probe: 06 separates them by what the script does with
the answer, "a precondition check refuses ... the script's behaviour does not
change; it only does not happen", against a probe that adapts and produces a
result either way. This script produces no result on an unsupported machine, so
it is the first of the two, and the fact that its condition is read over D-Bus
rather than with `command -v` changes nothing about which it is.

That is the whole vocabulary answer. The reasoning of
[01](01-name-the-distro-divergence.md) against a Distro Marker applies
unchanged: a term nobody would read is not a term. What this ticket adds is a
second instance of a pattern 06 already named, not a pattern of its own.

### 8. What this corrects elsewhere

- **The roster gains an `upower` row.**
  `dnf repoquery --installed --whatrequires upower` returns nothing on the
  reference machine: the daemon stands alone, pulled in by the spin rather than
  by anything this repo installs. The whole design rests on it running, so under
  [04](04-package-set-form.md)'s rule it has to be promised, exactly as 06 had
  to add `jq`. `libnotify` is already on the roster and needs nothing.
- **[08](08-completeness-check.md) gains a candidate it did not have**: whether
  the hwdb override is in place, observable without root by reading
  `ChargeEndThreshold` off the running daemon. Whether the check takes it is
  08's decision, not this one; the boundary between "the packages are present"
  and "the machine is configured" is the thing 08 draws.
- **[05](05-install-route-and-manual-steps.md) gains two manual steps**, the
  hwdb override and the removal of the ZenBook's four legacy artifacts, and a
  short HP paragraph. **[09](09-spec-and-build-tickets.md) carries all of it**,
  because none of it is visible in the tickets it corrects.

### 9. What was measured, and where it stops

Everything below ran on the ZenBook in the resolving session, as the user.

```
$ pkcheck --action-id org.freedesktop.UPower.enable-charging-limit --process $$
$ echo $?
0
$ busctl --system introspect org.freedesktop.UPower \
    /org/freedesktop/UPower/devices/battery_BAT0
.ChargeThresholdSupported          property  b  true
.ChargeThresholdEnabled            property  b  false
.ChargeEndThreshold                property  u  80
.ChargeThresholdSettingsSupported  property  u  2
```

The one claim no read could settle, that the call actually goes through, was
settled by running it with the operator's explicit consent and reverting
afterwards:

```
before     Enabled=false  End=80  sysfs=60
$ busctl --system call org.freedesktop.UPower \
    /org/freedesktop/UPower/devices/battery_BAT0 \
    org.freedesktop.UPower.Device EnableChargeThreshold b true
                                    (no error, no prompt, no password)
after      Enabled=true   End=80  sysfs=80
$ … EnableChargeThreshold b false
reverted   Enabled=false  End=80  sysfs=100
```

Two things fall out of it. An ordinary session's call is accepted, and `false`
writes **100** rather than restoring a previous value, so the boolean's two
states are exactly the two states this design wants once the hwdb override makes
the enabled one 60.

**What that block does not prove, and what does.** Reading the sysfs attribute
back is not a hardware observation: `asus-wmi` keeps no way to ask the firmware,
so the value returned is the driver's own cached variable, "There isn't any
method in the DSDT to read the threshold, so we save the threshold". The block
above therefore shows the daemon and the driver accepting the write, and nothing
more. The hardware observation is separate and comes from the charge counters,
which the embedded controller does own. At the start of the session the machine
sat plugged in at `capacity=60` with `status=Not charging` and
`energy_now=41013000`; afterwards, the threshold having been above 60 only
during the window above, it reported `capacity=100` with
`energy_now=energy_full=68902000`. The cell charged past a cap that had been
holding it, which is the enforcement the design depends on.

The cost of that proof is recorded rather than hidden: the battery is left full.
The threshold was put back to 60 with the old `sudo battery-threshold-toggle`,
the last useful thing that rule will ever do, but an embedded controller
enforcing a cap only declines to charge and never discharges to reach it, so the
cell stays at 100 until normal use brings it under 60.
