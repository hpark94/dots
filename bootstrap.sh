#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh <desktop|headless>
#
# Takes a machine from a bare `git clone` to a fully built one: stow succeeds
# even on a fresh Fedora $HOME, the Role Marker and a ~/.gitconfig stub exist,
# mise and its toolchain are installed, and every tmux/nvim/zinit plugin is
# actually installed rather than waiting on first interactive use. Every step
# guards itself, so re-running is safe and it also retrofits a machine already
# deployed by hand with no Marker and no state. The Role is recorded, never
# branched on: every step below runs identically for both Roles.

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Fresh-Fedora shell startup files that collide with stow on the first run.
SKEL_FILES=(.bashrc .bash_profile .bash_logout .zshrc .zprofile)

usage() {
	printf 'Usage: bootstrap.sh <desktop|headless>\n' >&2
	exit 2
}

err() {
	printf 'Error: %s\n' "$*" >&2
}

role_marker_file() {
	echo "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/role"
}

theme_state_file() {
	echo "${XDG_STATE_HOME:-$HOME/.local/state}/theme/mode"
}

tpm_dir() {
	echo "$HOME/.tmux/plugins/tpm"
}

# 1. The shared XDG namespaces must be real dirs before stow, or stow folds each
#    whole namespace into one symlink into the repo and mise/zinit/nvim plugins
#    and the Role Marker all drift into the working tree.
precreate_dirs() {
	mkdir -p "$HOME/.config" "$HOME/.local" "$HOME/.local/bin"
}

# 2. Back up any real skel file that would abort stow; leave an already-stowed
#    symlink alone, so a re-run is a no-op.
backup_skel() {
	local f target
	for f in "${SKEL_FILES[@]}"; do
		target="$HOME/$f"
		if [[ -f "$target" && ! -L "$target" ]]; then
			mv "$target" "$target.bak"
		fi
	done
}

# 3. Stow the single package. A no-op once already stowed.
run_stow() {
	(cd "$REPO_DIR" && stow .)
}

# 4. Write the Role Marker from the argument, but never clobber an existing one
#    (a retrofit or recovery run keeps the Role already decided on this machine).
write_role_marker() {
	local role=$1 marker
	marker=$(role_marker_file)
	if [[ -e "$marker" ]]; then
		return 0
	fi
	mkdir -p "$(dirname "$marker")"
	printf '%s\n' "$role" >"$marker"
}

# 5. Write the include-only ~/.gitconfig stub if absent; never overwrite one a
#    tool (e.g. `gh auth login`) has since appended its own settings to.
write_gitconfig_stub() {
	local stub="$HOME/.gitconfig"
	if [[ -e "$stub" || -L "$stub" ]]; then
		return 0
	fi
	printf '[include]\n\tpath = ~/.gitconfig.shared\n' >"$stub"
}

# 6a. Install mise only if absent. It bootstraps the pinned toolchain, so it is
#     deliberately itself unpinned.
install_mise() {
	if command -v mise >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/mise" ]]; then
		return 0
	fi
	curl https://mise.run | sh
}

# 6b. Activate mise in this process (not just for later shells) so every step
#     below resolves the mise-managed toolchain, including the pinned neovim.
activate_mise() {
	local bin=mise
	command -v mise >/dev/null 2>&1 || bin="$HOME/.local/bin/mise"
	eval "$("$bin" activate bash --shims)"
}

# 7. Install everything the tracked mise config declares. Slow on first run
#    (Headless builds Desktop-weight tools too), so say so rather than look hung.
mise_install() {
	printf 'bootstrap: installing the mise toolchain; the first run can take several minutes...\n'
	mise install
}

# 8a. Clone tpm if missing (nothing else in the repo does, so every @plugin line
#     is inert on a fresh box until this runs).
clone_tpm() {
	local dir
	dir=$(tpm_dir)
	if [[ ! -d "$dir" ]]; then
		git clone --depth 1 https://github.com/tmux-plugins/tpm "$dir"
	fi
}

# 8b. Install the declared tmux plugins. Idempotent upstream.
install_tpm_plugins() {
	"$(tpm_dir)/bin/install_plugins"
}

# 9. Force nvim's plugin manager to completion now that the pinned neovim is on
#    PATH, so the machine is done on exit rather than on first interactive nvim.
install_nvim_plugins() {
	nvim --headless '+Lazy! sync' +qa
}

# 10. Force zinit's self-install (driven from .zshrc) for the same reason.
install_zinit() {
	if command -v zsh >/dev/null 2>&1; then
		zsh -ic exit
	fi
}

# 11. Write a default Theme Mode only if absent (never resets a live mode on a
#     retrofit run); a cold machine renders light, matching nvim's own fallback.
write_theme_default() {
	local mode_file
	mode_file=$(theme_state_file)
	if [[ -e "$mode_file" ]]; then
		return 0
	fi
	mkdir -p "$(dirname "$mode_file")"
	printf '%s' light >"$mode_file"
}

main() {
	if [[ $# -ne 1 ]]; then
		usage
	fi
	local role=$1
	case "$role" in
	desktop | headless) ;;
	*)
		err "unknown role '$role'"
		usage
		;;
	esac

	precreate_dirs
	backup_skel
	run_stow
	write_role_marker "$role"
	write_gitconfig_stub
	install_mise
	activate_mise
	mise_install
	clone_tpm
	install_tpm_plugins
	install_nvim_plugins
	install_zinit
	write_theme_default
	# TODO(theme-switch-expansion ticket 05): once `theme-switch` gains its
	# render-only entry point, invoke it here UNCONDITIONALLY (outside the
	# create-if-absent mode guard above) to regenerate every app's color
	# fragment, so a fresh Desktop's waybar/zathura configs find their
	# @import/include targets on the first sway launch. Deferred until that
	# entry point exists; see
	# .scratch/roles-bootstrap-deployment/issues/04-bootstrap-theme-fragment-generation.md
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
