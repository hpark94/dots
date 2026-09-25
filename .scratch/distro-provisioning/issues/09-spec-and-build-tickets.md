# 09 Turn the decisions into a spec and build tickets

**Type:** `task` (the handoff, and the last ticket on this map)

**Status:** resolved

**Blocked by:**
[07 The battery threshold keybind and its missing script](07-battery-threshold-keybind.md),
[08 A completeness check for a machine](08-completeness-check.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

Nothing, and that is what makes it the last one. Every decision this map exists
to make is settled by the time this ticket is takeable; what is left is carrying
them across the edge of the map, into the form `CLAUDE.md` requires of large
work: a `spec.md`, then numbered build tickets under
`.scratch/<feature>/issues/`, each sliced to fit one session, each read by a
fresh session as its task statement.

It is a `task` because it does rather than decides. It is not the build: it
writes no deployed file, no `docs/install.md`, no `CONTEXT.md` entry, no
`packages/roster.md`. It writes the handoff, and the session that writes it
builds nothing.

### What it must carry

1. **The decisions, as requirements rather than as arguments.** A build session
   reads a ticket, not a map. What 01, 04, 05, 06, 07 and 08 decided has to
   arrive in the spec in a form that can be checked off, with the reasoning left
   behind in the ticket it came from and linked, not copied.
   [02](02-package-availability-survey.md) and
   [03](03-fedora-reference-inventory.md) are different in kind: both say they
   decide nothing, so their findings enter the spec as linked inputs and never
   as requirements of their own.
2. **The corrections that live in only one place.**
   [06](06-config-assumptions.md) corrected two already-resolved tickets, and
   neither correction is visible in the ticket it corrects: `packages/roster.md`
   gains a `jq` row; `packages/optional.md` is a new file holding the optional
   tier, out of reach of [04](04-package-set-form.md)'s install line; and
   [05](05-install-route-and-manual-steps.md)'s phase 1 step 2 is marked
   optional and paired with an optional install line of its own. A spec
   assembled from 04 and 05 alone would be wrong on all three.
3. **The artifacts that were specified and deliberately not written.**
   [01](01-name-the-distro-divergence.md) holds the verbatim `CONTEXT.md` entry
   for **Distro Fact** and an `_Avoid_` line for **Capability Probe**, plus
   **ADR-0011 `the-deployed-tree-never-reads-the-distro`**.
   [06](06-config-assumptions.md) holds two more sentences and another `_Avoid_`
   line for **Capability Probe**, separating a probe that adapts from a
   precondition check that refuses. Both were held back so that later tickets
   could correct them; this is where they land.
4. **The slicing.** Which changes can be one session and which cannot. The
   packaging artifacts, the install document, the glossary and ADR, the
   screenshot script under `.config/sway/scripts/`, the mise entries for clangd
   and clang-format, whatever 07 decides about the battery keybind, and 08's
   completeness check are not one change, and the order between them is not
   arbitrary: [05](05-install-route-and-manual-steps.md)'s install line reads
   `packages/roster.md`, so that file has to exist before the install document
   can be checked against it. Whatever else depends on it, 08's check included,
   is for 07 and 08 to settle and for this ticket to take as given.
5. **What is untracked and per machine.** Removing `~/.local/llvm` and the
   `PATH` lines from `~/.env` touches no file in this repo and belongs in the
   spec as a manual step, next to the ones
   [05](05-install-route-and-manual-steps.md) already collected.

### Where this ticket ends

With the paths of the spec and its build tickets, and nothing built. The map is
then done: there is nothing left to decide before someone goes and does the
thing.

## Answer

The handoff is written: [the spec](../../desktop-install/spec.md) and eight
build tickets under `.scratch/desktop-install/issues/`. Nothing is built.

### The slicing

| Ticket                                                                                                                   | Blocked by | Kind              |
| ------------------------------------------------------------------------------------------------------------------------ | ---------- | ----------------- |
| [01 Distro Fact, a sharper Capability Probe, and ADR-0011](../../desktop-install/issues/01-distro-vocabulary-and-adr.md) | none       | `ready-for-agent` |
| [02 The package set](../../desktop-install/issues/02-package-set.md)                                                     | none       | `ready-for-agent` |
| [03 Screenshot keybinds become a tested script](../../desktop-install/issues/03-screenshot-script.md)                    | none       | `ready-for-agent` |
| [04 `battery-charge-limit`, the charge limit without sudo](../../desktop-install/issues/04-battery-charge-limit.md)      | none       | `ready-for-agent` |
| [05 clangd, clang-format and clang-tidy from mise](../../desktop-install/issues/05-clang-tools-from-mise.md)             | none       | `ready-for-agent` |
| [06 `completeness-check.sh`](../../desktop-install/issues/06-completeness-check.md)                                      | 01, 02     | `ready-for-agent` |
| [07 `docs/install.md`, and README points at it](../../desktop-install/issues/07-install-document.md)                     | 02, 06     | `ready-for-agent` |
| [08 Retire the ZenBook's hand-built pieces](../../desktop-install/issues/08-zenbook-migration.md)                        | 04, 05, 07 | `ready-for-human` |

The order follows from what reads what: the check and the install document both
read `packages/roster.md`, the document names the check in its last line, and
the migration removes what the other seven replace. The untracked steps
(`~/.local/llvm` and `~/.env`, the four legacy battery artifacts) are one
`ready-for-human` ticket rather than lines in `docs/install.md`, because they
apply once to one machine and a bare install has nothing to remove.

`README.md` has no ticket of its own: its two sentences from 05 section 9 ride
with the install document in 07.

### Two gaps closed here, with the operator

- **`clang-tidy`** was the third tool from the LLVM tarball: `nvim-lint.lua:15`
  runs it, and 06 moved only clangd and clang-format. It goes to mise as
  `"pypi:clang-tidy" = "22.1.8"`, on 06's own argument (rootless, both Roles).
  The version was read from `mise ls-remote pypi:clang-tidy`.
- **`imv`** was handed from 06 to 08, and 08 did not take it. It gets the row
  `imv-wayland | imv | imv`: 04's first clause takes the survey's derivation,
  which includes config-only packages, and `imv-wayland` is the command both
  distributions ship, so 08's check does not report a false miss on Ubuntu.

### Where the corrections landed

Each correction that 09's question listed as visible in only one place is now a
requirement in the spec: the `jq`, `upower` and `imv` rows,
`packages/optional.md` and ProtonVPN as an optional step, no `texlab` row, and
the three glossary texts, verbatim. ADR-0011 has no text to carry: 01 specified
its content, and the spec points the build at 01 sections 2 to 5. The untracked
one-off steps are in the spec's "Manual steps on the reference machine" and in
ticket 08.
