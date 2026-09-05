# 06 What the configs must stop assuming

**Type:** `grilling`

**Status:** open

**Blocked by:**
[01 Name the distro divergence](01-name-the-distro-divergence.md),
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Installing the right packages fixes the machine that is missing them. It does
not fix a config that assumes a program which the other distro cannot have at
all, or a path that exists on one machine only. Which of the repo's assumptions
have to go, and by which rule?

The known cases, all found while charting, on the Ubuntu machine:

- **`imv`** is installed on the Ubuntu machine, but as `/usr/bin/imv-wayland`:
  the package carries Fedora's name while the binary does not, so
  `command -v imv` fails on a machine that has it. Nothing in the repo calls
  `imv` by name today, which is the only reason this has stayed invisible.
- **`satty`** sits in `/usr/local/bin` and belongs to no package.
- **`protonvpn connect --p2p`** is exec'd unconditionally at sway start.
  `wait-for-vpn` already treats protonvpn as a Capability Probe, so the repo
  contradicts itself: one file assumes the program, another handles its absence.
- **`fcitx5 -d`**, **`lxpolkit`**, **`swaybg`**, **`cliphist`** are likewise
  exec'd unconditionally.
- **`$monitor`** is an Iiyama serial number, and
  [`machine-independent-sway`](../../machine-independent-sway/spec.md) already
  decided that pointing at absent hardware is harmless. That precedent is the
  one to argue with: when is a broken `exec` harmless, and when is it a hole?

### To settle

1. **The rule.** For each assumption: absorb it into the package set so it
   becomes true, guard it with a Capability Probe, or leave it to fail because
   failing is harmless. What decides? A `sway exec` that fails costs nothing
   visible; a keybind that fails costs a keystroke and silence.
2. **Silent failure.** `machine-independent-sway` fixed a screenshot keybind
   that failed silently and lost the screenshot. The same shape probably repeats
   here. Which of the cases above fail silently, and does that change the answer
   for them?
3. **Whether a guard belongs in sway's config at all.** Sway's config language
   has no conditionals; the only guard available is moving the `exec` behind a
   shell script, which is what `wait-for-vpn` and `sway-start-on-workspace`
   already are. Multiplying one-line wrapper scripts is a cost, and this ticket
   should decide how much of it is acceptable rather than accepting it per case.
