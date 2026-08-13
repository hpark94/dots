# Spec: FLAC paths derived from tags

Status: done

## Problem Statement

As the owner of the FLAC library, I file every album by running `organize_flac`,
which reads each file's tags and moves the file to a path built from them. Two
things about that path are wrong for me.

First, a collaboration splits an album apart. `organize_flac` keys the artist
directory on the `ARTIST` tag, which names the performers on that one track. My
aespa album ships four different `ARTIST` values, so its eleven tracks land in
four sibling directories:

```
flac/aespa/lemonade_-_the_2nd_album/            (8 tracks)
flac/aespa;_g-dragon/lemonade_-_the_2nd_album/  (1)
flac/aespa;_ty_dolla_$ign/lemonade_-_the_2nd_album/ (1)
flac/aespa;_becky_g/lemonade_-_the_2nd_album/   (1)
```

The album is one album. I want to open one directory and see all of it. The
files already carry `ALBUMARTIST=aespa`, so the information I need is on disk
and simply goes unread.

Second, the names are noisy. The current rule maps spaces and apostrophes to `_`
while letting a `-` from the tag through untouched, so the two characters
collide with each other and with themselves:

| Tag value                  | Current name fragment      | What is wrong           |
| -------------------------- | -------------------------- | ----------------------- |
| `LEMONADE - The 2nd Album` | `lemonade_-_the_2nd_album` | `_-_`                   |
| `'Til We Die`              | `10__til_we_die`           | doubled `_`             |
| `Shakin'`                  | `shakin_-aespa`            | `_` stranded before `-` |
| `aespa; Ty Dolla $ign`     | `aespa;_ty_dolla_$ign`     | `;` and `$` in a path   |

I want one separator, used consistently, with no doubled or stranded runs.

## Solution

`organize_flac` derives the path from the tags by two named rules.

**Which artist decides what.** The directory is keyed on the **Album Artist**,
the artist the release as a whole is credited to, read from `ALBUMARTIST` and
falling back to `ARTIST` when that tag is absent. The filename suffix stays
keyed on the **Track Artist**, the artist credited on the individual track, read
from `ARTIST`. An album therefore occupies exactly one directory, while the
per-track collaboration survives in the filename rather than being lost.

**How a tag value becomes a path segment.** Every tag value passes through the
same **Slug** rule before it touches the filesystem, and `-` is the only
separator the rule can produce. Runs collapse and edges are trimmed, so no input
can yield a doubled or stranded separator.

The aespa album afterwards, all eleven tracks in
`flac/aespa/lemonade-the-2nd-album/`:

```
01-wda-(whole-different-animal)-aespa-g-dragon.flac
02-lemonade-aespa.flac
03-shakin-aespa.flac
04-can-t-help-myself-aespa.flac
05-camouflage-aespa.flac
06-bite-aespa.flac
07-switchblade-aespa-ty-dolla-ign.flac
08-roll-aespa.flac
09-my-plan-aespa.flac
10-til-we-die-aespa.flac
11-lemonade-aespa-becky-g.flac
```

The run also removes the directories it empties, so the three stale `aespa;_...`
husks and the old album directory do not survive the migration.

## User Stories

1. As a music library owner, I want every track of an album to land in one
   directory, so that I can play or copy the album without hunting through
   sibling directories.
2. As a music library owner, I want the artist directory keyed on the Album
   Artist, so that a featured guest on one track does not fork the album.
3. As a music library owner, I want the Album Artist read from `ALBUMARTIST`, so
   that the grouping follows what the release itself declares rather than a
   guess derived from `ARTIST`.
4. As a music library owner, I want `ARTIST` used as the Album Artist when
   `ALBUMARTIST` is absent, so that files from taggers that omit the tag are
   still filed rather than rejected.
5. As a music library owner, I want the filename suffix to keep naming the Track
   Artist, so that a collaboration is still visible after the directory stops
   recording it.
6. As a music library owner, I want a single track's collaborators readable from
   its filename alone, so that a file copied out of the library still says who
   is on it.
7. As a music library owner, I want `-` to be the only separator in a path
   segment, so that names look uniform instead of mixing `_` and `-`.
8. As a music library owner, I want repeated separators collapsed to one, so
   that `'Til We Die` produces `10-til-we-die-...` and not a doubled run.
9. As a music library owner, I want separators trimmed from the ends of a
   segment, so that `Shakin'` produces `shakin` and not a name with a stranded
   separator before the suffix.
10. As a music library owner, I want a real dash inside a tag value to fold into
    the same separator, so that `LEMONADE - The 2nd Album` becomes
    `lemonade-the-2nd-album`.
11. As a music library owner, I want an apostrophe treated as a separator, so
    that `Can't Help Myself` reads as `can-t-help-myself` rather than gluing
    words together.
12. As a music library owner, I want Korean, Japanese and Chinese titles to keep
    their characters, so that a Hangul track title is filed under its actual
    name instead of a row of separators.
13. As a music library owner, I want parentheses preserved, so that the
    bracketed qualifier K-pop titles almost always carry stays legible.
14. As a music library owner, I want `;`, `$` and every other punctuation mark
    turned into a separator, so that no path in the library needs quoting to
    survive a shell.
15. As a music library owner, I want the Slug rule to behave identically no
    matter how the script was started, so that running it from a timer or over
    SSH cannot silently mangle non-Latin titles.
16. As a music library owner, I want a file whose tags slug down to nothing
    moved to Skipped, so that it is quarantined loudly rather than filed under
    an empty name.
17. As a music library owner, I want the completeness check applied to the
    slugged value rather than the raw tag, so that a title made only of
    punctuation cannot slip through as a valid name.
18. As a music library owner, I want two files that slug to the same name to
    leave the first one intact, so that a collision costs me an error message
    and never a track.
19. As a music library owner, I want a second run over an already filed library
    to move nothing, so that running the script is safe at any time.
20. As a music library owner, I want the directories a run empties removed by
    that same run, so that migrating my library does not leave husks behind.
21. As a music library owner, I want that cleanup confined to the FLAC tree, so
    that Skipped and the MP3 tree are never touched by it even when empty.
22. As a music library owner, I want Skipped to keep working exactly as it does
    today, so that the change to naming does not change how bad files are
    quarantined.
23. As a music library owner, I want track numbers to keep their two-digit
    zero-padded form and their existing base-10 handling, so that sort order is
    unaffected.
24. As a music library owner, I want the `COMMENT` tag stripped as it is today,
    so that the change is confined to naming.
25. As a music library owner, I want `convert_flac` to keep mirroring whatever
    layout `organize_flac` produces, so that the MP3 tree follows the new names
    without its own rule.
26. As a music library owner, I want both scripts to look at the real `~/Music`,
    so that they stop failing on a directory that does not exist.
27. As a maintainer of this repo, I want the test suite green against the
    directory the scripts actually use, so that the suite tells me the truth.
28. As a maintainer of this repo, I want the naming rule covered by tests at the
    existing seam, so that a future edit to the rule cannot regress the cases I
    care about.
29. As a maintainer of this repo, I want the two artist concepts written into
    the glossary, so that the next reader does not have to work out why one path
    contains two different artist tags.
30. As a maintainer of this repo, I want the rejected alternatives recorded in
    an ADR, so that this discussion does not have to happen again.

## Implementation Decisions

### Modules

- **`organize_flac`** carries every behavioural change: reading the Album
  Artist, the new Slug rule, path assembly, the locale pin, and the
  empty-directory sweep.
- **`convert_flac`** changes only the library root's capitalisation. It derives
  the MP3 path mechanically by stripping the FLAC root prefix from the source
  path, so it mirrors the new layout with no rule of its own. It performs no
  slugging and therefore needs no locale pin.
- **`organize_flac`'s BATS suite** gains a default Album Artist in setup, moves
  to the corrected library root, and updates every expected path. Its `metaflac`
  stub answers any tag generically, so reading a new tag costs it nothing. It
  does need one addition: a tag value scoped to a single file, so that a test
  covering two differently credited tracks can drive both in one run. Answering
  every file from one global value forces such a test into two runs, where the
  second run re-tags the file the first run already filed and the outcome turns
  on directory traversal order.

### Path derivation

Two tags decide two different things, and this asymmetry is the whole point of
the change:

| Path component   | Tag           |
| ---------------- | ------------- |
| Artist directory | Album Artist  |
| Album directory  | `ALBUM`       |
| Track prefix     | `TRACKNUMBER` |
| Title            | `TITLE`       |
| Filename suffix  | Track Artist  |

The Album Artist resolves to `ALBUMARTIST` when that tag holds a value, and to
`ARTIST` otherwise. The fallback is a fallback in the tag layer only: once
resolved, the Album Artist is slugged and validated like any other value, so a
file with neither tag still ends up in Skipped rather than being filed under an
empty directory name.

The extension segment between the library root and the artist directory keeps
its current derivation from the source file's extension.

### The Slug rule

Applied to each tag value independently, before assembly:

1. Lowercase.
2. Replace every character that is neither a letter, nor a digit, nor a
   parenthesis with `-`. Letters and digits are meant in the Unicode sense:
   Hangul, Kana and CJK are letters and survive.
3. Collapse runs of `-` to a single `-`.
4. Trim `-` from both ends.

Parentheses are the sole punctuation exception, kept because the bracketed
qualifier is load-bearing in this library's titles.

Assembly joins the slugged parts with the same `-`:
`<track>-<title>-<track-artist>.<ext>`. The separator between fields is
therefore indistinguishable from a separator inside a field. This is accepted:
the tags remain the authority on field boundaries, and the filename is for
humans.

### Locale

`organize_flac` pins `LC_ALL` to a UTF-8 locale at the top of the script.
Without it, step 2 of the Slug rule is locale-dependent: under a C locale, bash
does not consider Hangul a letter and a Korean title collapses to a row of
separators with no error. Pinning is preferred over probing-and-aborting because
it costs one line and cannot fail. `C.UTF-8` is present on the target system.

### Completeness and collisions

The existing quarantine behaviour is preserved and inherits the new rule rather
than being rewritten:

- The completeness check runs on the **slugged** values. A tag that is present
  but slugs to the empty string counts as unusable, and the file moves to
  Skipped exactly as a missing tag does today.
- `TRACKNUMBER` keeps its separate numeric validation and its base-10 padding.
- A target name that is already taken produces an error on stderr and leaves the
  source file where it is. Collapsing widens the set of inputs that can collide,
  which makes this guard more load-bearing than before, not less.
- A run remains idempotent: a file already at its target path is reported
  unchanged and not moved.

### Empty-directory sweep

After every move, `organize_flac` removes directories it has emptied. The sweep
is confined to the FLAC tree, which structurally excludes Skipped and the MP3
tree. It runs depth-first so that a directory emptied only because its children
were removed is itself removed in the same pass.

This is an acknowledged widening of the original request, taken because the
migration itself creates four husks and every future collaboration album or tag
correction would create more.

### Deliberately not built

No configuration flags, no environment overrides for the library root, no
transliteration option, no dry-run mode. None were asked for.

## Testing Decisions

### What makes a good test here

A good test drives the script the way the user does and asserts only on what the
user can see: where a file ended up, what its name is, what was printed, and the
exit status. It never reaches inside for a helper function and never asserts on
intermediate values. Each test states one rule in its name, so a failure names
the rule that broke.

### Seam

One, and it already exists: the script boundary. The suite points `HOME` at the
per-test temporary directory so every move stays away from the real library, and
puts a `metaflac` stub on `PATH` that answers `--show-tag=X` from an environment
variable `TAG_X`. Because the stub resolves the tag name generically, Album
Artist support costs a default export in setup and nothing else. The stub does
gain a per-file override, consulted before the global value, so that a test can
give two files different tags within a single run; without it, any such test
needs a second run and its result depends on traversal order.

No second seam is introduced. The Slug rule is not extracted into a sourceable
function for direct table-testing: that would add a way into the script that
production never uses, and the rule is fully observable through the resulting
paths.

### Prior art

`organize_flac`'s own suite is the model and already contains the stub, the
`HOME` redirection, and the quarantine and collision cases. `fy` and
`theme-switch` use the same PATH-stub pattern for external commands.

### Coverage

Existing cases carry over with updated expectations, since every expected path
changes shape. Added cases:

- An album whose tracks differ in Track Artist but share an Album Artist files
  every track into one directory.
- The filename suffix reflects the Track Artist, not the Album Artist, for such
  a track.
- A file with no `ALBUMARTIST` falls back to `ARTIST` for the directory.
- A file with neither `ALBUMARTIST` nor `ARTIST` goes to Skipped.
- A tag value containing a real dash surrounded by spaces yields a single
  separator.
- A leading apostrophe yields no leading or doubled separator.
- A trailing apostrophe yields no stranded separator before the suffix.
- A Hangul title keeps its characters.
- The same Hangul title still keeps them when the caller's environment sets a
  non-UTF-8 locale, which is the only case that actually exercises the locale
  pin: on a UTF-8 development machine the plain Hangul test passes with the pin
  removed.
- Parentheses survive; other punctuation does not.
- A title consisting only of punctuation slugs to empty and goes to Skipped.
- Two distinct titles that slug to the same name leave the first file intact and
  report the collision.
- A second run over the filed result moves nothing.
- A directory emptied by a move is removed.
- An empty Skipped directory is not removed by the sweep.

The suite must be run against the corrected library root; the pre-existing
mismatch between the scripts' root and the suite's is fixed as part of this
work.

## Out of Scope

- **Moving the real library.** The build and its tests run entirely against
  temporary directories. Migrating the actual eleven files is a separate,
  explicitly authorised step.
- **Orphaned MP3 files.** Renaming a FLAC after converting it leaves the old MP3
  behind. The MP3 tree is currently empty, so nothing is stranded today.
  Detecting or deleting orphans is not built.
- **Tests for `convert_flac`.** It has none today and its only change is the
  library root's capitalisation.
- **Splitting multi-artist tags.** `ARTIST` values holding several performers
  are slugged as one string, not parsed into a list.
- **Retagging.** Nothing writes tags except the existing `COMMENT` removal.
  Files with wrong or missing tags are quarantined, never corrected.
- **Transliteration.** Hangul and CJK are preserved as-is; romanisation is not
  offered.
- **Unicode normalisation.** No NFC/NFD folding is applied, so two visually
  identical titles in different normal forms remain different names.
- **Formats other than FLAC as input.** The scan still matches FLAC files only.
- **Configurability.** No flags, no overrides, no alternative naming schemes.

## Further Notes

- The library the change is designed against is small and homogeneous: eleven
  files, one album, four distinct `ARTIST` values over a single `ALBUMARTIST`.
  Every rule here was checked against those files and against a synthetic Hangul
  title.
- The locale sensitivity was confirmed empirically, not assumed: the same title
  slugs correctly under a UTF-8 locale and collapses to separators without one.
- `convert_flac` was examined for required changes and found to need none. It is
  named in this spec so that the absence of a change is a recorded decision
  rather than an oversight.
- Work proceeds under this repo's agent roles: a Builder implements and writes
  the tests, then a fresh Reviewer reads the diff.
