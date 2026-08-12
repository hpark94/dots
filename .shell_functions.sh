function _fzf_comprun() {
    local command=$1
    shift

    case "${command}" in
        export | unset) fzf --preview "eval 'echo \${}'" "$@" ;;
        ssh) fzf --preview 'dig {}' "$@" ;;
        *) fzf --preview 'fzf-preview {}' "$@" ;;
    esac
}

tmux_start() {
    if [[ "${TERMINAL_EMULATOR}" == "JetBrains-JediTerm" ]]; then
        return
    fi
    if [[ "${TERM_PROGRAM}" == "vscode" ]]; then
        return
    fi

    if [[ -z ${TMUX} ]] && command -v tmux >/dev/null 2>&1; then
        local session_name="${USER}"
        local start_dir="${HOME}"

        if tmux has-session -t "${session_name}" 2>/dev/null; then
            tmux attach-session -t "${session_name}"
        else
            tmux new-session -s "${session_name}" -c "${start_dir}"
        fi
    fi
}

function tmux_sessionizer_wrapper() {
    if [[ -z ${BUFFER} ]]; then
        BUFFER="tmux-sessionizer"
        zle accept-line
    fi
}

zupdate() {
    zinit self-update
    zinit update --all
    find ~/.local/share/zinit/completions/ -xtype l -delete
    rm -f ~/.zcompdump*
    exec zsh
}

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="${tmp}"
    IFS= read -r -d '' cwd <"${tmp}"
    [ "${cwd}" != "${PWD}" ] && [ -d "${cwd}" ] && builtin cd -- "${cwd}"
    command rm -f -- "${tmp}"
}
