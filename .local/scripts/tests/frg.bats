#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# fzf is stubbed on a prepended PATH, so no interactive picker is ever started.
# Two fzf stubs: the recorder writes every argument on its own line so the
# reload, opener and preview strings can be asserted verbatim, and the runner
# additionally does what fzf does on enter, filling the placeholders and running
# the `become` command through a shell, so the opener is exercised rather than
# assumed. rg only needs to exist on PATH, because frg never runs it itself,
# fzf does.

SCRIPT="${BATS_TEST_DIRNAME}/../frg"

setup() {
    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"

    FZF_ARGS="${BATS_TEST_TMPDIR}/fzf.args"
    FRG_SELECTION="${BATS_TEST_TMPDIR}/selection"
    FRG_RUN_LOG="${BATS_TEST_TMPDIR}/run.log"
    # The runner stub and the nvim stub read these out of the environment, so
    # their bodies can stay literal heredocs.
    export FZF_ARGS FRG_SELECTION FRG_RUN_LOG

    local cmd
    for cmd in rg fzf-preview; do
        printf '#!/usr/bin/env bash\nexit 0\n' >"${STUB_BIN}/${cmd}"
        chmod +x "${STUB_BIN}/${cmd}"
    done

    make_nvim_stub 0
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

# nvim stub: record argv, then exit with the requested status.
make_nvim_stub() {
    cat >"${STUB_BIN}/nvim" <<STUB_EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >>"${FRG_RUN_LOG}"
exit $1
STUB_EOF
    chmod +x "${STUB_BIN}/nvim"
}

# fzf stub that also acts on the enter binding, with the given lines as the
# selection: it fills fzf's placeholders the way fzf does, single-quoting each
# value, and runs the resulting command through a shell. FZF_SELECT_COUNT is
# fzf's own, 0 unless the user multi-selected, and is what the opener branches
# on, so it is the first argument here.
make_fzf_runner() {
    export FRG_SELECT_COUNT="$1"
    shift
    printf '%s\n' "$@" >"${FRG_SELECTION}"

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

quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

mapfile -t selection <"${FRG_SELECTION}"
# {1} and {2} are the first two colon-separated fields of the line under the
# cursor, and {+f} is a file fzf writes the whole selection into.
IFS=: read -r file line _ <<<"${selection[0]}"
list="${FRG_SELECTION}.list"
printf '%s\n' "${selection[@]}" >"${list}"

command="${command//\{1\}/$(quote "${file}")}"
command="${command//\{2\}/$(quote "${line}")}"
command="${command//\{+f\}/$(quote "${list}")}"

export FZF_SELECT_COUNT="${FRG_SELECT_COUNT}"
exec sh -c "${command}"
STUB_EOF
    chmod +x "${STUB_BIN}/fzf"
}

# A PATH holding every stub except the named one.
path_without() {
    local missing="$1" cmd
    local dir="${BATS_TEST_TMPDIR}/without-${missing}"
    mkdir -p "${dir}"
    for cmd in rg fzf nvim fzf-preview; do
        [[ "${cmd}" == "${missing}" ]] && continue
        ln -sf "${STUB_BIN}/${cmd}" "${dir}/${cmd}"
    done
    printf '%s' "${dir}"
}

@test "a missing rg fails loudly" {
    run env PATH="$(path_without rg)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"rg not available"* ]]
    [ ! -e "${FZF_ARGS}" ]
}

@test "a missing fzf fails loudly" {
    run env PATH="$(path_without fzf)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fzf not available"* ]]
}

@test "a missing nvim fails before the picker, not after the pick" {
    run env PATH="$(path_without nvim)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"nvim not available"* ]]
    [ ! -e "${FZF_ARGS}" ]
}

@test "a missing fzf-preview fails loudly" {
    run env PATH="$(path_without fzf-preview)" "${BASH}" "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"fzf-preview not available"* ]]
    [ ! -e "${FZF_ARGS}" ]
}

@test "fzf drives rg instead of filtering itself" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *"--disabled"* ]]
    [[ "${args}" == *$'--delimiter\n:'* ]]
    [[ "${args}" == *'start:reload:rg --column --hidden --color=always --smart-case --glob "!.git/**" {q} || :'* ]]
    [[ "${args}" == *'change:reload:rg --column --hidden --color=always --smart-case --glob "!.git/**" {q} || :'* ]]
}

@test "the query is seeded from the arguments" {
    run "${SCRIPT}" foo bar
    [ "${status}" -eq 0 ]
    [[ "$(cat "${FZF_ARGS}")" == *$'--query\nfoo bar'* ]]
}

@test "enter and ctrl-o open the match in nvim" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *'if [[ $FZF_SELECT_COUNT -eq 0 ]]; then'* ]]
    [[ "${args}" == *"nvim {1} +{2}"* ]]
    [[ "${args}" == *"nvim +cw -q {+f}"* ]]
    [[ "${args}" == *"esc:abort"* ]]
    [[ "${args}" == *"alt-a:select-all"* ]]
    [[ "${args}" == *"alt-d:deselect-all"* ]]
    [[ "${args}" == *"ctrl-/:toggle-preview"* ]]
}

@test "the preview is the shared renderer, told which line matched" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *$'--preview\nfzf-preview {1} {2}'* ]]
}

@test "fzf centres the matched line itself" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${FZF_ARGS}")" == *$'--preview-window\n+{2}-/2,<50(up)'* ]]
}

@test "no hand-rolled preview window is left in the fzf arguments" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    # Matched on the invocation shapes, not the bare names: fzf's own --header
    # and --tail options contain "head" and "tail" as substrings.
    [[ "${args}" != *"wc -l"* ]]
    [[ "${args}" != *"tail -n"* ]]
    [[ "${args}" != *"head -n"* ]]
    [[ "${args}" != *"bat --style"* ]]
}

@test "only the enter binding remaps the opener's status" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local args
    args=$(cat "${FZF_ARGS}")
    [[ "${args}" == *'fi; rc=$?;'* ]]
    # ctrl-o uses execute, whose status never reaches this script, so it is left
    # as the bare opener: exactly one of the two bindings carries the remap.
    [ "$(grep -c 'exit 121' <<<"${args}")" -eq 1 ]
    # `${s}` would reach fzf as its own {s} placeholder, not as a variable.
    [[ "${args}" != *'{s}'* ]]
}

@test "an opener that failed is not reported as an empty pick" {
    make_nvim_stub 1
    make_fzf_runner 0 "src/a.txt:12:3:a hit"

    run "${SCRIPT}"
    [ "${status}" -eq 1 ]
}

@test "an opener that exited 130 is not reported as an abort" {
    make_nvim_stub 130
    make_fzf_runner 0 "src/a.txt:12:3:a hit"

    run "${SCRIPT}"
    [ "${status}" -eq 130 ]
}

@test "an opener that failed for another reason keeps its status" {
    make_nvim_stub 2
    make_fzf_runner 0 "src/a.txt:12:3:a hit"

    run "${SCRIPT}"
    [ "${status}" -eq 2 ]
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
