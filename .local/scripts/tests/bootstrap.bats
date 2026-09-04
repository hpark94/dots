#!/usr/bin/env bats

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../../bootstrap.sh"
    export HOME="${BATS_TEST_TMPDIR}/home"
    export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
    export XDG_RUNTIME_DIR="${BATS_TEST_TMPDIR}/run"
    mkdir -p "${HOME}"
    source "${SCRIPT}"
}

# Put a failing stub for the named commands first on PATH, so a test proves an
# external command is never reached: if a guard is broken, the stub aborts it.
failing_stubs() {
    local cmd
    mkdir -p "${BATS_TEST_TMPDIR}/stub-bin"
    for cmd in "$@"; do
        printf '#!/usr/bin/env bash\nexit 1\n' >"${BATS_TEST_TMPDIR}/stub-bin/${cmd}"
        chmod +x "${BATS_TEST_TMPDIR}/stub-bin/${cmd}"
    done
}

@test "main errors with no argument" {
    run main
    [ "${status}" -ne 0 ]
}

@test "main errors with an unknown role" {
    run main laptop
    [ "${status}" -ne 0 ]
}

@test "main errors with extra arguments" {
    run main desktop headless
    [ "${status}" -ne 0 ]
}

@test "precreate_dirs creates the shared XDG container dirs" {
    precreate_dirs
    [ -d "${HOME}/.config" ]
    [ -d "${HOME}/.local" ]
    [ -d "${HOME}/.local/bin" ]
}

@test "mask_wm_units masks the units sway starts on its own" {
    mask_wm_units
    [ "$(readlink "${HOME}/.config/systemd/user/swaync.service")" = /dev/null ]
    [ "$(readlink "${HOME}/.config/systemd/user/waybar.service")" = /dev/null ]
}

@test "mask_wm_units is a no-op on a second run" {
    mask_wm_units
    run mask_wm_units
    [ "${status}" -eq 0 ]
    [ "$(readlink "${HOME}/.config/systemd/user/waybar.service")" = /dev/null ]
}

@test "mask_wm_units never reaches the user manager when no session is running" {
    failing_stubs systemctl
    PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run mask_wm_units
    [ "${status}" -eq 0 ]
}

@test "backup_skel backs up a real skel file" {
    printf 'original\n' >"${HOME}/.zshrc"
    backup_skel
    [ ! -e "${HOME}/.zshrc" ]
    [ -f "${HOME}/.zshrc.bak" ]
}

@test "backup_skel leaves an already-stowed symlink alone" {
    printf 'real\n' >"${HOME}/target"
    ln -s "${HOME}/target" "${HOME}/.zshrc"
    backup_skel
    [ -L "${HOME}/.zshrc" ]
    [ ! -e "${HOME}/.zshrc.bak" ]
}

@test "write_role_marker writes the role when the marker is absent" {
    write_role_marker desktop
    [ "$(cat "$(role_marker_file)")" = "desktop" ]
}

@test "write_role_marker keeps an existing marker untouched" {
    mkdir -p "$(dirname "$(role_marker_file)")"
    printf 'headless\n' >"$(role_marker_file)"
    write_role_marker desktop
    [ "$(cat "$(role_marker_file)")" = "headless" ]
}

@test "write_gitconfig_stub writes the include stub when absent" {
    write_gitconfig_stub
    grep -q '\[include\]' "${HOME}/.gitconfig"
    grep -q 'path = ~/.gitconfig.shared' "${HOME}/.gitconfig"
}

@test "write_gitconfig_stub never overwrites an existing gitconfig" {
    printf 'CUSTOM\n' >"${HOME}/.gitconfig"
    write_gitconfig_stub
    [ "$(cat "${HOME}/.gitconfig")" = "CUSTOM" ]
}

@test "install_mise skips the installer when mise is already present" {
    failing_stubs curl
    printf '#!/usr/bin/env bash\nexit 0\n' >"${BATS_TEST_TMPDIR}/stub-bin/mise"
    chmod +x "${BATS_TEST_TMPDIR}/stub-bin/mise"
    PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run install_mise
    [ "${status}" -eq 0 ]
}

# Put a mise stub exiting with the given status in the given dir, standing in
# for the `mise token github --raw` probe. It records its arguments so a test
# can pin the invocation, and its absence proves mise was never reached.
stub_mise() {
    local dir=$1 code=$2
    mkdir -p "${dir}"
    cat >"${dir}/mise" <<-EOF
		#!/usr/bin/env bash
		printf '%s\n' "\$*" >>"\$BATS_TEST_TMPDIR/mise-args"
		exit ${code}
	EOF
    chmod +x "${dir}/mise"
}

# The suite runs on developer machines that very likely export a token, so a
# scenario needing its absence has to clear all three sources itself.
clear_token_env() {
    unset MISE_GITHUB_TOKEN GITHUB_TOKEN GITHUB_API_TOKEN
}

@test "require_github_token accepts an env token without invoking mise" {
    clear_token_env
    # A passing stub: only the missing args file can prove the env source is
    # consulted first, which is what keeps the gate working where mise has no
    # `token` subcommand.
    stub_mise "${BATS_TEST_TMPDIR}/stub-bin" 0
    GITHUB_TOKEN=t PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run require_github_token
    [ "${status}" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/mise-args" ]
}

@test "require_github_token accepts a token mise resolves itself" {
    clear_token_env
    stub_mise "${BATS_TEST_TMPDIR}/stub-bin" 0
    PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run require_github_token
    [ "${status}" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/mise-args")" = "token github --raw" ]
}

@test "require_github_token probes mise by path when it is off PATH" {
    clear_token_env
    stub_mise "${HOME}/.local/bin" 0
    PATH="/usr/bin:/bin" run require_github_token
    [ "${status}" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/mise-args")" = "token github --raw" ]
}

@test "require_github_token fails when no token can be resolved" {
    clear_token_env
    stub_mise "${BATS_TEST_TMPDIR}/stub-bin" 1
    PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run require_github_token
    [ "${status}" -ne 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/mise-args")" = "token github --raw" ]
}

@test "clone_tpm skips cloning when tpm is already present" {
    mkdir -p "$(tpm_dir)"
    failing_stubs git
    PATH="${BATS_TEST_TMPDIR}/stub-bin:${PATH}" run clone_tpm
    [ "${status}" -eq 0 ]
}

@test "write_theme_default writes the light default when absent" {
    write_theme_default
    [ "$(cat "$(theme_state_file)")" = "light" ]
}

@test "write_theme_default keeps an existing mode untouched" {
    mkdir -p "$(dirname "$(theme_state_file)")"
    printf 'dark' >"$(theme_state_file)"
    write_theme_default
    [ "$(cat "$(theme_state_file)")" = "dark" ]
}

@test "build_bat_cache is a no-op when bat is unavailable" {
    # Drop bat off PATH entirely so the presence guard skips the cache build.
    PATH="/nonexistent" run build_bat_cache
    [ "${status}" -eq 0 ]
}

# Record every theme-switch invocation via a stubbed binary path, so we can
# prove --render is called with the resolved mode on every run.
stub_theme_switch() {
    mkdir -p "${BATS_TEST_TMPDIR}/stub-bin"
    cat >"${BATS_TEST_TMPDIR}/stub-bin/theme-switch" <<-'EOF'
		#!/usr/bin/env bash
		printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/render-args"
	EOF
    chmod +x "${BATS_TEST_TMPDIR}/stub-bin/theme-switch"
    theme_switch_bin() { echo "${BATS_TEST_TMPDIR}/stub-bin/theme-switch"; }
}

@test "render_theme_fragments invokes --render with the resolved mode" {
    stub_theme_switch
    mkdir -p "$(dirname "$(theme_state_file)")"
    printf 'dark' >"$(theme_state_file)"
    render_theme_fragments
    [ "$(cat "${BATS_TEST_TMPDIR}/render-args")" = "--render dark" ]
}

@test "render_theme_fragments still runs when the mode file already existed" {
    stub_theme_switch
    # write_theme_default is a no-op here (mode already set), but fragment
    # generation must still happen unconditionally on the same run.
    mkdir -p "$(dirname "$(theme_state_file)")"
    printf 'light' >"$(theme_state_file)"
    write_theme_default
    render_theme_fragments
    [ "$(cat "${BATS_TEST_TMPDIR}/render-args")" = "--render light" ]
}
