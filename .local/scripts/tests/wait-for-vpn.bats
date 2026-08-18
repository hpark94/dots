#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The script is run with PATH set to the stub directory alone, never with the
# stubs merely prepended: protonvpn and nmcli both exist on the developing
# machine, and the whole point of the probe is what happens when they do not.
# grep and bash are symlinked in because the script and the stub shebangs need
# them. sleep is a stub, so the sixty second timeout costs the suite nothing and
# no test spins waiting for real time to pass.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../wait-for-vpn"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"

    NMCLI_LOG="${BATS_TEST_TMPDIR}/nmcli.log"
    SLEEP_LOG="${BATS_TEST_TMPDIR}/sleep.log"
    RAN="${BATS_TEST_TMPDIR}/ran"
    POLLS_AT_LAUNCH="${BATS_TEST_TMPDIR}/polls-at-launch"
    : >"${NMCLI_LOG}"
    : >"${SLEEP_LOG}"

    local cmd
    for cmd in bash grep; do
        ln -s "$(command -v "${cmd}")" "${STUB_BIN}/${cmd}"
    done

    cat >"${STUB_BIN}/protonvpn" <<'STUB_EOF'
#!/usr/bin/env bash
exit 0
STUB_EOF

    cat >"${STUB_BIN}/sleep" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${SLEEP_LOG}"
STUB_EOF

    # The command being gated records what it saw, one argument per line, so an
    # argument containing a space is distinguishable from two arguments. It also
    # appends how many polls had already happened, which pins down both that it
    # started after the vpn came up and that it started exactly once.
    cat >"${STUB_BIN}/fake-app" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${RAN}"
mapfile -t seen <"${NMCLI_LOG}"
printf '%s\n' "\${#seen[@]}" >>"${POLLS_AT_LAUNCH}"
STUB_EOF

    chmod +x "${STUB_BIN}"/protonvpn "${STUB_BIN}"/sleep "${STUB_BIN}"/fake-app

    make_nmcli_stub 0
}

# $1 = how many polls report a state other than connected before it connects.
make_nmcli_stub() {
    cat >"${STUB_BIN}/nmcli" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${NMCLI_LOG}"
mapfile -t calls <"${NMCLI_LOG}"
printf 'wlo1:connected\n'
if ((\${#calls[@]} > $1)); then
    printf 'proton0:connected\n'
else
    printf 'proton0:connecting\n'
fi
STUB_EOF
    chmod +x "${STUB_BIN}/nmcli"
}

run_gated() {
    run --separate-stderr env PATH="${STUB_BIN}" /usr/bin/bash "${SCRIPT}" "$@"
}

polls() {
    mapfile -t lines <"${NMCLI_LOG}"
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

@test "a machine without protonvpn runs the command without consulting the network" {
    rm "${STUB_BIN}/protonvpn"

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 0 ]
    [ "$(naps)" -eq 0 ]
    [ "$(launched_after)" -eq 0 ]
}

@test "an already connected vpn runs the command after a single poll" {
    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 1 ]
    [ "$(naps)" -eq 0 ]
    [ "$(launched_after)" -eq 1 ]
}

@test "a vpn that connects late is waited for, and the command runs afterwards" {
    make_nmcli_stub 3

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 4 ]
    [ "$(naps)" -eq 3 ]
    [ "$(launched_after)" -eq 4 ]
}

@test "a vpn that never connects still gets the command started, loudly" {
    make_nmcli_stub 999

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [ "$(polls)" -eq 60 ]
    [ "$(launched_after)" -eq 60 ]
    [[ "${stderr}" == *"proton0 did not connect within 60s"* ]]
    [[ "${stderr}" == *"starting fake-app anyway"* ]]
}

@test "protonvpn without nmcli reports why it cannot wait and starts anyway" {
    rm "${STUB_BIN}/nmcli"

    run_gated fake-app
    [ "${status}" -eq 0 ]
    [ -f "${RAN}" ]
    [[ "${stderr}" == *"nmcli not available"* ]]
}

@test "arguments reach the command unchanged, including one containing a space" {
    run_gated fake-app run org.mozilla.thunderbird 'two words'
    [ "${status}" -eq 0 ]
    [ "$(cat "${RAN}")" = "run
org.mozilla.thunderbird
two words" ]
}

@test "no command at all is a usage error" {
    run_gated
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"usage: wait-for-vpn <command> [args...]"* ]]
}

@test "a command that is not on PATH fails before any waiting happens" {
    run_gated no-such-command
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"command not found: no-such-command"* ]]
    [ "$(polls)" -eq 0 ]
    [ "$(naps)" -eq 0 ]
}
