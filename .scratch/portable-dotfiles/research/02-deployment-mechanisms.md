# Deployment mechanism survey

**Resolves:** [02 Deployment mechanism survey](../issues/02-deployment-mechanism-survey.md)

**Map:** [Portable dotfiles](../map.md)

**Date:** 2026-07-21

**Status:** facts only. This document does not choose. The choice is
[05 Choose the deployment mechanism](../issues/05-choose-deployment-mechanism.md).

## Scope and method

Five candidates: GNU Stow with multiple packages, chezmoi, yadm, a bare git repo driven by
`--git-dir`/`--work-tree`, and a hand-rolled bootstrap script. Each is assessed on the five axes the
ticket names: templating, conditionals, machine-local state and secrets, bootstrap cost on a fresh
headless Linux remote, and update/drift behaviour.

Targets held throughout: the Fedora/sway host and headless Linux SSH remotes with root. macOS,
containers, and rootless remotes are out of scope per the map and are not evaluated.

### What counts as primary here

| Source | How it was read |
| --- | --- |
| GNU Stow 2.4.1 info manual | `/usr/share/info/stow.info.gz` on this host, the manual the man page calls "the definitive documentation" |
| GNU Stow 2.4.1 man page | `man stow` (`stow(8)`) on this host |
| GNU Stow source | `/usr/bin/stow`, `/usr/share/perl5/vendor_perl/Stow.pm`, `/usr/share/perl5/vendor_perl/Stow/Util.pm` |
| Stow behaviour | executed directly against an isolated scratch tree, see [Appendix A](#appendix-a-stow-behaviour-executed-not-inferred) |
| chezmoi | official docs at `chezmoi.io`, plus the actual install script served at `get.chezmoi.io` |
| yadm | official docs at `yadm.io`, plus `yadm.md` (the man page) and the `yadm` script in `yadm-dev/yadm` |
| git | `man git`, `man git-config`, `man git-merge`, `man git-clone`, `man git-update-index`, `man git-sparse-checkout` on this host (git 2.55.0) |
| mise | official docs at `mise.jdx.dev`, plus `mise registry` executed on this host (mise 2026.7.7) |
| Packaging | `dnf` executed against this host's configured repos (Fedora 44); `packages.debian.org` for Debian |

Per repo style, no em dashes below.

## Repo baseline

Facts about `/home/hpark/dots` as it stands, established by reading it. These frame the cost of
every candidate.

- **The whole repo root is one Stow package.** `.stow-local-ignore` sits at the repo root, and the
  Stow manual specifies that this file is read "within any top level package directory". Its
  presence at the root is what makes the root the package. Everything not matched by the ignore
  list folds into `$HOME`.
- **The ignore list is doing package-selection work.** Beyond Stow's built-in defaults, it carves
  out `^/\.claude`, `^/CLAUDE\.md`, `^/\.scratch`, `^/CONTEXT.md`, `^/docs`, and `^/nvim`. These are
  static exclusions, identical on every machine, because the file is tracked.
- **There is no documented install procedure.** `README.md` is 24 lines and contains no occurrence
  of "install", "stow", "setup", or "bootstrap". Nothing anywhere in the repo records how to deploy
  it.
- **`mise` is the toolchain manager**, with one flat `[tools]` table of roughly 40 entries in
  `.config/mise/config.toml`, mixing shared dev tooling with host-weight entries.
- **Machine-local convention is copy-the-example.** `.gitconfig.example` is tracked; `.gitconfig` is
  listed in `.gitignore`. On this host the two files are byte-identical, so the convention in
  practice is "copy the example, then diverge if needed". `.gitignore` also excludes other
  machine-local state: `lazy-lock.json`, `.local/state/theme/`, `**/.claude/settings.local.json`.
- **Divergence today is resolved at runtime, not at deploy time.** `.tmux.conf:38` uses
  `if-shell 'test -n "$SSH_CLIENT"' 'source-file ~/.tmux.remote.conf'`, and `.envs.sh:4` branches on
  `if [[ -z "$SSH_CONNECTION" && -z "$SSH_TTY" ]]`. One tracked file, one deployed artefact, decision
  deferred to execution.
- **Three plugin managers already self-bootstrap, inconsistently.** `.zshrc:4-9` clones zinit if
  missing; `.config/nvim/lua/core/lazy.lua:1-22` clones lazy.nvim if missing;
  `.tmux.conf:58` runs `~/.tmux/plugins/tpm/tpm` but **nothing in the repo ever clones tpm**. That
  is an existing gap any candidate inherits.
- **A fresh `$HOME` is not empty.** `/etc/skel` on this Fedora host ships `.bashrc`, `.bash_profile`,
  `.bash_logout`, `.zshrc`, `.zprofile`, and `.config/`. On this very host, `.bash_profile` and
  `.bash_logout` are still real files from skel while `.bashrc` and `.zshrc` are symlinks into
  `dots/`. This matters directly for Stow, see below.

---

## 1. GNU Stow with multiple packages

Version on the Fedora host: 2.4.1-4.fc44, from the official `fedora` repo.

### 1.1 Templating: none, verified

The ticket asked for this to be confirmed against documentation rather than assumed. It is
confirmed, by exhaustive negative search rather than by absence of a mention:

- A case-insensitive grep for `templat`, `conditional`, `hostname`, `interpolat`, `{{`, `per-machine`,
  and `per-host` across the **entire** 2095-line GNU Stow 2.4.1 info manual returns **zero matches**
  (exit 1).
- The same grep across `/usr/bin/stow`, `Stow.pm`, and `Stow/Util.pm`, that is, the complete
  implementation, also returns **zero matches** (exit 1).

The manual's own table of contents is the positive form of the same fact. Stow's complete feature
surface is: Introduction, Terminology, Invoking Stow, Ignore Lists, Installing Packages, Deleting
Packages, Conflicts, Mixing Operations, Multiple Stow Directories, Target Maintenance, Resource
Files, Compile-time vs. Install-time, Bootstrapping, Reporting Bugs, Known Bugs. There is no node
for content transformation of any kind.

The reason is structural, not an omission. The manual describes Stow as "a symlink farm manager"
whose job is to make separate directories "appear to be installed in a single directory tree", and
states plainly: "Stow only creates relative symlinks." A symlink has no content of its own. One
tracked file cannot produce different content per machine because Stow never produces content at
all.

**Cost to read a year later:** zero, because there is nothing to read. There is no template language.

### 1.2 Conditionals: package selection only, verified

Confirmed: selective `stow <pkg>` is the full extent of it, and it is real but coarse.

- The man page's synopsis is `stow [ options ] package ...`, and "Each package given on the command
  line is the name of a package in the stow directory". Naming a subset of packages is therefore the
  supported way to deploy a subset of files. Verified by execution: with packages `shared` and
  `host` side by side, `stow -t <target> shared` linked only `.bashrc` and left `.swayrc` alone.
- The granularity is the package, not the file, and the discriminator is the argument you type, not
  a machine attribute. Stow itself never inspects the hostname, the OS, `$SSH_CONNECTION`, or
  whether Wayland is running. Something outside Stow must decide which package names to pass.

Two near-misses worth recording, because they look like conditionals and are not:

- **Ignore lists are static.** `.stow-local-ignore` holds "Perl regular expressions, one per line"
  matched against paths within the package. It is a tracked file, so it evaluates identically on
  every machine. It excludes files from every deploy, not from some deploys.
- **`.stowrc` is the one genuinely machine-local lever.** The manual: "Default command line options
  may be set in `.stowrc` (current directory) or `~/.stowrc` (home directory)", their effect "similar
  to simply prepending the options to the command line", and for repeatable options such as
  `--ignore`, "command line options and resource options are appended together". Crucially,
  `~/.stowrc` need not be tracked, so an untracked per-machine `~/.stowrc` carrying extra
  `--ignore` lines is a real per-machine skip mechanism. Its ceiling: "The options `-D`, `-S`, and
  `-R` are ignored in resource files. This is also true of any package names given in the resource
  file." So `~/.stowrc` can subtract files on a given machine but cannot select which packages get
  stowed. It also requires an untracked bootstrap step to place it, which is the same unsolved
  problem it is meant to solve.

### 1.3 Machine-local state and secrets

Stow has no concept of either. It has no encryption, no keyring integration, and no notion of a file
that should exist but not be tracked.

What it does have is the conflict rule, which is the mechanism the repo's `.gitconfig.example`
convention is quietly relying on. Per the manual: "If Stow needs to create a directory or a symlink
in the target tree and it cannot because that name is already in use and is not owned by Stow, then
a conflict has arisen." Verified by execution: a pre-existing real file at the target produced
`cannot stow ... over existing target .swayrc since neither a link nor a directory and --adopt not
specified`, followed by `All operations aborted`, with the target file left byte-identical.

So the working pattern is: track `X.example`, `.gitignore` the real `X`, exclude the real `X` from
the package, and have the user copy it. That is exactly what the repo does today. Stow contributes
nothing to it except staying out of the way, and it will not remind anyone the step was skipped.

Two options bear on this and are worth knowing precisely:

- `--adopt` is explicitly flagged in the man page: "Warning! This behaviour is specifically intended
  to alter the contents of your stow directory. If you do not want that, this option is not for
  you." It resolves a conflict by moving the machine's existing file **into the repo**, then linking.
  On a fresh remote that would import that remote's `/etc/skel` `.bashrc` into the dotfiles repo.
- Since version 2.0 Stow uses "a two-phase algorithm, first scanning for any potential conflicts
  before any stowing or unstowing operations are performed", and terminates "without making any
  modifications to the filesystem" if any are found. Conflicts are therefore all-or-nothing per
  invocation, not partial.

### 1.4 Bootstrap on a fresh headless remote

| Item | Finding |
| --- | --- |
| Runtime dependency | Perl. `rpm -q --requires stow` lists `/usr/bin/perl`, `perl(:VERSION) >= 5.6.0`, and core modules `Carp`, `Exporter`, `File::Copy`, `File::Find`, `File::Spec`, `Getopt::Long`, `POSIX`, `Scalar::Util`, `Text::ParseWords`. All are core Perl; no CPAN modules are required. |
| Compiler needed | No. Stow is "a combination of a Perl script providing a CLI interface, and a backend Perl module". |
| Single static binary | No, and it cannot be. It is interpreted Perl plus two `.pm` files that must be on `@INC`. Not curl-able as one file. |
| Fedora | Yes, official `fedora` repo, `stow-2.4.1-4.fc44`, noarch. |
| Debian/Ubuntu | Yes, all suites: bullseye 2.3.1-1, bookworm 2.3.1-1, trixie 2.4.1-2, forky 2.4.1-2, sid 2.4.1-2, arch `all`. |
| Installable by mise | **No.** `mise registry` on this host lists 990 tools; `stow` is not among them. mise's binary-fetching backends (`ubi`, `github`) resolve platform-labelled release binaries, which a Perl script tree is not. |

**The real bootstrap cost is not installing Stow, it is the conflict wall.** A fresh Linux `$HOME`
is populated from `/etc/skel`, which on Fedora 44 includes `.bashrc`, `.bash_profile`,
`.bash_logout`, `.zshrc`, and `.zprofile`. Every one of those that the repo also ships is a real
file blocking a real symlink, and because conflict detection is all-or-nothing, **a single collision
aborts the entire stow run**. The first `stow` on any fresh remote fails until those files are moved
or deleted. Nothing in the repo does that today, and there is no documented procedure that says to.

Also note the manual's own Bootstrapping chapter is about a different problem entirely (using Stow
to install Stow into `/usr/local`) and offers nothing for the dotfiles case.

### 1.5 Update and drift

This is Stow's strongest and its most surprising property, and it is a direct consequence of
symlinks.

**Verified by execution:** appending a line to the deployed file at the target caused the write to
land in the package file inside the repo. The target `.bashrc` was `lrwxrwxrwx ... -> ../pkgs/shared/.bashrc`,
and after editing "in place", the package file itself read `shared v1\nedited on the machine`.

Consequences:

- **Drift between deployed and tracked content is impossible for symlinked files.** They are the
  same inode. Editing `~/.zshrc` on a remote is editing the repo working tree. It shows up in
  `git status` immediately, and nothing needs to be re-imported.
- **Corollary: a remote edit is an uncommitted repo change on that remote.** Pulling is then a plain
  git operation and inherits git's protection: per `man git-merge`, "git pull and git merge will
  stop without doing anything when local uncommitted changes overlap with files that git pull/git
  merge may need to update."
- **Updating means `git pull`, and usually nothing else.** Changing a file's content requires no
  re-stow at all, because the symlink already points at it. Re-stowing is needed only when the set
  of files changes: adding a file needs `stow`, and removing one leaves a dangling symlink that
  needs `stow -R` (`--restow`, documented as "useful for pruning obsolete symlinks from the target
  tree after updating the software in a package").
- **Tree folding is a live hazard when packages are split.** The manual describes folding, where an
  entire subtree becomes one symlink, and "splitting open" when a second package needs the same
  directory. The man page also records the still-open empty-directory bug: if package `foo` has an
  empty `foo/bar` and package `quux` also has `bar`, then unstowing `quux` removes `targetdir/bar`
  even though `foo` needs it. The documented workaround is a `.placeholder` file. Splitting one
  package into several makes this reachable where it currently is not.

---

## 2. chezmoi

Model, from the docs: chezmoi maintains a **source state** (the git repo, by default under
`~/.local/share/chezmoi`) and computes a **target state** from it, then writes that into `$HOME`.
The source directory and the deployed files are distinct artefacts. This one design choice drives
every row below.

### 2.1 Templating: full, Go `text/template` plus sprig

Documented: "chezmoi uses the `text/template` syntax from Go extended with text template functions
from `sprig`", plus chezmoi-specific helpers. A file becomes a template by carrying a `.tmpl`
suffix, by being added with `--template`, by `chezmoi chattr +template`, or by living in
`.chezmoitemplates`.

Machine attributes are exposed as `.chezmoi.*` variables. The ones relevant to this repo's split:

`.chezmoi.hostname` (up to the first `.`), `.chezmoi.fqdnHostname`, `.chezmoi.os`, `.chezmoi.arch`,
`.chezmoi.kernel` (from `/proc/sys/kernel`, Linux only), `.chezmoi.osRelease` (from `/etc/os-release`,
Linux only), `.chezmoi.username`, `.chezmoi.homeDir`, `.chezmoi.uid`, `.chezmoi.group`,
`.chezmoi.sourceDir`, `.chezmoi.destDir`, `.chezmoi.config`, `.chezmoi.targetFile`. User-defined
data comes from the `data` section of `~/.config/chezmoi/chezmoi.$FORMAT` or from
`.chezmoidata.$FORMAT` files. `chezmoi data` dumps everything available.

**Cost to read a year later:** this is the highest-cost item in the survey and the honest tradeoff
against Stow's zero. Go `text/template` is a real language with its own evaluation model, and sprig
adds a large function library on top. Every templated dotfile stops being a valid file of its own
type: a `.tmpl` tmux config is no longer parseable by tmux, no longer lintable by the tools pinned
in `.config/mise/config.toml` (`shellcheck`, `shfmt`, `stylua`, `biome`), and no longer directly
testable. The one mitigating fact is that the repo's current runtime branches (`if-shell`,
`$SSH_CONNECTION`) are already conditionals in a second language embedded in a config file, so the
delta is smaller than it first appears. The difference is when they evaluate.

Note one attribute chezmoi cannot see: **SSH-ness of the current session is not a `.chezmoi`
variable**, and cannot be, because templates are evaluated at `apply` time, not at shell-startup
time. `$SSH_CONNECTION` describes the session that ran `chezmoi apply`, not the sessions that will
later use the file. The repo's existing `.envs.sh` and `.tmux.conf` branches are therefore **not**
mechanically portable to chezmoi templating. They are answering a runtime question. Role, hostname,
and Wayland-presence are answerable at deploy time; SSH-ness of a future session is not.

### 2.2 Conditionals: yes, at file granularity, via `.chezmoiignore`

Documented and exact: `.chezmoiignore` specifies "a list of patterns that chezmoi should ignore, and
are interpreted as templates". Because the ignore file is itself a template, the ignore set is
computed per machine. The docs' own example:

```
README.md
{{- if ne .chezmoi.hostname "work-laptop" }}
.work # only manage .work on work-laptop
{{- end }}
```

with the accompanying warning: "The use of `ne` (not equal) is deliberate. What we want to achieve
is 'only install `.work` if hostname is `work-laptop`' but chezmoi installs everything by default,
so we have to turn the logic around." That inverted logic is a standing legibility tax and a known
source of mistakes. `chezmoi ignored` prints the resolved set, which mitigates it.

Granularity is per file or per pattern, not per package, so a role split does not require a
directory reorganisation the way Stow packages do.

### 2.3 Machine-local state and secrets

The most developed of the five candidates on this axis.

- **Files that must exist but not be overwritten:** the `create_` prefix. "Files with the `create_`
  prefix will be created in the target state with the contents of the file in the source state if
  they do not already exist." This is a direct, first-class replacement for the
  `.gitconfig.example`-plus-manual-copy convention: ship `create_dot_gitconfig`, and chezmoi seeds
  it once and never touches it again.
- **Files that must be merged rather than replaced:** the `modify_` prefix, where the source file is
  "treated as a script that modifies an existing file", receiving current contents on stdin.
- **Secrets, in-repo:** "chezmoi supports encrypting files with age, git-crypt, gpg, and
  transcrypt". Encrypted files carry the `encrypted_` attribute and are "stored in ASCII-armored
  format in the source directory". Added via `chezmoi add --encrypt ~/.ssh/id_rsa`. `chezmoi edit`
  "will transparently decrypt the file before editing and re-encrypt it afterwards". Configured
  under `encryption = "age" | "gpg" | ...` with `age.command` / `gpg.command`, defaulting to `age`
  and `gpg` respectively, so **the encryption binary is a separate prerequisite chezmoi shells out
  to**, not something chezmoi bundles.
- **Secrets, out-of-repo:** template functions pull from password managers and the environment at
  apply time.
- **Interactive first-run values:** init-only template functions `promptString`, `promptBool`,
  `promptInt`, `promptChoice`, `promptMultichoice`, and their `...Once` variants, plus `exit` and
  `writeToStdout`. "These template functions are only available when generating a config file with
  `chezmoi init`." They populate `~/.config/chezmoi/chezmoi.$FORMAT` from
  `.chezmoi.$FORMAT.tmpl`, which is the canonical way to ask "is this machine a host or a remote?"
  exactly once per machine. Note the interactivity: this wants a TTY, which is a consideration for
  scripted remote provisioning.

### 2.4 Bootstrap on a fresh headless remote

| Item | Finding |
| --- | --- |
| Runtime dependency | None beyond libc. Single self-contained Go binary. |
| Single static binary curl'd in | **Yes**, and this is its strongest practical property. `sh -c "$(curl -fsLS https://get.chezmoi.io)"` or the `wget` equivalent. |
| Does the installer compile? | **No.** Reading the actual script served at `get.chezmoi.io`: it detects OS, architecture, and libc variant, downloads a prebuilt artefact from `https://github.com/twpayne/chezmoi/releases/${tag}`, verifies a checksum, and extracts it. It requires `curl` or `wget`, `tar`/`unzip`, `uname`, and one of `sha256sum`/`shasum`/`sha256`/`openssl`. **Go is not required.** (The install docs mention Go 1.25+, but that applies only to the from-source `go install` path.) |
| Fedora | **Yes, official.** `dnf list --repo=fedora --repo=updates chezmoi` returns `chezmoi.x86_64 2.70.5-1.fc44` from `updates`. (This host also sees 2.70.0 from the third-party `terra` repo, but the official one supersedes it.) |
| Debian/Ubuntu | **Only sid.** `packages.debian.org` shows chezmoi in sid (unstable) at 2.71.0-5 and **nowhere else**: not bookworm, not trixie. `apt-get install chezmoi` will fail on a Debian stable remote. The curl installer is the practical answer there. |
| Installable by mise | **Yes.** `mise registry` lists `chezmoi  aqua:twpayne/chezmoi asdf:joke/asdf-chezmoi`. It is the **only** one of the five candidates present in mise's registry. |
| One-command bootstrap | `chezmoi init --apply --verbose https://github.com/$USER/dotfiles.git`, documented as combining "initialize, checkout, and apply". |
| Scripts as bootstrap | `run_` prefixed files execute during apply. `run_once_` runs "only if a script with the same contents has not been run successfully before"; `run_onchange_` runs "whenever their contents change"; `run_before_` and `run_after_` order relative to file updates. This is a first-class home for the tpm clone that currently has no home, and for `mise install`. |

Chicken-and-egg note: mise can install chezmoi, but mise itself is **not** in official Fedora repos.
On this host `dnf list mise` resolves only to the third-party `terra` repo. mise's own bootstrap is
`curl https://mise.run | sh`, installing to `~/.local/bin`. So "mise installs it" still bottoms out
at a curl pipe, the same as chezmoi's own installer, with one extra hop.

### 2.5 Update and drift

- **Update:** `chezmoi update`, documented as "Pull changes from the source repo and apply any
  changes", running `git pull --autostash --rebase` in the source directory then `chezmoi apply`.
  The cautious form is `chezmoi git pull -- --autostash --rebase && chezmoi diff`, then
  `chezmoi apply` if the diff is acceptable.
- **Drift is a real, first-class state, because deployed files are copies.** This is the exact
  inverse of Stow. Editing `~/.zshrc` on a remote edits a copy; the source state is untouched and
  the repo does not notice.
- **Drift is detectable.** `chezmoi status` prints two columns: the first is the difference between
  the last state chezmoi wrote and the current actual state (what changed on disk since apply), the
  second is the difference between actual and target state (what apply would do). Codes are
  ` ` (no change), `A`, `D`, `M`, and `R` (script will run, second column only). `chezmoi diff`
  shows the content.
- **Drift is not silently destroyed.** For `chezmoi apply`: "If a target has been modified since
  chezmoi last wrote it then the user will be prompted if they want to overwrite the file."
- **Reconciliation is an explicit act:** `chezmoi re-add` to pull the local edit back into the
  source state, `chezmoi merge` / `chezmoi merge-all` to reconcile by hand. `chezmoi edit` is the
  workflow that avoids drift entirely by editing the source and applying.
- **Optional automation:** `autoCommit = true` and `autoPush = true`.

The tradeoff is stark and worth stating plainly for the decision ticket: chezmoi turns a
zero-friction operation (edit a file on a remote, it is already in the repo) into a two-step one
(edit, then `re-add`), and buys in exchange the ability to have that file differ per machine at all.

---

## 3. yadm

Model, from `yadm.md`: yadm is a shell wrapper around git. The repository lives at
`$HOME/.local/share/yadm/repo.git`, and "By default, `$HOME` will be used as the work-tree". The
overview: "yadm is like having a version of Git, that only operates on your dotfiles. If you know
how to use Git, you already know how to use yadm", and "You don't have to move your dotfiles, or
have them symlinked from another location." Tracked files are the real files in `$HOME`.

This makes yadm, structurally, the bare-git-repo approach (candidate 4) with a wrapper and three
added features: alternates, templates, and encryption.

### 3.1 Templating: yes, four processors, one built in

A file becomes a template via a filename suffix: `##template.<processor>` or `##t.<processor>`, and
"the processor can be omitted for 'default'".

| Processor | Dependency | Capability |
| --- | --- | --- |
| `default` (built in) | `awk` only | Deliberately limited |
| `esh` | `esh`, a POSIX shell script | "allows executing shell commands within templates" |
| `j2cli` | Python + `j2` | "full support" for Jinja2 |
| `envtpl` | Python + `envtpl` | Jinja2; the docs themselves note "online comments suggest this software might not be maintained anymore" |

The built-in processor's ceiling is documented explicitly: it supports `{{ }}` substitution,
`{% if %}...{% endif %}` blocks, and `{% include "filename" %}`, but "the 'if' directive only
supports testing a single variable, and there is no 'elif' directive."

Variables cover hostname, OS type, architecture, distro, user, and class, plus "any VAR in the
environment while yadm templates are processed" as `env.VAR`.

**Cost to read a year later:** the built-in processor is the cheapest real templating in this survey,
precisely because it is so constrained: three directives, no `elif`, single-variable tests. It is
learnable in one sitting. The risk is the opposite of chezmoi's: outgrowing it and having to adopt
`esh` or `j2cli`, which reintroduces a Python or shell dependency on every target, exactly the kind
of thing headless remotes make annoying.

### 3.2 Conditionals: yes, and this is yadm's distinctive feature

**Alternate files.** A file named with a `##<condition>[,<condition>,...]` suffix is selected per
machine and linked into place. Supported conditions, with short forms:

`os` (`o`, from `uname -s`), `hostname` (`h`, from `uname -n`), `distro` (`d`, from `lsb_release -si`
or `/etc/os-release`), `distro_family` (`f`, from `/etc/os-release`), `arch` (`a`, from `uname -m`),
`user` (`u`, from `id -u -n`), `class` (`c`, set manually via `yadm config local.class`), `default`,
and `extension` (`e`, a non-selection attribute purely for editor syntax highlighting). Conditions
negate with `~` and compare case-insensitively.

**`class` is the important one for this map.** It is the only condition that is not derived from the
machine but declared on it: `yadm config local.class host` or `... remote`. That is a direct,
native encoding of a role split, without hostname allow-lists that need editing every time a new
remote appears.

Precedence is documented: "A template is always scored higher than any symlink condition. The number
of conditions is the next largest factor in scoring. Files with more conditions will always be
favored."

Mechanism: "yadm will automatically create a symbolic link to the appropriate version of a file,
when a valid suffix is appended to the filename", regenerated by `yadm alt`. So alternates are
symlinks, templates produce generated files.

Same limitation as chezmoi on the SSH question: all conditions are evaluated when `yadm alt` runs,
so SSH-ness of a future session is out of reach. Role, hostname, distro, and arch are in reach.

### 3.3 Machine-local state and secrets

- **Generated outputs are auto-excluded.** "Created links are automatically added to the
  repository's `info/exclude` file. This can be disabled using the `yadm.auto-exclude`
  configuration", and the same for template output: "Created files are automatically added to the
  repository's `info/exclude` file." This is a clean answer, using a git-native mechanism, and it
  keeps generated artefacts from ever appearing as spurious changes.
- **Encryption is built in.** Patterns go in `$HOME/.config/yadm/encrypt` (for example `.ssh/*.key`).
  `yadm encrypt` "will find all files matching the patterns, and prompt for a password", writing an
  archive to `$HOME/.local/share/yadm/archive`; both the patterns file and the archive are committed.
  `yadm decrypt` restores them, and "any decrypted files will have their 'group' and 'others'
  permissions removed". Requirement, stated flatly: "This feature will only work if the gpg or
  openssl commands are available." GPG symmetric by default; asymmetric via `yadm.gpg-recipient`;
  OpenSSL via `yadm.cipher openssl`. `transcrypt` and `git-crypt` also work when prefixed with
  `yadm`.
- **Plain machine-local files** get the same answer as bare git: `.gitignore` or `info/exclude`. The
  existing `.gitconfig.example` convention transfers unchanged. yadm has no `create_`-style
  "seed once, never overwrite" primitive, so the manual-copy step remains manual. Note that an
  `##default` alternate is close but not equivalent: it deploys a symlink into the repo, so editing
  it edits the repo.

### 3.4 Bootstrap on a fresh headless remote

| Item | Finding |
| --- | --- |
| Language | Shell. Shebang is `#!/bin/sh` but the script re-execs itself under bash (`if [ -z "$BASH_VERSION" ]; then [ "$YADM_TEST" != 1 ] && exec bash "$0" "$@"; fi`), with the source comment "execute script with bash (shebang line is /bin/sh for portability)". So **bash is a hard requirement.** No minimum bash or git version is stated in the source. |
| External commands | `git`, `gpg`, `openssl`, `gawk`/`awk`, `git-crypt`, `transcrypt`, `j2`, `envtpl`, `esh`, `lsb_release`, plus `readlink`, `uname`, `id`, `chmod`, `ln`. Only `git` and `awk` are needed for the core path; the rest gate optional features. |
| Compiler needed | No. |
| Single file curl'd in | **Yes.** `curl -fLo /usr/local/bin/yadm https://github.com/yadm-dev/yadm/raw/master/yadm && chmod a+x /usr/local/bin/yadm`. Note this pulls from `raw/master`, so it is unversioned and unverified, unlike chezmoi's checksummed release download. Writing to `/usr/local/bin` needs root, which the targets have; `~/.local/bin` works equally well. |
| Fedora | **Not in official repos.** `dnf list --repo=fedora --repo=updates yadm` returns "No matching packages". This host sees `yadm 3.5.0-2.fc44` only from the third-party `terra` repo. yadm's own docs point Fedora users at the openSUSE Build Service rather than giving a command. |
| Debian/Ubuntu | **Yes, well covered.** bullseye 3.0.2-2, bookworm 3.2.2-1, trixie 3.5.0-1, forky 3.5.0-1, sid 3.5.0-1, arch `all`. `sudo apt-get install yadm`. |
| Installable by mise | **No.** Not in mise's 990-entry registry. The `ubi`/`github` backends resolve platform-labelled release binaries; querying the GitHub releases API for `yadm-dev/yadm` returns an empty list (`[]`), so there are no release assets for those backends to resolve at all. |
| Bootstrap hook | **Yes, first class.** `$HOME/.config/yadm/bootstrap`, which "must be made executable", is offered automatically after `yadm clone` ("yadm will ask the user if the bootstrap program should be run"), suppressible with `--bootstrap`/`--no-bootstrap`, and runnable later via `yadm bootstrap`. Docs advise: "It is best to make the logic of your bootstrap idempotent." |

**Notable asymmetry for these exact targets:** yadm is packaged well on Debian/Ubuntu and not at all
officially on Fedora; chezmoi is the reverse, official on Fedora and sid-only on Debian. Neither is
a blocker, since both have a single-file download path, but it is a real difference in how much of
the bootstrap can lean on the distro.

### 3.5 Update and drift

Because the work tree is `$HOME` and tracked files are the real files:

- **Editing a tracked file in place is editing the repo working tree**, exactly as with Stow, and
  unlike chezmoi. `yadm status` shows it immediately. No `re-add` step exists or is needed.
- **Update is `yadm pull`**, inheriting git semantics in full, including the pre-merge check: "git
  pull and git merge will stop without doing anything when local uncommitted changes overlap with
  files that git pull/git merge may need to update." A locally-edited file therefore blocks the pull
  loudly rather than being silently overwritten.
- **Generated artefacts need regeneration.** After a pull that changes an alternate or template
  source, `yadm alt` re-resolves the links and re-renders the templates. yadm runs this
  automatically on most operations, but it is a second state to keep in mind: the `##`-suffixed
  source and the generated output are separate files on disk.
- **Merge conflicts are ordinary git conflicts** in files that are live config, so a conflicted
  `.zshrc` is a broken `.zshrc` until resolved. This is true of Stow and bare git equally.

---

## 4. Bare git repo with `--git-dir`/`--work-tree`

This is a technique, not a tool, so there is no product documentation to cite. Every claim below is
grounded in git's own man pages on this host (git 2.55.0). The pattern: a bare repo (conventionally
`~/.cfg` or similar) plus an alias such as
`alias config='git --git-dir=$HOME/.cfg --work-tree=$HOME'`.

The primitives, verbatim:

- `--git-dir=<path>`: "Set the path to the repository ('.git' directory). This can also be
  controlled by setting the `GIT_DIR` environment variable... Specifying the location of the '.git'
  directory using this option (or `GIT_DIR` environment variable) turns off the repository discovery
  that tries to find a directory with '.git' subdirectory... and tells Git that you are at the top
  level of the working tree. If you are not at the top-level directory of the working tree, you
  should tell Git where the top-level of the working tree is, with the `--work-tree=<path>` option."
- `git clone --bare`: "Make a bare Git repository. That is, instead of creating `<directory>` and
  placing the administrative files in `<directory>/.git`, make the `<directory>` itself the
  `$GIT_DIR`. This obviously implies the `--no-checkout`... Also the branch heads at the remote are
  copied directly to corresponding local branch heads, without mapping them to `refs/remotes/origin/`.
  When this option is used, neither remote-tracking branches nor the related configuration variables
  are created."

That last sentence is a genuine, under-appreciated cost: a `--bare` clone has **no remote-tracking
branches**, so `git status` will not report ahead/behind and the upstream must be configured by
hand before pull/push behave normally.

### 4.1 Templating: none

git does not transform file content on checkout. Smudge/clean filters via `.gitattributes` exist and
could technically be abused for this, but that would be a hand-rolled templating system wearing a
git hat, and would then be evaluated as candidate 5, not as this one. As shipped: no templating.

### 4.2 Conditionals: essentially none, with two partial escapes

- **`git sparse-checkout`** is the only in-tree mechanism for having a subset of tracked files
  present: it "change[s] the working tree from having all tracked files present to only having a
  subset of those files", by directories in cone mode or patterns otherwise. The sparse spec lives
  in `.git/info/sparse-checkout`, which is per-clone and untracked, so it genuinely can differ per
  machine. Two caveats, both from the man page: it is stated in capitals that **"THIS COMMAND IS
  EXPERIMENTAL. ITS BEHAVIOR, AND THE BEHAVIOR OF OTHER COMMANDS IN THE PRESENCE OF SPARSE-CHECKOUTS,
  WILL LIKELY CHANGE IN THE FUTURE."**, and "other Git commands behave a bit differently" in its
  presence. Deploying dotfiles is a long-lived, low-attention activity; an explicitly experimental
  primitive is a poor fit.
- **`git update-index --skip-worktree`** is the older primitive: "Tell git to avoid writing the file
  to the working directory when reasonably possible, and treat the file as unchanged when it is not
  present in the working directory." But the same page warns "not all git commands will pay
  attention to this bit, and some only partially support it", that commands "will sometimes write
  these files anyway in important cases such as conflicts during a merge or rebase", and steers
  users away: "we strongly encourage the use of `git-sparse-checkout(1)` in preference to the
  low-level `update-index` and `read-tree` primitives."

Either way, the discriminator is manual per-machine configuration, not a machine attribute git
evaluates. Everything conditional has to be set up by hand on each machine, once, and remembered.

One genuine conditional exists but only for git's own config, and the repo can already use it
regardless of which candidate wins: `includeIf.<condition>.path` in `man git-config`, with `gitdir`
glob conditions, `onbranch`, and `hasconfig`. Relevant to `.gitconfig.example` specifically, not to
dotfile deployment generally.

### 4.3 Machine-local state and secrets

- **Untracked files coexist naturally.** Since `$HOME` is the work tree, anything not tracked simply
  sits there. The `.gitconfig.example` convention transfers unchanged.
- **The known ergonomic problem:** with `$HOME` as the work tree, `git status` reports the entire
  home directory as untracked. The standard mitigation is `status.showUntrackedFiles = no`,
  documented in `man git-config`: "By default, git-status(1) and git-commit(1) show files which are
  not currently tracked by Git... `no` - Show no untracked files." The cost of that setting is that
  it also hides genuinely new dotfiles you meant to add, so files get forgotten. `info/exclude` is
  the finer-grained alternative, and is exactly what yadm automates.
- **Secrets:** nothing built in. Whatever you bolt on (`git-crypt`, `transcrypt`, `age`, `sops`) is
  an extra dependency on every target, chosen and wired by hand.

### 4.4 Bootstrap on a fresh headless remote

| Item | Finding |
| --- | --- |
| Prerequisite | git, and nothing else. git 2.55.0 is already present on this Fedora host as `git-2.55.0-1.fc44`. It is in every distro's base repos and is arguably already on any machine you would SSH into to do development. |
| Installable by mise | Not needed. |
| Compiler / binary download | Neither. |
| Cost | The **lowest prerequisite footprint of the five, by a wide margin.** No new tool enters the picture at all. |

The costs land elsewhere. The alias must be defined before it can be used, which is circular: the
alias lives in the shell config that the repo is supposed to deploy. Bootstrapping therefore means
typing the full `git --git-dir=... --work-tree=...` invocation at least once. And the same
`/etc/skel` collision that blocks Stow blocks the initial checkout here, in a different form: git
will refuse to overwrite existing untracked `.bashrc`/`.zshrc`, and they must be moved aside first.

### 4.5 Update and drift

Identical to yadm's, minus the generated-artefact step, because it is the same model:

- Tracked files are the real files, so editing in place is editing the repo. Drift between deployed
  and tracked content cannot exist. `git status` (subject to `showUntrackedFiles`) shows it.
- `git pull` inherits the pre-merge check: it "will stop without doing anything when local
  uncommitted changes overlap with files that git pull/git merge may need to update", and "will also
  abort if there are any changes registered in the index relative to the HEAD commit".
- No re-deploy step exists, because there is no deploy step. A pull is the deploy.
- Merge conflicts land directly in live config files.

---

## 5. Hand-rolled bootstrap script

No external documentation exists by definition. What can be established factually is the capability
ceiling (unbounded), the cost structure, and, usefully, what the repo already demonstrates about how
this goes.

### 5.1 Templating

Anything you write. Realistic options with the tools already pinned in
`.config/mise/config.toml`: `envsubst`, shell heredocs, `sed`, `jq` (1.8.1, pinned), or a full
templating engine pulled in as a dependency. Nothing is provided; everything is possible.

**Cost to read a year later:** entirely a function of discipline, and this is the axis where the
candidate is genuinely different in kind. The others have a fixed, documented, externally-maintained
cost. A hand-rolled script has a cost that starts near zero and grows silently. The repo has partial
evidence on this already: only `theme-switch` sets `set -euo pipefail` among the scripts in
`.local/scripts/`, which the map flags as an open question. Whatever is written here inherits that
same unsettled convention problem.

### 5.2 Conditionals

Unbounded, and uniquely so on one point: **a script is the only candidate that can freely mix
deploy-time and runtime conditionals**, and the only one with unrestricted access to arbitrary
machine attributes. Wayland presence via `$WAYLAND_DISPLAY` or `$XDG_SESSION_TYPE`, sway presence
via `command -v sway`, SSH-ness via `$SSH_CONNECTION`, role via a marker file the script itself
writes: all trivially available, none requiring a variable to be exposed by a tool vendor.

Worth noting for the decision ticket: the repo's existing runtime branches
(`.tmux.conf` `if-shell`, `.envs.sh` `$SSH_CONNECTION`) are already this candidate's approach,
applied inside config files rather than in a deploy script.

### 5.3 Machine-local state and secrets

Whatever is written. The obvious low-cost implementation, and the one continuous with the repo's
existing convention, is "for each `X.example`, if `X` does not exist, copy it, otherwise leave it
alone", which reimplements chezmoi's `create_` in about three lines. Secrets have no built-in story;
GPG, `age`, or a password-manager CLI would be invoked directly.

### 5.4 Bootstrap on a fresh headless remote

| Item | Finding |
| --- | --- |
| Prerequisite | A shell, plus whatever the script itself calls. If written to POSIX `sh`, the floor is as low as bare git's. |
| In distro repos | Not applicable; it lives in the repo. |
| Installable by mise | Not applicable. |
| Cost | **Effectively zero prerequisite cost, and the highest authorship and maintenance cost.** |

Two grounded observations from the repo:

- **The pieces already exist and are inconsistent, which is the actual current state.**
  `.zshrc:4-9` clones zinit if `$ZINIT_HOME` is absent. `.config/nvim/lua/core/lazy.lua:1-22`
  clones lazy.nvim if absent. `.tmux.conf:58` runs `~/.tmux/plugins/tpm/tpm` but nothing anywhere in
  the repo ever clones tpm, so tmux plugins silently do not work on a fresh machine until someone
  clones it by hand. A bootstrap script is partly a proposal to consolidate three ad-hoc
  self-installers and one missing one.
- **Every other candidate still needs some of this.** chezmoi has `run_once_` scripts and yadm has
  `.config/yadm/bootstrap` precisely because tool-managed deployment does not cover installing mise,
  cloning tpm, or running `mise install`. So this candidate is not purely an alternative to the
  others; it is partly a component of them. The real question the decision ticket faces is how much
  of the job the script does, not whether one exists.

### 5.5 Update and drift

Whatever is written, and this is the axis where hand-rolled scripts most often fall short in
practice. The specific facts:

- If the script **copies** files, it inherits chezmoi's problem (drift is possible) without
  inheriting chezmoi's solution (`chezmoi status` two-column diff, `re-add`, prompt-before-overwrite).
  Detecting and reconciling drift would all have to be written.
- If the script **symlinks** files, it inherits Stow's property for free: drift is impossible,
  edits land in the repo, `git status` is the drift report. This is the cheap path, and it is what
  the repo effectively has today via Stow.
- Either way, updating means `git pull` plus re-running the script, and the script must be
  idempotent. yadm's docs give the general form of the advice: "It is best to make the logic of your
  bootstrap idempotent, allowing it to be re-run in the future when you merge changes made on other
  hosts."

---

## Cross-cutting summary

### Capability matrix

| | Stow | chezmoi | yadm | bare git | script |
| --- | --- | --- | --- | --- | --- |
| Templating | **None** (verified in manual + source) | Go `text/template` + sprig | 4 processors, `awk`-only default | None | Unbounded |
| Conditional deploy | Package selection only | `.chezmoiignore` as template, per file | Alternates: os/host/distro/arch/user/**class** | sparse-checkout (experimental) or manual | Unbounded |
| Machine attributes visible to the tool | **None** | `.chezmoi.*` (hostname, os, arch, osRelease, ...) | os, hostname, distro, distro_family, arch, user, class | None | Anything |
| Deploy-time role declaration | No | `promptBool`/config `data` | `yadm config local.class` | No | Anything |
| Seed-once local file | No | `create_` prefix | No | No | Trivial to write |
| Built-in secrets | No | age / git-crypt / gpg / transcrypt | gpg / openssl archive | No | No |
| Deployed artefact | Symlink | **Copy** (or symlink in `mode = "symlink"`) | Real file (alternates: symlink) | Real file | Your choice |
| Drift possible? | **No** | **Yes**, detected + prompted | **No** | **No** | Depends on copy vs symlink |
| Re-import step after local edit | None needed | `chezmoi re-add` | None needed | None needed | Depends |

### Bootstrap matrix

| | Stow | chezmoi | yadm | bare git | script |
| --- | --- | --- | --- | --- | --- |
| Must pre-exist | Perl 5.6+ (core modules only) | libc | bash + git + awk | git | sh |
| Official Fedora repo | **Yes** (`fedora`, 2.4.1) | **Yes** (`updates`, 2.70.5) | **No** (third-party `terra` only) | Yes (git) | n/a |
| Debian/Ubuntu | **Yes**, all suites | **sid only** (2.71.0-5) | **Yes**, all suites | Yes | n/a |
| Single file / binary download | No (Perl script + 2 `.pm`) | **Yes**, checksummed release | **Yes**, raw `master` script, unversioned | n/a | n/a |
| In mise registry | **No** | **Yes** (`aqua:twpayne/chezmoi`) | **No** (no GH release assets at all) | n/a | n/a |
| Native bootstrap hook | No | `run_once_` / `run_before_` / `run_after_` | `.config/yadm/bootstrap` | No | is one |
| Blocked by `/etc/skel` files | **Yes, aborts entire run** | No (prompts / overwrites) | Yes, on initial checkout | Yes, on initial checkout | Your choice |

### Constraint check

No candidate is disqualified by the map's hard constraints. All five work on Fedora and on headless
Linux remotes with root. Specifically:

- Nothing here depends on macOS, containers, or rootless operation.
- The two weakest packaging stories (yadm on Fedora, chezmoi on Debian stable) are both fully
  recoverable by a single-file download, and both targets have root, so neither becomes a blocker.

Three constraint-adjacent facts the decision ticket should carry forward, since they are the closest
anything came to a hard limit:

1. **Stow's conflict rule versus `/etc/skel` is the sharpest practical obstacle found.** Conflicts
   abort the whole invocation, and a fresh Fedora `$HOME` ships at least `.bashrc`, `.bash_profile`,
   `.bash_logout`, `.zshrc`, `.zprofile`. This is not a disqualification, it is a mandatory,
   currently-undocumented pre-step. It applies in milder form to yadm and bare git (initial checkout
   only), and not to chezmoi.
2. **No candidate can resolve SSH-ness at deploy time.** chezmoi and yadm evaluate conditions when
   `apply`/`alt` runs, which describes the session doing the deploying, not future sessions. The
   repo's existing `.tmux.conf` and `.envs.sh` branches are answering a question that only runtime
   can answer, so **they are not portable to any deploy-time conditional mechanism** and must either
   stay as runtime branches or be reframed as role rather than SSH-ness. This cuts across the split
   ticket, not just this one.
3. **Symlink-based deployment and per-machine content are mutually exclusive by construction.**
   Stow's inability to template is not a missing feature; a symlink has no content. Any mechanism
   that gives one tracked file different content per machine must copy or generate, which is exactly
   what creates the possibility of drift. The two properties trade off directly and cannot both be
   had for the same file.

### Verified against the ticket's specific asks

- "Stow can do neither templating nor conditionals; confirm that" → **Confirmed**, by zero-match
  greps across the complete GNU Stow 2.4.1 info manual and the complete implementation, plus the
  manual's own complete node list. Templating: absent, and structurally impossible for a symlink
  farm manager. Conditionals: absent from the tool; the closest thing is per-machine `--ignore`
  lines in an untracked `~/.stowrc`, which can subtract files but cannot select packages.
- "confirm whether multiple packages plus selective `stow <pkg>` is the full extent of its answer"
  → **Confirmed, with one addition.** Selective `stow <pkg>` is the primary and only
  file-set-selection mechanism the tool offers, verified by execution. The one thing to add to the
  answer is untracked `~/.stowrc` with per-machine `--ignore` lines, which the manual documents and
  which is a genuine second lever, though a weaker and less discoverable one that requires its own
  bootstrap step.

## Open questions and limits of this survey

- **Not executed:** chezmoi, yadm, and bare-git behaviours are documented rather than run, since
  neither chezmoi nor yadm is installed on this host and the survey was constrained not to invoke
  git. Stow is the one candidate whose behaviour was executed directly. Anything load-bearing from
  the chezmoi or yadm sections would benefit from a throwaway `/prototype` before the decision
  ticket closes.
- **Version drift:** chezmoi in Debian sid at 2.71.0-5 versus Fedora updates at 2.70.5 versus
  whatever `get.chezmoi.io` serves means three different versions across the target fleet if
  installed per-distro. Not investigated: whether chezmoi's source-state format is
  forward-compatible across minor versions, which matters if the Fedora host and the remotes run
  different builds.
- **yadm release assets:** the GitHub releases API for `yadm-dev/yadm` returned an empty list,
  which is why the `ubi`/`github` mise backends have nothing to resolve. The project ships versioned
  releases to distros (3.5.0 is in Debian trixie and in `terra`), so the empty list may reflect the
  repository's move from `TheLocehiliosan/yadm` to `yadm-dev/yadm` rather than an absence of
  releases upstream. The conclusion (mise cannot install yadm) holds either way, since it is also
  absent from the registry.
- **Not assessed, deliberately:** which candidate is better. That is
  [ticket 05](../issues/05-choose-deployment-mechanism.md).
- **Feeds other tickets:** the `/etc/skel` collision and the tpm-never-cloned gap both belong to the
  map's "Bootstrap sequence" open item. The SSH-ness-is-runtime-only finding belongs to the split
  ticket.

## Appendix A: Stow behaviour, executed not inferred

Run against an isolated scratch tree with Stow 2.4.1, with two sibling packages `shared` and `host`.
No repository was touched.

**Selective deploy of one of two packages:**

```
$ stow -t <target> -v shared
LINK: .bashrc => ../pkgs/shared/.bashrc
$ ls -la <target>
lrwxrwxrwx. 1 hpark hpark 22 ... .bashrc -> ../pkgs/shared/.bashrc
```

`host`'s `.swayrc` was not deployed. Package selection works, at package granularity.

**Editing the deployed file writes through to the repo:**

```
$ echo "edited on the machine" >> <target>/.bashrc
$ cat <pkgs>/shared/.bashrc
shared v1
edited on the machine
```

The write landed in the package file. Deployed and tracked content are the same inode, so drift
between them is impossible and a local edit is immediately an uncommitted repo change.

**A pre-existing real file at the target aborts the whole run:**

```
$ echo "pre-existing local file" > <target>/.swayrc
$ stow -t <target> -v host
WARNING! stowing host would cause conflicts:
  * cannot stow ../pkgs/host/.swayrc over existing target .swayrc since neither
    a link nor a directory and --adopt not specified
All operations aborted.
$ cat <target>/.swayrc
pre-existing local file
```

Exit status non-zero, filesystem unmodified, consistent with the manual's documented two-phase
conflict scan. This is the mechanism that will block the first `stow` on any fresh remote whose
`$HOME` was populated from `/etc/skel`.
