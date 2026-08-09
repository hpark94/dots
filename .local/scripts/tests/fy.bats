#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for fy. Mocks wl-copy with a stub that records its args and
# stdin to files on disk, so assertions survive the `run bash "$SCRIPT"` subshell
# and can inspect exactly what was placed on the clipboard.

SCRIPT="${BATS_TEST_DIRNAME}/../../../.local/scripts/fy"

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    mkdir -p "${BATS_TEST_TMPDIR}/stub-bin"
    export PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}"
    WL_COPY_ARGS="${BATS_TEST_TMPDIR}/wl-copy.args"
    WL_COPY_STDIN="${BATS_TEST_TMPDIR}/wl-copy.stdin"
}

# wl-copy stub: record args and stdin, then succeed.
setup_wl_copy_stub() {
    cat >"${BATS_TEST_TMPDIR}/stub-bin/wl-copy" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >"${WL_COPY_ARGS}"
cat >"${WL_COPY_STDIN}"
exit 0
STUB_EOF
    chmod +x "${BATS_TEST_TMPDIR}/stub-bin/wl-copy"
}

# wl-copy stub that records then fails.
setup_failing_wl_copy_stub() {
    cat >"${BATS_TEST_TMPDIR}/stub-bin/wl-copy" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >"${WL_COPY_ARGS}"
cat >"${WL_COPY_STDIN}"
exit 1
STUB_EOF
    chmod +x "${BATS_TEST_TMPDIR}/stub-bin/wl-copy"
}

create_test_file() {
    local filepath="$1" content="$2"
    mkdir -p "$(dirname "${filepath}")"
    printf '%s' "${content}" >"${filepath}"
}

@test "fy errors with no arguments" {
    setup_wl_copy_stub
    run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"usage: fy <file>"* ]]
}

@test "fy errors with multiple arguments" {
    setup_wl_copy_stub
    create_test_file "${BATS_TEST_TMPDIR}/a.txt" "a"
    create_test_file "${BATS_TEST_TMPDIR}/b.txt" "b"
    run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/a.txt" "${BATS_TEST_TMPDIR}/b.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"usage: fy <file>"* ]]
}

@test "fy errors when file does not exist" {
    setup_wl_copy_stub
    run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/nonexistent.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"file does not exist"* ]]
}

@test "fy errors when wl-copy is unavailable" {
    create_test_file "${BATS_TEST_TMPDIR}/test.txt" "content"
    # PATH with bash and realpath but no wl-copy, so command -v wl-copy fails.
    mkdir -p "${BATS_TEST_TMPDIR}/nowl"
    ln -s "$(command -v bash)" "${BATS_TEST_TMPDIR}/nowl/bash"
    ln -s "$(command -v realpath)" "${BATS_TEST_TMPDIR}/nowl/realpath"
    PATH="${BATS_TEST_TMPDIR}/nowl" run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/test.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"wl-copy not available"* ]]
}

@test "fy errors when clipboard copy fails" {
    setup_failing_wl_copy_stub
    create_test_file "${BATS_TEST_TMPDIR}/test.txt" "content"
    run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/test.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"failed to copy file to clipboard"* ]]
}

@test "fy copies a text/uri-list reference for one file" {
    setup_wl_copy_stub
    create_test_file "${BATS_TEST_TMPDIR}/test.txt" "content"
    run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/test.txt"
    [ "${status}" -eq 0 ]
    [ "$(cat "${WL_COPY_ARGS}")" = "--type text/uri-list" ]
    local expected
    expected=$(printf 'file://%s\r\n' "$(realpath "${BATS_TEST_TMPDIR}/test.txt")")
    [ "$(cat "${WL_COPY_STDIN}")" = "${expected}" ]
}

@test "fy percent-encodes a filename with a space" {
    setup_wl_copy_stub
    create_test_file "${BATS_TEST_TMPDIR}/a b.txt" "content"
    run bash "${SCRIPT}" "${BATS_TEST_TMPDIR}/a b.txt"
    [ "${status}" -eq 0 ]
    local payload
    payload=$(cat "${WL_COPY_STDIN}")
    [[ "${payload}" == *"/a%20b.txt"* ]]
    [[ "${payload}" != *"/a b.txt"* ]]
}

@test "fy outputs the tilde-collapsed path on stdout" {
    setup_wl_copy_stub
    create_test_file "${HOME}/test.txt" "content"
    run bash "${SCRIPT}" "${HOME}/test.txt"
    [ "${status}" -eq 0 ]
    [ "${output}" = "~/test.txt" ]
}
