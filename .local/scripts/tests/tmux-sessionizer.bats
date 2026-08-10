#!/usr/bin/env bats

# Covers the theme-fragment sourcing (the sessionizer is normally started by
# `tmux neww`, which hands it the tmux server's frozen environment, so it has to
# read the current theme vars off disk itself) and the session dispatch. `TMUX`
# and `pgrep` are pinned by stubs so the result does not depend on whether bats
# itself runs inside a tmux session.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
    mkdir -p "${HOME}" "${XDG_STATE_HOME}/theme"
    SCRIPT="${BATS_TEST_DIRNAME}/../tmux-sessionizer"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    export FZF_LOG="${BATS_TEST_TMPDIR}/fzf.log"
    export TMUX_LOG="${BATS_TEST_TMPDIR}/tmux.log"
    : >"${FZF_LOG}"
    : >"${TMUX_LOG}"
    # Records the options it was given and aborts the way Esc does, exit 130.
    cat >"${STUB_BIN}/fzf" <<'STUB_EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$FZF_DEFAULT_OPTS" >>"$FZF_LOG"
exit 130
STUB_EOF
    # Logs every subcommand; `has-session` reports "no such session".
    cat >"${STUB_BIN}/tmux" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMUX_LOG"
if [[ "$1" == "has-session" ]]; then
    exit 1
fi
exit 0
STUB_EOF
    # No tmux server running, the state pgrep reports with exit 1.
    printf '#!/usr/bin/env bash\nexit 1\n' >"${STUB_BIN}/pgrep"
    chmod +x "${STUB_BIN}/fzf" "${STUB_BIN}/tmux" "${STUB_BIN}/pgrep"
    PATH="${STUB_BIN}:${PATH}"
    unset TMUX
}

# fzf stub that picks the given path instead of aborting.
setup_selecting_fzf_stub() {
    cat >"${STUB_BIN}/fzf" <<STUB_EOF
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$1"
STUB_EOF
    chmod +x "${STUB_BIN}/fzf"
}

@test "fzf gets FZF_DEFAULT_OPTS from the theme fragment, not from a stale environment" {
    printf "export FZF_DEFAULT_OPTS='--color=bg:#f00001'\n" \
        >"${XDG_STATE_HOME}/theme/shell-env.sh"
    export FZF_DEFAULT_OPTS='--color=bg:#d00001'

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${FZF_LOG}")" = "--color=bg:#f00001" ]
}

@test "a missing theme fragment leaves the sessionizer working and exiting cleanly" {
    rm -f "${XDG_STATE_HOME}/theme/shell-env.sh"
    export FZF_DEFAULT_OPTS='--color=bg:#d00001'

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${FZF_LOG}")" = "--color=bg:#d00001" ]
    # `run` folds stderr into $output, so an empty $output is what pins the
    # readability guard down: without it, sourcing the absent file would still
    # exit 0 but would spill a "No such file or directory" onto the terminal.
    [ -z "${output}" ]
}

@test "outside tmux with no server running, a selection opens an attached session" {
    mkdir -p "${BATS_TEST_TMPDIR}/my.project"
    setup_selecting_fzf_stub "${BATS_TEST_TMPDIR}/my.project"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${TMUX_LOG}")" = "new-session -s my_project -c ${BATS_TEST_TMPDIR}/my.project" ]
}

@test "inside tmux, a selection switches the client instead of attaching" {
    mkdir -p "${BATS_TEST_TMPDIR}/notes"
    setup_selecting_fzf_stub "${BATS_TEST_TMPDIR}/notes"
    export TMUX="/run/user/1000/tmux-1000/default,4242,0"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qx "new-session -ds notes -c ${BATS_TEST_TMPDIR}/notes" "${TMUX_LOG}"
    grep -qx "switch-client -t notes" "${TMUX_LOG}"
}
