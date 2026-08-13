# A FLAC path takes its artist from two different tags

`organize_flac` built the whole path out of the `ARTIST` tag, which credits one
recording rather than a release. A collaboration therefore forked its own album:
the aespa LEMONADE tracks scattered across `aespa/`, `aespa;_g-dragon/`,
`aespa;_ty_dolla_$ign/` and `aespa;_becky_g/`, four directories for eleven
tracks. We now split the two readings apart: the **Album Artist**
(`ALBUMARTIST`, falling back to `ARTIST`) decides the directory, and the **Track
Artist** (`ARTIST`) decides the filename suffix. In the same change every tag
value passes through one **Slug** rule whose only separator is `-`, replacing a
scheme in which `_` and `-` collided with each other and with themselves.

## Considered Options

**Album Artist over parsing the first name out of `ARTIST`.** Splitting
`aespa; G-DRAGON` on its separator and keeping the head would group this album
identically without needing a second tag. It guesses, though, and guesses wrong
on a genuine joint release: an album credited to two artists throughout, where
`ALBUMARTIST` legitimately holds both names, would file under the first name
alone. Reading a tag that already states the answer beats inferring it.

**Fallback over quarantine when `ALBUMARTIST` is missing.** Treating an absent
`ALBUMARTIST` as unusable metadata and sending the file to Skipped would be
consistent with how a missing `TITLE` is handled. It would also mean
hand-tagging every file from a tagger that omits the tag, for no benefit:
`ARTIST` is exactly what the old behaviour used, so the fallback is a strict
improvement over the status quo rather than a guess. The Slug of the resolved
value is still validated, so a file with neither tag is quarantined as before.

The fallback deliberately sits in the tag layer, ahead of slugging, so it fires
only on a tag that is truly absent or empty. An `ALBUMARTIST` that is present
but whitespace or pure punctuation is a real value as far as this rule is
concerned: it slugs to nothing, fails the completeness check, and quarantines
the file even though `ARTIST` would have served. Moving the fallback behind
slugging would absorb that case in one line and was rejected on purpose. A tag
that is present and unusable is a tagging error, and this repo's shells answer
those by failing loudly rather than by papering over them; quarantine costs one
retag and loses nothing, while a silent substitution would file the release
under a name its own metadata never claimed.

**Track Artist kept in the filename.** Once the directory stops recording the
collaboration, the filename is the only place it can survive. Naming the Album
Artist there instead would make the suffix redundant with the directory and lose
the guest credit from the filesystem entirely. The cost is a filename whose `-`
between fields looks like any `-` inside a field; the tags remain the authority
on field boundaries.

**One separator over repairing the old two.** The narrower fix, keeping `_` as
the word separator and only collapsing the `__`, `_-_` and edge cases it
produced, was rejected because it leaves names mixing both characters
(`lemonade-the_2nd_album`) with no rule a reader can state. Reserving `-` purely
as a field boundary and stripping every `-` out of tag values was rejected for
the opposite reason: it destroys real content, turning `G-DRAGON` into
`g_dragon` and deleting the dash from the album's own title.

**Letters in the Unicode sense, not ASCII.** A strict `[a-z0-9]` rule is locale
independent and portable, but collapses a Hangul title to a row of separators,
so Korean and Japanese releases would be filed under nothing. The Slug therefore
keeps letters and digits of any script. Parentheses are the sole punctuation
exception, because the bracketed qualifier is load-bearing in this library's
titles.

## Consequences

- `organize_flac` pins `LC_ALL` to a UTF-8 locale. Without it, bash does not
  treat Hangul as a letter and the Slug rule silently mangles non-Latin titles
  when the script runs from a timer, a unit, or a bare SSH command. Pinning
  costs one line and cannot fail; probing and aborting was the alternative.
- `convert_flac` is unchanged. It derives the MP3 path by stripping the FLAC
  root prefix from the source path, so it mirrors the new layout with no rule of
  its own, and it slugs nothing, so it needs no locale pin either.
- Collapsing widens the set of inputs that produce the same name: `Rock & Roll`
  and `Rock Roll` both slug to `rock-roll`. The pre-existing collision guard
  carries the extra weight, reporting on stderr and leaving the second file
  where it is. Nothing is overwritten.
- A tag that is present but slugs to the empty string, a title made only of
  punctuation, now counts as unusable and sends its file to Skipped. The
  completeness check reads the slugged value, not the raw tag.
- `organize_flac` removes the directories a run empties, confined to the FLAC
  tree so that Skipped and the MP3 tree are structurally out of reach. Without
  it, this migration alone would leave four husks and every future collaboration
  album would leave more.
- Existing libraries are renamed wholesale on the next run. That is the intended
  migration, and it is why reversing this decision later is expensive.
