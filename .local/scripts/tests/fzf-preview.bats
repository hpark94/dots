#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Every command the script can reach is stubbed on a prepended PATH and records
# its args to a file, so the assertions see the exact renderer invocation
# without depending on whichever eza/bat/kitten/chafa happens to be installed.

SCRIPT="${BATS_TEST_DIRNAME}/../fzf-preview"

# Writes an executable stub that records its args, with the body read from
# stdin. A stub answers out of the environment rather than out of a file,
# because a PATH stripped down to the stubs has no coreutils left to read one.
# `.args` holds the last call, one argument per line, so an assertion can see
# argument boundaries; `.log` appends one line per call, so a command the script
# invokes more than once still shows every question it asked.
stub() {
    local name="$1"

    {
        printf '#!/usr/bin/env bash\n'
        printf 'printf "%%s\\n" "$@" >"%s"\n' "${BATS_TEST_TMPDIR}/${name}.args"
        printf 'printf "%%s\\n" "$*" >>"%s"\n' "${BATS_TEST_TMPDIR}/${name}.log"
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
    TMUX_LOG="${BATS_TEST_TMPDIR}/tmux.log"
    KITTEN_ARGS="${BATS_TEST_TMPDIR}/kitten.args"
    CHAFA_ARGS="${BATS_TEST_TMPDIR}/chafa.args"
    CHAFA_LOG="${BATS_TEST_TMPDIR}/chafa.log"

    # What the stubbed file(1) and tmux(1) answer, overridden per test. The
    # tmux answers differ per subcommand and per format string, so a test can
    # prove which question the script asked and not merely which words it used.
    export STUB_MIME="text/plain"
    export STUB_TERMTYPE="xterm(390)"
    export STUB_TERMNAME="xterm-256color"
    # This machine's tmux, built without --enable-sixel; a test wanting the
    # sixel rung has to say so.
    export STUB_SIXEL="0"

    stub eza <<'STUB_EOF'
printf 'tree line\n'
STUB_EOF
    stub bat <<'STUB_EOF'
printf 'file line\n'
STUB_EOF
    stub file <<'STUB_EOF'
printf '%s\n' "${STUB_MIME}"
STUB_EOF
    # `display` still answers every format string a single-client tmux would,
    # so a test that asserts on `list-clients` proves the script asked the
    # honest question rather than one that merely mentions the same words.
    stub tmux <<'STUB_EOF'
case "$1" in
    list-clients)
        # One line per attached client. STUB_CLIENTS is that answer verbatim,
        # so a test can describe several clients or none at all; leaving it
        # unset means the one client STUB_TERMTYPE describes.
        if [[ -n "${STUB_CLIENTS+set}" ]]; then
            printf '%s' "${STUB_CLIENTS}"
        else
            printf '%s\n' "${STUB_TERMTYPE}"
        fi
        ;;
    display)
        case "$*" in
            *client_termtype*) printf '%s\n' "${STUB_TERMTYPE}" ;;
            *client_termname*) printf '%s\n' "${STUB_TERMNAME}" ;;
            *sixel_support*) printf '%s\n' "${STUB_SIXEL}" ;;
        esac
        ;;
esac
STUB_EOF
    stub kitten <<'STUB_EOF'
printf 'kitten render\n'
STUB_EOF
    stub chafa <<'STUB_EOF'
printf 'chafa render\n'
STUB_EOF

    # The suite itself runs inside some terminal, usually inside tmux; the
    # script must see only what each test says it should, TMUX_PANE included,
    # since it decides whether the client list is targeted at a session.
    unset TMUX TMUX_PANE TERM_PROGRAM
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

@test "an image under ghostty is rendered with kitten despite the claimed name" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    STUB_TERMNAME="xterm-256color"
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
    STUB_TERMTYPE="kitty(0.47.1)"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${KITTEN_ARGS}")" == "icat"* ]]
    [ ! -e "${CHAFA_ARGS}" ]
}

# foot.ini sets `term=xterm-256color`, so the claimed name never says foot and
# only the self-report can put this window on the sixel rung.
@test "an image under foot is rendered as sixels despite the claimed name" {
    an_image
    STUB_TERMTYPE="foot(1.27.0)"
    STUB_TERMNAME="xterm-256color"
    STUB_SIXEL="1"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "chafa render" ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsixels'* ]]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-s\n40x20'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${BAT_ARGS}" ]
}

# A tmux built without --enable-sixel erases the image a moment after drawing
# it, which is worse than blocky art that stays on the screen.
@test "under foot a tmux without sixel support gets symbols, not sixels" {
    an_image
    STUB_TERMTYPE="foot(1.27.0)"
    STUB_SIXEL="0"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [[ "$(cat "${CHAFA_ARGS}")" != *"sixels"* ]]
    [[ "$(cat "${TMUX_ARGS}")" == *"sixel_support"* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

@test "an image under an unknown terminal is rendered as symbols" {
    an_image
    STUB_TERMTYPE="xterm(390)"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

# chafa questions the terminal even when -f already decided the format, and
# waits its default 5 seconds for an answer that a tty console or an ssh session
# never sends. That would be a 5 second stall on every keystroke of a preview.
@test "a rung that already knows its format does not question the terminal" {
    an_image
    STUB_TERMTYPE="xterm(390)"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *"--probe=off"* ]]
}

# A terminal that answers no XTVERSION leaves #{client_termtype} empty, and the
# claimed name is not consulted to fill the gap: it is the source this ladder
# stopped trusting, and the empty string lands on the rung that cannot fail.
@test "an empty self-report is symbols, not a fall back to the claimed name" {
    an_image
    STUB_TERMTYPE=""
    STUB_TERMNAME="foot"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

@test "the self-report comes from the tmux client, not from TERM" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    export TMUX="/tmp/fake,1,0"
    export TERM="foot"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMUX_ARGS}")" == *"client_termtype"* ]]
    [[ "$(cat "${TMUX_ARGS}")" != *"client_termname"* ]]
    [ -e "${KITTEN_ARGS}" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

# `display -p` answers for whichever client tmux last considered current, which
# is a coin toss once a second terminal is attached to the session. Only the
# client list names them all, so the format string alone does not prove the
# script asked the right question.
@test "the self-report is read from the client list, not from display -p" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    grep -q 'list-clients .*#{client_termtype}' "${TMUX_LOG}"
    # Not `! grep`: a negated command is exempt from errexit, so it would assert
    # nothing here.
    if grep -q 'display .*client_termtype' "${TMUX_LOG}"; then
        echo "the self-report was read with display -p" >&2
        return 1
    fi
    [ -e "${KITTEN_ARGS}" ]
}

# An untargeted `list-clients` lists every client of every session, including
# the ones drawing nothing of this pane.
@test "the client list is targeted at the pane" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    export TMUX="/tmp/fake,1,0"
    export TMUX_PANE="%7"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMUX_ARGS}")" == *$'-t\n%7'* ]]
}

@test "without TMUX_PANE the client list is not targeted at all" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    if grep -qxF -- '-t' "${TMUX_ARGS}"; then
        echo "the client list was targeted although TMUX_PANE was unset" >&2
        return 1
    fi
    grep -qxF -- '#{client_termtype}' "${TMUX_ARGS}"
}

# The pane is drawn on both terminals at once, so neither the Kitty protocol nor
# sixels can be right for both. Symbol art is plain text, so it is.
@test "clients that disagree settle on symbol art" {
    an_image
    export TMUX="/tmp/fake,1,0"
    export STUB_CLIENTS=$'ghostty 1.3.1\nfoot(1.27.0)\n'
    # What `display -p` answered on the machine this was measured on, and what
    # taking either client's word for it would have drawn.
    STUB_TERMTYPE="foot(1.27.0)"
    STUB_SIXEL="1"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [[ "$(cat "${CHAFA_ARGS}")" != *"sixels"* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

@test "clients that agree keep their rung" {
    an_image
    export TMUX="/tmp/fake,1,0"
    export STUB_CLIENTS=$'ghostty 1.3.1\nghostty 1.3.1\n'

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

# A detached session still previews, for a client that may attach later and for
# `capture-pane`; nothing is drawing pixels, so the rung that cannot fail wins.
@test "a session with no attached client gets symbol art" {
    an_image
    export TMUX="/tmp/fake,1,0"
    export STUB_CLIENTS=""
    STUB_TERMTYPE="ghostty 1.3.1"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

# A terminal that answers no XTVERSION is a client like any other: it cannot be
# told to draw Kitty graphics, so it holds the whole set down.
@test "a client answering nothing collapses the set to symbol art" {
    an_image
    export TMUX="/tmp/fake,1,0"
    export STUB_CLIENTS=$'ghostty 1.3.1\n\n'
    STUB_TERMTYPE="ghostty 1.3.1"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

# Inside tmux TERM_PROGRAM reads `tmux`, and the copy in the server environment
# goes stale on a reattach from another terminal, so it may not be consulted.
@test "inside tmux TERM_PROGRAM loses to the tmux client" {
    an_image
    STUB_TERMTYPE="foot(1.27.0)"
    STUB_SIXEL="1"
    export TMUX="/tmp/fake,1,0"
    export TERM_PROGRAM="ghostty"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsixels'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
}

# Outside tmux nothing stands between chafa and the terminal, so the sixel rung
# is not gated and tmux is not consulted at all.
@test "outside tmux TERM_PROGRAM is the self-report, over TERM" {
    an_image
    export TERM_PROGRAM="foot"
    export TERM="xterm-256color"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsixels'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${TMUX_ARGS}" ]
    [ ! -e "${TMUX_LOG}" ]
}

@test "outside tmux TERM is the fallback, and nothing is passed through" {
    an_image
    export TERM="xterm-ghostty"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    [[ "$(cat "${KITTEN_ARGS}")" != *"--passthrough"* ]]
    [[ "$(cat "${KITTEN_ARGS}")" == *"--unicode-placeholder"* ]]
    [ ! -e "${TMUX_ARGS}" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

# A name that identifies the terminal is the whole answer, so the terminal is
# never asked and the common case pays nothing for the probe existing.
@test "outside tmux a name that gives a rung is never followed by a probe" {
    an_image
    export TERM_PROGRAM="kitty"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "kitten render" ]
    [ ! -e "${CHAFA_ARGS}" ]
}

# foot unsets TERM_PROGRAM in the process it starts and foot.ini renames $TERM,
# so outside tmux nothing in the environment names it. chafa asks the terminal
# instead, and no -f, because the answer is what chooses the format.
@test "outside tmux a name that gives no rung lets chafa probe the terminal" {
    an_image
    export TERM="xterm-256color"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "chafa render" ]
    # Newline-delimited on both sides, so `-f` is looked for as a whole
    # argument: `set -e` ignores a `!`-negated command, so a bare `! grep`
    # here would assert nothing.
    local args
    args=$'\n'
    args+="$(cat "${CHAFA_ARGS}")"$'\n'
    [[ "${args}" == *$'\n--probe=0.2\n'* ]]
    [[ "${args}" == *$'\n--probe-mode=ctty\n'* ]]
    [[ "${args}" == *$'\n-s\n40x20\n'* ]]
    [[ "${args}" == *$'\n'"${IMAGE}"$'\n'* ]]
    [[ "${args}" != *$'\n-f\n'* ]]
    [ "$(wc -l <"${CHAFA_LOG}")" -eq 1 ]
}

# Inside tmux the client's self-report already answered, for free and per
# client, so the round trip the probe costs buys nothing here.
@test "inside tmux a self-report that gives no rung still never probes" {
    an_image
    STUB_TERMTYPE=""
    export TMUX="/tmp/fake,1,0"

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    # --probe-mode, not --probe: the -f rungs carry --probe=off, which is the
    # opposite of a probe and would match a looser pattern.
    [[ "$(cat "${CHAFA_LOG}")" != *"--probe-mode"* ]]
    [[ "$(cat "${CHAFA_LOG}")" != *"--probe=0"* ]]
}

@test "outside tmux a failing probe still leaves a usable preview" {
    an_image
    export TERM="xterm-256color"
    stub chafa <<'STUB_EOF'
exit 1
STUB_EOF

    run "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "file line" ]
    grep -q -- '--probe=0.2' "${CHAFA_LOG}"
    grep -q -- '-f symbols' "${CHAFA_LOG}"
    [[ "$(cat "${BAT_ARGS}")" == *"${IMAGE}"* ]]
}

@test "a rung whose binary is missing falls through to the next" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
    export TMUX="/tmp/fake,1,0"

    run env PATH="$(path_without kitten)" "${BASH}" "${SCRIPT}" "${IMAGE}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${CHAFA_ARGS}")" == *$'-f\nsymbols'* ]]
    [ ! -e "${KITTEN_ARGS}" ]
    [ ! -e "${BAT_ARGS}" ]
}

@test "a rung whose binary fails falls through to the next" {
    an_image
    STUB_TERMTYPE="ghostty 1.3.1"
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

@test "inside tmux without the tmux binary the self-report comes from TERM" {
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
    STUB_TERMTYPE="ghostty 1.3.1"
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
