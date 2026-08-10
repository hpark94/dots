#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for organize_flac. The script derives MUSIC_DIR from $HOME, so
# pointing HOME at BATS_TEST_TMPDIR keeps every `mv` inside a throwaway tree and
# away from the real music library. metaflac is stubbed to dictate the tags.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    music_dir="${HOME}/music"
    mkdir -p "${music_dir}"
    SCRIPT="${BATS_TEST_DIRNAME}/../organize_flac"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"
}

# metaflac stub answering --show-tag=TRACKNUMBER with the given value; an empty
# value makes it print nothing, which is what a missing tag looks like.
setup_metaflac_stub() {
    cat >"${STUB_BIN}/metaflac" <<STUB_EOF
#!/usr/bin/env bash
case "\$1" in
--show-tag=ARTIST) printf 'ARTIST=Some Artist\n' ;;
--show-tag=ALBUM) printf 'ALBUM=Some Album\n' ;;
--show-tag=TITLE) printf 'TITLE=Some Title\n' ;;
--show-tag=TRACKNUMBER) [[ -n "${1}" ]] && printf 'TRACKNUMBER=%s\n' "${1}" ;;
esac
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/metaflac"
}

@test "a file without TRACKNUMBER is moved to skipped/ instead of aborting the run" {
    setup_metaflac_stub ""
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"metadata missing"* ]]
    [ -f "${music_dir}/skipped/song.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}

@test "a fully tagged file is renamed into artist/album with a padded track number" {
    setup_metaflac_stub "3/12"
    printf 'flac bytes' >"${music_dir}/song.flac"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${music_dir}/flac/some_artist/some_album/03_some_title-some_artist.flac" ]
    [ ! -e "${music_dir}/song.flac" ]
}
