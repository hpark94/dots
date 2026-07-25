export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:$HOME/.local/scripts:$PATH
export PATH="$HOME/go/bin:$PATH"

# Each of these is a Capability Probe on the thing it actually needs, not a
# proxy for SSH-ness: SSHing into this Desktop, or connecting under waypipe,
# should not strip a variable whose resource is still present here.
export OMPI_CXX=g++

# export NAME=VALUE only when a given unix socket actually exists.
_export_if_socket() {
    if [[ -S "$3" ]]; then
        export "$1"="$2"
    fi
}
_export_if_socket DOCKER_HOST "unix://${XDG_RUNTIME_DIR}/docker.sock" "${XDG_RUNTIME_DIR}/docker.sock"
_export_if_socket LIBVIRT_DEFAULT_URI "qemu:///system" /run/libvirt/libvirt-sock

if [[ -n "$WAYLAND_DISPLAY" ]]; then
    export QT_QPA_PLATFORM=wayland
fi

# ~/.env holds machine-local secrets only (credentials, tokens); untracked.
if [[ -f "${HOME}/.env" ]]; then
    source "${HOME}/.env"
fi

_has() { command -v "$1" >/dev/null 2>&1; }
_has nvim && export EDITOR=nvim
_has librewolf && export BROWSER=librewolf
