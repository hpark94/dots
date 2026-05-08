export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:$HOME/.local/scripts:$PATH
export PATH="$HOME/go/bin:$PATH"
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
export OMPI_CXX=g++
export QT_QPA_PLATFORM=wayland
export LIBVIRT_DEFAULT_URI="qemu:///system"

if [[ -f "${HOME}/.env" ]]; then
    source "${HOME}/.env"
fi
