#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# swaymsg is stubbed on a prepended PATH, so no compositor is ever touched: the
# stub replays scripted event lines for `-t subscribe -m` and appends every other
# invocation to a log, which is how the move command is asserted despite the
# script discarding swaymsg's stdout.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../sway-start-on-workspace"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    EVENTS="${BATS_TEST_TMPDIR}/events.jsonl"
    MOVE_LOG="${BATS_TEST_TMPDIR}/swaymsg.log"
    LAUNCHED="${BATS_TEST_TMPDIR}/launched"
    : >"${EVENTS}"

    cat >"${STUB_BIN}/swaymsg" <<STUB_EOF
#!/usr/bin/env bash
exec 3>&-
if [[ "\$1" == "-t" && "\$2" == "subscribe" ]]; then
    cat "${EVENTS}"
    exit 0
fi
printf '%s\n' "\$*" >>"${MOVE_LOG}"
STUB_EOF
    chmod +x "${STUB_BIN}/swaymsg"

    cat >"${STUB_BIN}/fake-app" <<STUB_EOF
#!/usr/bin/env bash
exec 3>&-
printf '%s\n' "\$*" >>"${LAUNCHED}"
STUB_EOF
    chmod +x "${STUB_BIN}/fake-app"
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

@test "a subscription that ends without a match fails loudly" {
    printf '%s\n' '{"change":"new","container":{"id":11,"app_id":"org.mozilla.thunderbird"}}' >"${EVENTS}"

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no new org.keepassxc.KeePassXC window appeared"* ]]
    [ ! -e "${MOVE_LOG}" ]
}

@test "a move that swaymsg rejects fails loudly" {
    printf '%s\n' '{"change":"new","container":{"id":42,"app_id":"org.keepassxc.KeePassXC"}}' >"${EVENTS}"

    cat >"${STUB_BIN}/swaymsg" <<STUB_EOF
#!/usr/bin/env bash
exec 3>&-
if [[ "\$1" == "-t" && "\$2" == "subscribe" ]]; then
    cat "${EVENTS}"
    exit 0
fi
printf '%s\n' '{"success": false, "error": "No matching node"}'
exit 1
STUB_EOF

    run "${SCRIPT}" 10 org.keepassxc.KeePassXC fake-app
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"failed to move org.keepassxc.KeePassXC window 42 to workspace 10"* ]]
}
