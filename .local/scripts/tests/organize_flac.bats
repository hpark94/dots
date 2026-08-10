#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for organize_flac. The script derives MUSIC_DIR from $HOME, so
# pointing HOME at BATS_TEST_TMPDIR keeps every `mv` inside a throwaway tree and
# away from the real music library. metaflac is stubbed and reads the tag values
# from the TAG_* variables a test exports.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    music_dir="${HOME}/music"
    mkdir -p "${music_dir}"
    SCRIPT="${BATS_TEST_DIRNAME}/../organize_flac"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    export TAG_ARTIST="Some Artist"
    export TAG_ALBUM="Some Album"
    export TAG_TITLE="Some Title"
    export TAG_TRACKNUMBER="3/12"

    # An unset or empty TAG_* prints nothing, which is what a missing tag looks
    # like to the script.
    cat >"${STUB_BIN}/metaflac" <<'STUB_EOF'
#!/usr/bin/env bash
case "$1" in
--show-tag=*)
    tag="${1#--show-tag=}"
    var="TAG_${tag}"
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
    [ -f "${music_dir}/flac/some_artist/some_album/03_some_title-some_artist.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}

@test "a zero-padded TRACKNUMBER is not read as an octal number" {
    export TAG_TRACKNUMBER="08"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some_artist/some_album/08_some_title-some_artist.flac" ]
}

@test "a three-digit zero-padded TRACKNUMBER keeps its decimal value" {
    export TAG_TRACKNUMBER="012"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some_artist/some_album/12_some_title-some_artist.flac" ]
}

@test "a tag value containing = survives intact" {
    export TAG_ALBUM="Greatest = Hits"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some_artist/greatest_=_hits/03_some_title-some_artist.flac" ]
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
    local target="${music_dir}/flac/some_artist/some_album"
    mkdir -p "${target}"
    printf 'first' >"${target}/03_some_title-some_artist.flac"
    printf 'second' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"already taken"* ]]
    [ "$(cat "${target}/03_some_title-some_artist.flac")" = "first" ]
    [ -f "${music_dir}/song.flac" ]
}
