#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The real script runs from the stub-bin dir, which is first on PATH, so it
# resolves the stubbed `tput` and `delta`; the `delta` stub echoes its args.

setup() {
    export STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    export PATH="${STUB_BIN}:${PATH}"
    cp "${BATS_TEST_DIRNAME}/../delta-auto" "${STUB_BIN}/delta-auto"
    chmod +x "${STUB_BIN}/delta-auto"

    cat >"${STUB_BIN}/delta" <<'STUB_EOF'
#!/usr/bin/env bash
printf 'DELTA %s\n' "$*"
STUB_EOF
    chmod +x "${STUB_BIN}/delta"
}

# tput stub that answers `tput cols` with the given width.
setup_tput_stub() {
    local width="$1"
    cat >"${STUB_BIN}/tput" <<STUB_EOF
#!/usr/bin/env bash
if [[ "\$1" == "cols" ]]; then
	printf '%s\n' "${width}"
	exit 0
fi
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/tput"
}

# tput stub that fails outright (no output, exit 1).
setup_failing_tput_stub() {
    cat >"${STUB_BIN}/tput" <<'STUB_EOF'
#!/usr/bin/env bash
exit 1
STUB_EOF
    chmod +x "${STUB_BIN}/tput"
}

@test "width 120 enables side-by-side" {
    setup_tput_stub 120
    run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--side-by-side"* ]]
}

@test "width 80 stays unified" {
    setup_tput_stub 80
    run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"--side-by-side"* ]]
}

@test "width exactly 100 enables side-by-side (inclusive boundary)" {
    setup_tput_stub 100
    run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--side-by-side"* ]]
}

@test "falls back to COLUMNS when tput fails" {
    setup_failing_tput_stub
    COLUMNS=120 run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--side-by-side"* ]]
}

@test "unified default when width is unavailable" {
    setup_failing_tput_stub
    unset COLUMNS
    run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"--side-by-side"* ]]
}

@test "unified default when tput prints a non-numeric width" {
    setup_tput_stub abc
    unset COLUMNS
    run delta-auto
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"--side-by-side"* ]]
}

@test "passes extra args through to delta" {
    setup_tput_stub 80
    run delta-auto --paging=never
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--paging=never"* ]]
}
