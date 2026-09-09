#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The script is run with PATH set to the stub directory alone, never with the
# stubs merely prepended: timedatectl exists on the developing machine, and part
# of what is tested is what happens when it does not. bash is symlinked in
# because the script and the stub shebangs need it. sleep is a stub, so the sixty
# second timeout costs the suite nothing and no test spins waiting for real time
# to pass.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../wait-for-clock"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"

    CLOCK_LOG="${BATS_TEST_TMPDIR}/timedatectl.log"
    SLEEP_LOG="${BATS_TEST_TMPDIR}/sleep.log"
    RAN="${BATS_TEST_TMPDIR}/ran"
    POLLS_AT_LAUNCH="${BATS_TEST_TMPDIR}/polls-at-launch"
    : >"${CLOCK_LOG}"
    : >"${SLEEP_LOG}"

    ln -s "$(command -v bash)" "${STUB_BIN}/bash"

    cat >"${STUB_BIN}/sleep" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${SLEEP_LOG}"
STUB_EOF

    # The command being gated records what it saw, one argument per line, so an
    # argument containing a space is distinguishable from two arguments. It also
    # appends how many polls had already happened, which pins down both that it
    # started after the clock came up and that it started exactly once.
    cat >"${STUB_BIN}/fake-app" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${RAN}"
mapfile -t seen <"${CLOCK_LOG}"
printf '%s\n' "\${#seen[@]}" >>"${POLLS_AT_LAUNCH}"
STUB_EOF

    chmod +x "${STUB_BIN}"/sleep "${STUB_BIN}"/fake-app

    make_timedatectl_stub 0
}

# $1 = how many polls report an unsynchronised clock before it synchronises.
make_timedatectl_stub() {
    cat >"${STUB_BIN}/timedatectl" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${CLOCK_LOG}"
mapfile -t calls <"${CLOCK_LOG}"
if ((\${#calls[@]} > $1)); then
    printf 'yes\n'
else
    printf 'no\n'
fi
STUB_EOF
    chmod +x "${STUB_BIN}/timedatectl"
}

run_gated() {
    run --separate-stderr env PATH="${STUB_BIN}" /usr/bin/bash "${SCRIPT}" "$@"
}

polls() {
    mapfile -t lines <"${CLOCK_LOG}"
    printf '%s\n' "${#lines[@]}"
}

# The whole launch log, so an extra launch shows up as an extra line instead of
# overwriting the launch that mattered.
launched_after() {
    cat "${POLLS_AT_LAUNCH}"
}

naps() {
    mapfile -t lines <"${SLEEP_LOG}"
    printf '%s\n' "${#lines[@]}"
}

# Counting the naps is not enough: a sleep of two would keep the count and
# quietly double the sixty seconds the gate is supposed to take.
naps_are_one_second() {
    mapfile -t lines <"${SLEEP_LOG}"
    local line
    for line in "${lines[@]}"; do
        [ "${line}" = "1" ] || return 1
    done
}

@test "a clock already in sync runs the command after a single poll" {
    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 1 ]
    [ "$(naps)" -eq 0 ]
    [ "$(launched_after)" -eq 1 ]
    [ "$(cat "${CLOCK_LOG}")" = "show -p NTPSynchronized --value" ]
}

@test "a clock that syncs late is waited for, and the command runs afterwards" {
    make_timedatectl_stub 3

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 4 ]
    [ "$(naps)" -eq 3 ]
    naps_are_one_second
    [ "$(launched_after)" -eq 4 ]
}

@test "a clock that never syncs starts the command anyway, loudly" {
    make_timedatectl_stub 999

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 60 ]
    [ "$(naps)" -eq 60 ]
    naps_are_one_second
    [ "$(launched_after)" -eq 60 ]
    [[ "${stderr}" == *"the clock was not synchronised within 60s"* ]]
    [[ "${stderr}" == *"starting fake-app anyway"* ]]
}

@test "a timedatectl that fails counts as unsynchronised and still lets go" {
    cat >"${STUB_BIN}/timedatectl" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${CLOCK_LOG}"
exit 1
STUB_EOF
    chmod +x "${STUB_BIN}/timedatectl"

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 60 ]
    [ "$(naps)" -eq 60 ]
    naps_are_one_second
    [[ "${stderr}" == *"the clock was not synchronised within 60s"* ]]
}

@test "no timedatectl reports why the clock cannot be judged and starts anyway" {
    rm "${STUB_BIN}/timedatectl"

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 0 ]
    [ "$(naps)" -eq 0 ]
    [[ "${stderr}" == *"timedatectl not available"* ]]
}

@test "arguments reach the command unchanged, including one containing a space" {
    run_gated fake-app connect --p2p 'two words'
    [ "${status}" -eq 0 ]
    [ "$(cat "${RAN}")" = "connect
--p2p
two words" ]
}

@test "no command at all is a usage error" {
    run_gated
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"usage: wait-for-clock <command> [args...]"* ]]
}

@test "a command that is not on PATH fails before any waiting happens" {
    run_gated no-such-command
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"command not found: no-such-command"* ]]
    [ "$(polls)" -eq 0 ]
    [ "$(naps)" -eq 0 ]
}
