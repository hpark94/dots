#!/usr/bin/env bats

# Covers only the theme-fragment sourcing: the sessionizer is normally started
# by `tmux neww`, which hands it the tmux server's frozen environment, so it has
# to read the current theme vars off disk itself.

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    mkdir -p "$HOME" "$XDG_STATE_HOME/theme"
    SCRIPT="$BATS_TEST_DIRNAME/../tmux-sessionizer"

    local bin="$BATS_TEST_TMPDIR/stub-bin"
    mkdir -p "$bin"
    export FZF_LOG="$BATS_TEST_TMPDIR/fzf.log"
    : >"$FZF_LOG"
    # Records the options it was given and selects nothing, so the script takes
    # the empty-selection exit and never reaches the real tmux.
    cat >"$bin/fzf" <<'STUB_EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$FZF_DEFAULT_OPTS" >>"$FZF_LOG"
STUB_EOF
    printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/tmux"
    chmod +x "$bin/fzf" "$bin/tmux"
    PATH="$bin:$PATH"
}

@test "fzf gets FZF_DEFAULT_OPTS from the theme fragment, not from a stale environment" {
    printf "export FZF_DEFAULT_OPTS='--color=bg:#f00001'\n" \
        >"$XDG_STATE_HOME/theme/shell-env.sh"
    export FZF_DEFAULT_OPTS='--color=bg:#d00001'

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$FZF_LOG")" = "--color=bg:#f00001" ]
}

@test "a missing theme fragment leaves the sessionizer working and exiting cleanly" {
    rm -f "$XDG_STATE_HOME/theme/shell-env.sh"
    export FZF_DEFAULT_OPTS='--color=bg:#d00001'

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$FZF_LOG")" = "--color=bg:#d00001" ]
    # `run` folds stderr into $output, so an empty $output is what pins the
    # readability guard down: without it, sourcing the absent file would still
    # exit 0 but would spill a "No such file or directory" onto the terminal.
    [ -z "$output" ]
}
