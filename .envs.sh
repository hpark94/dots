export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:$HOME/.local/scripts:$PATH
export PATH="$HOME/go/bin:$PATH"

if [[ -z "$SSH_CONNECTION" && -z "$SSH_TTY" ]]; then
    export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
    export OMPI_CXX=g++
    export QT_QPA_PLATFORM=wayland
    export LIBVIRT_DEFAULT_URI="qemu:///system"
fi

if [[ -f "${HOME}/.env" ]]; then
    source "${HOME}/.env"
fi

_has() { command -v "$1" >/dev/null 2>&1; }
_has nvim && export EDITOR=nvim
_has librewolf && export BROWSER=librewolf
