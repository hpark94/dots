function _fzf_comprun() {
    local command=$1
    shift

    case "$command" in
        export | unset) fzf --preview "eval 'echo \${}'" "$@" ;;
        ssh) fzf --preview 'dig {}' "$@" ;;
        *) fzf --preview 'if [ -d {} ]; then eza --tree --color=always --level=2 {} | head -200; else bat -n --color=always --line-range 1:500 {}; fi' "$@" ;;
    esac
}

function frg() {
    local query="$*"

    local reload="reload:rg --column --hidden --color=always --smart-case \
        --glob \"!.git/**\" \
        {q} || :"

    local opener="
	if [[ \$FZF_SELECT_COUNT -eq 0 ]]; then
		nvim {1} +{2}
	else
		nvim +cw -q {+f}
	fi"

    local preview_script="
        line={2}
        total=\$(wc -l < {1})

        if [ \$line -gt 10 ]; then
            start=\$((line-10))
        else
            start=1
        fi

        bat --style=plain --color=always {1} | \\
        tail -n +\$start | \\
        head -n 20 | \\
        bat --style=plain --color=always --highlight-line \$((line-start+1))"

    local keybinds=(
        --bind "esc:abort"
        --bind "start:$reload"
        --bind "change:$reload"
        --bind "enter:become:$opener"
        --bind "ctrl-o:execute:$opener"
        --bind "alt-a:select-all"
        --bind "alt-d:deselect-all"
        --bind "ctrl-/:toggle-preview"
    )

    local fzf_opts=(
        --disabled
        --ansi
        --multi
        --delimiter ":"
        --preview "$preview_script"
        --preview-window "<80(up)"
        --query "$query"
    )

    fzf "${fzf_opts[@]}" "${keybinds[@]}"

    return $?
}

ffd() {
    local tool="${1:-nvim}"

    if ! command -v "${tool}" &>/dev/null; then
        echo "Error: '${tool}' is not installed or not in PATH" >&2
        return 1
    fi

    local is_terminal=false

    case "${tool}" in
        nvim | vim | vi | nano | emacs | less | more | cat | bat)
            is_terminal=true
            ;;
    esac

    local opener
    if [[ "${is_terminal}" == true ]]; then
        opener="${tool} \"\$@\""
    else
        opener="
		if [[ \$FZF_SELECT_COUNT -eq 0 ]]; then
		    ${tool} \"\$1\" &>/dev/null &
		else
		    for file in \"\$@\"; do
			${tool} \"\$file\" &>/dev/null &
		    done
		fi"
    fi

    local options=(
        --hidden
        --exclude ".git/"
    )

    local keybinds=(
        --bind "esc:abort"
        --bind "enter:become:bash -c '$opener' _ {+}"
        --bind "ctrl-o:execute:bash -c '$opener' _ {+}"
        --bind "alt-a:select-all"
        --bind "alt-d:deselect-all"
        --bind "ctrl-/:toggle-preview"
    )

    local preview_opts=(
        --preview "bat --style=plain --color=always {}"
        --preview-window "<80(up)"
    )

    fd -t f "." \
        "${options[@]}" \
        2>/dev/null \
        | fzf --ansi --multi \
            "${keybinds[@]}" \
            "${preview_opts[@]}"
    return $?
}

tmux_start() {
    if [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]]; then
        return
    fi
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        return
    fi

    if [[ -z $TMUX ]] && command -v tmux >/dev/null 2>&1; then
        local session_name="${USER}"
        local start_dir="${HOME}"

        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux attach-session -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$start_dir"
        fi
    fi
}

function tmux_sessionizer_wrapper() {
    if [[ -z $BUFFER ]]; then
        BUFFER="tmux-sessionizer"
        zle accept-line
    fi
}
