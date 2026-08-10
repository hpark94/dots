#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# MUSIC_DIR derives from $HOME, so pointing HOME at BATS_TEST_TMPDIR keeps every
# `mv` away from the real library; the metaflac stub answers from TAG_*.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    music_dir="${HOME}/Music"
    mkdir -p "${music_dir}"
    SCRIPT="${BATS_TEST_DIRNAME}/../organize_flac"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    export TAG_ALBUMARTIST="Some Artist"
    export TAG_ARTIST="Some Artist"
    export TAG_ALBUM="Some Album"
    export TAG_TITLE="Some Title"
    export TAG_TRACKNUMBER="3/12"

    # An unset or empty TAG_* prints nothing, which is what a missing tag looks
    # like to the script. TAG_<tag>_<basename> tags one file apart from the rest,
    # so a test can put two differently tagged files through a single run.
    cat >"${STUB_BIN}/metaflac" <<'STUB_EOF'
#!/usr/bin/env bash
case "$1" in
--show-tag=*)
    tag="${1#--show-tag=}"
    base="$(basename "$2" .flac)"
    # Folded to identifier characters: a filed name like 03-some-title-x is not
    # a legal variable name, and the lookup below would abort on it.
    var="TAG_${tag}_${base//[^A-Za-z0-9_]/_}"
    [[ -n "${!var:-}" ]] || var="TAG_${tag}"
    if [[ -n "${!var:-}" ]]; then
        printf '%s=%s\n' "${tag}" "${!var}"
    fi
    ;;
esac
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/metaflac"
}

@test "a file without TRACKNUMBER is moved to skipped/ instead of aborting the run" {
    export TAG_TRACKNUMBER=""
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"metadata missing"* ]]
    [ -f "${music_dir}/skipped/song.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}

@test "a non-numeric TRACKNUMBER is moved to skipped/ instead of aborting the run" {
    export TAG_TRACKNUMBER="A1"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"metadata missing or unusable"* ]]
    [ -f "${music_dir}/skipped/song.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}

@test "a fully tagged file is renamed into artist/album with a padded track number" {
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-some-title-some-artist.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}

@test "a zero-padded TRACKNUMBER is not read as an octal number" {
    export TAG_TRACKNUMBER="08"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/08-some-title-some-artist.flac" ]
}

@test "a three-digit zero-padded TRACKNUMBER keeps its decimal value" {
    export TAG_TRACKNUMBER="012"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/12-some-title-some-artist.flac" ]
}

@test "a tag value containing = is not truncated at the =" {
    export TAG_ALBUM="Greatest = Hits"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/greatest-hits/03-some-title-some-artist.flac" ]
}

@test "a second untagged file of the same name does not overwrite the first in skipped/" {
    export TAG_TRACKNUMBER=""
    mkdir -p "${music_dir}/skipped"
    printf 'first' >"${music_dir}/skipped/song.flac"
    printf 'second' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"already taken"* ]]
    [ "$(cat "${music_dir}/skipped/song.flac")" = "first" ]
    [ -f "${music_dir}/song.flac" ]
}

@test "a file whose target name is taken is left where it is" {
    local target="${music_dir}/flac/some-artist/some-album"
    mkdir -p "${target}"
    printf 'first' >"${target}/03-some-title-some-artist.flac"
    printf 'second' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"already taken"* ]]
    [ "$(cat "${target}/03-some-title-some-artist.flac")" = "first" ]
    [ -f "${music_dir}/song.flac" ]
}

@test "tracks sharing an Album Artist but differing in Track Artist land in one directory" {
    export TAG_ARTIST_duet="Some Artist; A Guest"
    export TAG_TITLE_duet="Another Title"
    export TAG_TRACKNUMBER_duet="4"
    printf 'flac bytes' >"${music_dir}/solo.flac"
    printf 'flac bytes' >"${music_dir}/duet.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"already taken"* ]]
    [ -f "${music_dir}/flac/some-artist/some-album/03-some-title-some-artist.flac" ]
    [ -f "${music_dir}/flac/some-artist/some-album/04-another-title-some-artist-a-guest.flac" ]
}

@test "the filename suffix names the Track Artist, not the Album Artist" {
    export TAG_ARTIST="Some Artist; A Guest"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-some-title-some-artist-a-guest.flac" ]
}

@test "a missing ALBUMARTIST falls back to ARTIST for the directory" {
    export TAG_ALBUMARTIST=""
    export TAG_ARTIST="Lone Tagger"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/lone-tagger/some-album/03-some-title-lone-tagger.flac" ]
}

@test "neither ALBUMARTIST nor ARTIST sends the file to skipped/" {
    export TAG_ALBUMARTIST=""
    export TAG_ARTIST=""
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"metadata missing or unusable"* ]]
    [ -f "${music_dir}/skipped/song.flac" ]
}

@test "a dash surrounded by spaces yields a single separator" {
    export TAG_ALBUM="LEMONADE - The 2nd Album"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/lemonade-the-2nd-album/03-some-title-some-artist.flac" ]
}

@test "a leading apostrophe yields no leading or doubled separator" {
    export TAG_TITLE="'Til We Die"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-til-we-die-some-artist.flac" ]
}

@test "a trailing apostrophe yields no stranded separator before the suffix" {
    export TAG_TITLE="Shakin'"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-shakin-some-artist.flac" ]
}

@test "a Hangul title keeps its characters" {
    export TAG_TITLE="이미 (Already) - Remix"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-이미-(already)-remix-some-artist.flac" ]
}

@test "a Hangul title survives a C locale in the environment" {
    export LC_ALL=C
    export TAG_TITLE="이미 (Already)"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-이미-(already)-some-artist.flac" ]
}

@test "parentheses survive while other punctuation does not" {
    export TAG_TITLE="WDA (Whole Different Animal)"
    export TAG_ARTIST="aespa; Ty Dolla \$ign"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-wda-(whole-different-animal)-aespa-ty-dolla-ign.flac" ]
}

@test "a title of pure punctuation slugs to empty and goes to skipped/" {
    export TAG_TITLE="!!!"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"metadata missing or unusable"* ]]
    [ -f "${music_dir}/skipped/song.flac" ]
}

@test "two distinct titles that slug to the same name leave the first file intact" {
    export TAG_TITLE="Rock & Roll"
    printf 'first' >"${music_dir}/one.flac"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]

    export TAG_TITLE="Rock Roll"
    printf 'second' >"${music_dir}/two.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"already taken"* ]]
    [ "$(cat "${music_dir}/flac/some-artist/some-album/03-rock-roll-some-artist.flac")" = "first" ]
    [ "$(cat "${music_dir}/two.flac")" = "second" ]
}

@test "a second run over the filed result moves nothing" {
    printf 'flac bytes' >"${music_dir}/song.flac"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Not changed"* ]]
    [ -f "${music_dir}/flac/some-artist/some-album/03-some-title-some-artist.flac" ]
}

@test "a directory emptied by a move is removed" {
    mkdir -p "${music_dir}/flac/old-artist/old-album"
    printf 'flac bytes' >"${music_dir}/flac/old-artist/old-album/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some-artist/some-album/03-some-title-some-artist.flac" ]
    [ ! -e "${music_dir}/flac/old-artist" ]
}

@test "an empty skipped/ directory is not removed by the sweep" {
    mkdir -p "${music_dir}/skipped"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -d "${music_dir}/skipped" ]
}
