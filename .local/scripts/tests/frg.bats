#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# fzf is stubbed on a prepended PATH and records every argument on its own line,
# so the reload, opener and preview strings can be asserted verbatim without
# starting an interactive picker; rg only needs to exist on PATH, because frg
# never runs it itself, fzf does.

SCRIPT="${BATS_TEST_DIRNAME}/../frg"

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    FZF_ARGS="${BATS_TEST_TMPDIR}/fzf.args"

    printf '#!/usr/bin/env bash\nexit 0\n' >"${STUB_BIN}/rg"
    chmod +x "${STUB_BIN}/rg"

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

# A PATH holding every stub except the named one.
path_without() {
    local missing="$1" cmd
    local dir="${BATS_TEST_TMPDIR}/without-${missing}"
    mkdir -p "${dir}"
    for cmd in rg fzf; do
        [[ "${cmd}" == "${missing}" ]] && continue
        ln -sf "${STUB_BIN}/${cmd}" "${dir}/${cmd}"
    done
    printf '%s' "${dir}"
}

@test "a missing rg fails loudly" {
    run env PATH="$(path_without rg)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"rg not available"* ]]
    [ ! -e "${FZF_ARGS}" ]
}

@test "a missing fzf fails loudly" {
    run env PATH="$(path_without fzf)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fzf not available"* ]]
}

@test "fzf drives rg instead of filtering itself" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *"--disabled"* ]]
    [[ "${args}" == *$'--delimiter\n:'* ]]
    [[ "${args}" == *'start:reload:rg --column --hidden --color=always --smart-case --glob "!.git/**" {q} || :'* ]]
    [[ "${args}" == *'change:reload:rg --column --hidden --color=always --smart-case --glob "!.git/**" {q} || :'* ]]
}

@test "the query is seeded from the arguments" {
    run "${SCRIPT}" foo bar
    [ "${status}" -eq 0 ]
    [[ "$(cat "${FZF_ARGS}")" == *$'--query\nfoo bar'* ]]
}

@test "enter and ctrl-o open the match in nvim" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *'if [[ $FZF_SELECT_COUNT -eq 0 ]]; then'* ]]
    [[ "${args}" == *"nvim {1} +{2}"* ]]
    [[ "${args}" == *"nvim +cw -q {+f}"* ]]
    [[ "${args}" == *"esc:abort"* ]]
    [[ "${args}" == *"alt-a:select-all"* ]]
    [[ "${args}" == *"alt-d:deselect-all"* ]]
    [[ "${args}" == *"ctrl-/:toggle-preview"* ]]
}

@test "the preview is the shared renderer, told which line matched" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *$'--preview\nfzf-preview {1} {2}'* ]]
}

@test "fzf centres the matched line itself" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${FZF_ARGS}")" == *$'--preview-window\n+{2}-/2,<80(up)'* ]]
}

@test "no hand-rolled preview window is left in the fzf arguments" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    # Matched on the invocation shapes, not the bare names: fzf's own --header
    # and --tail options contain "head" and "tail" as substrings.
    [[ "${args}" != *"wc -l"* ]]
    [[ "${args}" != *"tail -n"* ]]
    [[ "${args}" != *"head -n"* ]]
    [[ "${args}" != *"bat --style"* ]]
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
