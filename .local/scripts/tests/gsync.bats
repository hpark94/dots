#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for gsync's argument handling. `git` is stubbed to log the
# subcommands it was handed, so a test can prove gsync rejected its arguments
# before reaching the working tree at all.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../gsync"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"
    export GIT_LOG="${BATS_TEST_TMPDIR}/git.log"
    : >"${GIT_LOG}"
    cat >"${STUB_BIN}/git" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GIT_LOG"
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/git"
}

@test "gsync rejects a second argument and runs no git command" {
    run "${SCRIPT}" "first message" "second"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"gsync: usage: gsync [message]"* ]]
    [[ "${output}" == *"got 2"* ]]
    [ ! -s "${GIT_LOG}" ]
}

@test "gsync uses a single argument as the commit message" {
    run "${SCRIPT}" "my message"
    [ "${status}" -eq 0 ]
    grep -qx "commit -m my message" "${GIT_LOG}"
}
