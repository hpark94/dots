#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# fd and fzf are stubbed on a prepended PATH: fzf records every argument on its
# own line so the multi-line opener and the preview wiring can be asserted
# verbatim, and no interactive picker is ever started.

SCRIPT="${BATS_TEST_DIRNAME}/../ffd"

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    FD_ARGS="${BATS_TEST_TMPDIR}/fd.args"
    FZF_ARGS="${BATS_TEST_TMPDIR}/fzf.args"

    cat >"${STUB_BIN}/fd" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FD_ARGS}"
printf 'a.txt\nb.txt\n'
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    make_fzf_stub 0
}

# fzf stub: record args, then exit with the requested status.
make_fzf_stub() {
    cat >"${STUB_BIN}/fzf" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FZF_ARGS}"
exit $1
STUB_EOF
    chmod +x "${STUB_BIN}/fzf"
}

@test "a missing fd fails loudly" {
    run env PATH=/nonexistent "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fd not available"* ]]
}

@test "a missing fzf fails loudly" {
    mkdir -p "${BATS_TEST_TMPDIR}/fd-only"
    ln -s "${STUB_BIN}/fd" "${BATS_TEST_TMPDIR}/fd-only/fd"

    run env PATH="${BATS_TEST_TMPDIR}/fd-only" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fzf not available"* ]]
    [ ! -e "${FD_ARGS}" ]
}

@test "a tool that is not on PATH fails loudly" {
    run "${SCRIPT}" no-such-tool
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'no-such-tool' is not installed or not in PATH"* ]]
    [ ! -e "${FD_ARGS}" ]
}

@test "fd is asked for hidden files outside .git" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FD_ARGS}")
    [[ "${args}" == *$'-t\nf\n.'* ]]
    [[ "${args}" == *"--hidden"* ]]
    [[ "${args}" == *$'--exclude\n.git/'* ]]
}

@test "fd errors are not swallowed" {
    cat >"${STUB_BIN}/fd" <<'STUB_EOF'
#!/usr/bin/env bash
echo "fd: broken glob" >&2
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    run "${SCRIPT}"
    [[ "${output}" == *"fd: broken glob"* ]]
}

@test "fd dying on SIGPIPE is not a failure of this script" {
    # fzf stops reading once the user picks; make fd write far more than a pipe
    # buffer holds so it is guaranteed to still be writing when fzf leaves, and
    # so gets killed by SIGPIPE instead of exiting cleanly.
    cat >"${STUB_BIN}/fd" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FD_ARGS}"
seq 1 200000
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "fzf previews through fzf-preview" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *$'--preview\nfzf-preview {}'* ]]
    [[ "${args}" == *$'--preview-window\n<80(up)'* ]]
    [[ "${args}" == *"--multi"* ]]
    [[ "${args}" == *"--ansi"* ]]
}

@test "a terminal tool opens in place" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *"enter:become:bash -c 'nvim  \"\$@\"' _ {+}"* ]]
    [[ "${args}" == *"ctrl-o:execute:bash -c 'nvim  \"\$@\"' _ {+}"* ]]
    [[ "${args}" == *"esc:abort"* ]]
    [[ "${args}" == *"alt-a:select-all"* ]]
    [[ "${args}" == *"alt-d:deselect-all"* ]]
    [[ "${args}" == *"ctrl-/:toggle-preview"* ]]
}

@test "a non-terminal tool is launched in the background" {
    cat >"${STUB_BIN}/myviewer" <<'STUB_EOF'
#!/usr/bin/env bash
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/myviewer"

    run "${SCRIPT}" myviewer --flag
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *'myviewer --flag "$1" &>/dev/null &'* ]]
    [[ "${args}" == *'for file in "$@"; do'* ]]
}

@test "an fzf abort is not an error" {
    make_fzf_stub 130

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "an empty fzf result is not an error" {
    make_fzf_stub 1

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "a real fzf failure keeps its status" {
    make_fzf_stub 2

    run "${SCRIPT}"
    [ "${status}" -eq 2 ]
}
