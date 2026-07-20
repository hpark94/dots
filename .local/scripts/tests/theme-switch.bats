#!/usr/bin/env bats

setup() {
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
	export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
	unset SWAYSOCK
	SCRIPT="$BATS_TEST_DIRNAME/../theme-switch"
	source "$SCRIPT"

	mkdir -p "$XDG_CONFIG_HOME/theme"
	{
		for i in $(seq 0 15); do
			printf 'color%d=#0000%02x\n' "$i" "$i"
		done
		printf 'bg=#f00001\n'
		printf 'fg=#f00002\n'
		printf 'selection_bg=#f00003\n'
		printf 'selection_fg=#f00004\n'
	} >"$XDG_CONFIG_HOME/theme/hp_light.sh"
	{
		for i in $(seq 0 15); do
			printf 'color%d=#1000%02x\n' "$i" "$i"
		done
		printf 'bg=#d00001\n'
		printf 'fg=#d00002\n'
		printf 'selection_bg=#d00003\n'
		printf 'selection_fg=#d00004\n'
	} >"$XDG_CONFIG_HOME/theme/hp_dark.sh"
}

@test "resolve_mode dark returns dark" {
	run resolve_mode dark
	[ "$status" -eq 0 ]
	[ "$output" = "dark" ]
}

@test "resolve_mode light returns light" {
	run resolve_mode light
	[ "$status" -eq 0 ]
	[ "$output" = "light" ]
}

@test "resolve_mode rejects an invalid argument" {
	run resolve_mode bogus
	[ "$status" -ne 0 ]
}

@test "resolve_mode toggle with no existing state defaults to dark" {
	run resolve_mode toggle
	[ "$output" = "dark" ]
}

@test "resolve_mode toggle flips from dark to light" {
	write_state dark
	run resolve_mode toggle
	[ "$output" = "light" ]
}

@test "resolve_mode toggle flips from light to dark" {
	write_state light
	run resolve_mode toggle
	[ "$output" = "dark" ]
}

@test "write_state persists mode to the state file" {
	write_state dark
	[ "$(cat "$XDG_STATE_HOME/theme/mode")" = "dark" ]
}

@test "notify_mode does not error when notify-send is unavailable" {
	mkdir -p "$BATS_TEST_TMPDIR/empty-bin"
	run "$(command -v bash)" -c "PATH='$BATS_TEST_TMPDIR/empty-bin'; source '$SCRIPT'; notify_mode dark"
	[ "$status" -eq 0 ]
}

@test "main persists state and notifies" {
	mkdir -p "$BATS_TEST_TMPDIR/stub-bin"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/stub-bin/notify-send"
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/notify-send"
	PATH="$BATS_TEST_TMPDIR/stub-bin:$PATH"
	main dark
	[ "$(cat "$XDG_STATE_HOME/theme/mode")" = "dark" ]
}

@test "main toggle flips the persisted mode" {
	mkdir -p "$BATS_TEST_TMPDIR/stub-bin"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/stub-bin/notify-send"
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/notify-send"
	PATH="$BATS_TEST_TMPDIR/stub-bin:$PATH"
	main dark
	main toggle
	[ "$(cat "$XDG_STATE_HOME/theme/mode")" = "light" ]
}

@test "generate_foot sets initial-color-theme to the requested mode" {
	generate_foot dark "$BATS_TEST_TMPDIR/out"
	grep -qx "initial-color-theme=dark" "$BATS_TEST_TMPDIR/out/foot-colors.ini"

	generate_foot light "$BATS_TEST_TMPDIR/out"
	grep -qx "initial-color-theme=light" "$BATS_TEST_TMPDIR/out/foot-colors.ini"
}

@test "generate_foot writes both colors-light and colors-dark blocks with # stripped, regardless of mode" {
	generate_foot dark "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/foot-colors.ini"

	[[ "$output" == *"[colors-light]"* ]]
	[[ "$output" == *"background=f00001"* ]]
	[[ "$output" == *"foreground=f00002"* ]]
	[[ "$output" == *"regular0=000000"* ]]
	[[ "$output" == *"bright7=00000f"* ]]
	[[ "$output" == *"selection-foreground=f00004"* ]]
	[[ "$output" == *"selection-background=f00003"* ]]

	[[ "$output" == *"[colors-dark]"* ]]
	[[ "$output" == *"background=d00001"* ]]
	[[ "$output" == *"regular3=100003"* ]]
	[[ "$output" == *"bright0=100008"* ]]
}

@test "generate_sway writes client.focused/focused_inactive from the light palette" {
	generate_sway light "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/sway-colors.conf"
	[ "${lines[0]}" = "client.focused #00000b #00000b #ffffff #00000b #00000b" ]
	[ "${lines[1]}" = "client.focused_inactive #000008 #000008 #ffffff #000008 #000008" ]
}

@test "generate_sway writes client.focused/focused_inactive from the dark palette" {
	generate_sway dark "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/sway-colors.conf"
	[ "${lines[0]}" = "client.focused #10000b #10000b #ffffff #10000b #10000b" ]
	[ "${lines[1]}" = "client.focused_inactive #100008 #100008 #ffffff #100008 #100008" ]
}

@test "generate_ghostty writes only a theme line matching the mode" {
	generate_ghostty dark "$BATS_TEST_TMPDIR/out"
	[ "$(cat "$BATS_TEST_TMPDIR/out/ghostty-theme.conf")" = 'theme = "hp_dark"' ]

	generate_ghostty light "$BATS_TEST_TMPDIR/out"
	[ "$(cat "$BATS_TEST_TMPDIR/out/ghostty-theme.conf")" = 'theme = "hp_light"' ]
}

@test "apply_foot does not error when no foot process is running" {
	run apply_foot dark
	[ "$status" -eq 0 ]
}

@test "apply_sway does not error and skips live commands when SWAYSOCK is unset" {
	run apply_sway dark
	[ "$status" -eq 0 ]
}

@test "generate_tmux writes status/window/message/mode styling from the light palette" {
	generate_tmux light "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/tmux-colors.conf"
	[[ "$output" == *'set -g window-status-style "fg=#000004"'* ]]
	[[ "$output" == *'set -g window-status-current-style "fg=#f00001,bold,bg=#000004"'* ]]
	[[ "$output" == *'set -g display-panes-colour "#000004"'* ]]
	[[ "$output" == *'set -g display-panes-active-colour "#000003"'* ]]
	[[ "$output" == *'set -g status-style "fg=#f00002,bg=#f00001"'* ]]
	[[ "$output" == *'set -g status-left "#[fg=#000004,bold] #S #[default] "'* ]]
	[[ "$output" == *'set -g status-right "#[fg=#f00002] %H:%M #[fg=#000004,bold] #H "'* ]]
	[[ "$output" == *'set -g message-style "fg=#000005"'* ]]
	[[ "$output" == *'set -g mode-style "bg=#00000c"'* ]]
}

@test "generate_tmux writes status/window/message/mode styling from the dark palette" {
	generate_tmux dark "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/tmux-colors.conf"
	[[ "$output" == *'set -g window-status-style "fg=#100004"'* ]]
	[[ "$output" == *'set -g display-panes-active-colour "#100003"'* ]]
	[[ "$output" == *'set -g mode-style "bg=#10000c"'* ]]
}

@test "apply_tmux does not error when no tmux server is running" {
	run apply_tmux dark
	[ "$status" -eq 0 ]
}

@test "apply_gtk does not error when gsettings is unavailable" {
	mkdir -p "$BATS_TEST_TMPDIR/empty-bin"
	run "$(command -v bash)" -c "PATH='$BATS_TEST_TMPDIR/empty-bin'; source '$SCRIPT'; apply_gtk dark"
	[ "$status" -eq 0 ]
}

@test "generate_shell_env writes FZF_DEFAULT_OPTS and BAT_THEME for the light palette" {
	generate_shell_env light "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/shell-env.sh"
	[[ "$output" == *"export FZF_DEFAULT_OPTS='--color=fg:#f00002,bg:#f00001,hl:#f00002 --color=fg+:#f00002,bg+:#f00003,hl+:#f00002 --color=info:#000004,prompt:#000005,pointer:#000001 --color=marker:#000002,spinner:#000005,header:#000003'"* ]]
	[[ "$output" == *"export BAT_THEME=light"* ]]
}

@test "generate_shell_env writes FZF_DEFAULT_OPTS and BAT_THEME for the dark palette" {
	generate_shell_env dark "$BATS_TEST_TMPDIR/out"
	run cat "$BATS_TEST_TMPDIR/out/shell-env.sh"
	[[ "$output" == *"export FZF_DEFAULT_OPTS='--color=fg:#d00002,bg:#d00001,hl:#d00002 --color=fg+:#d00002,bg+:#d00003,hl+:#d00002 --color=info:#100004,prompt:#100005,pointer:#100001 --color=marker:#100002,spinner:#100005,header:#100003'"* ]]
	[[ "$output" == *"export BAT_THEME=dark"* ]]
}
