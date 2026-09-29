#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The script is run with PATH set to the stub directory alone, never with the
# stubs merely prepended: every program it calls exists on the developing
# machine, and part of what is tested is what happens when one does not. bash is
# symlinked in because the script and the stub shebangs need it. date is a stub,
# so the file name a save produces is known in advance.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../screenshot"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"

    LOG_DIR="${BATS_TEST_TMPDIR}/log"
    mkdir -p "${LOG_DIR}"
    FOCUSED="${BATS_TEST_TMPDIR}/focused"
    printf 'eDP-1\n' >"${FOCUSED}"

    SHOTS="${BATS_TEST_TMPDIR}/screens"
    mkdir -p "${SHOTS}"

    ln -s "$(command -v bash)" "${STUB_BIN}/bash"

    # Every stub logs its arguments joined by '|', one call per line, so an
    # argument containing a space is distinguishable from two arguments.
    make_stub swaymsg 'printf "[]\n"'
    make_stub jq ': "$(</dev/stdin)"; printf "%s\n" "$(<"'"${FOCUSED}"'")"'
    make_stub grim 'if [ "${!#}" = - ]; then printf PNG; else printf PNG >"${!#}"; fi'
    make_stub satty 'printf "%s" "$(</dev/stdin)" >"'"${LOG_DIR}"'/satty.stdin"'
    make_stub notify-send ':'
    make_stub date 'printf "20260929-120000\n"'
}

# $1 = command name, $2 = what it does after logging its arguments.
make_stub() {
    cat >"${STUB_BIN}/$1" <<STUB_EOF
#!/usr/bin/env bash
(IFS='|'; printf '%s\n' "\$*") >>"${LOG_DIR}/$1.log"
$2
STUB_EOF
    chmod +x "${STUB_BIN}/$1"
}

run_screenshot() {
    run --separate-stderr env PATH="${STUB_BIN}" /usr/bin/bash "${SCRIPT}" "$@"
}

calls() {
    cat "${LOG_DIR}/$1.log" 2>/dev/null || true
}

# A refusal says why on stderr, says it again as a notification, exits
# non-zero, and never takes a screenshot.
assert_refused() {
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"$1"* ]]
    [[ "$(calls notify-send)" == "Screenshot failed|"*"$1"* ]]
    [ -z "$(calls grim)" ]
}

@test "edit hands the focused output to satty" {
    run_screenshot edit
    [ "${status}" -eq 0 ]
    [ "$(calls swaymsg)" = "-t|get_outputs" ]
    [ "$(calls jq)" = "-r|.[] | select(.focused) | .name" ]
    [ "$(calls grim)" = "-o|eDP-1|-" ]
    [ "$(calls satty)" = "-f|-" ]
    [ "$(cat "${LOG_DIR}/satty.stdin")" = "PNG" ]
    [ -z "$(calls notify-send)" ]
}

@test "save writes a timestamped PNG into the directory and notifies" {
    run_screenshot save "${SHOTS}"
    [ "${status}" -eq 0 ]
    [ "$(calls grim)" = "-o|eDP-1|${SHOTS}/screenshot-20260929-120000.png" ]
    [ "$(cat "${SHOTS}/screenshot-20260929-120000.png")" = "PNG" ]
    [ "$(calls date)" = "+%Y%m%d-%H%M%S" ]
    [ "$(calls notify-send)" = "Screenshot|Saved to ${SHOTS}/" ]
}

@test "save keeps a directory containing a space as one argument" {
    mkdir -p "${BATS_TEST_TMPDIR}/two words"

    run_screenshot save "${BATS_TEST_TMPDIR}/two words"
    [ "${status}" -eq 0 ]
    [ -f "${BATS_TEST_TMPDIR}/two words/screenshot-20260929-120000.png" ]
}

@test "save does not need satty" {
    rm "${STUB_BIN}/satty"

    run_screenshot save "${SHOTS}"
    [ "${status}" -eq 0 ]
    [ -f "${SHOTS}/screenshot-20260929-120000.png" ]
}

@test "no verb is refused" {
    run_screenshot
    assert_refused "usage: screenshot edit | screenshot save <dir>"
}

@test "an unknown verb is refused" {
    run_screenshot shoot
    assert_refused "usage: screenshot edit | screenshot save <dir>"
}

@test "edit with an argument is refused" {
    run_screenshot edit "${SHOTS}"
    assert_refused "usage: screenshot edit | screenshot save <dir>"
}

@test "save without a directory is refused" {
    run_screenshot save
    assert_refused "usage: screenshot edit | screenshot save <dir>"
}

@test "save with two directories is refused" {
    run_screenshot save "${SHOTS}" "${SHOTS}"
    assert_refused "usage: screenshot edit | screenshot save <dir>"
}

@test "save into a directory that does not exist is refused" {
    run_screenshot save "${BATS_TEST_TMPDIR}/missing"
    assert_refused "not a directory: ${BATS_TEST_TMPDIR}/missing"
}

@test "no focused output is refused" {
    : >"${FOCUSED}"

    run_screenshot save "${SHOTS}"
    assert_refused "no focused output"
}

@test "edit without swaymsg is refused" {
    rm "${STUB_BIN}/swaymsg"
    run_screenshot edit
    assert_refused "command not found: swaymsg"
}

@test "edit without jq is refused" {
    rm "${STUB_BIN}/jq"
    run_screenshot edit
    assert_refused "command not found: jq"
}

@test "edit without grim is refused" {
    rm "${STUB_BIN}/grim"
    run_screenshot edit
    assert_refused "command not found: grim"
}

@test "edit without satty is refused" {
    rm "${STUB_BIN}/satty"
    run_screenshot edit
    assert_refused "command not found: satty"
}

@test "save without swaymsg is refused" {
    rm "${STUB_BIN}/swaymsg"
    run_screenshot save "${SHOTS}"
    assert_refused "command not found: swaymsg"
}

@test "save without jq is refused" {
    rm "${STUB_BIN}/jq"
    run_screenshot save "${SHOTS}"
    assert_refused "command not found: jq"
}

@test "save without grim is refused" {
    rm "${STUB_BIN}/grim"
    run_screenshot save "${SHOTS}"
    assert_refused "command not found: grim"
}

@test "save without date is refused" {
    rm "${STUB_BIN}/date"
    run_screenshot save "${SHOTS}"
    assert_refused "command not found: date"
}

@test "save without notify-send is refused before anything is captured" {
    rm "${STUB_BIN}/notify-send"
    run_screenshot save "${SHOTS}"
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"command not found: notify-send"* ]]
    [ -z "$(calls grim)" ]
}

@test "edit does not need notify-send" {
    rm "${STUB_BIN}/notify-send"
    run_screenshot edit
    [ "${status}" -eq 0 ]
    [ "$(calls satty)" = "-f|-" ]
}
