_has() { command -v "$1" >/dev/null 2>&1; }

# Zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load completions
autoload -Uz compinit && compinit
_comp_options+=(globdots)

# Source config
source "$HOME/.envs.sh"
_has mise && eval "$(~/.local/bin/mise activate zsh)"
source "$HOME/.aliases.sh"
_has fzf && _has tmux && source "$HOME/.shell_functions.sh"
_has fzf && source <(fzf --zsh)
_has zoxide && eval "$(zoxide init --cmd cd zsh)"
_has direnv && eval "$(direnv hook zsh)"

# Plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure

zinit cdreplay -q
# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -d $realpath ]]; then eza --tree --color=always --level=2 $realpath | head -200; else bat -n --color=always $realpath; fi'
zstyle ':fzf-tab:*' use-fzf-default-opts yes

_ffd() {
    local -a tools
    tools=()
    local dir bin
    for dir in ${(s.:.)PATH}; do
        for bin in "$dir"/*(N-x:t); do
            tools+=("$bin")
        done
    done
    tools=(${(u)tools})
    _describe 'tool' tools
}
compdef _ffd ffd

# Themes
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS' --color=fg:#4d4851,bg:#f9f7f6,hl:#4d4851 --color=fg+:#4d4851,bg+:#e4ded7,hl+:#4d4851 --color=info:#3a7292,prompt:#614096,pointer:#a63f3f --color=marker:#3a784c,spinner:#614096,header:#c36022'
# export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS' --color=fg:#e9e6e2,bg:#100e11,hl:#e9e6e2 --color=fg+:#e9e6e2,bg+:#29252d,hl+:#e9e6e2 --color=info:#69acd3,prompt:#a381da,pointer:#d36969 --color=marker:#59c076,spinner:#a381da,header:#e08852'

# History
HIST_STAMPS="dd.mm.yyyy"
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Ulimit set
ulimit -n 4096

# Keybindings
bindkey -e
bindkey "^p" history-search-backward
bindkey "^n" history-search-forward
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

zle -N tmux_sessionizer_wrapper
bindkey '^f' tmux_sessionizer_wrapper
bindkey '^ ' autosuggest-accept

# Disable highlight of pasted text
zle_highlight+=(paste:none)

# Start TMUX-Session
[[ -o interactive ]] && declare -f tmux_start >/dev/null && tmux_start
