#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# swaymsg and timeout are stubbed on a prepended PATH, so no compositor is ever
# touched: the swaymsg stub rejects any subscription that is not the monitored
# window-and-tick one, acknowledges it the way sway does and then replays scripted
# event lines, while every other invocation is appended to a log, which is how the
# move command is asserted despite the script discarding swaymsg's stdout. The
# timeout stub records that the subscription was bounded before running it. The
# app stub records what it can see of the script's state at launch, so the order
# of subscribing and launching, and the fd it must not inherit, are both testable.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../sway-start-on-workspace"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    EVENTS="${BATS_TEST_TMPDIR}/events.jsonl"
    MOVE_LOG="${BATS_TEST_TMPDIR}/swaymsg.log"
    TIMEOUT_LOG="${BATS_TEST_TMPDIR}/timeout.log"
    LAUNCHED="${BATS_TEST_TMPDIR}/launched"
    LAUNCH_STATE="${BATS_TEST_TMPDIR}/launch-state"
    SUBSCRIBED="${BATS_TEST_TMPDIR}/subscribed"
    SUBSCRIBER_PID="${BATS_TEST_TMPDIR}/subscriber.pid"
    : >"${EVENTS}"

    make_swaymsg_stub

    cat >"${STUB_BIN}/timeout" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${TIMEOUT_LOG}"
shift
exec "\$@"
STUB_EOF
    chmod +x "${STUB_BIN}/timeout"

    cat >"${STUB_BIN}/fake-app" <<STUB_EOF
#!/usr/bin/env bash
if [[ -e "${SUBSCRIBED}" ]]; then
    printf 'after-subscribe\n' >>"${LAUNCH_STATE}"
else
    printf 'before-subscribe\n' >>"${LAUNCH_STATE}"
fi
if [[ -e /dev/fd/3 ]]; then
    printf 'fd3-open\n' >>"${LAUNCH_STATE}"
else
    printf 'fd3-closed\n' >>"${LAUNCH_STATE}"
fi
printf '%s\n' "\$*" >>"${LAUNCHED}"
STUB_EOF
    chmod +x "${STUB_BIN}/fake-app"
}

teardown() {
    # A stub that outlived its test, because the reaping assertion failed, must
    # not stay blocked on its fifo for the rest of the run.
    if [[ -s "${SUBSCRIBER_PID}" ]]; then
        kill "$(cat "${SUBSCRIBER_PID}")" 2>/dev/null || :
    fi
}

# swaymsg stub: the subscription has to be the one this script depends on, so
# anything else fails it here rather than passing silently. The move exits with
# the given status, 0 by default.
make_swaymsg_stub() {
    local move_status="${1:-0}"
    cat >"${STUB_BIN}/swaymsg" <<STUB_EOF
#!/usr/bin/env bash
exec 3>&-
if [[ "\$1" == "-t" && "\$2" == "subscribe" ]]; then
    if [[ "\$3" != "-m" ]]; then
        printf 'swaymsg stub: subscription is not monitored: %s\n' "\$*" >&2
        exit 2
    fi
    if [[ "\$4" != *'"window"'* || "\$4" != *'"tick"'* ]]; then
        printf 'swaymsg stub: subscription misses window or tick: %s\n' "\$4" >&2
        exit 2
    fi
    : >"${SUBSCRIBED}"
    printf '%s\n' '{"first":true,"payload":""}'
    cat "${EVENTS}"
    exit 0
fi
printf '%s\n' "\$*" >>"${MOVE_LOG}"
if [[ ${move_status} -ne 0 ]]; then
    printf '%s\n' '{"success": false, "error": "No matching node"}'
    exit ${move_status}
fi
STUB_EOF
    chmod +x "${STUB_BIN}/swaymsg"
}

@test "the first matching new window is moved to the requested workspace" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [ "$(cat "${MOVE_LOG}")" = "[con_id=42] move container to workspace number 10" ]
}

@test "other app_ids and non-new changes are skipped, a later match still wins" {
    cat >"${EVENTS}" <<'EVENTS_EOF'
{"change":"new","container":{"id":11,"app_id":"org.mozilla.thunderbird"}}
{"change":"new","container":{"id":12,"app_id":null}}
{"change":"title","container":{"id":99,"app_id":"org.keepassxc.KeePassXC"}}
{"change":"focus","container":{"id":99,"app_id":"org.keepassxc.KeePassXC"}}
{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}
{"change":"new","container":{"id":43,"app_id":"org.keepassxc.KeePassXC"}}
EVENTS_EOF

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [ "$(cat "${MOVE_LOG}")" = "[con_id=42] move container to workspace number 10" ]
}

@test "a tick arriving after the acknowledgement is not a window event" {
    cat >"${EVENTS}" <<'EVENTS_EOF'
{"first":false,"payload":"some-tick"}
{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}
EVENTS_EOF

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [ "$(cat "${MOVE_LOG}")" = "[con_id=42] move container to workspace number 10" ]
}

@test "an app_id containing a quote still matches" {
    printf '%s\n' '{"change":"new","container":{"id":5,"app_id":"org.weird.\"App\""}}' >"${EVENTS}"

    run "${SCRIPT}" 9 'org.weird."App"' fake-app
    [ "${status}" -eq 0 ]
    [ "$(cat "${MOVE_LOG}")" = "[con_id=5] move container to workspace number 9" ]
}

@test "the command is launched with its arguments" {
    printf '%s\n' '{"change":"new","container":{"id":7,"app_id":"md.obsidian.Obsidian"}}' >"${EVENTS}"

    run "${SCRIPT}" 8 md.obsidian.Obsidian fake-app run md.obsidian.Obsidian
    [ "${status}" -eq 0 ]
    [ "$(cat "${LAUNCHED}")" = "run md.obsidian.Obsidian" ]
}

@test "the subscription is bounded by a timeout" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TIMEOUT_LOG}")" == "60 swaymsg -t subscribe -m "* ]]
}

@test "the app is launched only once the subscription is acknowledged" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [[ "$(cat "${LAUNCH_STATE}")" == *"after-subscribe"* ]]
}

@test "the launched app does not inherit the subscription" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    [[ "$(cat "${LAUNCH_STATE}")" == *"fd3-closed"* ]]
}

@test "a subscription still open when the window is placed is reaped" {
    mkfifo "${BATS_TEST_TMPDIR}/gate"

    cat >"${STUB_BIN}/swaymsg" <<STUB_EOF
#!/usr/bin/env bash
exec 3>&-
if [[ "\$1" == "-t" && "\$2" == "subscribe" ]]; then
    printf '%s\n' "\$\$" >"${SUBSCRIBER_PID}"
    printf '%s\n' '{"first":true,"payload":""}'
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}'
    # A subscription that stays open the way a real one does, without a busy
    # wait and without holding the script's stderr, so an unreaped stub shows up
    # as a live process rather than as a hung test.
    exec 2>&-
    read -r line <"${BATS_TEST_TMPDIR}/gate"
    exit 0
fi
printf '%s\n' "\$*" >>"${MOVE_LOG}"
STUB_EOF
    chmod +x "${STUB_BIN}/swaymsg"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -eq 0 ]
    # The script waits for the subscriber before exiting, so this is settled by
    # the time run returns.
    run ! kill -0 "$(cat "${SUBSCRIBER_PID}")"
}

@test "too few arguments fail with a usage message" {
    run "${SCRIPT}" 10 org.keepassxc.KeePassXC
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"usage: sway-start-on-workspace"* ]]
    [ ! -e "${MOVE_LOG}" ]
}

@test "a non-numeric workspace fails loudly" {
    run "${SCRIPT}" ten org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"workspace must be a positive integer, got: ten"* ]]
    [ ! -e "${LAUNCHED}" ]
}

@test "an empty app_id fails loudly before anything is started" {
    run "${SCRIPT}" 10 "" fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"app_id must not be empty"* ]]
    [ ! -e "${LAUNCHED}" ]
    [ ! -e "${SUBSCRIBED}" ]
}

@test "an empty workspace and an empty command are rejected as well" {
    run "${SCRIPT}" "" org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"workspace must be a positive integer"* ]]

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC ""
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"command not found"* ]]
    [ ! -e "${LAUNCHED}" ]
    [ ! -e "${SUBSCRIBED}" ]
}

@test "a missing swaymsg fails loudly" {
    run env PATH=/nonexistent /usr/bin/bash "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"swaymsg not available"* ]]
    [ ! -e "${LAUNCHED}" ]
}

@test "a missing jq fails loudly" {
    run env PATH="${STUB_BIN}" /usr/bin/bash "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"jq not available"* ]]
    [ ! -e "${LAUNCHED}" ]
}

@test "a command that is not on PATH fails loudly" {
    run "${SCRIPT}" 10 org.keepassxc.KeePassXC no-such-command
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"command not found: no-such-command"* ]]
    [ ! -e "${MOVE_LOG}" ]
}

@test "a subscription that is never acknowledged fails loudly" {
    cat >"${STUB_BIN}/swaymsg" <<'STUB_EOF'
#!/usr/bin/env bash
exec 3>&-
exit 0
STUB_EOF
    chmod +x "${STUB_BIN}/swaymsg"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"subscription ended before it was acknowledged"* ]]
    [ ! -e "${LAUNCHED}" ]
}

@test "a subscription that ends without a match fails loudly" {
    printf '%s\n' '{"change":"new","container":{"id":11,"app_id":"org.mozilla.thunderbird"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no new org.keepassxc.KeePassXC window appeared"* ]]
    [ ! -e "${MOVE_LOG}" ]
}

@test "a move that swaymsg rejects fails loudly" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"
    make_swaymsg_stub 1

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"failed to move org.keepassxc.KeePassXC window 42 to workspace 10"* ]]
}
