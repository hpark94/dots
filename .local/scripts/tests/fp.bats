#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for fp's x-special/gnome-copied-files branch. Mocks wl-paste
# with a stub driven by files on disk: one lists the offered types, one holds the
# gnome-copied-files payload. This mirrors what fy writes to the clipboard.

SCRIPT="$BATS_TEST_DIRNAME/../../../.local/scripts/fp"

setup() {
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME"
	mkdir -p "$BATS_TEST_TMPDIR/stub-bin"
	export PATH="$BATS_TEST_TMPDIR/stub-bin:$PATH"
	WL_PASTE_TYPES="$BATS_TEST_TMPDIR/wl-paste.types"
	WL_PASTE_GNOME="$BATS_TEST_TMPDIR/wl-paste.gnome"
	WL_PASTE_URILIST="$BATS_TEST_TMPDIR/wl-paste.urilist"
}

# wl-paste stub: `--list-types` prints the types file; `--type <t>` prints the
# matching payload file (gnome-copied-files and uri-list are wired up).
setup_wl_paste_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/wl-paste" <<STUB_EOF
#!/usr/bin/env bash
case "\$1" in
--list-types) cat "$WL_PASTE_TYPES" ;;
--type)
	case "\$2" in
	x-special/gnome-copied-files) cat "$WL_PASTE_GNOME" ;;
	text/uri-list) cat "$WL_PASTE_URILIST" ;;
	*) exit 1 ;;
	esac
	;;
esac
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/wl-paste"
}

@test "fp reconstructs a file from a gnome-copied-files reference" {
	setup_wl_paste_stub
	local src="$BATS_TEST_TMPDIR/src/note.txt"
	mkdir -p "$(dirname "$src")"
	printf 'hello' >"$src"
	printf 'x-special/gnome-copied-files\n' >"$WL_PASTE_TYPES"
	printf 'copy\nfile://%s\n' "$src" >"$WL_PASTE_GNOME"

	mkdir -p "$BATS_TEST_TMPDIR/dst"
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/dst"
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/dst/note.txt" ]
	[ "$(cat "$BATS_TEST_TMPDIR/dst/note.txt")" = "hello" ]
}

@test "fp decodes a percent-encoded space in a gnome reference" {
	setup_wl_paste_stub
	local src="$BATS_TEST_TMPDIR/src/my note.txt"
	mkdir -p "$(dirname "$src")"
	printf 'spaced' >"$src"
	printf 'x-special/gnome-copied-files\n' >"$WL_PASTE_TYPES"
	printf 'copy\nfile://%s/src/my%%20note.txt\n' "$BATS_TEST_TMPDIR" >"$WL_PASTE_GNOME"

	mkdir -p "$BATS_TEST_TMPDIR/dst"
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/dst"
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/dst/my note.txt" ]
	[ "$(cat "$BATS_TEST_TMPDIR/dst/my note.txt")" = "spaced" ]
}

# Stub-level roundtrip: run fy to produce the text/uri-list payload, feed it to
# fp's stubbed wl-paste, and confirm the reconstructed file matches by checksum.
# The space in the name proves fy's encode and fp's decode line up.
@test "fy payload round-trips through fp" {
	local fy="$BATS_TEST_DIRNAME/../../../.local/scripts/fy"
	local src="$BATS_TEST_TMPDIR/src/data file.bin"
	mkdir -p "$(dirname "$src")"
	head -c 4096 /dev/urandom >"$src"

	# wl-copy stub captures the payload fy writes.
	local captured="$BATS_TEST_TMPDIR/captured"
	cat >"$BATS_TEST_TMPDIR/stub-bin/wl-copy" <<STUB_EOF
#!/usr/bin/env bash
cat >"$captured"
exit 0
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/wl-copy"

	run bash "$fy" "$src"
	[ "$status" -eq 0 ]

	# Feed the captured payload into fp via the wl-paste stub as text/uri-list.
	setup_wl_paste_stub
	printf 'text/uri-list\n' >"$WL_PASTE_TYPES"
	cp "$captured" "$WL_PASTE_URILIST"

	mkdir -p "$BATS_TEST_TMPDIR/dst"
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/dst"
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/dst/data file.bin" ]
	cmp "$src" "$BATS_TEST_TMPDIR/dst/data file.bin"
}
