#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# eza and bat are stubbed on a prepended PATH and record their args to a file,
# so the assertions see the exact renderer invocation without depending on
# whichever eza/bat version happens to be installed.

SCRIPT="${BATS_TEST_DIRNAME}/../fzf-preview"

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    EZA_ARGS="${BATS_TEST_TMPDIR}/eza.args"
    BAT_ARGS="${BATS_TEST_TMPDIR}/bat.args"

    cat >"${STUB_BIN}/eza" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${EZA_ARGS}"
printf 'tree line\n'
STUB_EOF
    chmod +x "${STUB_BIN}/eza"

    cat >"${STUB_BIN}/bat" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${BAT_ARGS}"
printf 'file line\n'
STUB_EOF
    chmod +x "${STUB_BIN}/bat"
}

# A PATH holding every stub except the named one.
path_without() {
    local missing="$1" cmd
    local dir="${BATS_TEST_TMPDIR}/without-${missing}"
    mkdir -p "${dir}"
    for cmd in eza bat; do
        [[ "${cmd}" == "${missing}" ]] && continue
        ln -sf "${STUB_BIN}/${cmd}" "${dir}/${cmd}"
    done
    printf '%s' "${dir}"
}

@test "a directory is rendered with eza" {
    mkdir -p "${BATS_TEST_TMPDIR}/dir"

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/dir"
    [ "${status}" -eq 0 ]
    [ "${output}" = "tree line" ]
    [[ "$(cat "${EZA_ARGS}")" == *"--tree"* ]]
    [[ "$(cat "${EZA_ARGS}")" == *"--level=2"* ]]
    [ ! -e "${BAT_ARGS}" ]
}

@test "a directory tree longer than 200 lines is truncated, not failed" {
    mkdir -p "${BATS_TEST_TMPDIR}/dir"
    cat >"${STUB_BIN}/eza" <<'STUB_EOF'
#!/usr/bin/env bash
seq 1 100000
STUB_EOF
    chmod +x "${STUB_BIN}/eza"

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/dir"
    [ "${status}" -eq 0 ]
    [ "${#lines[@]}" -eq 200 ]
}

@test "a file is rendered with bat" {
    printf 'content\n' >"${BATS_TEST_TMPDIR}/a.txt"

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/a.txt"
    [ "${status}" -eq 0 ]
    [ "${output}" = "file line" ]
    local args
    args=$(cat "${BAT_ARGS}")
    [[ "${args}" == *"--style=numbers"* ]]
    [[ "${args}" == *"--color=always"* ]]
    [[ "${args}" != *"--highlight-line"* ]]
    [ ! -e "${EZA_ARGS}" ]
}

@test "a line argument highlights that line" {
    printf 'content\n' >"${BATS_TEST_TMPDIR}/a.txt"

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/a.txt" 42
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${BAT_ARGS}")
    [[ "${args}" == *"--highlight-line"* ]]
    [[ "${args}" == *$'--highlight-line\n42'* ]]
}

@test "a missing path fails loudly" {
    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/nope.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"path does not exist"* ]]
    [ ! -e "${BAT_ARGS}" ]
    [ ! -e "${EZA_ARGS}" ]
}

@test "no arguments fail with a usage message" {
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"usage: fzf-preview <path> [line]"* ]]
}

@test "a missing eza fails loudly" {
    mkdir -p "${BATS_TEST_TMPDIR}/dir"

    run env PATH="$(path_without eza)" "${BASH}" "${SCRIPT}" "${BATS_TEST_TMPDIR}/dir"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"eza not available"* ]]
}

@test "a missing bat fails loudly" {
    printf 'content\n' >"${BATS_TEST_TMPDIR}/a.txt"

    run env PATH="$(path_without bat)" "${BASH}" "${SCRIPT}" "${BATS_TEST_TMPDIR}/a.txt"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"bat not available"* ]]
    [ ! -e "${EZA_ARGS}" ]
}

@test "too many arguments fail with a usage message" {
    printf 'content\n' >"${BATS_TEST_TMPDIR}/a.txt"

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/a.txt" 1 2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"usage: fzf-preview <path> [line]"* ]]
    [ ! -e "${BAT_ARGS}" ]
}
