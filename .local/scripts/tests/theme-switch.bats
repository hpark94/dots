#!/usr/bin/env bats

setup() {
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
	SCRIPT="$BATS_TEST_DIRNAME/../theme-switch"
	source "$SCRIPT"
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
