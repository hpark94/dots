#!/usr/bin/env bash
set -euo pipefail

# completeness-check.sh
#
# Asks one Desktop machine whether everything that should be here is actually
# here: every row of packages/roster.md, every line of packages/flatpak.txt, and
# the manual steps nothing else would notice missing. It asserts presence and
# never correctness, installs nothing and changes nothing. Run by path from the
# clone, because packages/ is not deployed. Exit 0 complete, 1 something
# missing, 2 the check itself could not run.

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROSTER="${REPO_DIR}/packages/roster.md"
FLATPAKS="${REPO_DIR}/packages/flatpak.txt"
HWDB_FILE=/etc/udev/hwdb.d/61-battery-local.hwdb

# Set by pick_package_manager: which manager answers for the `-` rows, and which
# roster column speaks for this machine.
PKG_MANAGER=""
PKG_COLUMN=""
MISSING=0

refuse() {
    printf 'completeness-check: %s\n' "$*" >&2
    exit 2
}

# Canonical Role Marker reader: path, contract and error wording may not drift
# (.scratch/portable-dotfiles/issues/14 and 13). The read itself is corrected
# per theme-switch-expansion/issues/05; do not restore the pinned 2>/dev/null.
read_role() {
    local marker="${XDG_CONFIG_HOME:-${HOME}/.config}/dotfiles/role" role=""
    if [[ -r "${marker}" ]]; then
        role=$(<"${marker}")
    fi
    role="${role//[[:space:]]/}"
    case "${role}" in
        desktop | headless)
            printf '%s' "${role}"
            ;;
        *)
            echo "Error: ${marker} must contain exactly 'desktop' or 'headless'. Fix: printf '%s' desktop > ${marker} (or headless)." >&2
            return 1
            ;;
    esac
}

# A Capability Probe on the tools, never a read of the distro (ADR-0011). With
# both or neither there is no telling which column is this machine's.
pick_package_manager() {
    local has_rpm=0 has_dpkg=0
    if command -v rpm >/dev/null 2>&1; then
        has_rpm=1
    fi
    if command -v dpkg >/dev/null 2>&1; then
        has_dpkg=1
    fi
    if [[ "${has_rpm}${has_dpkg}" == 10 ]]; then
        PKG_MANAGER=rpm
        PKG_COLUMN=3
    elif [[ "${has_rpm}${has_dpkg}" == 01 ]]; then
        PKG_MANAGER=dpkg
        PKG_COLUMN=4
    elif [[ "${has_rpm}${has_dpkg}" == 11 ]]; then
        refuse "both rpm and dpkg are on PATH; cannot tell which roster column is this machine's"
    else
        refuse "neither rpm nor dpkg is on PATH; cannot tell which roster column is this machine's"
    fi
}

# One "<command> <package>" line per roster row, backticks stripped, header and
# separator left out.
roster_rows() {
    awk -F'|' -v col="${PKG_COLUMN}" 'NF>4 {
        gsub(/[ `]/, "", $2); gsub(/[ `]/, "", $col)
        if ($2 != "binary" && $2 !~ /^--+$/) print $2, $col
    }' "${ROSTER}"
}

# dpkg keeps a removed package as "deinstall ok config-files", so the name alone
# is not enough: only the installed state counts. Exit 1 is no such package;
# exit 2 is a query that broke and says nothing about the machine.
package_installed() {
    local name=$1 state="" status=0
    if [[ "${PKG_MANAGER}" == rpm ]]; then
        if rpm -q "${name}" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    state=$(dpkg-query -W -f='${db:Status-Status}' "${name}" 2>/dev/null) || status=$?
    case "${status}" in
        0) [[ "${state}" == installed ]] ;;
        1) return 1 ;;
        *) refuse "dpkg-query failed on ${name} (exit ${status})" ;;
    esac
}

# The device is found by what it supports, never by name, as in
# battery-charge-limit. A failed call is the check's own failure.
charge_limit_supported() {
    local devices word path supported
    local -a words
    devices=$(busctl --system call org.freedesktop.UPower /org/freedesktop/UPower \
        org.freedesktop.UPower EnumerateDevices) \
        || refuse "could not enumerate UPower devices"
    read -ra words <<<"${devices}"
    for word in "${words[@]:2}"; do
        path="${word//\"/}"
        supported=$(busctl --system get-property org.freedesktop.UPower "${path}" \
            org.freedesktop.UPower.Device ChargeThresholdSupported) \
            || refuse "could not read ChargeThresholdSupported of ${path}"
        if [[ "${supported}" == "b true" ]]; then
            return 0
        fi
    done
    return 1
}

# report <label> <present> <unchecked> <unchecked wording> [missing...]
report() {
    local label=$1 present=$2 unchecked=$3 unchecked_label=$4 line joined
    shift 4
    line="${present} present"
    if [[ "${unchecked}" -gt 0 ]]; then
        line+=", ${unchecked} ${unchecked_label}"
    fi
    if [[ $# -gt 0 ]]; then
        line+=", $# missing"
    fi
    printf '%-16s%s\n' "${label}:" "${line}"
    if [[ $# -gt 0 ]]; then
        joined=$(printf '%s, ' "$@")
        printf '%-16s%s\n' "" "${joined%, }"
        MISSING=1
    fi
}

check_roster() {
    local rows cmd pkg present=0 unchecked=0
    local -a missing=()
    rows=$(roster_rows) || refuse "could not read ${ROSTER}"
    if [[ -z "${rows}" ]]; then
        refuse "no rows found in ${ROSTER}"
    fi
    while read -r cmd pkg; do
        if [[ "${cmd}" != - ]]; then
            if command -v "${cmd}" >/dev/null 2>&1; then
                present=$((present + 1))
            else
                missing+=("${cmd}")
            fi
        elif [[ "${pkg}" == - ]]; then
            unchecked=$((unchecked + 1))
        elif package_installed "${pkg}"; then
            present=$((present + 1))
        else
            missing+=("${pkg}")
        fi
    done <<<"${rows}"
    report roster "${present}" "${unchecked}" "not checkable here" "${missing[@]}"
}

# By id and whatever the scope: a user-installed Flatpak is present too. Without
# flatpak nothing here can be asked, and its own roster row already says so.
check_flatpaks() {
    local id present=0 unchecked=0 has_flatpak=0
    local -a missing=()
    if command -v flatpak >/dev/null 2>&1; then
        has_flatpak=1
    fi
    while read -r id; do
        if [[ -z "${id}" ]]; then
            continue
        fi
        if [[ "${has_flatpak}" -eq 0 ]]; then
            unchecked=$((unchecked + 1))
        elif flatpak info "${id}" >/dev/null 2>&1; then
            present=$((present + 1))
        else
            missing+=("${id}")
        fi
    done <"${FLATPAKS}"
    report flatpaks "${present}" "${unchecked}" "not checkable here" "${missing[@]}"
}

# check_manual_steps <supported|unsupported>: whether this machine's UPower
# offers a charge limit, which decides if the hwdb file is expected at all. The
# quoted tildes are what the report prints, not paths.
# shellcheck disable=SC2088
check_manual_steps() {
    local charge_limit=$1 present=0 unsupported=0
    local -a missing=()
    local include='^[[:space:]]*Include[[:space:]]+~/\.config/ssh/config\.shared[[:space:]]*$'

    if [[ -d "${HOME}/Sync" ]]; then
        present=$((present + 1))
    else
        missing+=("~/Sync")
    fi
    if [[ -d "${HOME}/projects" ]]; then
        present=$((present + 1))
    else
        missing+=("~/projects")
    fi
    if [[ -f "${HOME}/Sync/.pictures/wallpaper/frieren.jpg" ]]; then
        present=$((present + 1))
    else
        missing+=("~/Sync/.pictures/wallpaper/frieren.jpg")
    fi
    if [[ -f "${HOME}/.ssh/config" ]] && grep -Eq "${include}" "${HOME}/.ssh/config"; then
        present=$((present + 1))
    else
        missing+=("Include ~/.config/ssh/config.shared in ~/.ssh/config")
    fi
    if [[ "${charge_limit}" == unsupported ]]; then
        unsupported=$((unsupported + 1))
    elif [[ -f "${HWDB_FILE}" ]]; then
        present=$((present + 1))
    else
        missing+=("${HWDB_FILE}")
    fi
    report "manual steps" "${present}" "${unsupported}" "not supported on this machine" "${missing[@]}"
}

main() {
    local role cmd charge_limit=unsupported
    if [[ $# -ne 0 ]]; then
        refuse "takes no arguments; run it as ./completeness-check.sh from the clone"
    fi
    role=$(read_role) || exit 2
    if [[ "${role}" == headless ]]; then
        refuse "this machine's Role is 'headless'; the package set is Desktop and promises a Headless machine nothing"
    fi
    if [[ ! -r "${ROSTER}" || ! -r "${FLATPAKS}" ]]; then
        refuse "cannot read ${ROSTER} or ${FLATPAKS}"
    fi
    pick_package_manager
    for cmd in awk grep busctl; do
        command -v "${cmd}" >/dev/null 2>&1 || refuse "command not found: ${cmd}"
    done
    if charge_limit_supported; then
        charge_limit=supported
    fi

    check_roster
    check_flatpaks
    check_manual_steps "${charge_limit}"
    printf '\nHow each entry is installed or set up: docs/install.md\n'
    return "${MISSING}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
