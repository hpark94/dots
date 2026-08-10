#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for caffeine. XDG_RUNTIME_DIR points into BATS_TEST_TMPDIR and
# systemd-inhibit is stubbed, so the machine's own idle inhibitor is never
# touched. The stub renames itself through /proc/self/comm, because that name is
# what caffeine reads to tell its own inhibitor from a recycled PID.

setup() {
    export XDG_RUNTIME_DIR="${BATS_TEST_TMPDIR}/run"
    mkdir -p "${XDG_RUNTIME_DIR}"
    PID_FILE="${XDG_RUNTIME_DIR}/caffeine.pid"
    SCRIPT="${BATS_TEST_DIRNAME}/../caffeine"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"
    # The redirect matters: a background job holding the pipe `run` reads would
    # block the test until the stub finished on its own.
    cat >"${STUB_BIN}/systemd-inhibit" <<'STUB_EOF'
#!/usr/bin/env bash
exec >/dev/null 2>&1
printf 'systemd-inhibit' >/proc/self/comm
sleep 30
STUB_EOF
    chmod +x "${STUB_BIN}/systemd-inhibit"
}

# Only ever kills PIDs this suite started itself, addressed by number.
teardown() {
    if [[ -r "${PID_FILE}" ]]; then
        kill "$(cat "${PID_FILE}")" 2>/dev/null || true
    fi
    if [[ -n "${HELPER_PID:-}" ]]; then
        kill "${HELPER_PID}" 2>/dev/null || true
    fi
}

@test "the first call starts an inhibitor and records its PID" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -f "${PID_FILE}" ]
    local pid
    pid=$(cat "${PID_FILE}")
    [ "$(cat "/proc/${pid}/comm")" = "systemd-inhibit" ]
}

@test "the second call stops the inhibitor it started and clears the PID file" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local pid
    pid=$(cat "${PID_FILE}")

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -e "${PID_FILE}" ]
    ! kill -0 "${pid}" 2>/dev/null
}

@test "a PID recycled by an unrelated process is left alone" {
    sleep 30 </dev/null >/dev/null 2>&1 &
    HELPER_PID=$!
    printf '%s\n' "${HELPER_PID}" >"${PID_FILE}"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    kill -0 "${HELPER_PID}"
    local pid
    pid=$(cat "${PID_FILE}")
    [ "${pid}" != "${HELPER_PID}" ]
    [ "$(cat "/proc/${pid}/comm")" = "systemd-inhibit" ]
}

@test "an inhibitor that dies at once is reported instead of claimed as success" {
    printf '#!/usr/bin/env bash\nexit 1\n' >"${STUB_BIN}/systemd-inhibit"
    chmod +x "${STUB_BIN}/systemd-inhibit"

    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"caffeine: systemd-inhibit exited immediately"* ]]
    [ ! -e "${PID_FILE}" ]
}
