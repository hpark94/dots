#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# fd and fzf are stubbed on a prepended PATH, so no interactive picker is ever
# started. Two fzf stubs: the recorder writes every argument on its own line so
# the wiring can be asserted verbatim, and the runner additionally does what fzf
# does on enter, substituting the selection into the `become` command and
# running it, so assertions can be made on the tool's real argv.

SCRIPT="${BATS_TEST_DIRNAME}/../ffd"

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    FD_ARGS="${BATS_TEST_TMPDIR}/fd.args"
    FZF_ARGS="${BATS_TEST_TMPDIR}/fzf.args"
    FFD_SELECTION="${BATS_TEST_TMPDIR}/selection"
    FFD_RUN_LOG="${BATS_TEST_TMPDIR}/run.log"
    # The runner stub and the tool stubs read these out of the environment, so
    # their bodies can stay literal heredocs.
    export FZF_ARGS FFD_SELECTION FFD_RUN_LOG

    cat >"${STUB_BIN}/fd" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FD_ARGS}"
printf 'a.txt\nb.txt\n'
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    make_fzf_stub 0
}

# fzf stub: record args, then exit with the requested status.
make_fzf_stub() {
    cat >"${STUB_BIN}/fzf" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FZF_ARGS}"
exit $1
STUB_EOF
    chmod +x "${STUB_BIN}/fzf"
}

# fzf stub that also acts on the enter binding, with the given lines as the
# selection: it single-quotes each one the way fzf does and runs the resulting
# command through a shell, which is what makes the quoting assertions real.
make_fzf_runner() {
    printf '%s\n' "$@" >"${FFD_SELECTION}"

    cat >"${STUB_BIN}/fzf" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"${FZF_ARGS}"

command=""
previous=""
for arg in "$@"; do
    if [[ "${previous}" == "--bind" && "${arg}" == enter:become:* ]]; then
        command="${arg#enter:become:}"
    fi
    previous="${arg}"
done

selection=""
while IFS= read -r line; do
    selection+=" '${line//\'/\'\\\'\'}'"
done <"${FFD_SELECTION}"
selection="${selection# }"

command="${command//\{+\}/${selection}}"
exec sh -c "${command}"
STUB_EOF
    chmod +x "${STUB_BIN}/fzf"
}

# Tool stub: append one record per invocation, marker line then argv.
make_tool_stub() {
    local dir="${2:-${STUB_BIN}}"
    mkdir -p "${dir}"
    cat >"${dir}/$1" <<'STUB_EOF'
#!/usr/bin/env bash
{
    echo "--"
    printf '%s\n' "$@"
} >>"${FFD_RUN_LOG}"
STUB_EOF
    chmod +x "${dir}/$1"
}

# setsid stub: record the invocation, then run what it was asked to run so the
# tool's own record still lands in the log.
make_setsid_stub() {
    cat >"${STUB_BIN}/setsid" <<'STUB_EOF'
#!/usr/bin/env bash
{
    echo "-- setsid"
    printf '%s\n' "$@"
} >>"${FFD_RUN_LOG}"
shift
exec "$@"
STUB_EOF
    chmod +x "${STUB_BIN}/setsid"
}

@test "a missing fd fails loudly" {
    run env PATH=/nonexistent "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fd not available"* ]]
}

@test "a missing fzf fails loudly" {
    mkdir -p "${BATS_TEST_TMPDIR}/fd-only"
    ln -s "${STUB_BIN}/fd" "${BATS_TEST_TMPDIR}/fd-only/fd"

    run env PATH="${BATS_TEST_TMPDIR}/fd-only" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fzf not available"* ]]
    [ ! -e "${FD_ARGS}" ]
}

@test "a tool that is not on PATH fails loudly" {
    run "${SCRIPT}" no-such-tool
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'no-such-tool' is not installed or not in PATH"* ]]
    [ ! -e "${FD_ARGS}" ]
}

@test "a leading-dash tool name fails loudly before the picker" {
    run "${SCRIPT}" -- -b
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'--' is not installed or not in PATH"* ]]
    [ ! -e "${FD_ARGS}" ]
}

@test "fd is asked for hidden files outside .git" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FD_ARGS}")
    [[ "${args}" == *$'-t\nf\n.'* ]]
    [[ "${args}" == *"--hidden"* ]]
    [[ "${args}" == *$'--exclude\n.git/'* ]]
}

@test "fd errors are not swallowed" {
    cat >"${STUB_BIN}/fd" <<'STUB_EOF'
#!/usr/bin/env bash
echo "fd: broken glob" >&2
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    run "${SCRIPT}"
    [[ "${output}" == *"fd: broken glob"* ]]
}

@test "fd dying on SIGPIPE is not a failure of this script" {
    # fzf stops reading once the user picks; make fd write far more than a pipe
    # buffer holds so it is guaranteed to still be writing when fzf leaves, and
    # so gets killed by SIGPIPE instead of exiting cleanly.
    cat >"${STUB_BIN}/fd" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${FD_ARGS}"
seq 1 200000
STUB_EOF
    chmod +x "${STUB_BIN}/fd"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "fzf previews through fzf-preview" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *$'--preview\nfzf-preview {}'* ]]
    [[ "${args}" == *$'--preview-window\n<50(up)'* ]]
    [[ "${args}" == *"--multi"* ]]
    [[ "${args}" == *"--ansi"* ]]
}

@test "the tool runs in the foreground by default" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *"enter:become:nvim {+}"* ]]
    [[ "${args}" == *"ctrl-o:execute:nvim {+}"* ]]
    [[ "${args}" != *"setsid"* ]]
    [[ "${args}" != *"/dev/null"* ]]
    [[ "${args}" != *"bash -c"* ]]
    [[ "${args}" != *"esc:abort"* ]]
    [[ "${args}" == *"alt-a:select-all"* ]]
    [[ "${args}" == *"alt-d:deselect-all"* ]]
    [[ "${args}" == *"ctrl-/:toggle-preview"* ]]
}

@test "-b prefixes the launch with setsid" {
    run "${SCRIPT}" -b nvim
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    # --fork is load-bearing: setsid only forks on its own when it already leads
    # a process group, which it does not when fzf becomes it.
    [[ "${args}" == *"enter:become:setsid --fork nvim {+}"* ]]
    [[ "${args}" == *"ctrl-o:execute:setsid --fork nvim {+}"* ]]
}

@test "-b runs the tool through setsid with the whole selection" {
    make_tool_stub mytool
    make_setsid_stub
    make_fzf_runner "a.txt" "b.txt"

    run "${SCRIPT}" -b mytool
    [ "${status}" -eq 0 ]
    local -a lines
    mapfile -t lines <"${FFD_RUN_LOG}"
    [ "${lines[0]}" = "-- setsid" ]
    [ "${lines[1]}" = "--fork" ]
    [ "${lines[2]}" = "mytool" ]
    [ "${lines[3]}" = "a.txt" ]
    [ "${lines[4]}" = "b.txt" ]
    [ "${lines[5]}" = "--" ]
    [ "${lines[6]}" = "a.txt" ]
    [ "${lines[7]}" = "b.txt" ]
    [ "${#lines[@]}" -eq 8 ]
}

@test "-b fails loudly when setsid is missing" {
    make_tool_stub mytool
    mkdir -p "${BATS_TEST_TMPDIR}/no-setsid"
    local dir="${BATS_TEST_TMPDIR}/no-setsid"
    ln -s "${STUB_BIN}/fd" "${dir}/fd"
    ln -s "${STUB_BIN}/fzf" "${dir}/fzf"
    ln -s "${STUB_BIN}/mytool" "${dir}/mytool"

    run env PATH="${dir}" "${BASH}" "${SCRIPT}" -b mytool
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"setsid not available"* ]]
    [ ! -e "${FZF_ARGS}" ]
}

@test "a multi-file selection reaches the tool in one invocation" {
    make_tool_stub mytool
    make_fzf_runner "a.txt" "b.txt" "c.txt"

    run "${SCRIPT}" mytool --flag
    [ "${status}" -eq 0 ]
    local -a lines
    mapfile -t lines <"${FFD_RUN_LOG}"
    [ "${lines[0]}" = "--" ]
    [ "${lines[1]}" = "--flag" ]
    [ "${lines[2]}" = "a.txt" ]
    [ "${lines[3]}" = "b.txt" ]
    [ "${lines[4]}" = "c.txt" ]
    # One marker line only: three files are three arguments, not three runs.
    [ "${#lines[@]}" -eq 5 ]
}

@test "a filename with a quote and a space arrives intact" {
    make_tool_stub mytool
    make_fzf_runner "it's a file.txt"

    run "${SCRIPT}" mytool
    [ "${status}" -eq 0 ]
    local -a lines
    mapfile -t lines <"${FFD_RUN_LOG}"
    [ "${lines[0]}" = "--" ]
    [ "${lines[1]}" = "it's a file.txt" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "a non-editor tool still runs in the foreground" {
    local dir="${BATS_TEST_TMPDIR}/lone-bin"
    make_tool_stub deleter "${dir}"
    make_fzf_runner "a.txt" "b.txt"
    # The tool here stands in for a destructive one, so PATH is exactly this
    # directory: nothing the test did not put there can be reached, and a stub
    # that went missing fails the test instead of running the real thing.
    ln -s "${STUB_BIN}/fd" "${dir}/fd"
    ln -s "${STUB_BIN}/fzf" "${dir}/fzf"
    ln -s "${BASH}" "${dir}/bash"
    ln -s "$(command -v sh)" "${dir}/sh"

    run env PATH="${dir}" "${BASH}" "${SCRIPT}" deleter -rf
    [ "${status}" -eq 0 ]
    local -a lines
    mapfile -t lines <"${FFD_RUN_LOG}"
    [ "${lines[0]}" = "--" ]
    [ "${lines[1]}" = "-rf" ]
    [ "${lines[2]}" = "a.txt" ]
    [ "${lines[3]}" = "b.txt" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "an fzf abort is not an error" {
    make_fzf_stub 130

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "an empty fzf result is not an error" {
    make_fzf_stub 1

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "a real fzf failure keeps its status" {
    make_fzf_stub 2

    run "${SCRIPT}"
    [ "${status}" -eq 2 ]
}
