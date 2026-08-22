#!/usr/bin/env bats

# The seam is a real tmux server rather than the config text: a line tmux
# refuses to parse would still satisfy a grep over the file. The server runs on
# its own socket under a temporary HOME, so neither the theme fragment nor the
# plugin manager needs to exist for the config to load.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    CONFIG="${BATS_TEST_DIRNAME}/../../../.tmux.conf"
    SOCKET="${BATS_TEST_TMPDIR}/socket"
    tmux -S "${SOCKET}" -f "${CONFIG}" new-session -d -s test
}

teardown() {
    tmux -S "${SOCKET}" kill-server 2>/dev/null
}

# `list-keys -T <table>` reports through the message log rather than stdout on a
# server with no attached client, so every assertion reads the unfiltered
# listing and matches the table in the line.
list_keys() {
    tmux -S "${SOCKET}" list-keys
}

@test "the sessionizer key is bound in the prefix table to a popup" {
    run list_keys
    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" \
        | grep -qE '^bind-key +-T prefix +C-f +display-popup .*tmux-sessionizer$'
}

@test "the sessionizer key is absent from the off key table" {
    run list_keys
    [ "${status}" -eq 0 ]
    ! printf '%s\n' "${output}" | grep -qE '^bind-key +-T off +C-f '
}
