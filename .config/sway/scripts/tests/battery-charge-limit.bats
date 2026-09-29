#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The script is run with PATH set to the stub directory alone, never with the
# stubs merely prepended: busctl exists on the developing machine, and a real
# call would move the actual charge limit. bash is symlinked in because the
# script and the stub shebangs need it. The busctl stub answers from files in
# STATE_DIR: the device list, the one path that supports a limit, and the
# current state.

BAT0=/org/freedesktop/UPower/devices/battery_BAT0
AC0=/org/freedesktop/UPower/devices/line_power_AC0
STYLUS=/org/freedesktop/UPower/devices/battery_hid_stylus_battery_7
ENUMERATE="--system|call|org.freedesktop.UPower|/org/freedesktop/UPower|org.freedesktop.UPower|EnumerateDevices"

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../battery-charge-limit"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"

    export STATE_DIR="${BATS_TEST_TMPDIR}/state"
    mkdir -p "${STATE_DIR}"
    printf 'ao 3 "%s" "%s" "%s"\n' "${AC0}" "${STYLUS}" "${BAT0}" >"${STATE_DIR}/devices"
    printf '%s\n' "${BAT0}" >"${STATE_DIR}/supported"
    printf 'true\n' >"${STATE_DIR}/enabled"

    ln -s "$(command -v bash)" "${STUB_BIN}/bash"

    # Every stub logs its arguments joined by '|', one call per line, so an
    # argument containing a space is distinguishable from two arguments. A call
    # containing the text in fail-on fails the way busctl does.
    cat >"${STUB_BIN}/busctl" <<'STUB_EOF'
#!/usr/bin/env bash
(IFS='|'; printf '%s\n' "$*") >>"${STATE_DIR}/busctl.log"
if [[ -e "${STATE_DIR}/fail-on" && "$*" == *"$(<"${STATE_DIR}/fail-on")"* ]]; then
    echo "Call failed: Access denied" >&2
    exit 1
fi
case "$2 $6" in
"call EnumerateDevices")
    printf '%s\n' "$(<"${STATE_DIR}/devices")"
    ;;
"get-property ChargeThresholdSupported")
    if [[ "$4" == "$(<"${STATE_DIR}/supported")" ]]; then
        printf 'b true\n'
    else
        printf 'b false\n'
    fi
    ;;
"get-property ChargeThresholdEnabled")
    printf 'b %s\n' "$(<"${STATE_DIR}/enabled")"
    ;;
"call EnableChargeThreshold") ;;
*)
    echo "unexpected busctl call: $*" >&2
    exit 1
    ;;
esac
STUB_EOF

    cat >"${STUB_BIN}/notify-send" <<'STUB_EOF'
#!/usr/bin/env bash
(IFS='|'; printf '%s\n' "$*") >>"${STATE_DIR}/notify-send.log"
STUB_EOF

    chmod +x "${STUB_BIN}/busctl" "${STUB_BIN}/notify-send"
}

run_limit() {
    run --separate-stderr env PATH="${STUB_BIN}" /usr/bin/bash "${SCRIPT}" "$@"
}

calls() {
    if [ -e "${STATE_DIR}/$1.log" ]; then
        printf '%s\n' "$(<"${STATE_DIR}/$1.log")"
    fi
}

enable_calls() {
    calls busctl | grep 'EnableChargeThreshold' || true
}

enable_call() {
    printf '%s\n' "--system|call|org.freedesktop.UPower|$1|org.freedesktop.UPower.Device|EnableChargeThreshold|b|$2"
}

# A refusal says why on stderr, exits non-zero, and never sets the limit.
assert_refused() {
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"$1"* ]]
    [ -z "$(enable_calls)" ]
}

assert_notified_refusal() {
    assert_refused "$1"
    [[ "$(calls notify-send)" == "Battery charge limit failed|"*"$1"* ]]
}

assert_silent_refusal() {
    assert_refused "$1"
    [ -z "$(calls notify-send)" ]
}

@test "toggle with the limit on turns it off and says so" {
    run_limit toggle
    [ "${status}" -eq 0 ]
    [ "$(calls busctl | head -n 1)" = "${ENUMERATE}" ]
    [ "$(enable_calls)" = "$(enable_call "${BAT0}" false)" ]
    [ "$(calls notify-send)" = "Battery charge limit|Off: the battery charges to full" ]
}

@test "toggle with the limit off turns it on and says so" {
    printf 'false\n' >"${STATE_DIR}/enabled"

    run_limit toggle
    [ "${status}" -eq 0 ]
    [ "$(enable_calls)" = "$(enable_call "${BAT0}" true)" ]
    [ "$(calls notify-send)" = "Battery charge limit|On" ]
}

@test "toggle reads the state of the supported device" {
    run_limit toggle
    [ "${status}" -eq 0 ]
    calls busctl | grep -qxF -- "--system|get-property|org.freedesktop.UPower|${BAT0}|org.freedesktop.UPower.Device|ChargeThresholdEnabled"
}

@test "restore with the limit on sets it on, silently" {
    run_limit restore
    [ "${status}" -eq 0 ]
    [ "$(enable_calls)" = "$(enable_call "${BAT0}" true)" ]
    [ -z "$(calls notify-send)" ]
}

@test "restore with the limit off sets it on, silently" {
    printf 'false\n' >"${STATE_DIR}/enabled"

    run_limit restore
    [ "${status}" -eq 0 ]
    [ "$(enable_calls)" = "$(enable_call "${BAT0}" true)" ]
    [ -z "$(calls notify-send)" ]
}

@test "the device is found by what it supports, not by its name" {
    local bat1=/org/freedesktop/UPower/devices/battery_BAT1
    printf 'ao 3 "%s" "%s" "%s"\n' "${BAT0}" "${bat1}" "${AC0}" >"${STATE_DIR}/devices"
    printf '%s\n' "${bat1}" >"${STATE_DIR}/supported"

    run_limit restore
    [ "${status}" -eq 0 ]
    [ "$(enable_calls)" = "$(enable_call "${bat1}" true)" ]
}

@test "toggle without a supported device is refused with a notification" {
    : >"${STATE_DIR}/supported"
    run_limit toggle
    assert_notified_refusal "no UPower device supports a charge limit"
}

@test "restore without a supported device is refused silently" {
    : >"${STATE_DIR}/supported"
    run_limit restore
    assert_silent_refusal "no UPower device supports a charge limit"
}

@test "restore with no devices at all is refused silently" {
    printf 'ao 0\n' >"${STATE_DIR}/devices"
    run_limit restore
    assert_silent_refusal "no UPower device supports a charge limit"
}

@test "toggle without busctl is refused with a notification" {
    rm "${STUB_BIN}/busctl"
    run_limit toggle
    assert_notified_refusal "command not found: busctl"
}

@test "restore without busctl is refused silently" {
    rm "${STUB_BIN}/busctl"
    run_limit restore
    assert_silent_refusal "command not found: busctl"
}

@test "toggle without notify-send is refused before the limit moves" {
    rm "${STUB_BIN}/notify-send"
    run_limit toggle
    assert_refused "command not found: notify-send"
    [ -z "$(calls busctl)" ]
}

@test "restore does not need notify-send" {
    rm "${STUB_BIN}/notify-send"
    run_limit restore
    [ "${status}" -eq 0 ]
    [ "$(enable_calls)" = "$(enable_call "${BAT0}" true)" ]
}

@test "toggle refused by UPower says so with a notification" {
    printf 'EnableChargeThreshold\n' >"${STATE_DIR}/fail-on"

    run_limit toggle
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"could not set the charge limit on ${BAT0}"* ]]
    [[ "$(calls notify-send)" == "Battery charge limit failed|could not set the charge limit on ${BAT0}" ]]
}

@test "restore refused by UPower fails silently" {
    printf 'EnableChargeThreshold\n' >"${STATE_DIR}/fail-on"

    run_limit restore
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"could not set the charge limit on ${BAT0}"* ]]
    [ -z "$(calls notify-send)" ]
}

@test "a failing enumeration is refused" {
    printf 'EnumerateDevices\n' >"${STATE_DIR}/fail-on"
    run_limit toggle
    assert_notified_refusal "could not enumerate UPower devices"
}

@test "a failing state read is refused" {
    printf 'ChargeThresholdEnabled\n' >"${STATE_DIR}/fail-on"
    run_limit toggle
    assert_notified_refusal "could not read ChargeThresholdEnabled of ${BAT0}"
}

@test "no verb is refused" {
    run_limit
    assert_silent_refusal "usage: battery-charge-limit toggle | battery-charge-limit restore"
}

@test "an unknown verb is refused" {
    run_limit on
    assert_silent_refusal "usage: battery-charge-limit toggle | battery-charge-limit restore"
}

@test "an extra argument is refused" {
    run_limit toggle now
    assert_notified_refusal "usage: battery-charge-limit toggle | battery-charge-limit restore"
}
