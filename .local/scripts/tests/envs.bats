#!/usr/bin/env bats

setup() {
	ENVS="$BATS_TEST_DIRNAME/../../../.envs.sh"
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME"
	export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/xdg"
	mkdir -p "$XDG_RUNTIME_DIR"
	unset DOCKER_HOST LIBVIRT_DEFAULT_URI QT_QPA_PLATFORM OMPI_CXX WAYLAND_DISPLAY
}

# Mint a real unix socket at the given path. AF_UNIX bind leaves the socket
# file behind after the process exits, so [[ -S ]] sees it.
make_socket() {
	python3 -c 'import socket, sys
socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$1"
}

@test "OMPI_CXX is exported unconditionally" {
	source "$ENVS" || true
	[ "$OMPI_CXX" = "g++" ]
}

@test "_export_if_socket exports when the socket exists" {
	source "$ENVS" || true
	make_socket "$BATS_TEST_TMPDIR/t.sock"
	_export_if_socket PROBE_VAR probe-value "$BATS_TEST_TMPDIR/t.sock"
	[ "$PROBE_VAR" = "probe-value" ]
}

@test "_export_if_socket does not export when the socket is absent" {
	source "$ENVS" || true
	_export_if_socket PROBE_VAR probe-value "$BATS_TEST_TMPDIR/missing.sock"
	[ -z "${PROBE_VAR:-}" ]
}

@test "DOCKER_HOST is exported when docker.sock exists" {
	make_socket "$XDG_RUNTIME_DIR/docker.sock"
	source "$ENVS" || true
	[ "$DOCKER_HOST" = "unix://$XDG_RUNTIME_DIR/docker.sock" ]
}

@test "DOCKER_HOST is not exported when docker.sock is absent" {
	source "$ENVS" || true
	[ -z "${DOCKER_HOST:-}" ]
}

# LIBVIRT_DEFAULT_URI's socket path is hard-coded (/run/libvirt/libvirt-sock),
# not fakeable via $XDG_*, so exercise the concrete variable through the same
# probe helper with a controllable path. `source` first sets it from this host's
# real socket, so unset before asserting.
@test "LIBVIRT_DEFAULT_URI is exported when its libvirt socket exists" {
	source "$ENVS" || true
	unset LIBVIRT_DEFAULT_URI
	make_socket "$BATS_TEST_TMPDIR/libvirt.sock"
	_export_if_socket LIBVIRT_DEFAULT_URI "qemu:///system" "$BATS_TEST_TMPDIR/libvirt.sock"
	[ "$LIBVIRT_DEFAULT_URI" = "qemu:///system" ]
}

@test "LIBVIRT_DEFAULT_URI is not exported when its libvirt socket is absent" {
	source "$ENVS" || true
	unset LIBVIRT_DEFAULT_URI
	_export_if_socket LIBVIRT_DEFAULT_URI "qemu:///system" "$BATS_TEST_TMPDIR/missing.sock"
	[ -z "${LIBVIRT_DEFAULT_URI:-}" ]
}

@test "QT_QPA_PLATFORM is exported when WAYLAND_DISPLAY is set" {
	export WAYLAND_DISPLAY=wayland-1
	source "$ENVS" || true
	[ "$QT_QPA_PLATFORM" = "wayland" ]
}

@test "QT_QPA_PLATFORM is not exported when WAYLAND_DISPLAY is unset" {
	source "$ENVS" || true
	[ -z "${QT_QPA_PLATFORM:-}" ]
}
