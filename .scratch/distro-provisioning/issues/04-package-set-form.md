# 04 Where the package sets live and in what form

**Type:** `grilling`

**Status:** resolved

**Blocked by:**
[01 Name the distro divergence](01-name-the-distro-divergence.md),
[02 Program roster and package availability survey](02-package-availability-survey.md),
[03 What the Fedora reference machine actually has](03-fedora-reference-inventory.md)

**Map:** [From a clone to a working Desktop on Fedora and Ubuntu](../map.md)

## Question

The map has already settled that `bootstrap.sh` stays sudo-free and that
installing packages is a step in front of it. What remains is the **tracked
artifact**: what does the repo hold, and what does the operator do with it?

### To settle

1. **The shape.** One list per distro, or one list with per-distro annotations?
   Plain text pasted into a `dnf install`/`apt install` line, or a script the
   operator runs under sudo? A script is still sudo-free from `bootstrap.sh`'s
   point of view, so "copy-paste" and "a script" are both open.
2. **Where in the repo.** `.stow-local-ignore` decides whether a new top-level
   path is deployed into `${HOME}` or stays repo-local. Package sets are
   repo-local, so the ignore file has to grow a line; check that against `docs/`
   and `.scratch/`, which already sit there.
3. **The boundary rule.** What belongs in a package set and what is a manual
   step in [05](05-install-route-and-manual-steps.md)? The obvious candidate
   rule: anything installable with one command from a repository that is already
   enabled belongs in the set; anything that first requires enabling a foreign
   source, logging in, or answering a prompt is a manual step. Test that rule
   against the survey's actual findings rather than accepting it.
4. **Flatpaks.** A second set, or the same set with a marker? `flatpak install`
   needs no root for a `--user` install, which makes Flatpaks structurally
   different from native packages: they could in principle be the one packaging
   step `bootstrap.sh` is allowed to take. Decide whether that is wanted or
   whether the sudo-free rule is really a "no installing at all" rule.
5. **Names diverge, and not only package names.** The Ubuntu package `imv`
   installs its binary as `/usr/bin/imv-wayland`, so `dpkg -S` finds the package
   under the same name Fedora uses while `command -v imv` fails. A package set
   that lists names must say which kind of name it lists, because
   [08](08-completeness-check.md) reads that same list and a wrong answer there
   is a silent one.
6. **Ubuntu versus Fedora content.** The survey will show programs available on
   one side and not the other. Does a package set list a program the other
   distro cannot have, and if so how is that marked?

## Answer

### 1. What a package set lists, in two clauses

**Clause one: the roster, not the machine.** The set lists what the tracked
files invoke, exactly as [the survey](../research/02-package-availability.md)
derived it, and not what the reference machine happens to have. The inventory's
section 8 is the reason: the ZenBook's 443 user-installed packages carry `gimp`,
`hashcat`, `wireshark`, the winapps dependencies, `@virtualization` and
`texlive-scheme-full`, which is 5081 packages for two binaries this repo
actually calls. A set derived from the machine would demand all of it on every
new machine, and [08](08-completeness-check.md) would then report a correct
machine as incomplete. The daily applications are not lost by this rule:
librewolf, thunderbird, obsidian and keepassxc are in the roster because
`.config/sway/config` launches them.

**Clause two: what the toolchain this repo installs needs in order to build.**
No tracked file invokes a compiler, but mise builds cargo and pipx tools and
nvim compiles treesitter parsers on first use, so a machine without a compiler
fails at the first grammar rather than at install. This is the second clause and
there is no third: a clause for "what one also likes to have" would turn the set
back into the machine's list that clause one just refused.

### 2. The boundary rule has two sides, and the split is the verb

> **The set is what one `dnf install` or `apt install` line installs, given the
> sources that [05](05-install-route-and-manual-steps.md) has already enabled.
> Everything that is not a plain package install is a manual step in 05.**

The rule separates **enabling a source** from **installing out of it**, and that
is what makes it usable. `ghostty` and `satty` are ordinary Fedora package names
once Terra is enabled; `librewolf` and `proton-vpn-cli` are ordinary names once
their upstream repositories are, and the second is itself a case for the first
column, because the command the sway config calls is `protonvpn`. Enabling those
four sources is 05's, installing from them is the set's, and the map's
"third-party sources are documented, never scripted" already governs the first
half.

What the rule pushes to 05, from the survey and the inventory: the
`dnf swap ffmpeg-free ffmpeg --allowerasing` and its `dnf update @multimedia`
follow-up, the satty binary on Ubuntu where no repository carries it, and the
cargo build of `texlab` (section 7). The clangd tarball is not decided here and
stays [06](06-config-assumptions.md)'s, where it hangs together with the `PATH`
lines in `~/.env`.

A third side, "mise owns it", was weighed and dropped; section 7 records why.

### 3. The artifact: one table, rows keyed by what proves the program is there

`packages/roster.md`, a single Markdown table, flat and sorted by the first
column, three columns:

| binary | fedora | ubuntu |
| ------ | ------ | ------ |

**The first column is a probe target, not a package name.** It names the command
the machine must have, which is the one thing a later check can ask about
without asking the distribution anything. The survey's 27 rows where the package
name does not name the binary are why the column exists at all, and this is the
answer to the ticket's item 5: the table carries **both** kinds of name, in
separate columns, and neither column is ever read as the other.

**Rows with no command on `PATH` carry `-` in the first column and stay in the
table.** `sway-systemd`, the two portals, the fcitx5 IM modules,
`python3-i3ipc`, the zathura PDF backend and `glibc-devel` all have to be
installed and none of them leaves a command a check could call: `sway-systemd`'s
files sit under `/usr/libexec`, the IM modules are libraries the toolkits load,
and `python3-i3ipc` is an import. Giving them a path instead
(`/usr/libexec/sway-systemd`) was refused: the path is Fedora's, so it
re-imports into the first column exactly the divergence the other two columns
exist to absorb.

**Package names may repeat down a column.** `wl-clipboard` stands in the two
rows for `wl-copy` and `wl-paste`, and `build-essential` in the four rows of
section 6, because one package can carry several commands and the two
distributions split them differently. The extraction line below collapses
duplicates with `sort -u`, so this never depends on how dnf or apt treat a
repeated argument. The sharpest case of the same kind, `clang-tools-extra`
against Ubuntu's three separate packages, is deliberately not used as the
example here: whether the clang tools come from a package at all is still
[06](06-config-assumptions.md)'s, since the reference machine takes them from a
tarball.

**`-` in a package column means this install line does not install it, and
[05](05-install-route-and-manual-steps.md) has the route.** It is deliberately
not "no package exists here", and it does not promise a route either. Three
different cases carry the same marker: `ffmpeg` on Fedora is a real RPM Fusion
package that arrives through `dnf swap` instead of the shared line, satty on
Ubuntu has no package anywhere, and `sway-systemd` on Ubuntu has nothing to
install at all, because the sway config already falls back to
`dbus-update-activation-environment`. The marker follows the boundary rule of
section 2, which sorts by the form of the command and not by whether something
exists.

One marker, not two, and no fourth column naming the route: a route column would
be a second copy of what 05 has to write anyway, and two copies drift. The cost
is real and accepted: from the table alone you cannot tell those two cases
apart. That answer is one file away.

**The table is Desktop.** One sentence in the header says so, and there is no
Role column: the map took Headless out of the packaging question, and a column
holding one value in every row is a column nobody reads.

Markdown rather than TSV, because every other data and prose file here is
Markdown, prettier formats it, and the diff stays legible. Parsing stays safe
because package names contain no whitespace. The install lines, which live in
05:

```sh
sudo dnf install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $3); if ($3 !~ /^-*$/ && $3 != "fedora") print $3}' packages/roster.md | sort -u)
sudo apt install $(awk -F'|' 'NF>4 {gsub(/[ `]/, "", $4); if ($4 !~ /^-*$/ && $4 != "ubuntu") print $4}' packages/roster.md | sort -u)
```

Proven rather than asserted, against a fixture written in a scratch directory
and formatted with this repo's own `prettier -w` first: the alignment padding
prettier inserts is stripped by the `gsub`, the header row and the `| --- |`
separator are both dropped by the `/^-*$/` test that also drops the `-` marker,
prose lines outside the table never reach it because they have no pipes, and the
nine fixture rows yield seven distinct Fedora names and four distinct Ubuntu
names, with the repeated ones collapsed once each.

Four sentences the file's header has to carry, because each one is a promise the
readers depend on: the set is Desktop; the first column is a command name and
not a package name; a `-` in a package column means this install line does not
install it, while a `-` in the first column means the row leaves no command on
`PATH`; package names may repeat.

### 4. Where it lives

`packages/` at the repo root, with `^/packages` added to `.stow-local-ignore`
next to `^/docs` and `^/templates`. Stow deploys every top-level path the ignore
file does not name, so the line is not optional, and it is exactly the price the
ticket's item 2 anticipated. Not `docs/`, although that would save the line:
this is data an install command reads, not prose a person reads, and `docs/`
holds prose and ADRs. Saving one line by blurring the only category the ignore
file maintains is a bad trade.

### 5. Flatpaks are a second list, and bootstrap installs none of them

`packages/flatpak.txt`, one application id per line, holding only the two ids
`.config/sway/config` actually launches: `org.mozilla.thunderbird` and
`md.obsidian.Obsidian`. The other five on the ZenBook are the operator's, not
the repo's, by clause one.

Separate from the table by construction: an application id is the same string on
both distributions, so a row in a distro-keyed table would claim a divergence
that does not exist. The map's "Flatpak, never snap" is what makes this list the
only route for thunderbird on Ubuntu, whose archive package is a snap transition
stub.

**`bootstrap.sh` does not install them**, although `flatpak install --user`
needs no root and was therefore the one packaging step it could structurally
have taken. The reason is not that bootstrap avoids the network or avoids
writing: it pipes `https://mise.run` into a shell, runs `mise install`, clones
tpm and syncs nvim's plugins, all of which fetch. The reason is the Role.
`bootstrap.sh` runs identically on Desktop and Headless, by its own header at
`bootstrap.sh:11`, and these two ids are compositor applications: installing
them from bootstrap would either put Thunderbird and Obsidian on a Headless
machine or force into bootstrap the Role branch it refuses to have. That keeps
the map's line intact for Flatpaks too, packaging in front of bootstrap and not
inside it. Whether the flathub remote is added per user or system wide is 05's,
not this ticket's.

### 6. The build toolchain is four rows, and the obvious group is the wrong one

| binary | fedora        | ubuntu            |
| ------ | ------------- | ----------------- |
| `gcc`  | `gcc`         | `build-essential` |
| `g++`  | `gcc-c++`     | `build-essential` |
| `make` | `make`        | `build-essential` |
| `-`    | `glibc-devel` | `build-essential` |

Ubuntu keeps the metapackage a person would type by hand, repeated down the
column exactly as `wl-clipboard` is across its two rows. Fedora gets explicit
names, for two measured reasons. `dnf group info development-tools`, the name
that suggests itself, lists `gettext`, `git`, `doxygen`, `subversion` and
`patch` and **no compiler at all**; the actual counterpart is `c-development`,
which is not installed on the reference machine and whose mandatory list pulls
`gdb`, `strace`, `bison`, `flex` and `libtool` alongside the four wanted
packages. And a group id is not a package name: `@c-development` in that column
would break the promise the column makes to the install line and to 08, and apt
has no counterpart for it.

The scope stays at four. `cmake` and `ninja` are already in
`.config/mise/config.toml`, so a row for either would be a second source for one
tool; `python3-devel` is needed only to build an extension from source, and the
repo's pipx entries (`pyright`, `ruff`) arrive as wheels. What is genuinely
missing announces itself as a loud build failure, and then the table grows by
one row.

**Headless gets nothing, not even a sentence in 05.** The map put package
installation on Headless machines out of scope, so the toolchain clause reaches
as far as the table does and no further. The consequence, that mise is left with
prebuilt binaries on a machine whose compiler nobody installed, is a property of
that scope ruling rather than a step anybody writes down here.

### 7. texlab: mise was weighed and refused, cargo from the git tag

Measured, not recalled:

- `mise registry | grep -ci texlab` returns `0`, so there is no registry entry.
- `mise ls-remote 'github:latex-lsp/texlab'` returns up to `5.26.0`. The
  `github:` backend is what replaces the deprecated `ubi:`.
- `mise ls-remote 'cargo:texlab'` returns up to `4.3.2`. The project no longer
  publishes to crates.io, so the cargo backend is two major versions stale and
  worse than Ubuntu's archive package at 5.25.1.
- The ZenBook's `~/.cargo/.crates.toml` records
  `texlab 5.26.0 (git+https://github.com/latex-lsp/texlab?tag=v5.26.0)`, so the
  working machine was never on crates.io either.

**`texlab` is a manual step in 05**, in the form the reference machine already
uses and with the tag pinned:

```sh
cargo install --git https://github.com/latex-lsp/texlab --tag v5.26.0 --locked
```

Untagged, two machines built on two days get two different language servers; via
crates.io they get 4.3.2. The step carries an ordering statement that 05 has to
write down: it needs mise's `rust`, so it runs **after** `bootstrap.sh`, which
makes it the only manual step that does not come before it.

**With that, the boundary rule's third side is dropped.** "Dev tooling mise can
carry belongs to mise" had exactly one candidate, and the candidate left. A rule
with no case is speculation, and clause two of section 1 shows how a clause is
added when a real case appears. Recorded here so the next reader does not derive
it again and land on `github:latex-lsp/texlab`, which is the tidier looking
route. Nothing technical forbids it:
`mise tool 'github:latex-lsp/texlab@5.26.0'` resolves that backend at that exact
version, so the backend takes an exact version like any other. It was refused as
a choice, not as an impossibility, and the reference machine is already on the
cargo route.

### 8. Facts this ticket measured in passing

- **The reference machine's only C++ compiler is an untracked one.**
  `command -v g++` and `command -v c++` are both empty on the ZenBook and
  `rpm -q gcc-c++` reports it not installed, while `gcc`, `make`, `automake`,
  `pkgconf` and `glibc-devel` are all there as dependencies rather than as a
  group. `command -v clang++` does answer, with
  `~/.local/llvm/LLVM-22.1.3-Linux-X64/bin/clang++`: the same hand-extracted
  tarball that supplies clangd, reachable only through the `PATH` lines in the
  untracked `~/.env` that [06](06-config-assumptions.md) is already looking at.
  So the machine can compile C++ and does it with a compiler no package owns and
  no tracked file puts on the path. That is the argument for the `g++` row, and
  it is a narrower one than "there is no C++ compiler here".
- **`development-tools` is a trap.** It is the group whose name suggests a
  compiler and whose content is version control and documentation tools. Written
  down because the wrong mapping is the one a reader reaches for first.

### What this hands the downstream tickets

- [05](05-install-route-and-manual-steps.md): the manual steps this ticket
  pushed there, namely enabling Terra, RPM Fusion, LibreWolf and ProtonVPN, the
  `ffmpeg` swap, satty on Ubuntu, the pinned cargo build of texlab after
  bootstrap, and the flathub remote; plus the two install lines in section 3.
- [06](06-config-assumptions.md): untouched by this ticket. clangd stays open
  there, and so does whether the `PATH` lines in `~/.env` are the route to
  reproduce. The table's first column is what a Capability Probe would look at,
  which is the same asymmetry 06 is measuring on `imv` and `imv-wayland`.
- [08](08-completeness-check.md): the table hands it three kinds of name in
  separate columns, plus the flatpak list, and which of them a check reads stays
  its own decision. What does bind it: a `-` in the first column has no command
  name to probe, so a check built on that column alone would pass on a machine
  missing the portals, the IM modules and the PDF backend; a package column may
  repeat a name across rows; and the table is Desktop only, so nothing in it
  says what a Headless machine should have. Whether a completeness check runs
  there at all is 08's own question.
