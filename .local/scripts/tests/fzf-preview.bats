#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Every command the script can reach is stubbed on a prepended PATH and records
# its args to a file, so the assertions see the exact renderer invocation
# without depending on whichever eza/bat/kitten/chafa happens to be installed.

SCRIPT="${BATS_TEST_DIRNAME}/../fzf-preview"

# Writes an executable stub that records its args, with the body read from
# stdin. A stub answers out of the environment rather than out of a file,
# because a PATH stripped down to the stubs has no coreutils left to read one.
stub() {
    local name="$1"

    {
        printf '#!/usr/bin/env bash\n'
        printf 'printf "%%s\\n" "$@" >"%s"\n' "${BATS_TEST_TMPDIR}/${name}.args"
        cat
    } >"${STUB_BIN}/${name}"
    chmod +x "${STUB_BIN}/${name}"
}

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    EZA_ARGS="${BATS_TEST_TMPDIR}/eza.args"
    BAT_ARGS="${BATS_TEST_TMPDIR}/bat.args"
    FILE_ARGS="${BATS_TEST_TMPDIR}/file.args"
    TMUX_ARGS="${BATS_TEST_TMPDIR}/tmux.args"
    KITTEN_ARGS="${BATS_TEST_TMPDIR}/kitten.args"
    CHAFA_ARGS="${BATS_TEST_TMPDIR}/chafa.args"

    # What the stubbed file(1) and tmux(1) answer, overridden per test.
    export STUB_MIME="text/plain"
    export STUB_TERMNAME="xterm-256color"

    stub eza <<'STUB_EOF'
printf 'tree line\n'
STUB_EOF
    stub bat <<'STUB_EOF'
printf 'file line\n'
STUB_EOF
    stub file <<'STUB_EOF'
printf '%s\n' "${STUB_MIME}"
STUB_EOF
    stub tmux <<'STUB_EOF'
printf '%s\n' "${STUB_TERMNAME}"
STUB_EOF
    stub kitten <<'STUB_EOF'
printf 'kitten render\n'
STUB_EOF
    stub chafa <<'STUB_EOF'
printf 'chafa render\n'
STUB_EOF

    # The suite itself runs inside some terminal, usually inside tmux; the
    # script must see only what each test says it should.
    unset TMUX
    export TERM="xterm-256color"
    export FZF_PREVIEW_COLUMNS=40
    export FZF_PREVIEW_LINES=20
}

# A PATH holding every stub except the named one.
path_without() {
    local missing="$1" cmd
    local dir="${BATS_TEST_TMPDIR}/without-${missing}"
    mkdir -p "${dir}"
    # The stubs are `#!/usr/bin/env bash` scripts, so the interpreter has to be
    # reachable on this PATH too or every stub fails as command-not-found.
    ln -sf "${BASH}" "${dir}/bash"
    for cmd in eza bat file tmux kitten chafa; do
        [[ "${cmd}" == "${missing}" ]] && continue
        ln -sf "${STUB_BIN}/${cmd}" "${dir}/${cmd}"
    done
    printf '%s' "${dir}"
}

# Creates a file that the stubbed file(1) calls an image, and names it in
# IMAGE. Not a command substitution: the STUB_MIME it sets has to outlive it.
an_image() {
    IMAGE="${BATS_TEST_TMPDIR}/pic.png"
    printf 'not really a png\n' >"${IMAGE}"
    STUB_MIME="image/png"
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

@test "a path starting with a dash is an operand, not a flag" {
    cd "${BATS_TEST_TMPDIR}"
    printf 'content\n' >./-dash.txt

    run -- "${SCRIPT}" -dash.txt
    [ "${status}" -eq 0 ]
    [ "${output}" = "file line" ]
    [[ "$(cat "${FILE_ARGS}")" == *$'--\n-dash.txt'* ]]
    [[ "$(cat "${BAT_ARGS}")" == *$'--\n-dash.txt'* ]]
}

@test "a directory starting with a dash is an operand, not a flag" {
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p ./-dashdir

    run -- "${SCRIPT}" -dashdir
    [ "${status}" -eq 0 ]
    [[ "$(cat "${EZA_ARGS}")" == *$'--\n-dashdir'* ]]
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

@test "an image under ghostty is rendered with kitten" {
    an_image
    STUB_TERMNAME="xterm-ghostty"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    local args
    args=$(cat "${KITTEN_ARGS}")
    [[ "$(cat "${FILE_ARGS}")" == *"--mime-type"* ]]
    [[ "${args}" == "icat"* ]]
    [[ "${args}" == *"--stdin=no"* ]]
    [[ "${args}" == *"--transfer-mode=memory"* ]]
    [[ "${args}" == *$'--place\n40x20@0x0'* ]]
    [[ "${args}" == *$'--passthrough\ntmux'* ]]
    [[ "${args}" == *"${IMAGE}"* ]]
    [ ! -e "${CHAFA_ARGS}" ]
    [ ! -e "${BAT_ARGS}" ]
}

@test "an image under kitty is rendered with kitten" {
    an_image
    STUB_TERMNAME="xterm-kitty"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${KITTEN_ARGS}")" == "icat"* ]]
    [ ! -e "${CHAFA_ARGS}" ]
}

@test "an image under foot is rendered as sixels" {
    an_image
    STUB_TERMNAME="foot"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "chafa render" ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsixels'* ]]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-s\n40x20'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${BAT_ARGS}" ]
}

@test "an image under an unknown terminal is rendered as symbols" {
    an_image
    STUB_TERMNAME="screen-256color"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

@test "the terminal name comes from the tmux client, not from TERM" {
    an_image
    STUB_TERMNAME="xterm-ghostty"
    export TMUX="/tmp/fake,1,0"
    export TERM="foot"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMUX_ARGS}")" == *"client_termname"* ]]
    [ -e "${KITTEN_ARGS}" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

@test "outside tmux the terminal name comes from TERM and nothing is passed through" {
    an_image
    export TERM="xterm-ghostty"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    [[ "$(cat "${KITTEN_ARGS}")" != *"--passthrough"* ]]
    [[ "$(cat "${KITTEN_ARGS}")" == *"--unicode-placeholder"* ]]
    [ ! -e "${TMUX_ARGS}" ]
}

@test "a rung whose binary is missing falls through to the next" {
    an_image
    STUB_TERMNAME="xterm-ghostty"
    export TMUX="/tmp/fake,1,0"

    run env PATH="$(path_without kitten)" "${BASH}" "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${BAT_ARGS}" ]
}

@test "a rung whose binary fails falls through to the next" {
    an_image
    STUB_TERMNAME="xterm-ghostty"
    export TMUX="/tmp/fake,1,0"
    stub kitten <<'STUB_EOF'
exit 1
STUB_EOF

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
}

@test "a failing last rung falls back to the text path" {
    an_image
    stub chafa <<'STUB_EOF'
exit 1
STUB_EOF

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "file line" ]
    [[ "$(cat "${BAT_ARGS}")" == *"${IMAGE}"* ]]
}

@test "without file(1) an image takes the text path quietly" {
    an_image

    run --separate-stderr env PATH="$(path_without file)" "${BASH}" "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "file line" ]
    [ -z "${stderr}" ]
    [[ "$(cat "${BAT_ARGS}")" == *"${IMAGE}"* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

@test "inside tmux without the tmux binary the name comes from TERM" {
    an_image
    export TMUX="/tmp/fake,1,0"
    export TERM="xterm-ghostty"

    run --separate-stderr env PATH="$(path_without tmux)" "${BASH}" "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    [ -z "${stderr}" ]
}

@test "an image still renders when eza is missing" {
    an_image
    STUB_TERMNAME="xterm-ghostty"
    export TMUX="/tmp/fake,1,0"

    run env PATH="$(path_without eza)" "${BASH}" "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
}

@test "outside fzf the geometry falls back to a whole default screen" {
    an_image
    unset FZF_PREVIEW_COLUMNS FZF_PREVIEW_LINES

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-s\n80x24'* ]]
}
