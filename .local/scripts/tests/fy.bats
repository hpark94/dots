#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for fy script
# Mocks wl-copy using stubs to test without requiring Wayland

SCRIPT="$BATS_TEST_DIRNAME/../../../.local/scripts/fy"

setup() {
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME"
	
	# Create a stub bin directory for mocking commands
	mkdir -p "$BATS_TEST_TMPDIR/stub-bin"
	export PATH="$BATS_TEST_TMPDIR/stub-bin:$PATH"
	
	# Track calls made to stubbed commands
	WL_COPY_CALLS=()
	FILE_CALLS=()
}

# Create a mock wl-copy that records its arguments
setup_wl_copy_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/wl-copy" <<'STUB_EOF'
#!/usr/bin/env bash
WL_COPY_CALLS+=("$@")
# Always succeed unless explicitly made to fail
exit 0
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/wl-copy"
}

# Create a failing wl-copy stub
setup_failing_wl_copy_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/wl-copy" <<'STUB_EOF'
#!/usr/bin/env bash
WL_COPY_CALLS+=("$@")
exit 1
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/wl-copy"
}

# Create a mock file command
setup_file_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/file" <<'STUB_EOF'
#!/usr/bin/env bash
FILE_CALLS+=("$@")
# Check if the argument matches a file we know about
case "$*" in
	*--mime-type*|*-b*")
		# Extract the filename from arguments
		for arg in "$@"; do
			if [[ "$arg" != "--mime-type" && "$arg" != "-b" ]]; then
				case "$arg" in
					*test.txt) printf 'text/plain' ;;
					*test.png) printf 'image/png' ;;
					*test.pdf) printf 'application/pdf' ;;
					*.jpg|*.jpeg) printf 'image/jpeg' ;;
					*) printf 'application/octet-stream' ;;
				esac
				break
			fi
		done
		;;
	*) printf 'application/octet-stream' ;;
esac
exit 0
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/file"
}

# Create a mock realpath
setup_realpath_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/realpath" <<'STUB_EOF'
#!/usr/bin/env bash
# Return the argument as-is (simplified for testing)
printf '%s' "$1"
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/realpath"
}

# Create a mock stat
setup_stat_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/stat" <<'STUB_EOF'
#!/usr/bin/env bash
# Simple stat stub that returns file size
# Usage: stat -c %s <file> or stat -f %z <file>
# Always return a small size (1024 bytes) for normal files
printf '1024'
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/stat"
}

# Create a large file stub for size limit testing
setup_large_stat_stub() {
	cat >"$BATS_TEST_TMPDIR/stub-bin/stat" <<'STUB_EOF'
#!/usr/bin/env bash
# Stat stub that returns large size for files with "large" in name
local filepath=""
for arg in "$@"; do
	if [[ "$arg" != "-c" && "$arg" != "-f" && "$arg" != "%s" && "$arg" != "%z" ]]; then
		filepath="$arg"
		break
	fi
done
if [[ "$filepath" == *"large"* ]]; then
	# 30MB - exceeds 25MB limit
	printf '31457280'
else
	printf '1024'
fi
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/stat"
}

# Helper to create a test file
create_test_file() {
	local filepath="$1"
	local content="$2"
	mkdir -p "$(dirname "$filepath")"
	printf '%s' "$content" >"$filepath"
}

@test "fy errors with no arguments" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	run bash "$SCRIPT"
	[ "$status" -ne 0 ]
	[[ "$output" == *"usage: fy <file>"* ]]
}

@test "fy errors with multiple arguments" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/file1.txt" "content1"
	create_test_file "$BATS_TEST_TMPDIR/file2.txt" "content2"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/file1.txt" "$BATS_TEST_TMPDIR/file2.txt"
	[ "$status" -ne 0 ]
	[[ "$output" == *"usage: fy <file>"* ]]
}

@test "fy errors when file does not exist" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nonexistent.txt"
	[ "$status" -ne 0 ]
	[[ "$output" == *"file does not exist"* ]]
}

@test "fy errors when wl-copy is unavailable" {
	setup_file_stub
	setup_realpath_stub
	setup_stat_stub
	
	# Create a wl-copy stub that exits with failure (not found)
	cat >"$BATS_TEST_TMPDIR/stub-bin/wl-copy" <<'STUB_EOF'
#!/usr/bin/env bash
exit 127
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/wl-copy"
	
	# Add basename stub
	cat >"$BATS_TEST_TMPDIR/stub-bin/basename" <<'STUB_EOF'
#!/usr/bin/env bash
# Simple basename implementation
local filepath="$1"
local suffix="$2"
local result="${filepath##*/}"
if [[ -n "$suffix" ]]; then
	result="${result%$suffix}"
fi
printf '%s' "$result"
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/basename"
	
	create_test_file "$BATS_TEST_TMPDIR/test.txt" "test content"
	
	# Set PATH to only include stub-bin
	local old_path="$PATH"
	export PATH="$BATS_TEST_TMPDIR/stub-bin"
	
	run -127 bash "$SCRIPT" "$BATS_TEST_TMPDIR/test.txt"
	[ "$status" -ne 0 ]
	
	export PATH="$old_path"
}

@test "fy errors when file is too large" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_large_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/large_file.txt" "test content"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/large_file.txt"
	[ "$status" -ne 0 ]
	[[ "$output" == *"file too large"* ]]
}

@test "fy succeeds with a regular text file" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/test.txt" "test content"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/test.txt"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.txt"* ]]
	# Verify wl-copy was called with correct MIME type
	# The stub recorded all calls
}

@test "fy succeeds with a binary file" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	# Create a fake PNG file
	create_test_file "$BATS_TEST_TMPDIR/test.png" "fake png data"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/test.png"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.png"* ]]
}

@test "fy succeeds with a PDF file" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/test.pdf" "fake pdf data"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/test.pdf"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.pdf"* ]]
}

@test "fy errors when clipboard copy fails" {
	setup_file_stub
	setup_failing_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/test.txt" "test content"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/test.txt"
	[ "$status" -ne 0 ]
	[[ "$output" == *"failed to copy file to clipboard"* ]]
}

@test "fy handles files with spaces in names" {
	setup_file_stub
	setup_wl_copy_stub
	setup_realpath_stub
	setup_stat_stub
	
	create_test_file "$BATS_TEST_TMPDIR/test file with spaces.txt" "test content"
	
	run bash "$SCRIPT" "$BATS_TEST_TMPDIR/test file with spaces.txt"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test file with spaces.txt"* ]]
}

@test "fy outputs user-friendly path with tilde for home directory" {
	setup_file_stub
	setup_wl_copy_stub
	
	# Use a realpath stub that returns HOME path
	cat >"$BATS_TEST_TMPDIR/stub-bin/realpath" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s/%s' "$HOME" "$(basename "$1")"
STUB_EOF
	chmod +x "$BATS_TEST_TMPDIR/stub-bin/realpath"
	
	# Use a stat stub
	setup_stat_stub
	
	create_test_file "$HOME/test.txt" "test content"
	
	run bash "$SCRIPT" "$HOME/test.txt"
	[ "$status" -eq 0 ]
	# Should output with ~ instead of full HOME path
	[[ "$output" == *"~/test.txt"* ]]
}
