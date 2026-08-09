# 14 Conventions for the `.local/scripts/` set

**Type:** `grilling`

**Status:** resolved

**Blocked by:** None (graduated from fog once [11](11-bootstrap-sequence.md)
resolved)

**Map:** [Portable dotfiles](../map.md)

## Question

The repo now has a set of hand-invoked scripts: `theme-switch`, `note`
(rewritten per [04](04-note-restructure-prototype.md), `scratch` folded in),
`bootstrap.sh` (new, per [11](11-bootstrap-sequence.md)), `tmux-sessionizer`,
and whatever else lives under `.local/scripts/`. **What conventions govern them
as a set?**

### Why this is now specifiable

It was fog waiting on [11](11-bootstrap-sequence.md), which had to decide "what
install owns and therefore whether a shared library is something install has to
place." [11](11-bootstrap-sequence.md) answered: **no shared library is placed
by install**, each script hand-rolls its Role Marker read against
[13](13-role-marker-reader.md)'s contract. So there is no library-hosting
question left, and the conventions can be settled directly.

### The open questions

1. **Strict mode.** Only `theme-switch` sets `set -euo pipefail` today. Is that
   the standard for every script, and where does it not fit (`note`'s
   [04](04-note-restructure-prototype.md) rewrite has its own error-handling
   shape, `bootstrap.sh` is idempotent-by-guard)?
2. **Usage and error handling.** A shared shape for `-h`/usage, argument
   validation, and how errors are reported (`theme-switch` and
   [11](11-bootstrap-sequence.md)'s bootstrap both fail loudly; is there one
   idiom).
3. **`bats` coverage.** `bats` is pinned in mise and `theme-switch` already has
   tests under `.local/scripts/tests/`. What is the coverage bar for a new
   script, and does `bootstrap.sh` (which installs software and writes into
   `$HOME`) get tested, and how, given it is hard to exercise without a
   throwaway machine.
4. **The Role Marker read.** [13](13-role-marker-reader.md) pinned a contract
   but left each of the two readers (`note`, `theme-switch`) hand-rolling it. Is
   a duplicated read acceptable as a convention, or does the set want a shared
   snippet (not a library, per [11](11-bootstrap-sequence.md), but perhaps a
   copy-pasted function with a pinned shape).

### What resolution must cover

The strict-mode rule, the usage/error idiom, the bats coverage bar (including
how or whether `bootstrap.sh` is tested), and whether the Role Marker read stays
duplicated or is standardized as a snippet.

## Answer

### 1. Strict mode is universal, no script opts out

Every script in `.local/scripts/`, including `bootstrap.sh` and the rewritten
`note`, opens with `set -euo pipefail`. `bootstrap.sh` is the strongest case for
it, not an exception: it installs software and writes into `$HOME`, so a
silently swallowed failure mid-sequence is worse than a hard stop.

Where a call is meant to be best-effort and tolerate absence, that is expressed
per call with `|| true`, the pattern `theme-switch` already uses in
`apply_foot`, `apply_sway` and `apply_gtk` (`theme-switch:161-200`). Strict mode
is never turned off for a whole script to get that behavior in one place.

### 2. Usage and error handling: a shared idiom, not shared code

Three rules, stated as a convention every script follows rather than a library
function:

- A `usage()` function prints one-line-per-flag usage to stderr, called from
  `-h`/`--help` (exit 0) and from an argument error (exit 1). This names the
  pattern `theme-switch`'s `resolve_mode` already half-does inline
  (`echo "usage: theme-switch dark|light|toggle" >&2; return 1`).
- All errors go to stderr, prefixed `Error:`, non-zero exit, naming what is
  wrong and where (file path, bad flag). This retires `note`'s current mix of
  unprefixed `echo ... >&2` and a `Warning:` that does not exit.
- No silent fallback on bad input. Ticket 13 already ruled this for the Role
  Marker; it generalizes to the whole set: an unrecognized flag or a missing
  required argument is a hard error, never a default.

Stays a convention rather than shared code for the same reason ticket 13
rejected a shared library: two or three scripts do not pay for it, and each
script's `usage()` text is script-specific anyway.

### 3. bats coverage bar: pure and computable logic, not side-effecting steps

The bar is not "does this script get a `.bats` file", it is "which of its
functions do." The model is `theme-switch.bats` as it stands today: it sources
the script with `XDG_STATE_HOME`/`XDG_CONFIG_HOME` redirected into
`$BATS_TEST_TMPDIR` and tests `resolve_mode` and `write_state`, functions with
real inputs and outputs. It does not test `apply_foot`, `apply_sway` or
`apply_gtk`, which only shell out to `pkill`/`swaymsg`/`gsettings`. This ticket
names that existing split as the explicit rule.

For a new script: any function with real branching or parsing (argument parsing,
path resolution, idempotency guards) gets bats tests using the
sourcing-plus-fake-`$XDG_*`-dirs pattern. A function that is a bare external
command invocation does not.

`bootstrap.sh` gets a `.bats` file under this rule, not full coverage and not
none. Its sequencing and guard logic (does it skip a `stow` conflict correctly
against a faked `$HOME`, does it write the Marker only if absent) is testable
the same way `theme-switch.bats` fakes `$XDG_STATE_HOME`. The actual
`mise install`, `curl | sh`, and `nvim --headless '+Lazy! sync'` invocations get
no bats coverage: there is no throwaway machine in this loop, which is the
obstacle the ticket itself named.

### 4. The Role Marker read: one canonical function, copy-pasted verbatim, not two independent implementations

Ticket 13 pinned the contract (path, whitespace-stripping, exact-word match, no
fallback) and left the question of whether the two call sites could each
implement it independently open. They do not: this ticket prescribes one exact
function body that `note` and `theme-switch` both carry byte for byte.

Independent implementations against a shared contract is how ticket 13's `echo`
vs `printf '%s'` trailing-newline mismatch happens again somewhere else: two
people encode the same four-line spec slightly differently. A copy-pasted
canonical function costs nothing beyond that: no new file, no `source`
dependency, no `PATH` concern, just a fixed block of code repeated in both
scripts.

Canonical shape (path and error wording may not drift; the function may be
renamed to fit each script's naming):

```bash
read_role() {
	local marker="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role" role
	if ! role=$(<"$marker" 2>/dev/null); then
		role=""
	fi
	role="${role//[[:space:]]/}"
	case "$role" in
	desktop | headless)
		printf '%s' "$role"
		;;
	*)
		echo "Error: ${marker} must contain exactly 'desktop' or 'headless'. Fix: printf '%s' desktop > ${marker} (or headless)." >&2
		return 1
		;;
	esac
}
```

If ticket 11's "no shared library" answer is ever revisited, this is the one
function that moves into it unchanged; until then it is duplicated on purpose,
per ticket 13.

### What this closes

With this resolved, the Script conventions fog patch is fully specified: strict
mode, the usage/error idiom, the bats coverage bar, and the Role Marker read all
have a pinned shape. No further tickets graduate from this patch.
