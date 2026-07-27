# 04 — BATS Test Suite for fy

**What to build:** A comprehensive BATS test suite for `fy` in `.local/scripts/tests/fy.bats` that verifies success cases and error handling. Tests should mock `wl-copy` using the same stubbing pattern as `bootstrap.bats`.

**Blocked by:** 01 — Core fy Script

**Status:** ready-for-agent

- [ ] Test file exists at `.local/scripts/tests/fy.bats`
- [ ] Tests success case: regular file copied correctly
- [ ] Tests success case: binary file (image) copied correctly
- [ ] Tests error case: non-existent file
- [ ] Tests error case: no arguments provided
- [ ] Tests error case: multiple arguments provided
- [ ] Tests error case: clipboard unavailable (wl-copy missing/failing)
- [ ] Tests error case: file too large (after ticket 03 lands)
- [ ] Uses stubbing pattern consistent with existing `bootstrap.bats`
- [ ] All tests pass when run with `bats .local/scripts/tests/`