_has() { command -v "$1" >/dev/null 2>&1; }

shopt -s checkwinsize

if [ -t 1 ] && tput colors >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
	PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n$ '
else
	PS1='\u@\h:\w\n$ '
fi

HISTFILE=~/.bash_history
HISTSIZE=5000
HISTFILESIZE=5000
HISTCONTROL=ignoreboth:erasedups

source "$HOME/.envs.sh"
_has mise && eval "$(~/.local/bin/mise activate bash)"

source "$HOME/.aliases.sh"
_has fzf && _has tmux && source "$HOME/.shell_functions.sh"

_has fzf && eval "$(fzf --bash)"
_has zoxide && eval "$(zoxide init --cmd cd bash)"
_has direnv && eval "$(direnv hook bash)"
