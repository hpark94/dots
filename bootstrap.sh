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

# theme-switch lives in the repo (and is stowed onto PATH), but bootstrap's own
# non-interactive process may not have the stowed scripts dir on PATH, so we call
# it by its repo path. A function so the bats suite can point it at a stub.
theme_switch_bin() {
	echo "$REPO_DIR/.local/scripts/theme-switch"
}

# mise may have just been installed into a dir that bootstrap's non-interactive
# process does not have on PATH, so fall back to where the installer puts it.
mise_bin() {
	if command -v mise >/dev/null 2>&1; then
		echo mise
	else
		echo "$HOME/.local/bin/mise"
	fi
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
	eval "$("$(mise_bin)" activate bash --shims)"
}

# 6c. Abort before the multi-minute install unless mise can resolve a GitHub API
#     token: unauthenticated, GitHub allows 60 requests/hour, which mise blows
#     through partway and then skips the remaining tools without failing loudly.
require_github_token() {
	# The env sources come first, mirroring mise's own precedence, and they also
	# keep this gate usable on a retrofit machine whose older mise has no `token`
	# subcommand: there the command below would exit nonzero and abort falsely.
	if [[ -n "${MISE_GITHUB_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" || -n "${GITHUB_API_TOKEN:-}" ]]; then
		return 0
	fi
	# Covers mise's remaining sources, above all a gh CLI login. --raw is what
	# makes the exit status meaningful (plain `mise token github` exits 0 and
	# prints "(none)"); its stdout is dropped so no token reaches the log.
	if "$(mise_bin)" token github --raw >/dev/null 2>&1; then
		return 0
	fi
	err "no GitHub API token; mise would hit GitHub's 60 requests/hour unauthenticated limit and silently skip tools"
	printf 'Set GITHUB_TOKEN and re-run: a classic PAT with no scopes suffices and raises the limit to 5000/hour.\n' >&2
	exit 1
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

# 10b. Rebuild bat's theme cache so the tracked custom themes (hp_dark/hp_light
#      under .config/bat/themes/) register; without it bat warns "Unknown theme
#      'hp_dark', using default" and silently falls back to a built-in theme.
#      Same "make a tracked asset take effect" category as tpm/nvim/zinit, and
#      idempotent. Guarded on bat's presence, matching install_zinit's zsh guard.
build_bat_cache() {
	if command -v bat >/dev/null 2>&1; then
		bat cache --build
	fi
}

# 11a. Write a default Theme Mode only if absent (never resets a live mode on a
#      retrofit run); a cold machine renders light, matching nvim's own fallback.
write_theme_default() {
	local mode_file
	mode_file=$(theme_state_file)
	if [[ -e "$mode_file" ]]; then
		return 0
	fi
	mkdir -p "$(dirname "$mode_file")"
	printf '%s' light >"$mode_file"
}

# 11b. Regenerate every app's Generated Config fragment for the resolved mode,
#      unconditionally every run. The mode value above is create-if-absent, but
#      the derived fragments are safe to regenerate and MUST exist before a
#      Desktop's first sway launch: waybar's and zathura's tracked configs
#      hard-fail to parse when their @import/include target is missing. Uses
#      theme-switch's gate-free --render entry point, which never touches the
#      Role Marker and whose live apply_* steps all self-guard, so it exits 0
#      here even with no compositor attached.
render_theme_fragments() {
	local mode
	mode=$(<"$(theme_state_file)")
	"$(theme_switch_bin)" --render "$mode"
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
	require_github_token
	mise_install
	clone_tpm
	install_tpm_plugins
	install_nvim_plugins
	install_zinit
	build_bat_cache
	write_theme_default
	render_theme_fragments
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
