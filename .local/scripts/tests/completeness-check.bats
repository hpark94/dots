#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Every function runs with PATH set to the stub directory alone, never with the
# stubs merely prepended: the check is about which commands exist, and the
# developing machine's own would answer instead. awk and grep are linked in
# because the script needs them. The stubs answer from files in STATE_DIR, and
# the roster, Flatpak list and hwdb file are fixtures under BATS_TEST_TMPDIR.

BAT0=/org/freedesktop/UPower/devices/battery_BAT0
AC0=/org/freedesktop/UPower/devices/line_power_AC0

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
    mkdir -p "${HOME}" "${XDG_CONFIG_HOME}/dotfiles"
    printf 'desktop\n' >"${XDG_CONFIG_HOME}/dotfiles/role"

    source "${BATS_TEST_DIRNAME}/../../../completeness-check.sh"
    REAL_ROSTER="${ROSTER}"

    ROSTER="${BATS_TEST_TMPDIR}/roster.md"
    cat >"${ROSTER}" <<'EOF'
# Roster

Prose above the table.

| binary    | fedora         | ubuntu       |
| --------- | -------------- | ------------ |
| -         | `portal`       | `portal-deb` |
| -         | `sway-systemd` | -            |
| `sway`    | `sway`         | `sway`       |
| `ghostty` | `ghostty`      | `ghostty`    |
| `satty`   | `satty`        | -            |
EOF
    FLATPAKS="${BATS_TEST_TMPDIR}/flatpak.txt"
    printf 'org.mozilla.thunderbird\nmd.obsidian.Obsidian\n' >"${FLATPAKS}"
    HWDB_FILE="${BATS_TEST_TMPDIR}/61-battery-local.hwdb"

    export STATE_DIR="${BATS_TEST_TMPDIR}/state"
    mkdir -p "${STATE_DIR}/dpkg"
    touch "${STATE_DIR}/rpm-installed" "${STATE_DIR}/flatpaks"
    printf 'ao 2 "%s" "%s"\n' "${AC0}" "${BAT0}" >"${STATE_DIR}/devices"
    printf '%s\n' "${BAT0}" >"${STATE_DIR}/supported"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    ln -s "$(command -v awk)" "${STUB_BIN}/awk"
    ln -s "$(command -v grep)" "${STUB_BIN}/grep"

    stub rpm <<'STUB_EOF'
grep -qxF "$2" "${STATE_DIR}/rpm-installed"
STUB_EOF
    # A package is known when STATE_DIR/dpkg/<name> holds its status word; a
    # file named "broken" makes every query fail the way a damaged database does.
    stub dpkg-query <<'STUB_EOF'
name="${!#}"
if [[ -e "${STATE_DIR}/dpkg/broken" ]]; then
    exit 2
fi
if [[ ! -e "${STATE_DIR}/dpkg/${name}" ]]; then
    echo "dpkg-query: no packages found matching ${name}" >&2
    exit 1
fi
printf '%s' "$(<"${STATE_DIR}/dpkg/${name}")"
STUB_EOF
    stub flatpak <<'STUB_EOF'
grep -qxF "$2" "${STATE_DIR}/flatpaks"
STUB_EOF
    stub busctl <<'STUB_EOF'
if [[ -e "${STATE_DIR}/fail-on" && "$*" == *"$(<"${STATE_DIR}/fail-on")"* ]]; then
    echo "Call failed: The name is not activatable" >&2
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
*)
    echo "unexpected busctl call: $*" >&2
    exit 1
    ;;
esac
STUB_EOF
}

# stub <name>: an executable in STUB_BIN whose body is read from stdin.
stub() {
    {
        printf '#!%s\n' "$(command -v bash)"
        cat
    } >"${STUB_BIN}/$1"
    chmod +x "${STUB_BIN}/$1"
}

# present <command...>: commands that merely exist.
present() {
    local cmd
    for cmd in "$@"; do
        stub "${cmd}" </dev/null
    done
}

in_stubs() {
    local PATH="${STUB_BIN}"
    "$@"
}

complete_home() {
    mkdir -p "${HOME}/Sync/.pictures/wallpaper" "${HOME}/projects" "${HOME}/.ssh"
    touch "${HOME}/Sync/.pictures/wallpaper/frieren.jpg" "${HWDB_FILE}"
    printf 'Host *\n\nInclude ~/.config/ssh/config.shared\n' >"${HOME}/.ssh/config"
}

@test "roster_rows gives command and package per row, without header or separator" {
    PKG_COLUMN=3
    run roster_rows
    [ "${status}" -eq 0 ]
    [ "${output}" = "- portal
- sway-systemd
sway sway
ghostty ghostty
satty satty" ]
}

@test "roster_rows reads every row of the real roster, for both columns" {
    ROSTER="${REAL_ROSTER}"
    local rows
    rows=$(($(grep -c '^| ' "${ROSTER}") - 2))
    for PKG_COLUMN in 3 4; do
        run roster_rows
        [ "${status}" -eq 0 ]
        [ "${#lines[@]}" -eq "${rows}" ]
        if printf '%s\n' "${lines[@]}" | grep -Eq 'binary|fedora|ubuntu|--|`|\|'; then
            false
        fi
    done
}

@test "pick_package_manager takes the fedora column where only rpm is present" {
    present rpm
    in_stubs pick_package_manager
    [ "${PKG_MANAGER}" = rpm ]
    [ "${PKG_COLUMN}" = 3 ]
}

@test "pick_package_manager takes the ubuntu column where only dpkg is present" {
    rm "${STUB_BIN}/rpm"
    present dpkg
    in_stubs pick_package_manager
    [ "${PKG_MANAGER}" = dpkg ]
    [ "${PKG_COLUMN}" = 4 ]
}

@test "pick_package_manager refuses where both are present" {
    present dpkg
    run --separate-stderr in_stubs pick_package_manager
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"both rpm and dpkg"* ]]
}

@test "pick_package_manager refuses where neither is present" {
    rm "${STUB_BIN}/rpm"
    run --separate-stderr in_stubs pick_package_manager
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"neither rpm nor dpkg"* ]]
}

@test "check_roster on rpm names the missing command and the missing package" {
    PKG_MANAGER=rpm PKG_COLUMN=3
    present sway satty
    printf 'sway-systemd\n' >"${STATE_DIR}/rpm-installed"
    run in_stubs check_roster
    [ "${status}" -eq 0 ]
    [ "${lines[0]}" = "roster:         3 present, 2 missing" ]
    [ "${lines[1]}" = "                portal, ghostty" ]
}

@test "check_roster on dpkg counts a row with - in both columns as not checkable" {
    PKG_MANAGER=dpkg PKG_COLUMN=4
    present sway ghostty
    printf 'installed' >"${STATE_DIR}/dpkg/portal-deb"
    run in_stubs check_roster
    [ "${status}" -eq 0 ]
    [ "${lines[0]}" = "roster:         3 present, 1 not checkable here, 1 missing" ]
    [ "${lines[1]}" = "                satty" ]
}

@test "check_roster counts a removed dpkg package with config files left as missing" {
    PKG_MANAGER=dpkg PKG_COLUMN=4
    present sway ghostty satty
    printf 'config-files' >"${STATE_DIR}/dpkg/portal-deb"
    run in_stubs check_roster
    [ "${lines[0]}" = "roster:         3 present, 1 not checkable here, 1 missing" ]
    [ "${lines[1]}" = "                portal-deb" ]
}

@test "check_roster refuses when dpkg-query itself fails" {
    PKG_MANAGER=dpkg PKG_COLUMN=4
    touch "${STATE_DIR}/dpkg/broken"
    run --separate-stderr in_stubs check_roster
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"dpkg-query failed on portal-deb (exit 2)"* ]]
}

@test "check_roster refuses when the roster yields no rows" {
    PKG_MANAGER=rpm PKG_COLUMN=3
    printf '# Roster\n' >"${ROSTER}"
    run --separate-stderr in_stubs check_roster
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"no rows found in ${ROSTER}"* ]]
    [ -z "${output}" ]
}

@test "check_roster refuses when awk fails instead of reporting an empty roster" {
    PKG_MANAGER=rpm PKG_COLUMN=3
    rm "${STUB_BIN}/awk"
    stub awk <<<'exit 2'
    run --separate-stderr in_stubs check_roster
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"could not read ${ROSTER}"* ]]
    [ -z "${output}" ]
}

@test "check_roster sets the missing flag, a complete roster leaves it clear" {
    PKG_MANAGER=rpm PKG_COLUMN=3
    present sway ghostty satty
    printf 'portal\nsway-systemd\n' >"${STATE_DIR}/rpm-installed"
    in_stubs check_roster >/dev/null
    [ "${MISSING}" -eq 0 ]
    rm "${STUB_BIN}/ghostty"
    in_stubs check_roster >/dev/null
    [ "${MISSING}" -eq 1 ]
}

@test "check_flatpaks asks for each id and names the missing one" {
    printf 'org.mozilla.thunderbird\n' >"${STATE_DIR}/flatpaks"
    run in_stubs check_flatpaks
    [ "${lines[0]}" = "flatpaks:       1 present, 1 missing" ]
    [ "${lines[1]}" = "                md.obsidian.Obsidian" ]
}

@test "check_flatpaks counts every id as not checkable without flatpak" {
    rm "${STUB_BIN}/flatpak"
    run in_stubs check_flatpaks
    [ "${output}" = "flatpaks:       0 present, 2 not checkable here" ]
}

@test "check_manual_steps finds all five on a complete machine" {
    complete_home
    run in_stubs check_manual_steps supported
    [ "${output}" = "manual steps:   5 present" ]
}

@test "check_manual_steps names every missing entry" {
    run in_stubs check_manual_steps supported
    [ "${lines[0]}" = "manual steps:   0 present, 5 missing" ]
    [ "${lines[1]}" = "                ~/Sync, ~/projects, ~/Sync/.pictures/wallpaper/frieren.jpg, Include ~/.config/ssh/config.shared in ~/.ssh/config, ${HWDB_FILE}" ]
}

@test "check_manual_steps does not expect the hwdb file where no charge limit is supported" {
    complete_home
    rm "${HWDB_FILE}"
    run in_stubs check_manual_steps unsupported
    [ "${output}" = "manual steps:   4 present, 1 not supported on this machine" ]
}

@test "check_manual_steps does not take a commented-out Include" {
    complete_home
    printf '# Include ~/.config/ssh/config.shared\n' >"${HOME}/.ssh/config"
    run in_stubs check_manual_steps supported
    [ "${lines[1]}" = "                Include ~/.config/ssh/config.shared in ~/.ssh/config" ]
}

@test "charge_limit_supported finds the device by what it supports" {
    run in_stubs charge_limit_supported
    [ "${status}" -eq 0 ]
}

@test "charge_limit_supported answers no where no device supports a limit" {
    printf 'none\n' >"${STATE_DIR}/supported"
    run in_stubs charge_limit_supported
    [ "${status}" -eq 1 ]
}

@test "charge_limit_supported refuses when UPower cannot be enumerated" {
    printf 'EnumerateDevices' >"${STATE_DIR}/fail-on"
    run --separate-stderr in_stubs charge_limit_supported
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"could not enumerate UPower devices"* ]]
}

@test "charge_limit_supported refuses when a device cannot be read" {
    printf 'ChargeThresholdSupported' >"${STATE_DIR}/fail-on"
    run --separate-stderr in_stubs charge_limit_supported
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"could not read ChargeThresholdSupported of ${AC0}"* ]]
}

@test "main reports a complete machine and exits 0" {
    complete_home
    present sway ghostty satty
    printf 'portal\nsway-systemd\n' >"${STATE_DIR}/rpm-installed"
    printf 'org.mozilla.thunderbird\nmd.obsidian.Obsidian\n' >"${STATE_DIR}/flatpaks"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 0 ]
    [ "${output}" = "roster:         5 present
flatpaks:       2 present
manual steps:   5 present

How each entry is installed or set up: docs/install.md" ]
}

@test "main exits 1 when anything is missing, and still reports every section" {
    complete_home
    rm "${HWDB_FILE}"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 1 ]
    [ "${lines[0]}" = "roster:         0 present, 5 missing" ]
    [ "${lines[2]}" = "flatpaks:       0 present, 2 missing" ]
    [ "${lines[4]}" = "manual steps:   4 present, 1 missing" ]
    [ "${lines[6]}" = "How each entry is installed or set up: docs/install.md" ]
}

@test "main refuses arguments" {
    run --separate-stderr in_stubs main --verbose
    [ "${status}" -eq 2 ]
    [ -z "${output}" ]
}

@test "main refuses without a Role Marker" {
    rm "${XDG_CONFIG_HOME}/dotfiles/role"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"must contain exactly 'desktop' or 'headless'"* ]]
    [ -z "${output}" ]
}

@test "main refuses on a Headless machine" {
    printf 'headless\n' >"${XDG_CONFIG_HOME}/dotfiles/role"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"Role is 'headless'"* ]]
    [ -z "${output}" ]
}

@test "main refuses without busctl" {
    rm "${STUB_BIN}/busctl"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"command not found: busctl"* ]]
    [ -z "${output}" ]
}

@test "main refuses without awk or grep" {
    local cmd
    for cmd in awk grep; do
        mv "${STUB_BIN}/${cmd}" "${STUB_BIN}/${cmd}.off"
        run --separate-stderr in_stubs main
        [ "${status}" -eq 2 ]
        [[ "${stderr}" == *"command not found: ${cmd}"* ]]
        [ -z "${output}" ]
        mv "${STUB_BIN}/${cmd}.off" "${STUB_BIN}/${cmd}"
    done
}

@test "main refuses before reporting when UPower cannot be asked" {
    printf 'EnumerateDevices' >"${STATE_DIR}/fail-on"
    run --separate-stderr in_stubs main
    [ "${status}" -eq 2 ]
    [ -z "${output}" ]
}
