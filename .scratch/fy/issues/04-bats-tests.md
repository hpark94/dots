# 04 — BATS Test Suite for fy and fp

**What to build:** BATS suites for `fy` (`.local/scripts/tests/fy.bats`) and for `fp`'s new reference branch (`.local/scripts/tests/fp.bats`). Stub `wl-copy`/`wl-paste` on PATH using the `bootstrap.bats` pattern. The `wl-copy` stub records its args and stdin to files on disk so assertions survive the `run bash "$SCRIPT"` subshell and can inspect the exact clipboard payload.

**Blocked by:** 01 — Core fy Script

**Status:** ready-for-agent

- [ ] Test files exist at `.local/scripts/tests/fy.bats` and `.local/scripts/tests/fp.bats`
- [ ] fy success: one-arg copy writes `text/uri-list` with payload `file://<encoded abs path>\r\n`
- [ ] fy success: filename with a space is percent-encoded (`%20`)
- [ ] fy success: stdout is the tilde-collapsed path
- [ ] fy error: zero args
- [ ] fy error: more than one arg
- [ ] fy error: non-existent file
- [ ] fy error: `wl-copy` unavailable (absent from PATH)
- [ ] fy error: `wl-copy` fails (stub returns non-zero)
- [ ] fp: reconstructs a file from a `x-special/gnome-copied-files` reference (still valid for real file managers)
- [ ] fp: decodes a percent-encoded space in that reference
- [ ] Roundtrip: fy's `text/uri-list` payload feeds fp's stubbed `wl-paste` and reproduces the file (space in name) by checksum
- [ ] Stubbing pattern consistent with `bootstrap.bats`
- [ ] All tests pass with `bats .local/scripts/tests/`
